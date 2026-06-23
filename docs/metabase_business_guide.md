# Metabase Guide cho Olist Analytics (macOS)

Tài liệu này giúp bạn:
- Kết nối Metabase với PostgreSQL trong project.
- Trả lời các business requirement quan trọng từ dữ liệu Olist.
- Triển khai dashboard cụ thể, có thứ tự thực hiện rõ ràng.

## 1) Kết nối Metabase vào database

Metabase đã chạy trong Docker Compose.

Thông số kết nối trong Metabase:
- Database type: PostgreSQL
- Host: `de_psql`
- Port: `5432`
- Database name: `postgres`
- Username: `admin`
- Password: `admin`
- Schema để phân tích: `warehouse`

Lý do host là `de_psql`: Metabase chạy cùng Docker network nên dùng tên service nội bộ, không dùng `localhost`.

## 2) Kiểm tra dữ liệu trước khi làm dashboard

Chạy các SQL sau trong Metabase SQL editor để xác nhận pipeline đã load dữ liệu vào `warehouse`.

### 2.1 Kiểm tra bảng đã có

```sql
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'warehouse'
ORDER BY table_name;
```

### 2.2 Kiểm tra số dòng từng bảng

```sql
SELECT 'dim_customers' AS table_name, COUNT(*) AS row_count FROM warehouse.dim_customers
UNION ALL
SELECT 'dim_products', COUNT(*) FROM warehouse.dim_products
UNION ALL
SELECT 'dim_sellers', COUNT(*) FROM warehouse.dim_sellers
UNION ALL
SELECT 'dim_geolocation', COUNT(*) FROM warehouse.dim_geolocation
UNION ALL
SELECT 'dim_dates', COUNT(*) FROM warehouse.dim_dates
UNION ALL
SELECT 'dim_payments', COUNT(*) FROM warehouse.dim_payments
UNION ALL
SELECT 'fact_orders', COUNT(*) FROM warehouse.fact_orders;
```

### 2.3 Kiểm tra dữ liệu thiếu ở fact

```sql
SELECT
  COUNT(*) AS total_rows,
  COUNT(*) FILTER (WHERE order_id IS NULL) AS null_order_id,
  COUNT(*) FILTER (WHERE customer_key IS NULL) AS null_customer_key,
  COUNT(*) FILTER (WHERE product_key IS NULL) AS null_product_key,
  COUNT(*) FILTER (WHERE seller_key IS NULL) AS null_seller_key,
  COUNT(*) FILTER (WHERE order_date_key IS NULL) AS null_order_date_key
FROM warehouse.fact_orders;
```

## 3) Business requirements (đề xuất) + SQL trả lời

## BR1: Doanh thu và số đơn theo tháng đang tăng hay giảm?

Business value:
- Theo dõi tăng trưởng.
- Kiểm tra seasonality.

SQL:

```sql
SELECT
  date_trunc('month', fo.order_date_key::timestamp)::date AS month,
  COUNT(DISTINCT fo.order_id) AS total_orders,
  ROUND(SUM(COALESCE(fo.price, 0) + COALESCE(fo.freight_value, 0))::numeric, 2) AS gmv,
  ROUND(
    (SUM(COALESCE(fo.price, 0) + COALESCE(fo.freight_value, 0))
    / NULLIF(COUNT(DISTINCT fo.order_id), 0))::numeric,
    2
  ) AS aov
FROM warehouse.fact_orders fo
GROUP BY 1
ORDER BY 1;
```

## BR2: Cơ cấu trạng thái đơn hàng như thế nào?

Business value:
- Đánh giá mức độ fulfillment và rủi ro hủy đơn.

SQL:

```sql
SELECT
  fo.order_status,
  COUNT(DISTINCT fo.order_id) AS orders,
  ROUND(100.0 * COUNT(DISTINCT fo.order_id)
    / NULLIF(SUM(COUNT(DISTINCT fo.order_id)) OVER (), 0), 2) AS pct_orders
FROM warehouse.fact_orders fo
GROUP BY fo.order_status
ORDER BY orders DESC;
```

## BR3: Top danh mục sản phẩm theo doanh thu

Business value:
- Ưu tiên danh mục để marketing và tồn kho.

