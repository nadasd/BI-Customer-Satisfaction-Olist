/* ============================================================
   PROJET BI - DATA MART SATISFACTION CLIENT
   Fichier : load_data.sql
   Objectif : Chargement des tables staging vers les dimensions
              et la table de faits F_AVIS
   SGBD : PostgreSQL
   ============================================================ */


/* ============================================================
   1. NETTOYAGE DES TABLES DECISIONNELLES
   Objectif : éviter les doublons lors d'un rechargement.
   Les tables staging ne sont pas vidées ici car elles sont
   alimentées par Talend.
   ============================================================ */

TRUNCATE TABLE public.f_avis RESTART IDENTITY CASCADE;
TRUNCATE TABLE public.d_client RESTART IDENTITY CASCADE;
TRUNCATE TABLE public.d_produit RESTART IDENTITY CASCADE;
TRUNCATE TABLE public.d_vendeur RESTART IDENTITY CASCADE;
TRUNCATE TABLE public.d_commande RESTART IDENTITY CASCADE;
TRUNCATE TABLE public.d_temps RESTART IDENTITY CASCADE;


/* ============================================================
   2. CHARGEMENT DE LA DIMENSION CLIENT
   Dimension historisée en SCD Type 2
   ============================================================ */

INSERT INTO public.d_client (
    customer_unique_id,
    customer_id,
    customer_city,
    customer_state,
    date_debut,
    date_fin,
    is_current
)
SELECT DISTINCT
    customer_unique_id,
    customer_id,
    LOWER(TRIM(customer_city)) AS customer_city,
    customer_state,
    CURRENT_DATE AS date_debut,
    NULL::DATE AS date_fin,
    TRUE AS is_current
FROM public.stg_customers;


/* ============================================================
   3. CHARGEMENT DE LA DIMENSION PRODUIT
   ============================================================ */

INSERT INTO public.d_produit (
    product_id,
    product_category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
SELECT DISTINCT
    product_id,
    COALESCE(product_category_name, 'Unknown') AS product_category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM public.stg_products;


/* ============================================================
   4. ENRICHISSEMENT DE D_PRODUIT AVEC LA TRADUCTION
   ============================================================ */

UPDATE public.d_produit p
SET product_category_name_english = t.product_category_name_english
FROM public.stg_category_translation t
WHERE p.product_category_name = t.product_category_name;

UPDATE public.d_produit
SET product_category_name_english = COALESCE(
    product_category_name_english,
    product_category_name,
    'Unknown'
);


/* ============================================================
   5. CHARGEMENT DE LA DIMENSION VENDEUR
   ============================================================ */

INSERT INTO public.d_vendeur (
    seller_id,
    seller_city,
    seller_state
)
SELECT DISTINCT
    seller_id,
    LOWER(TRIM(seller_city)) AS seller_city,
    seller_state
FROM public.stg_sellers;


/* ============================================================
   6. CHARGEMENT DE LA DIMENSION COMMANDE
   ============================================================ */

INSERT INTO public.d_commande (
    order_id,
    order_status,
    purchase_date,
    delivered_date,
    estimated_delivery_date
)
SELECT DISTINCT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM public.stg_orders;


/* ============================================================
   7. CHARGEMENT DE LA DIMENSION TEMPS
   ============================================================ */

INSERT INTO public.d_temps (
    date,
    year,
    quarter,
    month,
    day,
    day_of_week
)
SELECT DISTINCT
    DATE(order_purchase_timestamp) AS date,
    EXTRACT(YEAR FROM order_purchase_timestamp)::INT AS year,
    EXTRACT(QUARTER FROM order_purchase_timestamp)::INT AS quarter,
    EXTRACT(MONTH FROM order_purchase_timestamp)::INT AS month,
    EXTRACT(DAY FROM order_purchase_timestamp)::INT AS day,
    EXTRACT(DOW FROM order_purchase_timestamp)::INT AS day_of_week
FROM public.stg_orders
WHERE order_purchase_timestamp IS NOT NULL;


/* ============================================================
   8. CHARGEMENT DE LA TABLE DE FAITS F_AVIS
   Granularité : 1 ligne = 1 item de commande ayant un avis client
   ============================================================ */

INSERT INTO public.f_avis (
    time_key,
    client_key,
    produit_key,
    vendeur_key,
    commande_key,
    review_id,
    order_id,
    review_score,
    review_count,
    days_to_review,
    comment_length,
    delivery_delay_days,
    has_comment,
    is_positive_review,
    is_negative_review
)
SELECT
    t.time_key,
    c.client_key,
    p.produit_key,
    v.vendeur_key,
    co.commande_key,

    r.review_id,
    r.order_id,
    r.review_score,
    1 AS review_count,

    DATE(r.review_creation_date) - DATE(o.order_purchase_timestamp) AS days_to_review,

    COALESCE(LENGTH(r.review_comment_message), 0) AS comment_length,

    CASE
        WHEN o.order_delivered_customer_date IS NULL
          OR o.order_estimated_delivery_date IS NULL
        THEN NULL
        ELSE DATE(o.order_delivered_customer_date) - DATE(o.order_estimated_delivery_date)
    END AS delivery_delay_days,

    CASE
        WHEN r.review_comment_message IS NULL
          OR TRIM(r.review_comment_message) = ''
        THEN 0
        ELSE 1
    END AS has_comment,

    CASE
        WHEN r.review_score >= 4 THEN 1
        ELSE 0
    END AS is_positive_review,

    CASE
        WHEN r.review_score <= 2 THEN 1
        ELSE 0
    END AS is_negative_review

FROM public.stg_reviews r
JOIN public.stg_orders o
    ON r.order_id = o.order_id
JOIN public.stg_order_items oi
    ON o.order_id = oi.order_id
JOIN public.stg_products pr
    ON oi.product_id = pr.product_id
JOIN public.stg_sellers s
    ON oi.seller_id = s.seller_id
JOIN public.stg_customers cu
    ON o.customer_id = cu.customer_id

JOIN public.d_client c
    ON cu.customer_id = c.customer_id
   AND c.is_current = TRUE
JOIN public.d_produit p
    ON pr.product_id = p.product_id
JOIN public.d_vendeur v
    ON s.seller_id = v.seller_id
JOIN public.d_commande co
    ON o.order_id = co.order_id
JOIN public.d_temps t
    ON DATE(o.order_purchase_timestamp) = t.date;


/* ============================================================
   9. CONTROLES QUALITE APRES CHARGEMENT
   ============================================================ */

SELECT 'D_CLIENT' AS table_name, COUNT(*) AS nb_lignes FROM public.d_client
UNION ALL
SELECT 'D_PRODUIT', COUNT(*) FROM public.d_produit
UNION ALL
SELECT 'D_VENDEUR', COUNT(*) FROM public.d_vendeur
UNION ALL
SELECT 'D_COMMANDE', COUNT(*) FROM public.d_commande
UNION ALL
SELECT 'D_TEMPS', COUNT(*) FROM public.d_temps
UNION ALL
SELECT 'F_AVIS', COUNT(*) FROM public.f_avis;

SELECT 
    COUNT(*) AS nb_lignes_faits,
    COUNT(DISTINCT review_id) AS nb_avis_distincts,
    ROUND(AVG(review_score), 2) AS note_moyenne
FROM public.f_avis;

SELECT 
    review_score,
    COUNT(*) AS nombre
FROM public.f_avis
GROUP BY review_score
ORDER BY review_score;
