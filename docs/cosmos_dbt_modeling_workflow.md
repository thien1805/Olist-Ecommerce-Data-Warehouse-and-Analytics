# Cosmos + dbt Modeling Workflow

Tài liệu này mô tả workflow mới sau khi migrate Airflow DAG sang Astronomer Cosmos và tổ chức lại dbt models theo hướng giống modern analytics project.

---

## 1. Airflow workflow mới

DAG chính: `e_commerce_elt`

```text
drop_dbt_staging_views
  -> extract_and_load_to_staging
  -> dbt_transform [Cosmos DbtTaskGroup]
  -> send_success_email
```

Điểm khác so với bản cũ:

- Trước đây Airflow chỉ thấy 2 task lớn: `dbt_run` và `dbt_test`.
- Bây giờ Cosmos render từng dbt model/test thành task trong Airflow UI.
- Khi model fail, có thể nhìn trực tiếp model nào fail trên graph.
- dbt docs/exposures có lineage rõ hơn cho dashboard Tableau.

---

## 2. dbt folder structure mới

```text
dbt_olist/models/
  exposures.yml
  staging/
    sources.yml
    schema.yml
    stg_*.sql
  intermediate/
    schema.yml
    int_*.sql
  marts/
    core/
      schema.yml
      dim_*.sql
      fact_*.sql
    metrics/
      schema.yml
      agg_*.sql
```

Ý nghĩa từng layer:

- `staging`: clean/cast/rename nhẹ từ raw tables trong PostgreSQL schema `staging`.
- `intermediate`: chuẩn hóa grain và join logic. Layer này đang materialize dạng `ephemeral`.
- `marts/core`: dim/fact chính dùng cho Tableau relationship model.
- `marts/metrics`: aggregate marts phục vụ dashboard query nhanh hơn.
- `exposures.yml`: khai báo Tableau dashboard trong dbt docs lineage.

---

## 3. Grain của các bảng chính

| Model | Layer | Grain | Mục đích |
|---|---|---|---|
| `dim_customers` | marts/core | 1 dòng / customer_id | Customer attributes và geography |
| `dim_products` | marts/core | 1 dòng / product_id | Product attributes và English category |
| `dim_sellers` | marts/core | 1 dòng / seller_id | Seller attributes và geography |
| `dim_geolocation` | marts/core | 1 dòng / zip code prefix | Geolocation lookup |
| `dim_date` | marts/core | 1 dòng / date | Calendar analysis |
| `dim_payments` | marts/core | 1 dòng / order payment sequence | Payment transaction drill-through |
| `fact_orders` | marts/core | 1 dòng / order_id | Order-level sales, payment, review, delivery KPIs |
| `fact_order_items` | marts/core | 1 dòng / order_id + order_item_id | Product/category/seller sales analysis |

Điểm quan trọng: `fact_orders` không join trực tiếp `order_items` với `payments` ở raw grain nữa, vì cách đó có thể nhân dòng khi một order có nhiều item và nhiều payment. Thay vào đó:

```text
stg_order_items -> int_order_items_aggregated
stg_payments    -> int_order_payments_aggregated
stg_reviews     -> int_order_reviews_aggregated
                         |
                         v
                  int_orders_enriched
                         |
                         v
                    fact_orders
```

---

## 4. Metrics marts cho Tableau

Các bảng aggregate mới:

- `agg_monthly_sales`: GMV, orders, AOV, delivery rate, review score theo tháng.
- `agg_product_category_performance`: doanh thu và số lượng theo product category.
- `agg_delivery_performance`: delivery KPI theo customer state/city.
- `agg_seller_performance`: seller revenue và order item performance.

Tableau có thể dùng 2 kiểu:

1. Relationship model trên `fact_orders`, `fact_order_items` và các dimensions.
2. Kết nối trực tiếp các bảng `agg_*` cho dashboard nhanh và đơn giản hơn.

---

## 5. Bruin nên đặt ở đâu?

Bruin chưa được đưa vào core pipeline. Nếu muốn dùng giống project anh Tú, nên dùng như optional validation sau dbt:

```text
dbt_transform [Cosmos]
  -> optional_bruin_validation
  -> optional_export_to_duckdb
```

Vai trò phù hợp:

- kiểm tra connection PostgreSQL/DuckDB,
- chạy smoke query cho các bảng marts,
- validate một vài query quan trọng cho Tableau,
- dùng trong CI/CD sau này.

Chưa nên để Bruin thay Airflow hoặc dbt. Trong project này:

- Airflow + Cosmos: orchestration.
- dbt: transformation, tests, docs, exposures.
- PostgreSQL: warehouse chính.
- Tableau: BI chính.
- Bruin: optional developer validation.

---

## 6. Lệnh kiểm tra khuyến nghị

Chạy trong folder `dbt_olist`:

```bash
../.venv/bin/dbt parse --profiles-dir profiles --no-partial-parse
../.venv/bin/dbt build --profiles-dir profiles
../.venv/bin/dbt docs generate --profiles-dir profiles
```

Nếu chạy bằng Docker:

```bash
docker exec dbt dbt parse
docker exec dbt dbt build
docker exec dbt dbt docs generate
```

Với Airflow:

```bash
docker exec olist_analytics_platform-airflow-webserver-1 \
  airflow dags trigger e_commerce_elt
```

