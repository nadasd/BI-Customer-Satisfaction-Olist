SELECT 
    client_key,
    customer_unique_id,
    customer_id,
    customer_city,
    customer_state,
    date_debut,
    date_fin,
    is_current
FROM D_CLIENT
WHERE is_current = TRUE
LIMIT 1;
-- Démonstration SCD Type 2 sur D_CLIENT

-- 1. Fermer l'ancienne version du client
UPDATE D_CLIENT
SET 
    date_fin = CURRENT_DATE,
    is_current = FALSE
WHERE customer_unique_id = 'PUT_CUSTOMER_UNIQUE_ID_HERE'
  AND is_current = TRUE;

-- 2. Insérer une nouvelle version du client
INSERT INTO D_CLIENT (
    customer_unique_id,
    customer_id,
    customer_city,
    customer_state,
    date_debut,
    date_fin,
    is_current
)
SELECT
    customer_unique_id,
    customer_id,
    'rio de janeiro' AS customer_city,
    customer_state,
    CURRENT_DATE AS date_debut,
    NULL::DATE AS date_fin,
    TRUE AS is_current
FROM stg_customers
WHERE customer_unique_id = '0000366f3b9a7992bf8c76cfdf3221e2'
LIMIT 1;

-- 3. Vérifier les deux versions
SELECT 
    client_key,
    customer_unique_id,
    customer_id,
    customer_city,
    customer_state,
    date_debut,
    date_fin,
    is_current
FROM D_CLIENT
WHERE customer_unique_id = '0000366f3b9a7992bf8c76cfdf3221e2'
ORDER BY client_key;
\\ Dans ce projet, la dimension D_CLIENT est historisée en SCD Type 2. 
Les attributs historisés sont principalement la ville et l’état du client.
 Lorsqu’un changement est détecté, l’ancienne version du client est clôturée 
 en renseignant date_fin et en passant is_current à FALSE. Une nouvelle ligne
  est ensuite insérée avec les nouvelles valeurs, une nouvelle date de début
   et is_current = TRUE. Cette approche permet de conserver l’historique des 
   changements et d’éviter l’écrasement des anciennes valeurs. \\
   -- Démo SCD Type 2 propre sur D_CLIENT

-- 1. Choisir automatiquement un client actif
DROP TABLE IF EXISTS tmp_scd2_client;

CREATE TEMP TABLE tmp_scd2_client AS
SELECT customer_id
FROM D_CLIENT
WHERE is_current = TRUE
LIMIT 1;

-- 2. Fermer l'ancienne version
UPDATE D_CLIENT
SET 
    date_fin = CURRENT_DATE,
    is_current = FALSE
WHERE customer_id = (SELECT customer_id FROM tmp_scd2_client)
  AND is_current = TRUE;

-- 3. Insérer une nouvelle version du même client
INSERT INTO D_CLIENT (
    customer_unique_id,
    customer_id,
    customer_city,
    customer_state,
    date_debut,
    date_fin,
    is_current
)
SELECT
    customer_unique_id,
    customer_id,
    'rio de janeiro' AS customer_city,
    customer_state,
    CURRENT_DATE AS date_debut,
    NULL::DATE AS date_fin,
    TRUE AS is_current
FROM D_CLIENT
WHERE customer_id = (SELECT customer_id FROM tmp_scd2_client)
  AND is_current = FALSE
ORDER BY client_key DESC
LIMIT 1;

-- 4. Vérifier les deux versions
SELECT 
    client_key,
    customer_unique_id,
    customer_id,
    customer_city,
    customer_state,
    date_debut,
    date_fin,
    is_current
FROM D_CLIENT
WHERE customer_id = (SELECT customer_id FROM tmp_scd2_client)
ORDER BY client_key;