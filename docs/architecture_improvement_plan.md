# Olist Analytics Platform - Kế hoạch cải thiện Architecture

Tài liệu này so sánh project hiện tại với project `tunguyenn99/ecommerce-data-modeling`, sau đó đề xuất hướng nâng cấp architecture với Airflow Cosmos, dbt, DuckDB, Bruin và Tableau BI.

Nguồn tham khảo chính: https://github.com/tunguyenn99/ecommerce-data-modeling

---

## 1. Tóm tắt nhanh

Project hiện tại đã có nền tảng Data Engineering khá đầy đủ:

- Source DB: MySQL chứa raw Olist data.
- Data Warehouse: PostgreSQL với các schema `staging`, `staging_dbt`, `warehouse`.
- Orchestration: Apache Airflow.
- Transformation: dbt 3-layer `staging -> intermediate -> marts`.
- BI: Metabase, kèm artifact dashboard Power BI.
- Infrastructure: Docker Compose.

Project của anh Tú đi theo hướng "modern local analytics platform":

- DuckDB làm local OLAP database.
- dbt Core với adapter `dbt-duckdb`.
- Airflow + Astronomer Cosmos để biến dbt project thành Airflow task graph.
- Bruin CLI để kiểm tra connection, query, lineage và workflow validation.
- Evidence.dev làm BI dashboard native với DuckDB.
- SQLFluff và `uv` để nâng chất lượng developer workflow.

Kết luận ngắn gọn:

- Nên học theo project anh Tú ở phần Airflow Cosmos, dbt DAG graph, SQLFluff và cách tổ chức developer workflow.
- Chưa nên thay PostgreSQL bằng DuckDB nếu mục tiêu chính là kết nối Tableau ổn định và mô phỏng Data Warehouse production-like.
- Có thể thêm DuckDB như một optional OLAP layer để demo local analytics, export, benchmark hoặc chạy Evidence.dev.
- Tableau nên kết nối trực tiếp tới PostgreSQL schema `warehouse`.
- Bruin có thể dùng, nhưng nên để ở mức optional validation/dev tool, chưa nên đưa thành thành phần bắt buộc của pipeline.

---

## 2. So sánh project hiện tại và project anh Tú

| Hạng mục | Project hiện tại | Project anh Tú | Nhận xét |
|---|---|---|---|
| Source | MySQL container load CSV Olist | CSV -> DuckDB | Project hiện tại mô phỏng operational source tốt hơn. |
| Warehouse | PostgreSQL | DuckDB file `ecommerce.db` | PostgreSQL hợp với Tableau và production mindset hơn; DuckDB nhanh, gọn cho local OLAP. |
| Transform | dbt-postgres | dbt-duckdb | Cả hai đều dùng dbt đúng hướng. |
| Orchestration | Airflow `BashOperator` chạy `dbt run`, `dbt test` | Airflow + Astronomer Cosmos compile dbt thành task group | Cosmos là điểm nên nâng cấp nhất. |
| DAG observability | Airflow chỉ thấy các task lớn: extract, dbt_run, dbt_test | Airflow thấy dependency của từng dbt model/test | Cosmos giúp debug và trình bày architecture tốt hơn. |
| BI | Metabase, Power BI artifact | Evidence.dev | Nếu muốn Tableau, PostgreSQL phù hợp hơn DuckDB/Evidence. |
| Quality | dbt tests, custom SQL tests | dbt tests, SQLFluff, Bruin | Nên thêm SQLFluff; Bruin nên dùng optional. |
| Local setup | Docker Compose nhiều services | Local-first, DuckDB file, `uv` | Project hiện tại production-like hơn, nhưng nặng hơn. |

---

## 3. Đánh giá architecture hiện tại

Architecture hiện tại:

```text
CSV -> MySQL -> Airflow Extract -> PostgreSQL staging
                                  -> dbt staging_dbt/intermediate/warehouse
                                  -> Metabase/Power BI
```

Điểm mạnh:

- Có tách source DB và warehouse, hợp với tư duy Data Engineering.
- dbt đã thay Pandas transformation, giảm memory bottleneck trong Airflow.
- Có star schema với dimension và fact rõ ràng.
- PostgreSQL dễ kết nối với Tableau, Metabase, Power BI và các SQL client.
- Docker Compose giúp demo end-to-end dễ lặp lại.

