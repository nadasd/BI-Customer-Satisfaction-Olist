# Power BI model update checklist

The bundled PBIX still contains the original imported model. Apply this checklist
in Power BI Desktop before treating the dashboard as validated.

## 1. Connect to the corrected PostgreSQL model

Open `dashboard.pbix`, then use **Transform data > Data source settings** to point
the PostgreSQL source to the database containing the objects created by
`sql/create_tables.sql` and loaded by `sql/load_data.sql`.

Import or refresh these objects from the `public` schema:

- `d_temps`
- `d_client`
- `d_produit`
- `d_vendeur`
- `d_commande`
- `f_review`
- `f_order_delivery`
- `f_order_item`
- `bridge_review_order_item`

The compatibility view `f_avis` may remain available for legacy visuals, but it
must not be used for the four global KPI cards.

## 2. Configure relationships

Use single-direction, one-to-many relationships from each dimension to its facts.
Do not enable automatic bidirectional filtering.

| One side | Many side | Active |
|---|---|---:|
| `d_temps[time_key]` | `f_review[order_time_key]` | Yes |
| `d_temps[time_key]` | `f_review[review_time_key]` | No |
| `d_client[client_key]` | `f_review[client_key]` | Yes |
| `d_commande[commande_key]` | `f_review[commande_key]` | Yes |
| `d_temps[time_key]` | `f_order_delivery[order_time_key]` | Yes |
| `d_client[client_key]` | `f_order_delivery[client_key]` | Yes |
| `d_commande[commande_key]` | `f_order_delivery[commande_key]` | Yes |
| `d_temps[time_key]` | `f_order_item[order_time_key]` | Yes |
| `d_client[client_key]` | `f_order_item[client_key]` | Yes |
| `d_commande[commande_key]` | `f_order_item[commande_key]` | Yes |
| `d_produit[produit_key]` | `f_order_item[produit_key]` | Yes |
| `d_vendeur[vendeur_key]` | `f_order_item[vendeur_key]` | Yes |
| `f_review[review_key]` | `bridge_review_order_item[review_key]` | Yes |
| `f_order_item[order_item_key]` | `bridge_review_order_item[order_item_key]` | Yes |

## 3. Add measures and replace visual fields

Create the measures from `measures_corrected.dax`. Use these format strings:

| Measure | Format |
|---|---|
| `Nombre avis`, `Commandes eligibles`, `Commandes en retard` | `#,0` |
| `Note moyenne`, `Note moyenne allouee` | `0.0000` |
| `Taux avis positifs`, `Taux avis negatifs`, `Taux retard livraison` | `0.0000%` |
| Delivery-day measures | `0.00` |

Use `Nombre avis`, `Note moyenne`, and the review-rate measures for global,
time, and geography visuals. Use `Volume avis alloue` and
`Note moyenne allouee` for product and seller visuals so multi-item orders do
not multiply review counts.

## 4. Clear saved filters and review interactions

The current PBIX has stale saved filters in visual queries:

- Page 1 is saved with `agro_industry_and_commerce` selected.
- Page 2 is saved with customer state `AC` selected.

Clear both selections, clear visual/page/report filters that reproduce them, and
save the report with every slicer in its unfiltered state. Keep the delivery KPI
based on `f_order_delivery`; product and seller slicers should not silently
change its order-level grain.

## 5. Validate and capture

With all slicers cleared, the cards must show:

| KPI | Expected value |
|---|---:|
| Reviews | 99,224 |
| Average review score | 4.0864 |
| Positive review rate | 77.0680% |
| Late-delivery rate | 6.7737% |

Refresh, save the PBIX, close and reopen it, then verify the values again. Export
fresh screenshots of all three pages to `captures/powerbi/` using the existing
filenames. This close/reopen check is required before marking Power BI as
validated.
