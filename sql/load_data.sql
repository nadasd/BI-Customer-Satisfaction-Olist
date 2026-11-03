BEGIN;

CREATE OR REPLACE PROCEDURE load_d_client(p_effective_date DATE)
LANGUAGE plpgsql
AS $$
BEGIN
  IF p_effective_date IS NULL THEN RAISE EXCEPTION 'effective date is required'; END IF;
  DROP TABLE IF EXISTS tmp_customer_snapshot;
  CREATE TEMP TABLE tmp_customer_snapshot ON COMMIT DROP AS
  WITH ranked AS (
    SELECT c.customer_unique_id, c.customer_id,
           LOWER(TRIM(COALESCE(c.customer_city,'unknown'))) AS customer_city,
           UPPER(TRIM(COALESCE(c.customer_state,'NA'))) AS customer_state,
           MD5(LOWER(TRIM(COALESCE(c.customer_city,'unknown'))) || '|' || UPPER(TRIM(COALESCE(c.customer_state,'NA')))) AS attribute_hash,
           ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id
                              ORDER BY o.order_purchase_timestamp DESC NULLS LAST, c.customer_id DESC, c.stg_id DESC) AS rn
    FROM stg_customers c LEFT JOIN stg_orders o ON o.customer_id=c.customer_id
    WHERE c.customer_unique_id IS NOT NULL AND c.customer_id IS NOT NULL
  ) SELECT customer_unique_id,customer_id,customer_city,customer_state,attribute_hash FROM ranked WHERE rn=1;

  -- A correction arriving again on its opening date updates that version rather than creating a zero-day interval.
  UPDATE d_client d SET customer_id=s.customer_id, customer_city=s.customer_city,
      customer_state=s.customer_state, attribute_hash=s.attribute_hash
  FROM tmp_customer_snapshot s
  WHERE d.customer_unique_id=s.customer_unique_id AND d.is_current
    AND d.date_debut=p_effective_date AND d.attribute_hash<>s.attribute_hash;

  UPDATE d_client d SET date_fin=p_effective_date, is_current=FALSE
  FROM tmp_customer_snapshot s
  WHERE d.customer_unique_id=s.customer_unique_id AND d.is_current
    AND d.date_debut<p_effective_date AND d.attribute_hash<>s.attribute_hash;

  INSERT INTO d_client(customer_unique_id,customer_id,customer_city,customer_state,date_debut,date_fin,is_current,attribute_hash)
  SELECT s.customer_unique_id,s.customer_id,s.customer_city,s.customer_state,p_effective_date,NULL,TRUE,s.attribute_hash
  FROM tmp_customer_snapshot s LEFT JOIN d_client d
    ON d.customer_unique_id=s.customer_unique_id AND d.is_current
  WHERE d.client_key IS NULL;
END;
$$;

CREATE OR REPLACE PROCEDURE refresh_warehouse(
 p_batch_id VARCHAR DEFAULT 'manual',
 p_effective_date DATE DEFAULT CURRENT_DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
 IF p_batch_id IS NULL OR BTRIM(p_batch_id)='' THEN RAISE EXCEPTION 'batch id is required'; END IF;
 IF p_effective_date IS NULL THEN RAISE EXCEPTION 'effective date is required'; END IF;
INSERT INTO etl_batch_audit(batch_id,effective_date,status)
VALUES (p_batch_id,
        p_effective_date,'RUNNING')
ON CONFLICT(batch_id) DO UPDATE SET started_at=CURRENT_TIMESTAMP,finished_at=NULL,status='RUNNING',
 effective_date=EXCLUDED.effective_date,details='{}'::jsonb;

TRUNCATE bridge_review_order_item,f_review,f_order_item,f_order_delivery RESTART IDENTITY;
TRUNCATE d_produit,d_vendeur,d_commande,d_temps RESTART IDENTITY CASCADE;

-- Repeated staging ingestions are tolerated: downstream tables consume the latest source row per business key.
DROP TABLE IF EXISTS tmp_orders_latest;
CREATE TEMP TABLE tmp_orders_latest ON COMMIT DROP AS
SELECT * FROM (
 SELECT o.*,ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY loaded_at DESC,stg_id DESC) AS rn
 FROM stg_orders o WHERE order_id IS NOT NULL
) x WHERE rn=1;
CREATE UNIQUE INDEX ON tmp_orders_latest(order_id);