Điểm cần cải thiện:

- Airflow đang chạy dbt bằng `BashOperator`, nên Airflow không nhìn thấy dependency graph của từng dbt model.
- `dbt_run` là một task lớn; khi fail phải vào log để tìm model lỗi.
- Chưa có `dbt docs generate/serve` trong workflow chính thức.
- Chưa có SQL linting chính thức.
- Có `duckdb` và `astronomer-cosmos` trong `requirements.txt`, nhưng architecture chưa sử dụng thật sự.
- BI layer chưa chốt rõ: Metabase, Power BI hay Tableau.

---

## 4. Có nên dùng DuckDB làm OLAP không?

### Khuyến nghị

Không nên thay PostgreSQL bằng DuckDB làm warehouse chính trong project này nếu mục tiêu là:

- thể hiện Data Warehouse production-like,
- kết nối Tableau dễ dàng,
- cho nhiều BI tool hoặc nhiều client truy cập cùng lúc,
- giữ kiến trúc source DB -> warehouse -> BI rõ ràng.

Nên dùng DuckDB theo 1 trong 2 cách sau:

1. **Optional local OLAP layer**
   - PostgreSQL vẫn là warehouse chính.
   - Sau dbt marts, export các table trong schema `warehouse` sang DuckDB hoặc Parquet.
   - DuckDB dùng để query local rất nhanh, demo notebook, Evidence.dev hoặc benchmark.

2. **Alternative lightweight profile**
   - Tạo thêm dbt profile `duckdb_dev`.
   - Cho phép chạy dbt trên DuckDB khi muốn local-only, không cần Docker/Postgres.
   - Cách này tốt cho demo cá nhân, nhưng tăng công bảo trì vì phải đảm bảo SQL tương thích giữa PostgreSQL và DuckDB.

### Khi nào DuckDB phù hợp

- Dataset vừa/nhỏ, local analytics, single-user.
- Muốn demo nhanh không cần server database.
- Muốn query CSV/Parquet trực tiếp.
- Muốn tạo file `.duckdb` để share kèm dashboard local.

### Khi nào PostgreSQL phù hợp hơn

- Kết nối Tableau ổn định.
- Muốn mô phỏng DWH có service riêng.
- Cần multi-user access.
- Cần Airflow, dbt và BI cùng kết nối vào một database service.
- Muốn project portfolio trông gần production hơn.

---

## 5. Tableau BI nên kết nối với cái nào?

### Lựa chọn khuyến nghị: Tableau -> PostgreSQL

Nên để Tableau kết nối trực tiếp vào PostgreSQL:

```text
Tableau Desktop
  -> PostgreSQL connector
  -> host: localhost
  -> port: 5433
  -> database: postgres
  -> schema: warehouse
  -> tables: fact_orders, dim_customers, dim_products, dim_sellers, dim_payments, dim_date, dim_geolocation
```

Lý do:

- Tableau có native PostgreSQL connector.
- PostgreSQL đang là warehouse chính của project.
- Các marts trong schema `warehouse` đã được dbt materialize thành table, phù hợp cho BI.
- Không cần cài thêm ODBC/JDBC driver cho DuckDB.
- Dễ publish hoặc refresh hơn nếu sau này đưa lên server/cloud.

### Lựa chọn phụ: Tableau -> DuckDB

Chỉ nên dùng nếu rất muốn một local OLAP file:

```text
PostgreSQL warehouse -> export marts -> olist.duckdb -> Tableau via DuckDB ODBC/JDBC
```

Hạn chế:

- Tableau không có native DuckDB connector phổ biến như PostgreSQL.
- Cần cài DuckDB ODBC/JDBC driver.
- Refresh và share workbook phức tạp hơn.
- File database local có thể bị lock nếu nhiều process truy cập cùng lúc.

### Lựa chọn export: Tableau -> Parquet/CSV

Có thể dùng cho demo static:

```text
PostgreSQL warehouse -> export Parquet/CSV -> Tableau file connection
```

Nhưng cách này không đẹp bằng kết nối PostgreSQL vì mất tính chất live warehouse.

---

## 6. Project có nên dùng Bruin không?

### Bruin là gì trong context project anh Tú?

