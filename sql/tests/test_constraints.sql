DO $$
BEGIN
 BEGIN
  INSERT INTO d_vendeur(seller_id,seller_city,seller_state) VALUES ('S1','duplicate','SP');
  RAISE EXCEPTION 'seller unique constraint was not enforced';
 EXCEPTION WHEN unique_violation THEN NULL;
 END;
 BEGIN
  INSERT INTO f_review(review_event_key,review_id,order_id,commande_key,order_time_key,client_key,
   review_score,days_to_review,comment_length,has_comment,is_positive_review,is_negative_review)
  SELECT 'INVALID|O1','INVALID','O1',commande_key,order_time_key,client_key,6,0,0,FALSE,TRUE,FALSE
  FROM f_review LIMIT 1;
  RAISE EXCEPTION 'review score check constraint was not enforced';
 EXCEPTION WHEN check_violation THEN NULL;
 END;
 BEGIN
  INSERT INTO bridge_review_order_item(review_key,order_item_key,allocation_weight)
  VALUES (999999999,999999999,1);
  RAISE EXCEPTION 'bridge foreign keys were not enforced';
 EXCEPTION WHEN foreign_key_violation THEN NULL;
 END;
 RAISE NOTICE 'Constraint enforcement assertions passed';
END $$;