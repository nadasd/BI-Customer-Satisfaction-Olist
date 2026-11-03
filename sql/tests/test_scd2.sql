BEGIN;
DO $$ DECLARE d DATE; BEGIN SELECT MAX(date_debut)+1 INTO d FROM d_client; PERFORM SET_CONFIG('app.scd_test_date',d::TEXT,FALSE); END $$;
UPDATE stg_customers SET customer_city='Campinas' WHERE customer_unique_id='U1';
CALL load_d_client(current_setting('app.scd_test_date')::DATE);
CALL load_d_client(current_setting('app.scd_test_date')::DATE);
DO $$
DECLARE versions INTEGER; currents INTEGER; old_end DATE; new_start DATE;
BEGIN
 SELECT COUNT(*),COUNT(*) FILTER(WHERE is_current),MAX(date_fin) FILTER(WHERE NOT is_current),MIN(date_debut) FILTER(WHERE is_current)
 INTO versions,currents,old_end,new_start FROM d_client WHERE customer_unique_id='U1';
 IF versions<>2 OR currents<>1 OR old_end<>new_start THEN
  RAISE EXCEPTION 'SCD2 failed: versions %, currents %, old_end %, new_start %',versions,currents,old_end,new_start;
 END IF;
 RAISE NOTICE 'SCD2 change and idempotency assertions passed';
END $$;
ROLLBACK;