Trong project anh Tú, Bruin được dùng như một CLI hỗ trợ workflow analytics engineering:

- quản lý và kiểm tra connection,
- chạy query ad-hoc vào DuckDB,
- validate SQL/query rendering,
- hỗ trợ lineage hoặc kiểm tra asset ở mức workflow.

Bruin không thay thế dbt và cũng không thay Airflow. Nó giống một lớp tooling bổ sung cho developer experience và validation.

### Khuyến nghị cho project hiện tại

Nên dùng Bruin, nhưng chưa nên đưa vào core architecture ngay.

Mức ưu tiên hợp lý:

1. **Không bắt buộc cho pipeline chính**
   - Pipeline chính vẫn nên là Airflow + Cosmos + dbt + PostgreSQL + Tableau.
   - Airflow lo orchestration.
   - dbt lo transformation, tests, docs và lineage ở mức model.
   - PostgreSQL là warehouse.
   - Tableau là BI.

2. **Dùng Bruin như optional dev/validation tool**
   - Kiểm tra nhanh PostgreSQL/DuckDB connection.
   - Chạy query smoke test sau khi dbt build xong.
   - Validate một số query quan trọng cho dashboard.
   - Làm project trông hiện đại hơn nếu trình bày trong portfolio.

3. **Chỉ đưa Bruin vào CI/CD nếu đã có GitHub Actions**
   - Khi có CI, Bruin có thể chạy cùng `dbt parse`, `dbt build`, SQLFluff.
   - Nếu chưa có CI, thêm Bruin quá sớm có thể làm project phức tạp không cần thiết.

### Khi nào nên thêm Bruin

Nên thêm Bruin nếu bạn muốn:

- học thêm modern analytics engineering tooling,
- có command kiểm tra connection và query rõ ràng,
- bổ sung một lớp validation ngoài dbt tests,
- làm README/portfolio nổi bật hơn,
- có kế hoạch thêm CI/CD.

### Khi nào chưa cần Bruin

Chưa cần Bruin nếu:

- mục tiêu trước mắt là hoàn thiện Airflow Cosmos + Tableau,
- project vẫn chạy local thủ công,
- chưa có nhiều query ad-hoc hoặc nhiều environment,
- bạn muốn giảm độ phức tạp để demo dễ hiểu.

### Kết luận về Bruin

Với project này, thứ tự nên là:

```text
Airflow Cosmos + dbt build + Tableau
  -> SQLFluff + dbt docs
  -> optional DuckDB export
  -> optional Bruin validation
  -> CI/CD
```

Tức là có thể dùng Bruin, nhưng nên coi là điểm cộng ở tầng developer workflow, không phải thành phần cốt lõi bắt buộc.

---

## 7. Architecture đề xuất

### Phase 1 - Nâng cấp orchestration với Airflow Cosmos

Mục tiêu: thay `BashOperator(dbt run)` bằng Cosmos `DbtTaskGroup`.

Architecture:

```text
MySQL
  -> Airflow PythonOperator: extract_and_load_to_staging
  -> Cosmos DbtTaskGroup:
       stg_customers
       stg_orders
       stg_order_items
       ...
       int_orders_enriched
       dim_*
       fact_orders
       dbt tests
  -> Email/notification
  -> Tableau reads PostgreSQL warehouse
```

Lợi ích:

- Airflow UI hiện từng dbt model như một task riêng.
- Model nào fail thấy ngay trên graph.
- Thể hiện lineage tốt hơn khi thuyết trình.
- Giảm `BashOperator` thủ công.
- Gần với modern analytics engineering pattern trong project anh Tú.

Ví dụ DAG target:

```python
from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig, ExecutionConfig
from cosmos.profiles import PostgresUserPasswordProfileMapping

DBT_PROJECT = "/opt/airflow/dbt"
DBT_PROFILES = "/home/airflow/.dbt"

dbt_profile_config = ProfileConfig(
    profile_name="dbt_olist",
    target_name="dev",
    profile_mapping=PostgresUserPasswordProfileMapping(
        conn_id="postgres",
        profile_args={
            "schema": "warehouse",
        },
    ),
)

dbt_models = DbtTaskGroup(
    group_id="dbt_transform",
    project_config=ProjectConfig(DBT_PROJECT),
    profile_config=dbt_profile_config,
    execution_config=ExecutionConfig(
        dbt_executable_path="/home/airflow/.local/bin/dbt",
    ),
)
```

