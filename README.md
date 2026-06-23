# Olist Analytics Platform

An end-to-end data engineering and analytics project for the Brazilian Olist e-commerce dataset. The platform turns raw operational data into a tested PostgreSQL warehouse and Tableau-ready marts for sales, payment, seller, and product category analysis.

## What This Project Solves

E-commerce teams often need consistent business metrics across many views: revenue, payments, seller performance, product categories, delivery quality, and customer geography. Raw transactional tables are not easy to analyze directly because they have different grains, duplicated payment risks, and many joins.

This project solves that by building a reproducible ELT workflow that:

- Loads Olist source data from MySQL into PostgreSQL staging.
- Uses Airflow to orchestrate extract, dbt transform, dbt tests, and success notification.
- Uses Astronomer Cosmos to render dbt models as Airflow tasks.
- Builds a star-schema warehouse plus Tableau-specific marts.
- Provides interactive Tableau dashboards with synchronized filters.

## Dashboard Outputs

> Export the Tableau dashboards to the paths below so the README renders the latest screenshots.

| Executive Overview | Payment Overview |
| --- | --- |
| ![Olist Executive Overview](dashboard/executive_overview.png) | ![Olist Payment Overview](dashboard/payment_overview.png) |

| Seller Performance | Product Category Performance |
| --- | --- |
| ![Olist Seller Performance](dashboard/seller_performance.png) | ![Olist Product Category Performance](dashboard/category_performance.png) |

## Architecture

```text
MySQL source
  -> Airflow extract/upsert
  -> PostgreSQL staging
  -> Cosmos + dbt build/test
  -> PostgreSQL warehouse
  -> Tableau dashboards
```

## Core Stack

| Layer | Technology |
| --- | --- |
| Source database | MySQL |
| Warehouse | PostgreSQL |
| Orchestration | Apache Airflow |
| dbt orchestration | Astronomer Cosmos |
| Transformation | dbt Core |
| BI | Tableau |
| Runtime | Docker Compose |

## Data Modeling

The warehouse keeps a clear modeling flow:

```text
staging views
  -> intermediate models
  -> core star schema
  -> Tableau presentation marts
```

Core warehouse models include facts and dimensions such as:

- `fact_orders`
- `fact_order_items`
- `dim_customers`
- `dim_products`
- `dim_sellers`
- `dim_payments`
- `dim_date`
- `dim_geolocation`

Tableau marts are built at the correct grain for each dashboard:

| Mart | Purpose | Grain |
| --- | --- | --- |
| `mart_tableau_sales_dashboard` | Executive sales, delivery, seller, and category overview | 1 row per order item |
| `mart_tableau_payment_mix` | Payment method, installment, and geography analysis | 1 row per order payment sequence |
| `mart_tableau_seller_dashboard` | Seller revenue, review, and delivery performance | 1 row per seller order item |
| `mart_tableau_product_category_dashboard` | Category revenue, freight, review, and delivery analysis | 1 row per category order item |

## Airflow Workflow

Main DAG:

```text
e_commerce_elt
```

Workflow:

```text
extract_and_upsert_to_staging
  -> dbt_transform
  -> dbt_test
  -> send_success_email
```

The email step only runs after the dbt models and tests finish successfully.

## Quick Start

Start services:

```bash
docker compose build
docker compose up -d
```

Load source data into MySQL:

```bash
make mysql_create
make mysql_load
```

Open Airflow:

```text
http://localhost:8080
```

Default login:

```text
airflow / airflow
```

Trigger the DAG:

```bash
docker exec olist_analytics_platform-airflow-webserver-1 \
  airflow dags trigger e_commerce_elt
```

Run dbt tests manually:

```bash
docker exec dbt dbt build
```

Connect Tableau to PostgreSQL:

| Field | Value |
| --- | --- |
| Server | `localhost` |
| Port | `5433` |
| Database | `postgres` |
| Username | `admin` |
| Password | `admin` |
| Schema | `warehouse` |

## Key Metrics

- GMV
- Payment value
- Average order value
- Order count
- Seller count
- Category count
- On-time delivery rate
- Average review score
- Freight share
- Payment method share
