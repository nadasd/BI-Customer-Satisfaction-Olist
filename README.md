# 📊 Customer Satisfaction BI — Olist

An end-to-end **Business Intelligence project** focused on analyzing customer satisfaction in an e-commerce context using the **Olist dataset**.

The project transforms raw e-commerce data into a decision-oriented **Data Mart** using **PostgreSQL, Talend Open Studio, SQL/OLAP, and Power BI**.

---

## 🎯 Project Objectives

The main objective of this project is to analyze customer satisfaction and provide insights that can support business decision-making.

The project addresses questions such as:

- What is the overall level of customer satisfaction?
- How does satisfaction evolve over time?
- Which product categories receive the lowest ratings?
- Do delivery delays affect customer satisfaction?
- Which regions have the lowest satisfaction?
- Which sellers are associated with low ratings?
- What is the distribution of positive, negative, and neutral reviews?

---

## 🗄️ Data Mart

The project uses a **star schema** centered around the `F_AVIS` fact table.

### Fact Table

`F_AVIS` contains review-related measures and foreign keys connecting the fact table to the dimensions.

Main measures include:

- `review_score`
- `review_count`
- `days_to_review`
- `comment_length`
- `delivery_delay_days`
- `has_comment`
- `is_positive_review`
- `is_negative_review`

### Dimensions

| Dimension | Description |
|---|---|
| `D_TEMPS` | Time analysis |
| `D_CLIENT` | Customer information |
| `D_PRODUIT` | Product and category information |
| `D_VENDEUR` | Seller information |
| `D_COMMANDE` | Order and delivery information |

### Star Schema

![Star Schema](captures/powerbi/Shema_etoile.png)

---

## 🔄 ETL — Talend

The ETL process was implemented using **Talend Open Studio 7.3.1**.

The pipeline performs:

1. Extraction of the Olist CSV files
2. Loading into PostgreSQL staging tables
3. Data transformation and mapping
4. Loading of the dimensions
5. Loading of the `F_AVIS` fact table
6. Data validation

The Talend project is available in:

```text
etl/
└── talend_project/
    └── PROJET_BI_SATISFACTION.zip