Workflow mới:

```text
drop_dbt_staging_views
  -> extract_and_load_to_staging
  -> dbt_transform [Cosmos TaskGroup]
  -> optional_bruin_validation
  -> send_success_email
```

Ghi chú: `dbt test` có thể được Cosmos render thành task test riêng, tùy config và version Cosmos.

---

## 8. Phase 2 - Chuẩn hóa dbt project

Nên bổ sung:

- `dbt docs generate` trong workflow local.
- `schema.yml` đầy đủ cho tất cả marts: description, tests, relationship tests.
- `exposures.yml` cho Tableau dashboard.
- `sources.yml` có freshness check cho raw staging nếu có `loaded_at_field`.
- SQLFluff với dbt templater.
- Convention đặt tên: dùng `fct_` thay vì `fact_` nếu muốn theo dbt/Kimball common style, hoặc giữ `fact_` nhưng cần nhất quán trong docs.

Đề xuất dbt layer:

```text
models/
  staging/
    sources.yml
    stg_*.sql
    schema.yml
  intermediate/
    int_*.sql
    schema.yml
  marts/
    core/
      dim_*.sql
      fact_orders.sql
      schema.yml
    metrics/
      agg_monthly_revenue.sql
      agg_category_performance.sql
      schema.yml
```

Nên thêm marts aggregate cho BI:

- `agg_monthly_sales`
- `agg_product_category_performance`
- `agg_seller_performance`
- `agg_delivery_performance`
- `agg_state_city_revenue`

Lý do: Tableau có thể query fact/dim trực tiếp, nhưng dashboard sẽ nhanh hơn và dễ dùng hơn nếu có aggregate marts.

---

## 9. Phase 3 - Thêm DuckDB như optional OLAP layer

Nếu muốn dùng DuckDB mà không phá architecture chính, thêm task sau dbt:

```text
dbt_transform on PostgreSQL
  -> export_warehouse_to_duckdb
  -> optional Evidence.dev / local DuckDB analysis
```

File đề xuất:

```text
scripts/export_postgres_to_duckdb.py
data/olap/olist.duckdb
```

Bảng nên export:

- `warehouse.fact_orders`
- `warehouse.dim_customers`
- `warehouse.dim_products`
- `warehouse.dim_sellers`
- `warehouse.dim_payments`
- `warehouse.dim_date`
- `warehouse.dim_geolocation`
- các `agg_*` marts nếu có

Vai trò:

- DuckDB là analytics cache/local OLAP artifact.
- PostgreSQL vẫn là source of truth cho BI live connection.
- Tableau mặc định kết nối PostgreSQL; DuckDB chỉ là bonus.

---

## 10. Workflow project đề xuất

### Local development workflow

```text
1. Start infrastructure
   docker compose up -d --build

2. Load raw CSV vào MySQL
   make mysql_create
   make mysql_load

3. Kiểm tra dbt riêng
   docker exec dbt dbt debug
   docker exec dbt dbt deps
   docker exec dbt dbt build

4. Trigger Airflow DAG
   e_commerce_elt_cosmos

5. Validate warehouse
   dbt test
   dbt docs generate
   optional: bruin connections list
   optional: bruin query ...

6. Mở BI
   Tableau -> PostgreSQL localhost:5433 -> schema warehouse
```

### Production-like workflow trong Airflow

```text
DAG: e_commerce_elt_cosmos

start
  -> drop_dbt_staging_views
  -> extract_mysql_to_postgres_staging
  -> dbt_transform_and_test (Cosmos)
  -> optional_bruin_validation
  -> optional_export_to_duckdb
  -> notify_success
```

### BI workflow với Tableau

```text
1. Kết nối Tableau Desktop với PostgreSQL.
2. Chọn schema `warehouse`.
3. Dùng `fact_orders` làm central fact table.
4. Relationship:
   - fact_orders.customer_key -> dim_customers.customer_key
   - fact_orders.product_key -> dim_products.product_key
   - fact_orders.seller_key -> dim_sellers.seller_key
   - fact_orders.payment_key -> dim_payments.payment_key
   - fact_orders.order_date_key -> dim_date.date_key
5. Tạo dashboards:
   - Executive Sales Overview
   - Product Category Performance
   - Delivery Performance
   - Customer Geography
   - Seller Performance
```