DROP TABLE IF EXISTS tmp_customers_latest;
CREATE TEMP TABLE tmp_customers_latest ON COMMIT DROP AS
SELECT * FROM (
 SELECT c.*,ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY loaded_at DESC,stg_id DESC) AS rn
 FROM stg_customers c WHERE customer_id IS NOT NULL
) x WHERE rn=1;
CREATE UNIQUE INDEX ON tmp_customers_latest(customer_id);

WITH bounds AS (
 SELECT MIN(d)::DATE AS min_date,MAX(d)::DATE AS max_date FROM (
  SELECT order_purchase_timestamp::DATE d FROM tmp_orders_latest
  UNION ALL SELECT order_estimated_delivery_date::DATE FROM tmp_orders_latest
  UNION ALL SELECT order_delivered_customer_date::DATE FROM tmp_orders_latest
  UNION ALL SELECT review_creation_date::DATE FROM stg_reviews
 ) x WHERE d IS NOT NULL
)
INSERT INTO d_temps(time_key,date,year,quarter,month,day,day_of_week)
SELECT TO_CHAR(g,'YYYYMMDD')::INTEGER,g::DATE,EXTRACT(YEAR FROM g)::INTEGER,
 EXTRACT(QUARTER FROM g)::INTEGER,EXTRACT(MONTH FROM g)::INTEGER,
 EXTRACT(DAY FROM g)::INTEGER,EXTRACT(DOW FROM g)::INTEGER
FROM bounds CROSS JOIN LATERAL GENERATE_SERIES(min_date,max_date,INTERVAL '1 day') g;

WITH ranked AS (
 SELECT p.*,ROW_NUMBER() OVER(PARTITION BY product_id ORDER BY loaded_at DESC,stg_id DESC) rn FROM stg_products p WHERE product_id IS NOT NULL
)
INSERT INTO d_produit(product_id,product_category_name,product_category_name_english,
 product_weight_g,product_length_cm,product_height_cm,product_width_cm)
SELECT p.product_id,COALESCE(p.product_category_name,'unknown'),
 COALESCE(t.product_category_name_english,p.product_category_name,'unknown'),
 p.product_weight_g,p.product_length_cm,p.product_height_cm,p.product_width_cm
FROM ranked p LEFT JOIN (
 SELECT DISTINCT ON(product_category_name) product_category_name,product_category_name_english
 FROM stg_category_translation WHERE product_category_name IS NOT NULL ORDER BY product_category_name,loaded_at DESC,stg_id DESC
) t ON t.product_category_name=p.product_category_name WHERE p.rn=1 ORDER BY p.product_id;

WITH ranked AS (
 SELECT s.*,ROW_NUMBER() OVER(PARTITION BY seller_id ORDER BY loaded_at DESC,stg_id DESC) rn FROM stg_sellers s WHERE seller_id IS NOT NULL
)
INSERT INTO d_vendeur(seller_id,seller_city,seller_state)
SELECT seller_id,LOWER(TRIM(COALESCE(seller_city,'unknown'))),UPPER(TRIM(COALESCE(seller_state,'NA')))
FROM ranked WHERE rn=1 ORDER BY seller_id;

INSERT INTO d_commande(order_id,order_status,purchase_date,delivered_date,estimated_delivery_date)
SELECT order_id,COALESCE(order_status,'unknown'),order_purchase_timestamp,
 order_delivered_customer_date,order_estimated_delivery_date FROM tmp_orders_latest
WHERE order_purchase_timestamp IS NOT NULL ORDER BY order_id;

CALL load_d_client(p_effective_date);

INSERT INTO f_order_delivery(commande_key,order_time_key,client_key,order_id,
 is_delivery_eligible,delivery_variance_days,is_late)
SELECT dc.commande_key,dt.time_key,cl.client_key,o.order_id,
 o.order_delivered_customer_date IS NOT NULL AND o.order_estimated_delivery_date IS NOT NULL,
 CASE WHEN o.order_delivered_customer_date IS NOT NULL AND o.order_estimated_delivery_date IS NOT NULL
      THEN o.order_delivered_customer_date::DATE-o.order_estimated_delivery_date::DATE END,
 CASE WHEN o.order_delivered_customer_date IS NOT NULL AND o.order_estimated_delivery_date IS NOT NULL
      THEN o.order_delivered_customer_date::DATE>o.order_estimated_delivery_date::DATE END
