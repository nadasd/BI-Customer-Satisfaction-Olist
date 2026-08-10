/* ============================================================
   PROJET BI - DATA MART SATISFACTION CLIENT
   Fichier : queries.sql
   Objectif : Requêtes analytiques OLAP sur F_AVIS
   SGBD : PostgreSQL
   ============================================================ */


/* ============================================================
   0. CONTROLE GENERAL DU DATA MART
   Vérifier que les dimensions et la table de faits sont remplies.
   ============================================================ */

SELECT 'D_CLIENT' AS table_name, COUNT(*) AS nb_lignes FROM d_client
UNION ALL
SELECT 'D_PRODUIT', COUNT(*) FROM d_produit
UNION ALL
SELECT 'D_VENDEUR', COUNT(*) FROM d_vendeur
UNION ALL
SELECT 'D_COMMANDE', COUNT(*) FROM d_commande
UNION ALL
SELECT 'D_TEMPS', COUNT(*) FROM d_temps
UNION ALL
SELECT 'F_AVIS', COUNT(*) FROM f_avis;


/* ============================================================
   1. KPI GLOBALS
   Objectif : mesurer la satisfaction globale.
   Agrégations utilisées : AVG, COUNT DISTINCT, SUM
   ============================================================ */

SELECT 
    COUNT(*) AS nb_lignes_faits,
    COUNT(DISTINCT review_id) AS nb_avis_distincts,
    ROUND(AVG(review_score), 2) AS note_moyenne,
    ROUND(100.0 * SUM(is_positive_review) / COUNT(*), 2) AS taux_avis_positifs,
    ROUND(100.0 * SUM(is_negative_review) / COUNT(*), 2) AS taux_avis_negatifs,
    ROUND(AVG(delivery_delay_days), 2) AS retard_moyen_livraison
FROM f_avis;


/* ============================================================
   2. REPARTITION DES SCORES
   Objectif : analyser la distribution des notes de satisfaction.
   ============================================================ */

SELECT 
    review_score,
    COUNT(*) AS nb_lignes,
    COUNT(DISTINCT review_id) AS nb_avis_distincts
FROM f_avis
GROUP BY review_score
ORDER BY review_score;


/* ============================================================
   3. OLAP TEMPOREL
   Analyse : satisfaction par année et mois.
   Opération : agrégation temporelle.
   Dimensions utilisées : D_TEMPS
   ============================================================ */

SELECT 
    t.year,
    t.month,
    ROUND(AVG(f.review_score), 2) AS note_moyenne,
    COUNT(DISTINCT f.review_id) AS nombre_avis
FROM f_avis f
JOIN d_temps t 
    ON f.time_key = t.time_key
GROUP BY t.year, t.month
ORDER BY t.year, t.month;


/* ============================================================
   4. DRILL-DOWN TEMPOREL
   Analyse : Année → Trimestre → Mois.
   Opération OLAP : Drill-down
   Objectif : passer d’un niveau agrégé vers un niveau plus détaillé.
   ============================================================ */

SELECT 
    t.year,
    t.quarter,
    t.month,
    ROUND(AVG(f.review_score), 2) AS note_moyenne,
    COUNT(DISTINCT f.review_id) AS nombre_avis
FROM f_avis f
JOIN d_temps t 
    ON f.time_key = t.time_key
GROUP BY 
    t.year,
    t.quarter,
    t.month
ORDER BY 
    t.year,
    t.quarter,
    t.month;


/* ============================================================
   5. OLAP PRODUIT
   Analyse : satisfaction par catégorie de produit.
   Dimensions utilisées : D_PRODUIT
   Objectif : identifier les catégories les moins bien évaluées.
   ============================================================ */

SELECT 
    p.product_category_name_english AS categorie_produit,
    ROUND(AVG(f.review_score), 2) AS note_moyenne,
    COUNT(DISTINCT f.review_id) AS nombre_avis
FROM f_avis f
JOIN d_produit p 
    ON f.produit_key = p.produit_key
GROUP BY p.product_category_name_english
HAVING COUNT(DISTINCT f.review_id) >= 20
ORDER BY note_moyenne ASC;


/* ============================================================
   6. ROLL-UP PAR CATEGORIE PRODUIT
   Analyse : catégorie produit puis total général.
   Opération OLAP : Roll-up
   Objectif : agréger les données vers un niveau supérieur.
   ============================================================ */

SELECT 
    COALESCE(p.product_category_name_english, 'TOTAL_GENERAL') AS categorie_produit,
    ROUND(AVG(f.review_score), 2) AS note_moyenne,
    COUNT(DISTINCT f.review_id) AS nombre_avis