SQL:

```sql
SELECT
  COALESCE(dp.product_category_name_english, 'Unknown') AS category,
  COUNT(DISTINCT fo.order_id) AS orders,
  ROUND(SUM(COALESCE(fo.price, 0) + COALESCE(fo.freight_value, 0))::numeric, 2) AS gmv
FROM warehouse.fact_orders fo
LEFT JOIN warehouse.dim_products dp
  ON fo.product_key = dp.product_key
GROUP BY 1
ORDER BY gmv DESC
LIMIT 10;
```

## BR4: Bang/tiểu bang nào mang lại doanh thu cao nhất?

Business value:
- Tối ưu phân bổ ngân sách vùng.

SQL:

```sql
SELECT
  dc.customer_state,
  COUNT(DISTINCT fo.order_id) AS orders,
  ROUND(SUM(COALESCE(fo.price, 0) + COALESCE(fo.freight_value, 0))::numeric, 2) AS gmv
FROM warehouse.fact_orders fo
LEFT JOIN warehouse.dim_customers dc
  ON fo.customer_key = dc.customer_key
GROUP BY 1
ORDER BY gmv DESC;
```

## BR5: Seller nào đóng góp doanh thu lớn nhất?

Business value:
- Xếp hạng đối tác seller để có chính sách phù hợp.

SQL:

```sql
SELECT
  ds.seller_id,
  ds.seller_state,
  COUNT(DISTINCT fo.order_id) AS orders,
  ROUND(SUM(COALESCE(fo.price, 0) + COALESCE(fo.freight_value, 0))::numeric, 2) AS gmv
FROM warehouse.fact_orders fo
LEFT JOIN warehouse.dim_sellers ds
  ON fo.seller_key = ds.seller_key
GROUP BY 1, 2
ORDER BY gmv DESC
LIMIT 15;
```

## BR6: Hành vi thanh toán (payment type, installment)

Business value:
- Hiểu xu hướng thanh toán để tối ưu checkout.

SQL:

```sql
SELECT
  dp.payment_type,
  AVG(dp.payment_installments) AS avg_installments,
  ROUND(SUM(COALESCE(fo.payment_value, 0))::numeric, 2) AS total_payment_value,
  COUNT(DISTINCT fo.order_id) AS orders
FROM warehouse.fact_orders fo
LEFT JOIN warehouse.dim_payments dp
  ON fo.payment_key = dp.payment_key
GROUP BY 1
ORDER BY total_payment_value DESC;
```

## BR7: Hiệu năng giao hàng có đúng kỳ vọng không?

Business value:
- Kiểm soát SLA giao hàng.

SQL:

```sql
SELECT
  date_trunc('month', fo.order_date_key::timestamp)::date AS month,
  ROUND(AVG(fo.delivery_time)::numeric, 2) AS avg_delivery_days,
  ROUND(AVG(fo.estimated_delivery_time)::numeric, 2) AS avg_estimated_days,
  ROUND(
    100.0 * AVG(CASE WHEN fo.delivery_time > fo.estimated_delivery_time THEN 1 ELSE 0 END)::numeric,
    2
  ) AS late_delivery_pct
FROM warehouse.fact_orders fo
WHERE fo.delivery_time IS NOT NULL
  AND fo.estimated_delivery_time IS NOT NULL
GROUP BY 1
ORDER BY 1;
```

## BR8: Tỷ lệ hủy đơn và doanh thu bị mất theo tháng

Business value:
- Đo mức độ thất thoát và nguyên nhân vận hành.

SQL:

```sql
SELECT
  date_trunc('month', fo.order_date_key::timestamp)::date AS month,
  COUNT(DISTINCT fo.order_id) FILTER (WHERE fo.order_status = 'canceled') AS canceled_orders,
  ROUND(
    SUM(COALESCE(fo.price, 0) + COALESCE(fo.freight_value, 0))
      FILTER (WHERE fo.order_status = 'canceled')::numeric,
    2
  ) AS canceled_gmv,
  ROUND(
    100.0 * COUNT(DISTINCT fo.order_id) FILTER (WHERE fo.order_status = 'canceled')
    / NULLIF(COUNT(DISTINCT fo.order_id), 0),
    2
  ) AS cancel_rate_pct
FROM warehouse.fact_orders fo
GROUP BY 1
ORDER BY 1;
```

