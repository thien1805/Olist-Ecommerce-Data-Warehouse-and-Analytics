# Olist Analytics Platform

An end-to-end analytics engineering project for the Brazilian Olist e-commerce dataset. It builds a reproducible ELT pipeline from raw transactional data to a tested PostgreSQL warehouse and Tableau dashboards.

## Problem

Raw e-commerce tables are difficult to analyze directly because orders, items, payments, sellers, products, reviews, and delivery data all have different grains. This project standardizes those grains, prevents common double-counting issues, and creates BI-ready marts for business reporting.

## Solution

```text
MySQL source
  -> Airflow extract/upsert
  -> PostgreSQL staging
  -> Cosmos + dbt transform/test
  -> PostgreSQL warehouse
  -> Tableau dashboards
```

The pipeline creates a star-schema warehouse and Tableau presentation marts for:

- Executive sales overview
- Payment method and installment analysis
- Seller performance
- Product category performance

## Dashboard Preview

| Executive Overview | Payment Performance |
| --- | --- |
| ![Executive Overview](dashboard/Executive%20Overview.png) | ![Payment Performance](dashboard/Payment%20Performance.png) |

| Seller Performance | Category Performance |
| --- | --- |
| ![Seller Performance](dashboard/Seller%20Performance.png) | ![Category Performance](dashboard/Category%20Performance.png) |

## Technology Summary

| Area | Technology |
| --- | --- |
| Source database | MySQL |
| Warehouse | PostgreSQL |
| Orchestration | Apache Airflow |
| dbt orchestration | Astronomer Cosmos |
| Transformation | dbt Core |
| BI | Tableau |
| Runtime | Docker Compose |

## Techniques Used

- **ELT orchestration**: Airflow controls extract/upsert, dbt transformation, dbt tests, and success notification.
- **dbt modeling**: staging, intermediate, core star schema, and dashboard-specific marts.
- **Grain-aware marts**: separate marts for order items, payment transactions, sellers, and product categories to avoid double-counting.
- **Data quality checks**: dbt schema tests and reconciliation tests validate payment, GMV, relationships, and dashboard totals.
- **BI-ready design**: Tableau marts are denormalized enough for simple filters, KPIs, and interactive dashboards.

## Warehouse Design

Core star schema:

- `fact_orders`
- `fact_order_items`
- `dim_customers`
- `dim_products`
- `dim_sellers`
- `dim_payments`
- `dim_date`
- `dim_geolocation`

Tableau marts:

| Mart | Purpose |
| --- | --- |
| `mart_tableau_sales_dashboard` | Executive sales, delivery, seller, and category overview |
| `mart_tableau_payment_mix` | Payment method and installment analysis |
| `mart_tableau_seller_dashboard` | Seller revenue, review, and delivery performance |
| `mart_tableau_product_category_dashboard` | Category revenue, freight, review, and delivery analysis |

## Business Applications

- Track GMV, AOV, review score, and on-time delivery performance.
- Analyze payment methods, installment behavior, and regional payment value.
- Identify top sellers and seller states by revenue and delivery quality.
- Compare product categories by revenue, freight share, review score, and delivery performance.
- Provide clean Tableau datasets for business users without requiring manual joins.

## Airflow DAG

Main DAG:

```text
e_commerce_elt
```

Task flow:

```text
extract_and_upsert_to_staging
  -> dbt_transform
  -> dbt_test
  -> send_success_email
```

The success email is sent only after dbt models and tests pass.

## Quick Start

```bash
docker compose build
docker compose up -d
make mysql_create
make mysql_load
```

Trigger the pipeline:

```bash
docker exec olist_analytics_platform-airflow-webserver-1 \
  airflow dags trigger e_commerce_elt
```

Run dbt manually:

```bash
docker exec dbt dbt build
```

Tableau connection:

| Field | Value |
| --- | --- |
| Server | `localhost` |
| Port | `5433` |
| Database | `postgres` |
| Username | `admin` |
| Password | `admin` |
| Schema | `warehouse` |

## Project Direction

Next improvements:

- Add incremental dbt models for larger data volumes.
- Add data freshness checks and source-level quality alerts.
- Add CI to run dbt parse/build checks before merging.
- Extend dashboards with customer cohort and repeat purchase analysis.
