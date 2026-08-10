CREATE TABLE D_TEMPS (
    time_key SERIAL PRIMARY KEY,
    date DATE,
    year INT,
    quarter INT,
    month INT,
    day INT,
    day_of_week INT
);
CREATE TABLE D_CLIENT (
    client_key SERIAL PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    customer_id VARCHAR(50),
    customer_city VARCHAR(100),
    customer_state VARCHAR(10),
    date_debut DATE,
    date_fin DATE,
    is_current BOOLEAN
);
CREATE TABLE D_PRODUIT (
    produit_key SERIAL PRIMARY KEY,
    product_id VARCHAR(50),
    product_category_name VARCHAR(100),
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);
CREATE TABLE D_VENDEUR (
    vendeur_key SERIAL PRIMARY KEY,
    seller_id VARCHAR(50),
    seller_city VARCHAR(100),
    seller_state VARCHAR(10)
);
CREATE TABLE D_COMMANDE (
    commande_key SERIAL PRIMARY KEY,
    order_id VARCHAR(50),
    order_status VARCHAR(50),
    purchase_date TIMESTAMP,
    delivered_date TIMESTAMP,
    estimated_delivery_date TIMESTAMP
);
CREATE TABLE F_AVIS (
    avis_key SERIAL PRIMARY KEY,
    
    time_key INT,
    client_key INT,
    produit_key INT,
    vendeur_key INT,
    commande_key INT,

    review_id VARCHAR(50),
    order_id VARCHAR(50),

    review_score INT,
    review_count INT,
    days_to_review INT,
    comment_length INT,
    delivery_delay_days INT,
    has_comment INT,
    is_positive_review INT,
    is_negative_review INT,

    FOREIGN KEY (time_key) REFERENCES D_TEMPS(time_key),
    FOREIGN KEY (client_key) REFERENCES D_CLIENT(client_key),
    FOREIGN KEY (produit_key) REFERENCES D_PRODUIT(produit_key),
    FOREIGN KEY (vendeur_key) REFERENCES D_VENDEUR(vendeur_key),
    FOREIGN KEY (commande_key) REFERENCES D_COMMANDE(commande_key)
);