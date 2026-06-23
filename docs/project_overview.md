# Olist Analytics Platform

## Mục tiêu

Xây dựng **Data Warehouse** cho dữ liệu e-commerce Olist (Brazil), từ đó phục vụ phân tích kinh doanh qua dashboard Metabase.

---

## Data Pipeline (ELT)

```
MySQL          →    PostgreSQL       →    PostgreSQL        →    Tableau / Metabase
(Source DB)         schema: staging       schema: warehouse      (Dashboard)
 9 bảng raw         9 bảng raw            core marts + metrics marts
                         │                      │
                    Airflow Extract         Cosmos + dbt Transform
                    (Python/Pandas)         (SQL trên DB)
```

---

## Công nghệ sử dụng

| Thành phần | Công nghệ | Vai trò |
|---|---|---|
| Source DB | **MySQL 8.0** | Chứa data gốc Olist (~100K orders, 2016-2018) |
| Data Warehouse | **PostgreSQL 14** | Chứa staging + warehouse schemas |
| Orchestrator | **Apache Airflow 2.9.2** | Lên lịch, trigger pipeline |
| Transform | **dbt-core 1.8.7** | Chạy SQL transform trực tiếp trên PostgreSQL |
| BI Dashboard | **Tableau / Metabase** | Trực quan hóa dữ liệu |
| Infrastructure | **Docker Compose** | Container hóa toàn bộ hệ thống (7 services) |

---

## Star Schema (trong schema `warehouse`)

```
                    ┌──────────────┐
                    │  dim_date    │
                    └──────┬───────┘
┌──────────────┐           │           ┌──────────────┐
│dim_customers │───┐       │       ┌───│ dim_sellers   │
└──────────────┘   │       │       │   └──────────────┘
                   ▼       ▼       ▼
┌──────────────┐  ┌────────────────┐  ┌──────────────┐
│dim_geolocation│→│  fact_orders   │←│ dim_products  │
└──────────────┘  └────────────────┘  └──────────────┘
                         ▲
                   ┌─────┘
                   │
              ┌────────────┐
              │dim_payments│
              └────────────┘
```

---

## dbt 3-Layer Architecture

| Layer | Schema | Materialization | Số models | Chức năng |
|---|---|---|---|---|
| **Staging** | `staging_dbt` | VIEW | 8 | Clean cơ bản: cast type, trim, pad zip code |
| **Intermediate** | *(không tạo trong DB)* | EPHEMERAL | 2 | Join tables, tính delivery metrics |
| **Marts** | `warehouse` | TABLE | 7 | Final dim & fact với surrogate keys |

### Dependency Graph

```
staging.stg_* (raw tables — loaded by Airflow)
       │
       ▼
┌─ STAGING (views in staging_dbt) ───────────────────────┐
│ stg_customers  stg_orders  stg_order_items stg_payments│
│ stg_products   stg_sellers stg_geolocation             │
│ stg_category_translation                               │
└──────┬─────────────┬────────────────┬──────────────────┘
       │             │                │
       ▼             ▼                ▼
┌─ INTERMEDIATE (ephemeral — chỉ là CTE) ───────────────┐
│ int_products_joined        int_orders_enriched         │
│ (products + categories)    (orders + items + payments)  │
└──────┬──────────────────────────────┬──────────────────┘
       │                              │
       ▼                              ▼
┌─ MARTS (tables in warehouse) ──────────────────────────┐
│ dim_customers  dim_products  dim_sellers  dim_date     │
│ dim_geolocation  dim_payments                          │
│                                                        │
│           fact_orders ←── (joins tất cả dims)          │
└────────────────────────────────────────────────────────┘
```

---

## Airflow DAG: `e_commerce_elt`

```
drop_dbt_staging_views → extract_and_load_to_staging → dbt_transform [Cosmos DbtTaskGroup] → send_success_email
       (3s)                        (28s)                  (4s)      (7s)       (3s)
```

| Task | Operator | Chức năng |
|---|---|---|
| `drop_dbt_staging_views` | BashOperator | Xóa staging_dbt views để Airflow có thể replace raw tables |
| `extract_and_load_to_staging` | PythonOperator | Kéo 9 bảng từ MySQL → PostgreSQL schema `staging` |
| `dbt_transform` | Cosmos DbtTaskGroup | Render từng dbt model/test thành Airflow task |

Tổng thời gian chạy: **~45 giây**

---

## Schemas trong PostgreSQL

| Schema | Quản lý bởi | Nội dung |
|---|---|---|
| `staging` | Airflow | 9 raw tables (copy y nguyên từ MySQL) |
| `staging_dbt` | dbt | 9 views (SELECT + clean từ raw tables) |
| `warehouse` | dbt | core dim/fact tables + metrics marts cho BI |

---

## Docker Services

| Service | Image | Port | Vai trò |
|---|---|---|---|
| `mysql` | mysql:8.0 | 3307 | Source database |
| `de_psql` | postgres:14-alpine | 5433 | Data Warehouse |
| `postgres` | postgres:13 | - | Airflow metadata DB |
| `dbt` | python:3.10-slim + dbt | - | dbt container |
| `airflow-webserver` | apache/airflow:2.9.2 | 8080 | Airflow UI |
| `airflow-scheduler` | apache/airflow:2.9.2 | - | Task scheduler |
| `metabase` | metabase/metabase | 3000 | BI Dashboard |

---

## Cấu trúc Thư mục

```
Olist_Analytics_Platform/
├── docker-compose.yaml
├── Dockerfile                       # Airflow image (cài dbt-core, dbt-postgres)
├── requirements.txt
├── .env                             # DB credentials
│
├── dags/
│   ├── extract_data.py              # Extract: MySQL → PostgreSQL staging
│   └── transform/
│       └── e_commerce_dw_dag.py     # DAG: 5 tasks (drop → extract → deps → run → test)
│
├── plugins/
│   ├── mysql_operator.py            # Custom MySQL operator
│   └── postgresql_operator.py       # Custom PostgreSQL operator
│
├── dbt_olist/                       # dbt project
│   ├── dbt_project.yml
│   ├── packages.yml                 # dbt_utils
│   ├── profiles/profiles.yml        # Kết nối PostgreSQL
│   ├── macros/
│   │   ├── generate_schema_name.sql # Override schema naming
│   │   └── drop_staging_views.sql   # Drop views trước extract
│   └── models/
│       ├── staging/                 # 9 views
│       ├── intermediate/            # 5 ephemeral models
│       └── marts/
│           ├── core/                # dimensions + facts
│           └── metrics/             # aggregate KPI marts
│
├── docker/dbt/Dockerfile            # dbt container image
├── data/raw/                        # CSV files gốc
└── docs/                            # Tài liệu dự án
```