## BR9: Tỷ lệ khách hàng mua lại (repeat customers)

Business value:
- Đo loyalty và khả năng giữ chân.

SQL:

```sql
WITH customer_orders AS (
  SELECT
    customer_key,
    COUNT(DISTINCT order_id) AS order_cnt
  FROM warehouse.fact_orders
  GROUP BY customer_key
)
SELECT
  COUNT(*) AS total_customers,
  COUNT(*) FILTER (WHERE order_cnt > 1) AS repeat_customers,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE order_cnt > 1) / NULLIF(COUNT(*), 0),
    2
  ) AS repeat_rate_pct
FROM customer_orders;
```

## BR10: Doanh thu theo thứ trong tuần (day-of-week)

Business value:
- Tối ưu lịch campaign và vận hành theo ngày.

SQL:

```sql
SELECT
  dd.day_name,
  dd.day_of_week,
  COUNT(DISTINCT fo.order_id) AS orders,
  ROUND(SUM(COALESCE(fo.price, 0) + COALESCE(fo.freight_value, 0))::numeric, 2) AS gmv
FROM warehouse.fact_orders fo
LEFT JOIN warehouse.dim_dates dd
  ON fo.order_date_key::date = dd.date_key::date
GROUP BY 1, 2
ORDER BY dd.day_of_week;
```

## 4) Cách triển khai trên database (chuẩn cho Metabase)

Mục tiêu: tạo layer analytics ổn định để dashboard chạy nhanh, dễ maintain.

### 4.1 Tạo schema analytics

```sql
CREATE SCHEMA IF NOT EXISTS analytics;
```

### 4.2 Tạo view tổng hợp KPI theo tháng

```sql
CREATE OR REPLACE VIEW analytics.vw_monthly_kpi AS
SELECT
  date_trunc('month', fo.order_date_key::timestamp)::date AS month,
  COUNT(DISTINCT fo.order_id) AS total_orders,
  ROUND(SUM(COALESCE(fo.price, 0) + COALESCE(fo.freight_value, 0))::numeric, 2) AS gmv,
  ROUND(AVG(fo.delivery_time)::numeric, 2) AS avg_delivery_days,
  ROUND(
    100.0 * AVG(CASE WHEN fo.delivery_time > fo.estimated_delivery_time THEN 1 ELSE 0 END)::numeric,
    2
  ) AS late_delivery_pct,
  ROUND(
    100.0 * COUNT(DISTINCT fo.order_id) FILTER (WHERE fo.order_status = 'canceled')
    / NULLIF(COUNT(DISTINCT fo.order_id), 0),
    2
  ) AS cancel_rate_pct
FROM warehouse.fact_orders fo
GROUP BY 1;
```

### 4.3 Tạo view top category

```sql
CREATE OR REPLACE VIEW analytics.vw_category_performance AS
SELECT
  COALESCE(dp.product_category_name_english, 'Unknown') AS category,
  COUNT(DISTINCT fo.order_id) AS orders,
  ROUND(SUM(COALESCE(fo.price, 0) + COALESCE(fo.freight_value, 0))::numeric, 2) AS gmv
FROM warehouse.fact_orders fo
LEFT JOIN warehouse.dim_products dp
  ON fo.product_key = dp.product_key
GROUP BY 1;
```

### 4.4 Tạo view performance theo bang

```sql
CREATE OR REPLACE VIEW analytics.vw_state_performance AS
SELECT
  dc.customer_state,
  COUNT(DISTINCT fo.order_id) AS orders,
  ROUND(SUM(COALESCE(fo.price, 0) + COALESCE(fo.freight_value, 0))::numeric, 2) AS gmv
FROM warehouse.fact_orders fo
LEFT JOIN warehouse.dim_customers dc
  ON fo.customer_key = dc.customer_key
GROUP BY 1;
```

Gợi ý vận hành:
- Sau mỗi lần DAG load xong, các view vẫn giữ được (vì view nằm schema khác).
- Nếu cần tối ưu thêm tốc độ, chuyển view thành materialized view và refresh theo lịch.

