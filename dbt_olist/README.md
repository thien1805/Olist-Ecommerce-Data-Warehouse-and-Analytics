# dbt Olist Analytics

dbt project này transform dữ liệu Olist từ PostgreSQL schema `staging` thành mô hình analytics-ready cho BI.

## Layers

```text
staging      -> clean/cast raw tables loaded by Airflow
intermediate -> aggregate/join logic at correct grain
marts/core   -> dim/fact tables for Tableau relationships
marts/metrics -> aggregate KPI marts for dashboards
```

## Main marts

- `fact_orders`: 1 row per order, used for GMV, payment, delivery, and review KPIs.
- `fact_order_items`: 1 row per order item, used for product/category/seller analysis.
- `dim_customers`, `dim_products`, `dim_sellers`, `dim_geolocation`, `dim_date`, `dim_payments`: BI dimensions.
- `agg_monthly_sales`, `agg_product_category_performance`, `agg_delivery_performance`, `agg_seller_performance`: Tableau-ready aggregate marts.

## Common commands

```bash
dbt parse --profiles-dir profiles --no-partial-parse
dbt build --profiles-dir profiles
dbt docs generate --profiles-dir profiles
```

Airflow runs this project through Astronomer Cosmos, so each dbt model/test is visible as a task inside the `dbt_transform` task group.