FROM f_avis f
JOIN d_produit p 
    ON f.produit_key = p.produit_key
GROUP BY ROLLUP(p.product_category_name_english)
ORDER BY categorie_produit;


/* ============================================================
   7. OLAP GEOGRAPHIQUE
   Analyse : satisfaction par région client.
   Dimensions utilisées : D_CLIENT
   Objectif : détecter les régions avec plus d’insatisfaction.
   ============================================================ */

SELECT 
    c.customer_state AS region_client,
    ROUND(AVG(f.review_score), 2) AS note_moyenne,
    COUNT(DISTINCT f.review_id) AS nombre_avis
FROM f_avis f
JOIN d_client c 
    ON f.client_key = c.client_key
GROUP BY c.customer_state
ORDER BY note_moyenne ASC;


/* ============================================================
   8. SLICE SUR LE STATUT DE LIVRAISON
   Analyse : impact du retard de livraison sur la satisfaction.
   Opération OLAP : Slice
   Objectif : analyser un axe spécifique : la livraison.
   ============================================================ */

SELECT 
    CASE 
        WHEN f.delivery_delay_days > 0 THEN 'Livraison en retard'
        WHEN f.delivery_delay_days = 0 THEN 'Livraison à temps'
        WHEN f.delivery_delay_days < 0 THEN 'Livraison en avance'
        ELSE 'Date livraison inconnue'
    END AS statut_livraison,
    ROUND(AVG(f.review_score), 2) AS note_moyenne,
    COUNT(DISTINCT f.review_id) AS nombre_avis
FROM f_avis f
GROUP BY statut_livraison
ORDER BY note_moyenne ASC;


/* ============================================================
   9. DICE MULTIDIMENSIONNEL
   Analyse : satisfaction par année, région et catégorie produit.
   Opération OLAP : Dice
   Objectif : filtrer simultanément plusieurs dimensions.
   ============================================================ */

SELECT 
    t.year,
    c.customer_state AS region_client,
    p.product_category_name_english AS categorie_produit,
    ROUND(AVG(f.review_score), 2) AS note_moyenne,
    COUNT(DISTINCT f.review_id) AS nombre_avis
FROM f_avis f
JOIN d_temps t 
    ON f.time_key = t.time_key
JOIN d_client c 
    ON f.client_key = c.client_key
JOIN d_produit p 
    ON f.produit_key = p.produit_key
WHERE t.year = 2018
  AND c.customer_state IN ('SP', 'RJ', 'MG')
  AND p.product_category_name_english IS NOT NULL
GROUP BY 
    t.year,
    c.customer_state,
    p.product_category_name_english
HAVING COUNT(DISTINCT f.review_id) >= 20
ORDER BY note_moyenne ASC;


/* ============================================================
   10. OLAP VENDEUR
   Analyse : top 10 des vendeurs avec plus faible satisfaction.
   Dimensions utilisées : D_VENDEUR
   Objectif : identifier les vendeurs à surveiller.
   ============================================================ */

SELECT 
    v.seller_id,
    v.seller_city,
    v.seller_state,
    ROUND(AVG(f.review_score), 2) AS note_moyenne,
    COUNT(DISTINCT f.review_id) AS nombre_avis
FROM f_avis f
JOIN d_vendeur v 
    ON f.vendeur_key = v.vendeur_key
GROUP BY 
    v.seller_id,
    v.seller_city,
    v.seller_state
HAVING COUNT(DISTINCT f.review_id) >= 10
ORDER BY note_moyenne ASC
LIMIT 10;


/* ============================================================
   11. ANALYSE COMMENTAIRES
   Analyse : présence de commentaire et satisfaction.
   Objectif : comparer les avis avec ou sans commentaire.
   ============================================================ */

SELECT 
    CASE 
        WHEN has_comment = 1 THEN 'Avec commentaire'
        ELSE 'Sans commentaire'
    END AS type_avis,
    ROUND(AVG(review_score), 2) AS note_moyenne,
    COUNT(DISTINCT review_id) AS nombre_avis,
    ROUND(AVG(comment_length), 2) AS longueur_moyenne_commentaire
FROM f_avis
GROUP BY has_comment
ORDER BY note_moyenne ASC;


/* ============================================================
   12. VERIFICATION SCD TYPE 2
   Objectif : montrer deux versions d’un même client.
   ============================================================ */

SELECT 
    client_key,
    customer_unique_id,
    customer_id,
    customer_city,
    customer_state,
    date_debut,
    date_fin,
    is_current
FROM d_client
WHERE customer_id = (
    SELECT customer_id
    FROM d_client
    GROUP BY customer_id
    HAVING COUNT(*) > 1
    LIMIT 1
)
ORDER BY client_key;