## 5) Cách làm dashboard cụ thể trên Metabase

## Dashboard A: Executive Overview

Cards nên có:
- Total Orders (Card)
- GMV (Card)
- AOV (Card)
- Cancel Rate % (Card)
- GMV by Month (Line)
- Orders by Month (Bar)

Nguồn dữ liệu:
- Dùng `analytics.vw_monthly_kpi` cho biểu đồ theo tháng.
- Dùng custom SQL cho KPI tổng:

```sql
SELECT
  SUM(total_orders) AS total_orders,
  SUM(gmv) AS total_gmv,
  ROUND(SUM(gmv) / NULLIF(SUM(total_orders), 0), 2) AS aov,
  ROUND(AVG(cancel_rate_pct), 2) AS avg_cancel_rate_pct
FROM analytics.vw_monthly_kpi;
```

Filter gợi ý trên dashboard:
- Month range
- Order status (nếu dùng query trực tiếp fact_orders)

## Dashboard B: Product & Seller Performance

Cards nên có:
- Top 10 Category by GMV (Horizontal bar)
- Top 15 Seller by GMV (Table)
- GMV by State (Map hoặc bar)

Nguồn dữ liệu:
- `analytics.vw_category_performance`
- Query BR5 cho seller
- `analytics.vw_state_performance`

## Dashboard C: Delivery & Customer Health

Cards nên có:
- Avg Delivery Days by Month (Line)
- Late Delivery % by Month (Line)
- Repeat Customer Rate (Card)
- Orders by Day of Week (Bar)

Nguồn dữ liệu:
- `analytics.vw_monthly_kpi`
- BR9 và BR10

## 6) Cách tạo từng card trong Metabase (thực hành)

1. Vào `+ New` -> `Question`.
2. Chọn database PostgreSQL đã kết nối.
3. Chọn `Native query`.
4. Dán SQL từ BR1..BR10 hoặc từ view analytics.
5. Run query -> chọn Visualization phù hợp.
6. Đặt tên card theo chuẩn: `KPI - ...`, `Trend - ...`, `Breakdown - ...`.
7. Save vào Collection: `Olist / Dashboards`.
8. Vào `+ New` -> `Dashboard` -> thêm các card đã lưu.
9. Thêm dashboard filter (Date, State, Category) và map vào field tương ứng.

## 7) Chuẩn đặt tên và quản trị dashboard

Đề xuất convention:
- Collection: `Olist BI`
- Dashboard:
  - `01_Executive_Overview`
  - `02_Product_Seller_Performance`
  - `03_Delivery_Customer_Health`
- Question:
  - `KPI_Total_GMV`
  - `Trend_Monthly_Orders`
  - `Breakdown_Category_GMV`

## 8) Lưu ý dữ liệu để tránh hiểu sai số

- `fact_orders` hiện được build từ merge orders + items + payments.
- Nếu một order có nhiều item và nhiều payment record, một số metric có thể bị nhân bản theo dòng.
- Khi làm KPI quan trọng, ưu tiên:
  - Dùng `COUNT(DISTINCT order_id)` cho số đơn.
  - Kiểm tra chéo giữa `SUM(payment_value)` và `SUM(price + freight_value)`.
  - Tạo thêm lớp aggregate (view/materialized view) để chuẩn hóa metric trước khi vẽ.

## 9) Checklist triển khai nhanh

- Metabase chạy ổn tại `http://localhost:3000`.
- Kết nối được `de_psql:5432`.
- Có đủ bảng `warehouse`.
- Tạo xong schema `analytics` + 3 view.
- Tạo xong 3 dashboard và add filter.
- Chia sẻ dashboard cho team bằng link nội bộ.

## 10) Troubleshooting: tao schema moi nhung Metabase chua thay

Trieu chung:
- Da tao schema/view trong PostgreSQL nhung Metabase khong hien trong `Browse data` hoac `New question`.

Nguyen nhan pho bien:
- Database trong Metabase dang gioi han schema (vi du chi de `warehouse`).
- Metabase chua sync metadata sau khi ban tao schema moi.
- Schema bi an trong `Data Model`.
- User ket noi khong co quyen `USAGE/SELECT` tren schema moi.

### 10.1 Cac buoc sua nhanh trong Metabase

