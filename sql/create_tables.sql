BEGIN;

-- Staging metadata defaults keep existing Talend outputs compatible.
CREATE TABLE IF NOT EXISTS stg_customers (
 stg_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 customer_id VARCHAR(50), customer_unique_id VARCHAR(50), customer_zip_code_prefix INTEGER,
 customer_city VARCHAR(100), customer_state VARCHAR(10), batch_id VARCHAR(64) NOT NULL DEFAULT 'manual',
 source_file VARCHAR(255), source_row_number INTEGER, loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS stg_orders (
 stg_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 order_id VARCHAR(50), customer_id VARCHAR(50), order_status VARCHAR(50),
 order_purchase_timestamp TIMESTAMP, order_approved_at TIMESTAMP, order_delivered_carrier_date TIMESTAMP,
 order_delivered_customer_date TIMESTAMP, order_estimated_delivery_date TIMESTAMP,
 batch_id VARCHAR(64) NOT NULL DEFAULT 'manual', source_file VARCHAR(255), source_row_number INTEGER,
 loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS stg_order_items (
 stg_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 order_id VARCHAR(50), order_item_id INTEGER, product_id VARCHAR(50), seller_id VARCHAR(50),
 shipping_limit_date TIMESTAMP, price NUMERIC(14,2), freight_value NUMERIC(14,2),
 batch_id VARCHAR(64) NOT NULL DEFAULT 'manual', source_file VARCHAR(255), source_row_number INTEGER,
 loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS stg_products (
 stg_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 product_id VARCHAR(50), product_category_name VARCHAR(100), product_name_lenght INTEGER,
 product_description_lenght INTEGER, product_photos_qty INTEGER, product_weight_g INTEGER,
 product_length_cm INTEGER, product_height_cm INTEGER, product_width_cm INTEGER,
 batch_id VARCHAR(64) NOT NULL DEFAULT 'manual', source_file VARCHAR(255), source_row_number INTEGER,
 loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS stg_sellers (
 stg_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 seller_id VARCHAR(50), seller_zip_code_prefix INTEGER, seller_city VARCHAR(100), seller_state VARCHAR(10),
 batch_id VARCHAR(64) NOT NULL DEFAULT 'manual', source_file VARCHAR(255), source_row_number INTEGER,
 loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS stg_reviews (
 stg_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 review_id VARCHAR(50), order_id VARCHAR(50), review_score INTEGER, review_comment_title TEXT,
 review_comment_message TEXT, review_creation_date TIMESTAMP, review_answer_timestamp TIMESTAMP,
 batch_id VARCHAR(64) NOT NULL DEFAULT 'manual', source_file VARCHAR(255), source_row_number INTEGER,
 loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS stg_category_translation (
 stg_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 product_category_name VARCHAR(100), product_category_name_english VARCHAR(100),
 batch_id VARCHAR(64) NOT NULL DEFAULT 'manual', source_file VARCHAR(255), source_row_number INTEGER,
 loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS etl_batch_audit (
 batch_id VARCHAR(64) PRIMARY KEY, started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 finished_at TIMESTAMPTZ, effective_date DATE NOT NULL,
 status VARCHAR(20) NOT NULL DEFAULT 'RUNNING' CHECK (status IN ('RUNNING','SUCCESS','FAILED')),
 details JSONB NOT NULL DEFAULT '{}'::jsonb
);
CREATE TABLE IF NOT EXISTS d_temps (
 time_key INTEGER PRIMARY KEY, date DATE NOT NULL UNIQUE, year INTEGER NOT NULL,
 quarter INTEGER NOT NULL CHECK (quarter BETWEEN 1 AND 4), month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
 day INTEGER NOT NULL CHECK (day BETWEEN 1 AND 31), day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6)
);
CREATE TABLE IF NOT EXISTS d_client (
 client_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 customer_unique_id VARCHAR(50) NOT NULL, customer_id VARCHAR(50) NOT NULL,
 customer_city VARCHAR(100) NOT NULL, customer_state VARCHAR(10) NOT NULL,
 date_debut DATE NOT NULL, date_fin DATE, is_current BOOLEAN NOT NULL, attribute_hash CHAR(32) NOT NULL,
 CONSTRAINT uq_d_client_version UNIQUE (customer_unique_id,date_debut),
 CONSTRAINT ck_d_client_period CHECK (date_fin IS NULL OR date_fin > date_debut),
 CONSTRAINT ck_d_client_current_end CHECK ((is_current AND date_fin IS NULL) OR (NOT is_current AND date_fin IS NOT NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_d_client_one_current ON d_client(customer_unique_id) WHERE is_current;
CREATE INDEX IF NOT EXISTS ix_d_client_lookup ON d_client(customer_unique_id,date_debut,date_fin);
CREATE TABLE IF NOT EXISTS d_produit (
 produit_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, product_id VARCHAR(50) NOT NULL UNIQUE,
 product_category_name VARCHAR(100) NOT NULL, product_category_name_english VARCHAR(100) NOT NULL,
 product_weight_g INTEGER, product_length_cm INTEGER, product_height_cm INTEGER, product_width_cm INTEGER
);
CREATE TABLE IF NOT EXISTS d_vendeur (
 vendeur_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, seller_id VARCHAR(50) NOT NULL UNIQUE,
 seller_city VARCHAR(100) NOT NULL, seller_state VARCHAR(10) NOT NULL
);
CREATE TABLE IF NOT EXISTS d_commande (
 commande_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, order_id VARCHAR(50) NOT NULL UNIQUE,
 order_status VARCHAR(50) NOT NULL, purchase_date TIMESTAMP NOT NULL,
 delivered_date TIMESTAMP, estimated_delivery_date TIMESTAMP
);
CREATE TABLE IF NOT EXISTS f_order_delivery (
 order_delivery_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 commande_key BIGINT NOT NULL UNIQUE REFERENCES d_commande(commande_key),
 order_time_key INTEGER NOT NULL REFERENCES d_temps(time_key), client_key BIGINT NOT NULL REFERENCES d_client(client_key),
 order_id VARCHAR(50) NOT NULL UNIQUE, is_delivery_eligible BOOLEAN NOT NULL,
 delivery_variance_days INTEGER, is_late BOOLEAN,
 CONSTRAINT ck_delivery_flags CHECK ((is_delivery_eligible AND delivery_variance_days IS NOT NULL AND is_late IS NOT NULL)
  OR (NOT is_delivery_eligible AND delivery_variance_days IS NULL AND is_late IS NULL))
);
CREATE TABLE IF NOT EXISTS f_review (
 review_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, review_event_key VARCHAR(101) NOT NULL UNIQUE,
 review_id VARCHAR(50) NOT NULL, order_id VARCHAR(50) NOT NULL,
 commande_key BIGINT NOT NULL REFERENCES d_commande(commande_key),
 order_time_key INTEGER NOT NULL REFERENCES d_temps(time_key), review_time_key INTEGER REFERENCES d_temps(time_key),
 client_key BIGINT NOT NULL REFERENCES d_client(client_key), review_score INTEGER NOT NULL CHECK (review_score BETWEEN 1 AND 5),
 days_to_review INTEGER, comment_length INTEGER NOT NULL CHECK (comment_length >= 0),
 has_comment BOOLEAN NOT NULL, is_positive_review BOOLEAN NOT NULL, is_negative_review BOOLEAN NOT NULL,
 CONSTRAINT uq_f_review_source_event UNIQUE(review_id,order_id),
 CONSTRAINT ck_f_review_positive CHECK (is_positive_review = (review_score >= 4)),
 CONSTRAINT ck_f_review_negative CHECK (is_negative_review = (review_score <= 2))
);
CREATE TABLE IF NOT EXISTS f_order_item (
 order_item_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 order_id VARCHAR(50) NOT NULL, order_item_id INTEGER NOT NULL CHECK (order_item_id > 0),
 commande_key BIGINT NOT NULL REFERENCES d_commande(commande_key), order_time_key INTEGER NOT NULL REFERENCES d_temps(time_key),
 client_key BIGINT NOT NULL REFERENCES d_client(client_key), produit_key BIGINT NOT NULL REFERENCES d_produit(produit_key),
 vendeur_key BIGINT NOT NULL REFERENCES d_vendeur(vendeur_key), price NUMERIC(14,2) NOT NULL CHECK (price >= 0),
 freight_value NUMERIC(14,2) NOT NULL CHECK (freight_value >= 0),
 CONSTRAINT uq_f_order_item UNIQUE(order_id,order_item_id)
);
CREATE TABLE IF NOT EXISTS bridge_review_order_item (
 review_key BIGINT NOT NULL REFERENCES f_review(review_key) ON DELETE CASCADE,
 order_item_key BIGINT NOT NULL REFERENCES f_order_item(order_item_key) ON DELETE CASCADE,
 allocation_weight NUMERIC(18,12) NOT NULL CHECK (allocation_weight > 0 AND allocation_weight <= 1),
 PRIMARY KEY(review_key,order_item_key)
);
CREATE INDEX IF NOT EXISTS ix_f_review_order_time ON f_review(order_time_key);
CREATE INDEX IF NOT EXISTS ix_f_review_client ON f_review(client_key);
CREATE INDEX IF NOT EXISTS ix_f_order_item_product ON f_order_item(produit_key);
CREATE INDEX IF NOT EXISTS ix_f_order_item_seller ON f_order_item(vendeur_key);
CREATE INDEX IF NOT EXISTS ix_bridge_item ON bridge_review_order_item(order_item_key);

-- Compatibility projection for existing item-level analysis. Correct global KPI use f_review.
DO $$
DECLARE object_kind "char";
BEGIN
 SELECT relkind INTO object_kind FROM pg_class
 WHERE oid=TO_REGCLASS('f_avis');
 IF object_kind='v' THEN EXECUTE 'DROP VIEW f_avis CASCADE';
 ELSIF object_kind IS NOT NULL THEN EXECUTE 'DROP TABLE f_avis CASCADE';
 END IF;
END $$;
CREATE VIEW f_avis AS
SELECT r.review_key AS avis_key, r.order_time_key AS time_key, r.client_key,
 i.produit_key, i.vendeur_key, r.commande_key, r.review_event_key,
 r.review_id, r.order_id, r.review_score, b.allocation_weight AS review_count,
 r.days_to_review, r.comment_length, od.delivery_variance_days AS delivery_delay_days,
 r.has_comment::INTEGER AS has_comment, r.is_positive_review::INTEGER AS is_positive_review,
 r.is_negative_review::INTEGER AS is_negative_review, b.allocation_weight
FROM f_review r
JOIN bridge_review_order_item b ON b.review_key=r.review_key
JOIN f_order_item i ON i.order_item_key=b.order_item_key
JOIN f_order_delivery od ON od.commande_key=r.commande_key;
COMMIT;
