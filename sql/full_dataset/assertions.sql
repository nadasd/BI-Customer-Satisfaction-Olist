DO $$
DECLARE
 sellers BIGINT; customers BIGINT; orders BIGINT; items BIGINT; reviews BIGINT; bridge_rows BIGINT;
 stage_review_events BIGINT; avg_score NUMERIC; positive_rate NUMERIC; late_rate NUMERIC;
BEGIN
 SELECT COUNT(*) INTO sellers FROM d_vendeur;
 SELECT COUNT(*) INTO customers FROM d_client WHERE is_current;
 SELECT COUNT(*) INTO orders FROM d_commande;
 SELECT COUNT(*) INTO items FROM f_order_item;
 SELECT COUNT(*) INTO reviews FROM f_review;
 SELECT COUNT(*) INTO bridge_rows FROM bridge_review_order_item;
 SELECT COUNT(*) INTO stage_review_events FROM (
  SELECT review_id,order_id FROM stg_reviews
  WHERE review_id IS NOT NULL AND order_id IS NOT NULL AND review_score BETWEEN 1 AND 5
  GROUP BY review_id,order_id
 ) x;

 IF sellers<>(SELECT COUNT(DISTINCT seller_id) FROM stg_sellers WHERE seller_id IS NOT NULL)
 THEN RAISE EXCEPTION 'Seller dimension does not match distinct staging sellers'; END IF;
 IF sellers<>3095 THEN RAISE EXCEPTION 'Olist seller baseline regression: %, expected 3095',sellers; END IF;
 IF customers<>96096 THEN RAISE EXCEPTION 'Olist customer baseline regression: %, expected 96096',customers; END IF;
 IF orders<>99441 THEN RAISE EXCEPTION 'Olist order baseline regression: %, expected 99441',orders; END IF;
 IF items<>112650 THEN RAISE EXCEPTION 'Olist item baseline regression: %, expected 112650',items; END IF;
 IF reviews<>stage_review_events THEN RAISE EXCEPTION 'Review grain mismatch: fact %, staging events %',reviews,stage_review_events; END IF;
 IF reviews<>98465 THEN RAISE EXCEPTION 'Olist review-event baseline regression: %, expected 98465',reviews; END IF;
 IF bridge_rows<>(SELECT COUNT(*) FROM f_review r JOIN f_order_item i ON i.order_id=r.order_id)
 THEN RAISE EXCEPTION 'Review-item bridge coverage regression'; END IF;
 IF bridge_rows<>112372 THEN RAISE EXCEPTION 'Olist bridge baseline regression: %, expected 112372',bridge_rows; END IF;
 IF EXISTS(SELECT 1 FROM bridge_review_order_item GROUP BY review_key HAVING ABS(SUM(allocation_weight)-1)>0.000000001)
 THEN RAISE EXCEPTION 'Allocation weights do not sum to one'; END IF;
 IF EXISTS(SELECT 1 FROM d_client GROUP BY customer_unique_id HAVING COUNT(*) FILTER(WHERE is_current)<>1)
 THEN RAISE EXCEPTION 'Invalid current SCD2 cardinality'; END IF;
 IF EXISTS(SELECT 1 FROM f_review r LEFT JOIN d_commande d ON d.commande_key=r.commande_key WHERE d.commande_key IS NULL)
 THEN RAISE EXCEPTION 'Orphan review fact'; END IF;

 SELECT ROUND(AVG(review_score),4),ROUND(100*AVG(is_positive_review::INTEGER),4)
 INTO avg_score,positive_rate FROM f_review;
 SELECT ROUND(100.0*COUNT(*) FILTER(WHERE is_late)/NULLIF(COUNT(*),0),4)
 INTO late_rate FROM f_order_delivery WHERE is_delivery_eligible;
 RAISE NOTICE 'Olist full validation passed: sellers=%, customers=%, orders=%, items=%, reviews=%, bridge=%, avg_score=%, positive_rate=% percent, late_rate=% percent',
  sellers,customers,orders,items,reviews,bridge_rows,avg_score,positive_rate,late_rate;
END $$;