1. Vao `Admin settings` -> `Databases` -> chon database PostgreSQL dang ket noi.
2. O muc schema:
  - Neu dang de `warehouse` thi Metabase chi quet schema nay.
  - Doi thanh `warehouse,analytics` hoac de trong de quet tat ca.
3. Bam `Save`.
4. Bam `Sync database schema now`.
5. Bam `Re-scan field values now`.
6. Vao `Admin settings` -> `Data Model`, kiem tra schema `analytics` co bi `Hidden` khong; neu co thi bo an.

### 10.2 SQL kiem tra nhanh trong PostgreSQL

Kiem tra schema co ton tai:

```sql
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name = 'analytics';
```

Kiem tra object trong schema:

```sql
SELECT schemaname, tablename
FROM pg_tables
WHERE schemaname = 'analytics'
UNION ALL
SELECT schemaname, viewname
FROM pg_views
WHERE schemaname = 'analytics'
ORDER BY 1, 2;
```

### 10.3 Cap quyen neu can

Neu Metabase dung user khac voi user tao schema, cap them quyen:

```sql
GRANT USAGE ON SCHEMA analytics TO admin;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO admin;

ALTER DEFAULT PRIVILEGES IN SCHEMA analytics
GRANT SELECT ON TABLES TO admin;
```

### 10.4 Luu y cho project nay

- Trong huong dan ket noi ban dau, schema phan tich thuong de `warehouse`.
- Neu ban muon dung them `analytics`, nhat dinh phai cap nhat danh sach schema trong Metabase roi sync lai metadata.

## 11) Huong dan chi tiet thao tac tren Metabase (end-to-end)

Muc tieu: tu SQL/view san co -> tao question -> tao dashboard -> gan filter -> test.

### 11.1 Chuan bi truoc khi dung

1. Vao `Admin settings` -> `Databases` -> chon `de_psql`.
2. O `Schemas`, de trong hoac nhap `warehouse,analytics`.
3. Bam `Save` -> `Sync database schema now` -> `Re-scan field values now`.
4. Vao SQL editor test nhanh:

```sql
SELECT schema_name
FROM information_schema.schemata
ORDER BY 1;
```

### 11.2 Dashboard 01_Executive_Overview (chi tiet)

Buoc 1: Tao card KPI tong quan

1. `+ New` -> `Question` -> `Native query`.
2. Chon database `de_psql`.
3. Dung SQL:

```sql
SELECT
  SUM(total_orders) AS total_orders,
  SUM(gmv) AS total_gmv,
  ROUND(SUM(gmv) / NULLIF(SUM(total_orders), 0), 2) AS aov,
  ROUND(AVG(cancel_rate_pct), 2) AS avg_cancel_rate_pct
FROM analytics.vw_monthly_kpi;
```

4. Visualization: `Table` -> click tung cot -> doi sang `Number` card neu can tach card.
5. Save thanh 4 card rieng:
   - `KPI_Total_Orders`
   - `KPI_Total_GMV`
   - `KPI_AOV`
   - `KPI_Cancel_Rate`

Buoc 2: Tao trend theo thang

1. Tao question moi voi SQL:

```sql
SELECT
  month,
  total_orders,
  gmv
FROM analytics.vw_monthly_kpi
ORDER BY month;
```

2. Visualization 1: `Line` voi truc X = month, Y = gmv, ten `Trend_Monthly_GMV`.
3. Duplicate question -> doi Y = total_orders va chon `Bar`, ten `Trend_Monthly_Orders`.

Buoc 3: Lap dashboard

1. `+ New` -> `Dashboard` -> dat ten `01_Executive_Overview`.
2. Add 6 card vua tao.
3. Sap xep: hang 1 la 4 KPI, hang 2 la 2 chart trend.
4. Add filter `Date` (Month range) -> map vao field `month` cua 2 chart trend.

### 11.3 Dashboard 02_Product_Seller_Performance (chi tiet)

Buoc 1: Top category theo GMV

```sql
SELECT
  category,
  orders,
  gmv
FROM analytics.vw_category_performance
ORDER BY gmv DESC
LIMIT 10;
```

Visualization: `Horizontal bar`.
Ten card: `Breakdown_Top10_Category_GMV`.