---

## 11. File/folder nên thêm hoặc sửa

### Nên thêm

```text
dags/transform/e_commerce_elt_cosmos.py
scripts/export_postgres_to_duckdb.py
dbt_olist/models/marts/metrics/agg_monthly_sales.sql
dbt_olist/models/marts/metrics/agg_product_category_performance.sql
dbt_olist/models/marts/metrics/agg_delivery_performance.sql
dbt_olist/models/exposures.yml
.sqlfluff
docs/tableau_connection_guide.md
optional: .bruin.yml
optional: bruin/queries/*.sql
```

### Nên sửa

```text
requirements.txt
Dockerfile
docker-compose.yaml
dbt_olist/dbt_project.yml
dbt_olist/models/**/schema.yml
README.md
```

### Không nên làm ngay

- Không nên bỏ PostgreSQL để chuyển hết sang DuckDB nếu mục tiêu là Tableau.
- Không nên duy trì cùng lúc Metabase, Power BI, Tableau, Evidence.dev như các BI chính. Nên chọn Tableau là primary BI, các tool khác để demo/reference.
- Không nên đưa Bruin thành dependency bắt buộc trong Airflow DAG khi chưa có CI/CD hoặc nhu cầu validation rõ ràng.

---

## 12. Roadmap ưu tiên

### Priority 1 - High impact

1. Tạo DAG mới `e_commerce_elt_cosmos.py`.
2. Dùng Cosmos render dbt models/tests thay cho `dbt_run` BashOperator.
3. Thêm `dbt build` vào workflow local.
4. Thêm Tableau connection guide.
5. Cập nhật README architecture diagram.

### Priority 2 - BI readiness

1. Thêm aggregate marts cho dashboard.
2. Thêm dbt exposures cho Tableau.
3. Thêm descriptions/tests đầy đủ trong `schema.yml`.
4. Tạo dashboard Tableau trên schema `warehouse`.

### Priority 3 - Developer workflow

1. Thêm SQLFluff.
2. Thêm dbt docs.
3. Thêm Bruin ở dạng optional validation CLI.
4. Thêm GitHub Actions nếu muốn kiểm tra tự động.

### Priority 4 - Optional OLAP

1. Thêm export PostgreSQL -> DuckDB.
2. Thêm `dbt-duckdb` profile nếu muốn chạy local-only.
3. Thêm Evidence.dev nếu muốn có dashboard code-based trong repo.

---

## 13. Architecture final khuyến nghị

```text
                         +----------------------+
                         |      Raw CSV         |
                         +----------+-----------+
                                    |
                                    v
                         +----------------------+
                         | MySQL Source DB      |
                         +----------+-----------+
                                    |
                         Airflow PythonOperator
                                    |
                                    v
                         +----------------------+
                         | PostgreSQL staging   |
                         +----------+-----------+
                                    |
                         Airflow Cosmos + dbt
                                    |
                +-------------------+-------------------+
                |                   |                   |
                v                   v                   v
        staging_dbt views     intermediate CTEs   warehouse marts
                                                    dim/fact/agg
                                                        |
                                                        v
                                             +----------------------+
                                             | Tableau BI           |
                                             | PostgreSQL connector |
                                             +----------------------+
                                                        |
                                          optional validation/export
                                                        |
                              +-------------------------+-------------------------+
                              |                                                   |
                              v                                                   v
                     +----------------------+                         +----------------------+
                     | Bruin validation     |                         | DuckDB local OLAP    |
                     +----------------------+                         +----------------------+
```

Đây là hướng cân bằng tốt nhất cho project:

- Vẫn giữ được source -> warehouse -> BI như một Data Engineering project nghiêm túc.
- Thêm Cosmos để architecture hiện đại và dễ quan sát hơn.
- Tableau kết nối ổn định vào PostgreSQL.
- DuckDB trở thành điểm cộng local OLAP thay vì làm phức tạp BI chính.
- Bruin là điểm cộng cho validation/developer workflow, không phải thành phần bắt buộc của pipeline.

