# Olist Analytics Platform

End-to-end Data Engineering + BI project for Olist e-commerce data.

Current implementation focuses on an automated ETL pipeline using Apache Airflow (Dockerized), extracting raw data from MySQL, transforming with Python/Pandas, and loading into PostgreSQL Data Warehouse for dashboarding.

## 1) Project Overview

Main goals:
- Build a reproducible ETL pipeline for e-commerce analytics.
- Organize data into a warehouse schema for reporting.
- Deliver BI dashboards for business monitoring (Sales and Product performance).

Current pipeline scope:
- Source: MySQL (raw Olist tables).
- Orchestration: Apache Airflow.
- Transformation: Python + Pandas tasks in Airflow DAG.
- Target: PostgreSQL (`warehouse` schema).
- BI layer: Power BI / Metabase.

## 2) Architecture (Current State)

Data flow:
1. Raw CSV files are loaded into MySQL.
2. Airflow DAG extracts raw tables from MySQL into PostgreSQL staging tables.
3. Airflow transformation tasks build dimension and fact tables in `warehouse` schema.
4. BI tools connect to PostgreSQL and visualize KPIs/insights.

Core DAG:
- DAG ID: `e_commerce_dw_etl`
- Flow: `extract` -> `transform` -> `load`

## 3) Tech Stack

- Apache Airflow (LocalExecutor)
- Docker Compose
- MySQL 8.0 (source)
- PostgreSQL 14 (data warehouse)
- Python (Pandas, Airflow providers)
- Power BI / Metabase (analytics & visualization)

## 4) Repository Structure

Key folders:
- `dags/`: ETL tasks and DAG definition.
- `plugins/`: custom database operators.
- `data/raw/`: input CSV files.
- `load_dataset_into_mysql/`: SQL scripts to create and load MySQL source tables.
- `docs/`: project documentation and BI guides.
- `logs/`: Airflow logs.

## 5) Data Warehouse Model (Current)

Schema:
- `staging`: raw-to-staging tables (`stg_*`).
- `warehouse`: analytics-ready star-like model.

Main tables in `warehouse`:
- Dimensions: `dim_customers`, `dim_products`, `dim_sellers`, `dim_geolocation`, `dim_dates`, `dim_payments`
- Fact: `fact_orders`

## 6) KPI Examples

Typical KPIs currently tracked:
- GMV (Gross Merchandise Value)
- Total Orders
- AOV (Average Order Value)
- Cancel Rate
- Delivery Performance (on-time vs late)
- Top category/city/state by revenue

## 7) Run Project Locally

Prerequisites:
- Docker + Docker Compose
- Make (optional, for helper commands)

Start services:

```bash
docker compose up -d
```

Load source schema and data into MySQL:

```bash
make mysql_create
make mysql_load
```

Open Airflow:
- URL: http://localhost:8080
- Default account (from compose): airflow / airflow

Trigger ETL DAG:
- Enable and run DAG `e_commerce_dw_etl` in Airflow UI.

BI access:
- Metabase: http://localhost:3000
- PostgreSQL warehouse host from local machine: `localhost:5433`

## 8) Dashboard Preview

Add your screenshots here after exporting images.

Suggested file locations:
- `docs/images/sales_overview.png`
- `docs/images/products_overview.png`

### Sales Overview

![Sales Overview](docs/images/sales_overview.png)

### Products Overview

![Products Overview](docs/images/products_overview.png)

## 9) Current Status

- ETL pipeline is operational with Airflow scheduling.
- Data warehouse tables are generated in PostgreSQL.
- Basic BI dashboards are built and ready for further analytics enhancement.