/* Correct-grain analytical queries. Satisfaction uses f_review; delivery uses
   f_order_delivery; product/seller attribution uses bridge allocation_weight. */

-- 0. Reconciliation counts
SELECT 'D_CLIENT' table_name,COUNT(*) row_count FROM d_client UNION ALL
SELECT 'D_PRODUIT',COUNT(*) FROM d_produit UNION ALL
SELECT 'D_VENDEUR',COUNT(*) FROM d_vendeur UNION ALL
SELECT 'D_COMMANDE',COUNT(*) FROM d_commande UNION ALL
SELECT 'D_TEMPS',COUNT(*) FROM d_temps UNION ALL
SELECT 'F_REVIEW',COUNT(*) FROM f_review UNION ALL
SELECT 'F_ORDER_ITEM',COUNT(*) FROM f_order_item UNION ALL
SELECT 'F_ORDER_DELIVERY',COUNT(*) FROM f_order_delivery;

-- 1. Global satisfaction: one row per review event.
SELECT COUNT(*) AS nombre_avis,
 ROUND(AVG(review_score),2) AS note_moyenne,
 ROUND(100.0*AVG(is_positive_review::INTEGER),2) AS taux_avis_positifs,
 ROUND(100.0*AVG(is_negative_review::INTEGER),2) AS taux_avis_negatifs
FROM f_review;

-- 2. Score distribution.
SELECT review_score,COUNT(*) AS nombre_avis
FROM f_review GROUP BY review_score ORDER BY review_score;

-- 3. Delivery KPI: all orders with the required dates, including orders without reviews.
SELECT COUNT(*) FILTER(WHERE is_delivery_eligible) AS commandes_eligibles,
 COUNT(*) FILTER(WHERE is_delivery_eligible AND is_late) AS commandes_en_retard,
 ROUND(100.0*COUNT(*) FILTER(WHERE is_delivery_eligible AND is_late)
       /NULLIF(COUNT(*) FILTER(WHERE is_delivery_eligible),0),2) AS taux_retard,
 ROUND(AVG(delivery_variance_days) FILTER(WHERE is_delivery_eligible),2) AS ecart_signe_moyen_jours,
 ROUND(AVG(delivery_variance_days) FILTER(WHERE is_late),2) AS retard_moyen_commandes_en_retard
FROM f_order_delivery;

-- 4. Monthly satisfaction.
SELECT t.year,t.month,ROUND(AVG(r.review_score),2) AS note_moyenne,COUNT(*) AS nombre_avis
FROM f_review r JOIN d_temps t ON t.time_key=r.order_time_key
GROUP BY t.year,t.month ORDER BY t.year,t.month;

-- 5. Product category satisfaction. Allocation makes category volumes additive.
SELECT p.product_category_name_english AS categorie,
 ROUND(SUM(r.review_score*b.allocation_weight)/NULLIF(SUM(b.allocation_weight),0),2) AS note_moyenne_allouee,
 ROUND(SUM(b.allocation_weight),2) AS volume_avis_alloue,
 COUNT(DISTINCT r.review_key) AS avis_attribues
FROM f_review r JOIN bridge_review_order_item b ON b.review_key=r.review_key
JOIN f_order_item i ON i.order_item_key=b.order_item_key
JOIN d_produit p ON p.produit_key=i.produit_key
GROUP BY p.product_category_name_english
HAVING SUM(b.allocation_weight)>=20 ORDER BY note_moyenne_allouee;

-- 6. Seller satisfaction with the same allocation rule.
SELECT v.seller_id,v.seller_city,v.seller_state,
 ROUND(SUM(r.review_score*b.allocation_weight)/NULLIF(SUM(b.allocation_weight),0),2) AS note_moyenne_allouee,
 ROUND(SUM(b.allocation_weight),2) AS volume_avis_alloue,
 COUNT(DISTINCT r.review_key) AS avis_attribues
FROM f_review r JOIN bridge_review_order_item b ON b.review_key=r.review_key
JOIN f_order_item i ON i.order_item_key=b.order_item_key
JOIN d_vendeur v ON v.vendeur_key=i.vendeur_key
GROUP BY v.seller_id,v.seller_city,v.seller_state
HAVING SUM(b.allocation_weight)>=10 ORDER BY note_moyenne_allouee LIMIT 10;

-- 7. Geographic satisfaction.
SELECT c.customer_state,ROUND(AVG(r.review_score),2) AS note_moyenne,COUNT(*) AS nombre_avis
FROM f_review r JOIN d_client c ON c.client_key=r.client_key
GROUP BY c.customer_state ORDER BY note_moyenne;

-- 8. Satisfaction by delivery status, one review event per row.
SELECT CASE WHEN NOT d.is_delivery_eligible THEN 'Date livraison inconnue'
            WHEN d.is_late THEN 'Livraison en retard'
            WHEN d.delivery_variance_days=0 THEN 'Livraison a la date estimee'
            ELSE 'Livraison en avance' END AS statut_livraison,
 ROUND(AVG(r.review_score),2) AS note_moyenne,COUNT(*) AS nombre_avis
FROM f_review r JOIN f_order_delivery d ON d.commande_key=r.commande_key
GROUP BY 1 ORDER BY note_moyenne;

-- 9. Comment presence.
SELECT has_comment,ROUND(AVG(review_score),2) AS note_moyenne,
 COUNT(*) AS nombre_avis,ROUND(AVG(comment_length),2) AS longueur_moyenne
FROM f_review GROUP BY has_comment ORDER BY has_comment DESC;

-- 10. Current SCD2 versions and history depth.
SELECT customer_unique_id,COUNT(*) AS versions,
 COUNT(*) FILTER(WHERE is_current) AS versions_courantes,
 MIN(date_debut) AS premiere_version,MAX(COALESCE(date_fin,'infinity'::DATE)) AS fin_derniere_version
FROM d_client GROUP BY customer_unique_id HAVING COUNT(*)>1 ORDER BY versions DESC,customer_unique_id;