FROM tmp_orders_latest o JOIN d_commande dc ON dc.order_id=o.order_id
JOIN d_temps dt ON dt.date=o.order_purchase_timestamp::DATE
JOIN tmp_customers_latest sc ON sc.customer_id=o.customer_id
JOIN d_client cl ON cl.customer_unique_id=sc.customer_unique_id AND cl.is_current
WHERE o.order_purchase_timestamp IS NOT NULL
ORDER BY o.order_id;

WITH ranked AS (
 SELECT r.*,ROW_NUMBER() OVER(PARTITION BY review_id,order_id
  ORDER BY review_answer_timestamp DESC NULLS LAST,review_creation_date DESC NULLS LAST,stg_id DESC) rn
 FROM stg_reviews r WHERE review_id IS NOT NULL AND order_id IS NOT NULL AND review_score BETWEEN 1 AND 5
)
INSERT INTO f_review(review_event_key,review_id,order_id,commande_key,order_time_key,review_time_key,
 client_key,review_score,days_to_review,comment_length,has_comment,is_positive_review,is_negative_review)
SELECT r.review_id||'|'||r.order_id,r.review_id,r.order_id,dc.commande_key,ot.time_key,rt.time_key,
 cl.client_key,r.review_score,r.review_creation_date::DATE-dc.purchase_date::DATE,
 LENGTH(COALESCE(r.review_comment_message,'')),NULLIF(TRIM(COALESCE(r.review_comment_message,'')),'') IS NOT NULL,
 r.review_score>=4,r.review_score<=2
FROM ranked r JOIN d_commande dc ON dc.order_id=r.order_id
JOIN tmp_orders_latest o ON o.order_id=r.order_id JOIN tmp_customers_latest sc ON sc.customer_id=o.customer_id
JOIN d_client cl ON cl.customer_unique_id=sc.customer_unique_id AND cl.is_current
JOIN d_temps ot ON ot.date=dc.purchase_date::DATE LEFT JOIN d_temps rt ON rt.date=r.review_creation_date::DATE
WHERE r.rn=1 ORDER BY r.review_id,r.order_id;

WITH ranked AS (
 SELECT i.*,ROW_NUMBER() OVER(PARTITION BY order_id,order_item_id ORDER BY loaded_at DESC,stg_id DESC) rn
 FROM stg_order_items i WHERE order_id IS NOT NULL AND order_item_id IS NOT NULL
)
INSERT INTO f_order_item(order_id,order_item_id,commande_key,order_time_key,client_key,
 produit_key,vendeur_key,price,freight_value)
SELECT i.order_id,i.order_item_id,dc.commande_key,dt.time_key,cl.client_key,
 p.produit_key,v.vendeur_key,COALESCE(i.price,0),COALESCE(i.freight_value,0)
FROM ranked i JOIN d_commande dc ON dc.order_id=i.order_id
JOIN tmp_orders_latest o ON o.order_id=i.order_id JOIN tmp_customers_latest sc ON sc.customer_id=o.customer_id
JOIN d_client cl ON cl.customer_unique_id=sc.customer_unique_id AND cl.is_current
JOIN d_temps dt ON dt.date=dc.purchase_date::DATE
JOIN d_produit p ON p.product_id=i.product_id JOIN d_vendeur v ON v.seller_id=i.seller_id
WHERE i.rn=1 ORDER BY i.order_id,i.order_item_id;

INSERT INTO bridge_review_order_item(review_key,order_item_key,allocation_weight)
SELECT r.review_key,i.order_item_key,
 1.0/COUNT(*) OVER(PARTITION BY r.review_key)
FROM f_review r JOIN f_order_item i ON i.order_id=r.order_id;

UPDATE etl_batch_audit SET finished_at=CURRENT_TIMESTAMP,status='SUCCESS',
 details=JSONB_BUILD_OBJECT('reviews',(SELECT COUNT(*) FROM f_review),
  'order_items',(SELECT COUNT(*) FROM f_order_item),'sellers',(SELECT COUNT(*) FROM d_vendeur))
WHERE batch_id=p_batch_id;
END;
$$;

CALL refresh_warehouse(
 COALESCE(NULLIF(current_setting('app.batch_id',TRUE),''),'manual'),
 COALESCE(NULLIF(current_setting('app.effective_date',TRUE),'')::DATE,CURRENT_DATE)
);
COMMIT;