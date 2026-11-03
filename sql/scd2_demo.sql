-- Transactional SCD2 demonstration. It leaves the database unchanged.
BEGIN;
CREATE TEMP TABLE demo_customer AS
SELECT customer_unique_id,customer_city,date_debut
FROM d_client WHERE is_current ORDER BY customer_unique_id LIMIT 1;

UPDATE stg_customers s SET customer_city='scd2_demo_city'
FROM demo_customer d WHERE s.customer_unique_id=d.customer_unique_id;

CALL load_d_client((SELECT date_debut+1 FROM demo_customer));

DO $$
DECLARE v_customer VARCHAR(50); v_versions INTEGER; v_current INTEGER;
BEGIN
 SELECT customer_unique_id INTO v_customer FROM demo_customer;
 SELECT COUNT(*),COUNT(*) FILTER(WHERE is_current) INTO v_versions,v_current
 FROM d_client WHERE customer_unique_id=v_customer;
 IF v_versions<2 OR v_current<>1 THEN
  RAISE EXCEPTION 'SCD2 demonstration failed for %, versions %, current %',v_customer,v_versions,v_current;
 END IF;
 RAISE NOTICE 'SCD2 verified for %, versions %, current %',v_customer,v_versions,v_current;
END $$;

SELECT d.* FROM d_client d JOIN demo_customer x USING(customer_unique_id) ORDER BY d.date_debut;
ROLLBACK;
