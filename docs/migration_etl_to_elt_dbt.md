# Olist Analytics Platform — ELT với dbt

## Mục lục
1. [Tổng quan Dự án](#1-tổng-quan-dự-án)
2. [Kiến trúc Hệ thống](#2-kiến-trúc-hệ-thống)
3. [Cấu trúc Thư mục](#3-cấu-trúc-thư-mục)
4. [Hướng dẫn Chạy Dự án](#4-hướng-dẫn-chạy-dự-án)
5. [Chi tiết Kỹ thuật](#5-chi-tiết-kỹ-thuật)
6. [Các vấn đề đã xử lý](#6-các-vấn-đề-đã-xử-lý)
7. [Hướng phát triển nâng cao](#7-hướng-phát-triển-nâng-cao)
8. [Batch Processing & Dashboard theo thời gian](#8-batch-processing--dashboard-theo-thời-gian)

---

## 1. Tổng quan Dự án

### Trước (ETL — Airflow + Pandas)

Dự án ban đầu sử dụng mô hình **ETL truyền thống**:
- **Extract**: Airflow kéo data từ MySQL → Pandas DataFrame
- **Transform**: 7 file Python dùng Pandas để join, clean, tạo surrogate keys **trong memory**
- **Load**: Pandas ghi kết quả ngược lại PostgreSQL

**Hạn chế**: Toàn bộ data phải load vào RAM của Airflow worker → thắt cổ chai memory, không scale được.

### Sau (ELT — Airflow + dbt)

Chuyển sang mô hình **ELT** với kiến trúc 3-layer chuẩn dbt:
- **Extract & Load**: Airflow vẫn kéo raw data từ MySQL → PostgreSQL (schema `staging`)
- **Transform**: dbt chạy SQL **trực tiếp trên PostgreSQL**, không kéo data ra memory
- **Orchestrate**: Airflow trigger `dbt run` qua BashOperator

---

## 2. Kiến trúc Hệ thống

### Data Flow

```
MySQL (Source) ──[Airflow Extract]──> PostgreSQL schema: staging
                                            │
                                    ┌───────┴───────────────────────────────────┐
                                    │            dbt Transform (SQL)            │
                                    │                                           │
                                    │  ┌──────────┐  ┌──────────────┐  ┌──────┐│
                                    │  │ STAGING   │→ │ INTERMEDIATE │→ │MARTS ││
                                    │  │ (views)   │  │ (ephemeral)  │  │(table││
                                    │  │schema:    │  │ chỉ là CTE   │  │schema││
                                    │  │staging_dbt│  │ ko tạo trong │  │ware- ││
                                    │  │           │  │ DB           │  │house ││
                                    │  └──────────┘  └──────────────┘  └──────┘│
                                    └───────────────────────────────────────────┘
                                                                          │
                                                                    Metabase (BI)
```

### Docker Services

| Service | Image | Port | Vai trò |
|---|---|---|---|
| `mysql` | mysql:8.0 | 3307 | Source database (Olist operational data) |
| `de_psql` | postgres:14-alpine | 5433 | Data Warehouse (staging + warehouse schemas) |
| `postgres` | postgres:13 | - | Airflow metadata DB |
| `dbt` | python:3.10-slim + dbt | - | dbt container (chạy độc lập hoặc qua Airflow) |
| `airflow-webserver` | apache/airflow:2.9.2 | 8080 | Airflow UI |
| `airflow-scheduler` | apache/airflow:2.9.2 | - | Airflow task scheduler |
| `metabase` | metabase/metabase | 3000 | BI Dashboard |

### Airflow DAG: `e_commerce_elt`

```
extract_and_load_to_staging ──> dbt_deps ──> dbt_run ──> dbt_test
       (PythonOperator)        (Bash)        (Bash)       (Bash)
       ~25 giây                ~5 giây       ~8 giây      ~3 giây
```

---

## 3. Cấu trúc Thư mục

```
Olist_Analytics_Platform/
├── docker-compose.yaml              # Định nghĩa tất cả services
├── Dockerfile                       # Airflow image (cài dbt-core, dbt-postgres)
├── requirements.txt                 # Python deps cho Airflow (bao gồm dbt)
├── .env                             # Biến môi trường (DB credentials)
│
├── dags/
│   ├── extract_data.py              # Extract: MySQL → PostgreSQL staging
│   └── transform/
│       └── e_commerce_dw_dag.py     # DAG chính: Extract → dbt_deps → dbt_run → dbt_test
│
├── plugins/
│   ├── mysql_operator.py            # Custom MySQL operator
│   └── postgresql_operator.py       # Custom PostgreSQL operator
│
├── dbt_olist/                       # ← dbt project (mount vào cả dbt + airflow containers)
│   ├── dbt_project.yml              # Config: staging=view, intermediate=ephemeral, marts=table
│   ├── packages.yml                 # dbt_utils package
│   ├── profiles/
│   │   └── profiles.yml             # Kết nối tới de_psql container
│   ├── macros/
│   │   └── generate_schema_name.sql # Override schema naming (tránh prefix)
│   └── models/
│       ├── staging/                 # Layer 1: Views — làm sạch cơ bản, 1:1 với source
│       │   ├── sources.yml
│       │   ├── stg_customers.sql
│       │   ├── stg_orders.sql
│       │   ├── stg_order_items.sql
│       │   ├── stg_payments.sql
│       │   ├── stg_products.sql
│       │   ├── stg_sellers.sql
│       │   ├── stg_geolocation.sql
│       │   └── stg_category_translation.sql
│       ├── intermediate/            # Layer 2: Ephemeral — join & enrich
│       │   ├── int_products_joined.sql
│       │   └── int_orders_enriched.sql
│       └── marts/                   # Layer 3: Tables — final dim & fact
│           ├── dim_customers.sql
│           ├── dim_products.sql
│           ├── dim_sellers.sql
│           ├── dim_geolocation.sql
│           ├── dim_date.sql
│           ├── dim_payments.sql
│           └── fact_orders.sql
│
├── docker/dbt/Dockerfile            # dbt container image
├── docs/                            # Tài liệu dự án
└── data/raw/                        # CSV files gốc (Olist dataset)
```

### dbt 3-Layer Model

| Layer | Materialization | Output Schema | Số models | Vai trò |
|---|---|---|---|---|
| **staging** | `view` | `staging_dbt` | 8 | Cast types, trim, pad zip codes, lowercase. 1:1 với source |
| **intermediate** | `ephemeral` | *(không tạo trong DB)* | 2 | Join nhiều bảng, tính delivery metrics. Chỉ là CTE |
| **marts** | `table` | `warehouse` | 7 | Surrogate keys, SCD columns. Metabase đọc từ đây |

### Dependency Graph

```
staging.stg_* (raw tables from Airflow)
       │
       ▼
┌─ STAGING (views) ──────────────────────────────────────┐
│ stg_customers  stg_orders  stg_order_items stg_payments│
│ stg_products   stg_sellers stg_geolocation             │
│ stg_category_translation                               │
└──────┬─────────────┬────────────────┬──────────────────┘
       │             │                │
       ▼             ▼                ▼
┌─ INTERMEDIATE (ephemeral) ─────────────────────────────┐
│ int_products_joined        int_orders_enriched         │
│ (products + categories)    (orders + items + payments)  │
└──────┬──────────────────────────────┬──────────────────┘
       │                              │
       ▼                              ▼
┌─ MARTS (tables) ───────────────────────────────────────┐
│ dim_customers  dim_products  dim_sellers  dim_date     │
│ dim_geolocation  dim_payments                          │
│                                                        │
│           fact_orders ←── (joins tất cả dims)          │
└────────────────────────────────────────────────────────┘
```

---

## 4. Hướng dẫn Chạy Dự án

### Yêu cầu
- Docker & Docker Compose
- Ports trống: 3000, 3307, 5433, 8080

### Bước 1: Clone và khởi động

```bash
git clone <repo-url>
cd Olist_Analytics_Platform

# Build images và start tất cả services
docker compose build
docker compose up -d
```

### Bước 2: Load data vào MySQL (lần đầu)

```bash
# Chạy script load CSV vào MySQL
docker exec -it mysql bash
cd /tmp/load_dataset
# Chạy các SQL scripts theo hướng dẫn trong load_dataset_into_mysql/
```

### Bước 3: Cấu hình Airflow Connections (lần đầu)

Truy cập Airflow UI: http://localhost:8080 (user: `airflow`, pass: `airflow`)

Tạo 2 connections trong Admin → Connections:

| Conn ID | Type | Host | Schema | Login | Password | Port |
|---|---|---|---|---|---|---|
| `mysql` | MySQL | mysql | olist | admin | admin | 3306 |
| `postgres` | Postgres | de_psql | postgres | admin | admin | 5432 |

### Bước 4: Chạy Pipeline

**Cách 1 — Qua Airflow UI:**
1. Mở http://localhost:8080
2. Tìm DAG `e_commerce_elt`
3. Bật toggle (Unpause) → Click "Trigger DAG"
4. Theo dõi 4 tasks chạy tuần tự: Extract → dbt_deps → dbt_run → dbt_test

**Cách 2 — Qua CLI:**
```bash
# Trigger DAG
docker exec olist_analytics_platform-airflow-webserver-1 \
  airflow dags trigger e_commerce_elt
```

**Cách 3 — Chạy dbt thủ công (debug):**
```bash
# Test kết nối
docker exec dbt dbt debug --project-dir /usr/app/dbt --profiles-dir /root/.dbt

# Cài packages
docker exec dbt dbt deps --project-dir /usr/app/dbt --profiles-dir /root/.dbt

# Chạy tất cả models
docker exec dbt dbt run --project-dir /usr/app/dbt --profiles-dir /root/.dbt

# Chạy 1 model cụ thể
docker exec dbt dbt run --select dim_customers --project-dir /usr/app/dbt --profiles-dir /root/.dbt
```

### Bước 5: Xem Dashboard

Truy cập Metabase: http://localhost:3000
- Kết nối tới PostgreSQL: host=`de_psql`, port=5432, db=`postgres`, schema=`warehouse`

---

## 5. Chi tiết Kỹ thuật

### Python → SQL Transformation Mapping

| Pandas (cũ) | PostgreSQL SQL (mới) | Ví dụ |
|---|---|---|
| `df['col'].str.zfill(5)` | `lpad(col::text, 5, '0')` | Pad zip code |
| `df['col'].str.title()` | `initcap(trim(col))` | Title case city names |
| `df['col'].str.upper()` | `upper(trim(col))` | Uppercase state codes |
| `df['col'].str.lower()` | `lower(col)` | Lowercase payment types |
| `df['col'].fillna(0)` | `coalesce(col, 0)` | Fill nulls |
| `pd.merge(df1, df2, on='key')` | `LEFT JOIN ... ON` | Join tables |
| `df.drop_duplicates(subset=['col'])` | `DISTINCT ON (col)` | Dedup geolocation |
| `df.index + 1` (surrogate key) | `row_number() over(order by col)` | Generate keys |
| `pd.date_range(start, end)` | `generate_series(start, end, '1 day')` | Date dimension |
| `(col1 - col2).dt.total_seconds() / 86400` | `extract(epoch from (col1 - col2)) / 86400.0` | Delivery time |

### Key Configuration Files

**`dbt_project.yml`** — materialization strategy:
```yaml
models:
  dbt_olist:
    staging:
      +materialized: view
      +schema: staging_dbt
    intermediate:
      +materialized: ephemeral
    marts:
      +materialized: table
      +schema: warehouse
```

**`macros/generate_schema_name.sql`** — tránh prefix schema:
```sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

**`docker-compose.yaml`** — volume mounts cho Airflow:
```yaml
volumes:
  - ./dbt_olist:/opt/airflow/dbt        # dbt project
  - ./dbt_olist/profiles:/home/airflow/.dbt  # dbt profiles
```

---

## 6. Các vấn đề đã xử lý

| # | Vấn đề | Nguyên nhân | Giải pháp |
|---|---|---|---|
| 1 | Schema `warehouse_warehouse` | dbt nối `default_schema + custom_schema` | Tạo macro `generate_schema_name.sql` override behavior |
| 2 | Typo `product_name_lenght` | Column trong DB là `product_name_length` | Fix ở 3 files: stg_products, int_products_joined, dim_products |
| 3 | `docker exec dbt` fail từ Airflow | Airflow container không có Docker CLI | Mount dbt vào Airflow, gọi `dbt` trực tiếp |
| 4 | Staging views ghi đè raw tables | dbt views cùng tên/schema với Airflow source | Đổi staging output sang schema `staging_dbt` |
| 5 | Airflow extract fail khi có views phụ thuộc | `DROP TABLE` fail vì view depend on table | Tách schema, clean up old views |
| 6 | `dbt_utils` package chưa install | Chưa có `dbt deps` step | Thêm task `dbt_deps` vào DAG trước `dbt_run` |

---

## 7. Hướng phát triển nâng cao

### 7.1 Data Quality — dbt Tests & dbt Expectations

Thêm tests trong `schema.yml` cho mỗi layer:

```yaml
# models/marts/schema.yml
version: 2
models:
  - name: fact_orders
    columns:
      - name: order_id
        tests:
          - not_null
          - unique
      - name: customer_key
        tests:
          - not_null
          - relationships:
              to: ref('dim_customers')
              field: customer_key
```

Package nâng cao: [`dbt-expectations`](https://github.com/calogica/dbt-expectations) cho custom data quality rules.

### 7.2 dbt Snapshots — SCD Type 2 tự động

Hiện tại SCD Type 2 đang hardcode (`effective_date = current_date`). dbt Snapshots xử lý tự động:

```sql
-- snapshots/snap_customers.sql
{% snapshot snap_customers %}
{{ config(
    target_schema='snapshots',
    unique_key='customer_id',
    strategy='check',
    check_cols=['customer_city', 'customer_state'],
) }}
select * from {{ ref('stg_customers') }}
{% endsnapshot %}
```

### 7.3 Incremental Models — Xử lý dữ liệu tăng dần

Thay vì `REPLACE` toàn bộ bảng mỗi lần chạy, dùng incremental model:

```sql
-- models/marts/fact_orders.sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='merge'
) }}

select ...
from {{ ref('int_orders_enriched') }}

{% if is_incremental() %}
  where order_purchase_timestamp > (select max(order_purchase_timestamp) from {{ this }})
{% endif %}
```

### 7.4 Astronomer Cosmos — Airflow + dbt integration

Thay vì `BashOperator`, dùng [`astronomer-cosmos`](https://github.com/astronomer/astronomer-cosmos) để Airflow render từng dbt model thành 1 Airflow task. Lợi ích:
- Nhìn thấy dependency graph từng model trên Airflow UI
- Retry từng model riêng biệt
- Song song hóa tốt hơn

### 7.5 Data Lineage & Documentation

```bash
# Tạo documentation site
docker exec dbt dbt docs generate --project-dir /usr/app/dbt --profiles-dir /root/.dbt
docker exec dbt dbt docs serve --port 8081 --project-dir /usr/app/dbt --profiles-dir /root/.dbt
```

### 7.6 CI/CD Pipeline

- Tích hợp `dbt build` (= run + test) vào GitHub Actions
- Chạy `dbt test` trên PR trước khi merge
- Deploy tự động khi merge vào main

### 7.7 Monitoring & Alerting

- **Airflow**: Email/Slack notification khi task fail
- **dbt**: Freshness checks cho source tables
- **Metabase**: Alert khi metrics vượt ngưỡng

---

## 8. Batch Processing & Dashboard theo thời gian

### Câu hỏi: Có khả thi để thêm dữ liệu định kỳ và dashboard batching không?

**Trả lời: Có, hoàn toàn khả thi** — và kiến trúc hiện tại đã sẵn sàng cho điều này.

### Cách hoạt động

```
              ┌──────────┐     ┌──────────┐     ┌──────────┐
Ngày 1:       │ MySQL    │ ──> │ staging  │ ──> │warehouse │ ──> Metabase
(100K rows)   │ snapshot │     │ full load│     │ dbt run  │     Dashboard
              └──────────┘     └──────────┘     └──────────┘
                                                     │
              ┌──────────┐     ┌──────────┐     ┌────▼─────┐
Ngày 2:       │ MySQL    │ ──> │ staging  │ ──> │warehouse │ ──> Metabase
(+5K rows)    │ new data │     │ incremental│   │ dbt run  │     Dashboard
              └──────────┘     └──────────┘     │(chỉ xử lý│     (tự refresh)
                                                │ data mới)│
                                                └──────────┘
```

### Các bước triển khai

#### Bước 1: Chuyển Extract sang Incremental

Sửa `extract_data.py` để chỉ load data mới:

```python
def extract_and_load_to_staging(**kwargs):
    # Lấy timestamp lần chạy trước
    last_run = kwargs['prev_execution_date']
    
    for table in tables:
        # Chỉ lấy records mới/cập nhật
        df = source_operator.get_data_to_pd(
            f"SELECT * FROM {table} WHERE updated_at > '{last_run}'"
        )
        staging_operator.save_data_to_postgres(
            df, f"stg_{table}", schema="staging",
            if_exists="append",  # APPEND thay vì REPLACE
        )
```

#### Bước 2: Chuyển dbt Marts sang Incremental

```sql
-- models/marts/fact_orders.sql
{{ config(
    materialized='incremental',
    unique_key='order_id'
) }}

select ... from {{ ref('int_orders_enriched') }}

{% if is_incremental() %}
  where order_date_key > (select max(order_date_key) from {{ this }})
{% endif %}
```

#### Bước 3: Cấu hình Airflow chạy hàng ngày

DAG hiện tại đã có `schedule_interval=timedelta(days=1)` — chỉ cần unpause:

```python
with DAG(
    dag_id='e_commerce_elt',
    schedule_interval=timedelta(days=1),  # Chạy mỗi ngày
    catchup=False,
) as dag:
```

#### Bước 4: Dashboard Metabase tự động refresh

Metabase hỗ trợ **scheduled cache refresh**. Khi warehouse data được cập nhật bởi dbt, dashboard sẽ tự hiển thị data mới.

### Lưu ý với dataset Olist

Dataset Olist là **static** (2016-2018, ~100K orders). Để demo batch processing, bạn có thể:

1. **Simulate new data**: Viết script tạo fake orders mới insert vào MySQL hàng ngày
2. **Partition by date**: Load data theo từng tháng để giả lập luồng incremental
3. **Sử dụng dbt seeds**: Load CSV bổ sung qua `dbt seed`

### Ví dụ script simulate data mới

```python
# scripts/simulate_new_orders.py
import random
from datetime import datetime, timedelta

def generate_fake_orders(n=100):
    """Tạo n orders mới với timestamp = hôm nay"""
    today = datetime.now()
    orders = []
    for i in range(n):
        orders.append({
            'order_id': f'fake_{today.strftime("%Y%m%d")}_{i}',
            'customer_id': random.choice(existing_customer_ids),
            'order_status': 'delivered',
            'order_purchase_timestamp': today - timedelta(hours=random.randint(1, 24)),
            # ... other fields
        })
    return orders
```

### Kết luận

| Tính năng | Trạng thái | Effort |
|---|---|---|
| Full load hàng ngày (hiện tại) | ✅ Đã hoạt động | Sẵn sàng |
| Incremental load | 🔧 Cần sửa extract + dbt models | 2-3 giờ |
| Scheduled DAG | ✅ Đã cấu hình (1 ngày/lần) | Chỉ cần unpause |
| Dashboard auto-refresh | ✅ Metabase hỗ trợ sẵn | Config trong Metabase |
| Simulate new data | 🔧 Cần viết script | 1-2 giờ |
| SCD Type 2 (track changes) | 🔧 Dùng dbt snapshots | 1-2 giờ |

> **Tóm lại**: Kiến trúc ELT hiện tại đã là nền tảng vững chắc. Chỉ cần chuyển sang incremental models và viết script simulate data là có thể demo batch processing + dashboard theo thời gian hoàn chỉnh.