Buoc 2: Top seller theo GMV

```sql
SELECT
  ds.seller_id,
  ds.seller_state,
  COUNT(DISTINCT fo.order_id) AS orders,
  ROUND(SUM(COALESCE(fo.price, 0) + COALESCE(fo.freight_value, 0))::numeric, 2) AS gmv
FROM warehouse.fact_orders fo
LEFT JOIN warehouse.dim_sellers ds
  ON fo.seller_key = ds.seller_key
GROUP BY 1, 2
ORDER BY gmv DESC
LIMIT 15;
```

Visualization: `Table`.
Ten card: `Breakdown_Top15_Seller_GMV`.

Buoc 3: GMV theo state

```sql
SELECT
  customer_state,
  orders,
  gmv
FROM analytics.vw_state_performance
ORDER BY gmv DESC;
```

Visualization: `Map` (neu da map location) hoac `Bar`.
Ten card: `Breakdown_State_GMV`.

Buoc 4: Lap dashboard

1. Tao dashboard `02_Product_Seller_Performance`.
2. Add 3 card tren.
3. Add filter:
   - `State` -> map vao `seller_state` (card seller) va `customer_state` (card state).
   - `Category` -> map vao `category` (card category).

### 11.4 Dashboard 03_Delivery_Customer_Health (chi tiet)

Buoc 1: Delivery performance theo thang

```sql
SELECT
  month,
  avg_delivery_days,
  late_delivery_pct
FROM analytics.vw_monthly_kpi
ORDER BY month;
```

Visualization:
- `Line` cho `avg_delivery_days` (ten `Trend_Avg_Delivery_Days`).
- Duplicate -> `Line` cho `late_delivery_pct` (ten `Trend_Late_Delivery_Pct`).

Buoc 2: Repeat customer rate

```sql
WITH customer_orders AS (
  SELECT customer_key, COUNT(DISTINCT order_id) AS order_cnt
  FROM warehouse.fact_orders
  GROUP BY customer_key
)
SELECT
  COUNT(*) AS total_customers,
  COUNT(*) FILTER (WHERE order_cnt > 1) AS repeat_customers,
  ROUND(100.0 * COUNT(*) FILTER (WHERE order_cnt > 1) / NULLIF(COUNT(*), 0), 2) AS repeat_rate_pct
FROM customer_orders;
```

Visualization: `Number` cho `repeat_rate_pct`.
Ten card: `KPI_Repeat_Customer_Rate`.

Buoc 3: Orders theo day-of-week

```sql
SELECT
  dd.day_name,
  dd.day_of_week,
  COUNT(DISTINCT fo.order_id) AS orders
FROM warehouse.fact_orders fo
LEFT JOIN warehouse.dim_dates dd
  ON fo.order_date_key::date = dd.date_key::date
GROUP BY 1, 2
ORDER BY dd.day_of_week;
```

Visualization: `Bar`.
Ten card: `Breakdown_Orders_By_DayOfWeek`.

Buoc 4: Lap dashboard

1. Tao dashboard `03_Delivery_Customer_Health`.
2. Add 4 card tren.
3. Add filter `Date` va map vao field `month` cua 2 line chart delivery.

### 11.5 Quy trinh test truoc khi demo

1. Chon date range 3 thang gan nhat, doi chieu tong Orders va GMV giua 3 dashboard.
2. Chon 1 state cu the, kiem tra card state + seller co thay doi nhat quan.
3. Kiem tra KPI khong bi null/NaN khi doi filter.
4. Kiem tra query chay duoi 5s/card (neu cham, uu tien dung view analytics).

### 11.6 Neu Browse Data chua thay analytics nhung SQL thay

- Van phan tich duoc binh thuong bang `Native query` voi prefix `analytics.`.
- Day la van de metadata UI, khong phai loi du lieu.
- Tiep tuc dung SQL-based questions trong khi chua can bang duoc hieu thi o Browse.

## 12) Tai lieu Power BI tren VMware

- Neu ban lam dashboard tren Power BI Desktop trong Windows VM (VMware) va DB chay Docker tren macOS, xem them tai lieu:
  - `docs/powerbi_vmware_guide.md`
