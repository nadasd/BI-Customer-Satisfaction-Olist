TRUNCATE stg_customers,stg_orders,stg_order_items,stg_products,stg_sellers,stg_reviews,stg_category_translation RESTART IDENTITY;
INSERT INTO stg_customers(customer_id,customer_unique_id,customer_zip_code_prefix,customer_city,customer_state) VALUES
 ('C1','U1',1000,'Sao Paulo','SP'),('C2','U2',2000,'Rio','RJ'),('C3','U3',3000,'Belo Horizonte','MG');
INSERT INTO stg_orders(order_id,customer_id,order_status,order_purchase_timestamp,order_delivered_customer_date,order_estimated_delivery_date) VALUES
 ('O1','C1','delivered','2018-01-01','2018-01-12','2018-01-10'),
 ('O2','C2','delivered','2018-01-02','2018-01-08','2018-01-10'),
('O3','C3','shipped','2018-01-03',NULL,'2018-01-15');
-- Simulate a repeated staging ingestion. Warehouse counts and keys must remain stable.
INSERT INTO stg_customers(customer_id,customer_unique_id,customer_zip_code_prefix,customer_city,customer_state)
SELECT customer_id,customer_unique_id,customer_zip_code_prefix,customer_city,customer_state FROM stg_customers WHERE customer_id='C1';
INSERT INTO stg_orders(order_id,customer_id,order_status,order_purchase_timestamp,order_delivered_customer_date,order_estimated_delivery_date)
SELECT order_id,customer_id,order_status,order_purchase_timestamp,order_delivered_customer_date,order_estimated_delivery_date
FROM stg_orders WHERE order_id='O1';
INSERT INTO stg_products(product_id,product_category_name,product_weight_g,product_length_cm,product_height_cm,product_width_cm) VALUES
 ('P1','cat_a',100,10,10,10),('P2','cat_b',200,20,20,20);
INSERT INTO stg_category_translation(product_category_name,product_category_name_english) VALUES ('cat_a','category_a'),('cat_b','category_b');
-- S1 is intentionally duplicated in staging. The dimension must still contain one S1.
INSERT INTO stg_sellers(seller_id,seller_zip_code_prefix,seller_city,seller_state) VALUES
 ('S1',1000,'Sao Paulo','SP'),('S1',1000,'Sao Paulo','SP'),('S2',2000,'Rio','RJ');
INSERT INTO stg_order_items(order_id,order_item_id,product_id,seller_id,shipping_limit_date,price,freight_value) VALUES
 ('O1',1,'P1','S1','2018-01-05',100,10),('O1',2,'P2','S2','2018-01-05',50,5),
 ('O2',1,'P1','S1','2018-01-06',80,8),('O3',1,'P2','S2','2018-01-07',60,6);
-- R1 intentionally belongs to two orders; O1 intentionally has two review events.
INSERT INTO stg_reviews(review_id,order_id,review_score,review_comment_message,review_creation_date,review_answer_timestamp) VALUES
 ('R1','O1',1,'late','2018-01-13','2018-01-14'),('R2','O1',5,NULL,'2018-01-13','2018-01-15'),
 ('R1','O2',4,'good','2018-01-09','2018-01-10'),('R3','O2',4,'good','2018-01-09','2018-01-11');
