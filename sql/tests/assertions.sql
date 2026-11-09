DO $$
DECLARE n BIGINT; v NUMERIC;
BEGIN
 SELECT COUNT(*) INTO n FROM d_vendeur; IF n<>2 THEN RAISE EXCEPTION 'seller count %, expected 2',n; END IF;
 SELECT COUNT(*)-COUNT(DISTINCT seller_id) INTO n FROM d_vendeur; IF n<>0 THEN RAISE EXCEPTION 'duplicate sellers %',n; END IF;
 SELECT COUNT(*) INTO n FROM f_review; IF n<>4 THEN RAISE EXCEPTION 'review event count %, expected 4',n; END IF;
 SELECT COUNT(*)-COUNT(DISTINCT (review_id,order_id)) INTO n FROM f_review; IF n<>0 THEN RAISE EXCEPTION 'duplicate review events %',n; END IF;
 SELECT COUNT(*) INTO n FROM f_order_item; IF n<>4 THEN RAISE EXCEPTION 'order item count %, expected 4',n; END IF;
 SELECT COUNT(*) INTO n FROM f_order_delivery; IF n<>3 THEN RAISE EXCEPTION 'order delivery count %, expected 3',n; END IF;
 SELECT COUNT(*) INTO n FROM bridge_review_order_item; IF n<>6 THEN RAISE EXCEPTION 'bridge count %, expected 6',n; END IF;
 SELECT COUNT(*) INTO n FROM (SELECT review_key FROM bridge_review_order_item GROUP BY review_key HAVING ABS(SUM(allocation_weight)-1)>0.000000001) x;
 IF n<>0 THEN RAISE EXCEPTION 'bridge weights invalid for % reviews',n; END IF;
 SELECT ROUND(AVG(review_score),2) INTO v FROM f_review; IF v<>3.50 THEN RAISE EXCEPTION 'average score %, expected 3.50',v; END IF;
 SELECT ROUND(100*AVG(is_positive_review::INTEGER),2) INTO v FROM f_review; IF v<>75.00 THEN RAISE EXCEPTION 'positive rate %, expected 75',v; END IF;
 SELECT ROUND(100.0*COUNT(*) FILTER(WHERE is_late)/COUNT(*),2) INTO v FROM f_order_delivery WHERE is_delivery_eligible;
 IF v<>50.00 THEN RAISE EXCEPTION 'late rate %, expected 50',v; END IF;
 SELECT COUNT(*) INTO n FROM d_client WHERE is_current; IF n<>3 THEN RAISE EXCEPTION 'current clients %, expected 3',n; END IF;
 IF EXISTS(SELECT 1 FROM d_client GROUP BY customer_unique_id HAVING COUNT(*) FILTER(WHERE is_current)>1)
 THEN RAISE EXCEPTION 'multiple current SCD rows'; END IF;
 SELECT COUNT(*) INTO n FROM d_client a JOIN d_client b ON a.customer_unique_id=b.customer_unique_id AND a.client_key<b.client_key
  AND DATERANGE(a.date_debut,COALESCE(a.date_fin,'infinity'::DATE),'[)') && DATERANGE(b.date_debut,COALESCE(b.date_fin,'infinity'::DATE),'[)');
 IF n<>0 THEN RAISE EXCEPTION 'overlapping SCD periods %',n; END IF;
 IF EXISTS(SELECT 1 FROM f_review r LEFT JOIN d_client d ON d.client_key=r.client_key WHERE d.client_key IS NULL) THEN RAISE EXCEPTION 'orphan review client'; END IF;
 RAISE NOTICE 'All data quality assertions passed';
END $$;
