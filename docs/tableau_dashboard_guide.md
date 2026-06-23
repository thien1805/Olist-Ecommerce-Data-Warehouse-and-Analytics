# Hướng Dẫn Làm Tableau Dashboard Cho Olist Analytics Platform

Tài liệu này hướng dẫn tạo dashboard Tableau từ PostgreSQL warehouse của project hiện tại.

## 1. Mục Tiêu Dashboard

Dashboard nên trả lời 4 nhóm câu hỏi chính:

- Doanh thu theo thời gian tăng hay giảm?
- Nhóm sản phẩm nào đóng góp doanh thu tốt nhất?
- Seller nào bán tốt nhất?
- Khu vực nào giao hàng tốt hoặc chậm?

Luồng dữ liệu hiện tại:

```text
MySQL source
  -> Airflow extract_and_upsert_to_staging
  -> PostgreSQL staging
  -> dbt/Cosmos transform + test
  -> PostgreSQL warehouse
  -> Tableau dashboard
```

Tableau chỉ nên đọc schema `warehouse`.

## 2. Kết Nối Tableau Với PostgreSQL

Trong Tableau Desktop:

1. Chọn `Connect` -> `To a Server` -> `PostgreSQL`.
2. Điền thông tin:

| Field | Value |
| --- | --- |
| Server | `localhost` |
| Port | `5433` |
| Database | `postgres` |
| Authentication | `Username and Password` |
| Username | `admin` |
| Password | `admin` |
| SSL | Off/None |

3. Sau khi kết nối, chọn schema `warehouse`.
4. Kéo các bảng metrics vào canvas.

Nếu Tableau không thấy PostgreSQL connector, cần cài PostgreSQL driver cho Tableau.

## 3. Bảng Nên Dùng Trước

Ưu tiên dùng 4 bảng aggregate vì đã sẵn sàng cho BI, ít cần join phức tạp:

| Bảng | Dùng để làm gì |
| --- | --- |
| `warehouse.agg_monthly_sales` | KPI tổng quan và trend theo tháng |
| `warehouse.agg_product_category_performance` | Hiệu suất theo ngành hàng |
| `warehouse.agg_seller_performance` | Hiệu suất seller |
| `warehouse.agg_delivery_performance` | Giao hàng theo state/city |

Sau đó mới dùng bảng fact/dim để drill-down:

| Bảng | Khi nào dùng |
| --- | --- |
| `warehouse.fact_orders` | Phân tích order-level, payment, delivery, review |
| `warehouse.fact_order_items` | Phân tích item-level, product, seller |
| `warehouse.dim_products` | Drill theo category/product |
| `warehouse.dim_sellers` | Drill theo seller geography |
| `warehouse.dim_customers` | Drill theo customer geography |
| `warehouse.dim_date` | Time intelligence chi tiết hơn |

## 4. Data Source Gợi Ý

Làm dashboard đầu tiên bằng 4 data source độc lập:

1. `agg_monthly_sales`
2. `agg_product_category_performance`
3. `agg_seller_performance`
4. `agg_delivery_performance`

Không cần join 4 bảng aggregate với nhau trong Tableau. Mỗi worksheet dùng đúng bảng phù hợp. Cách này dễ làm, ít lỗi grain, dashboard chạy nhanh.

## 5. Calculated Fields Nên Tạo

### 5.1. GMV Format

Tableau có thể format trực tiếp field `gmv` thành currency. Nếu muốn field riêng:

```text
SUM([gmv])
```

Format:

- Number format: Currency/Custom
- Decimal places: 0 hoặc 2

### 5.2. On-Time Delivery Rate

Field `on_time_delivery_rate` đang là ratio từ 0 đến 1.

```text
AVG([on_time_delivery_rate])
```

Format:

- Percentage
- 1 hoặc 2 decimal places

### 5.3. Average Review Score

```text
AVG([avg_review_score])
```

Format:

- Number
- 2 decimal places

### 5.4. Freight Share

Dùng trong `agg_product_category_performance` hoặc `agg_seller_performance`:

```text
SUM([freight_value_total]) / SUM([total_amount])
```

Format:

- Percentage

### 5.5. Average Order Value

Trong `agg_monthly_sales` đã có sẵn `average_order_value`.

```text
AVG([average_order_value])
```

## 6. Worksheet Cần Làm

### Sheet 1: KPI Overview

Data source: `agg_monthly_sales`

Tạo 4 KPI card:

- `SUM(gmv)` -> Total GMV
- `SUM(payment_value_total)` -> Total Payment
- `AVG(average_order_value)` -> Average Order Value
- `AVG(on_time_delivery_rate)` -> On-Time Delivery Rate

Gợi ý:

- Dùng `Text` mark.
- Format số lớn gọn hơn, ví dụ `K`, `M`.
- On-time rate format dạng percentage.

### Sheet 2: Monthly GMV Trend

Data source: `agg_monthly_sales`

Setup:

- Columns: `month_start_date`
- Rows: `SUM(gmv)`
- Marks: Line
- Tooltip thêm:
  - `SUM(payment_value_total)`
  - `AVG(average_order_value)`
  - `AVG(on_time_delivery_rate)`
  - `AVG(avg_review_score)`

Gợi ý:

- Đặt title: `Monthly GMV Trend`
- Format month theo `MMM yyyy`.

### Sheet 3: Monthly Delivery Rate

Data source: `agg_monthly_sales`

Setup:

- Columns: `month_start_date`
- Rows: `AVG(on_time_delivery_rate)`
- Marks: Line
- Format percentage.

Mục tiêu: xem tháng nào giao hàng đúng hạn thấp.

### Sheet 4: Top Product Categories By GMV

Data source: `agg_product_category_performance`

Setup:

- Rows: `product_category_name_english`
- Columns: `SUM(total_amount)`
- Marks: Bar
- Sort descending.
- Filter Top N: Top 10 by `SUM(total_amount)`.

Tooltip nên có:

- `SUM(item_price_total)`
- `SUM(freight_value_total)`
- Freight Share

### Sheet 5: Seller Performance

Data source: `agg_seller_performance`

Setup:

- Rows: `seller_id`
- Columns: `SUM(total_amount)`
- Marks: Bar
- Sort descending.
- Filter Top 10 hoặc Top 20 sellers.

Nếu bảng có state/city seller thì thêm vào tooltip hoặc filter.

### Sheet 6: Delivery Performance By Geography

Data source: `agg_delivery_performance`

Setup option A - Bar chart:

- Rows: `customer_state`
- Columns: `AVG(on_time_delivery_rate)`
- Marks: Bar
- Color: `AVG(avg_review_score)`
- Size hoặc Label: `SUM(total_orders)`

Setup option B - Map:

- Nếu Tableau nhận diện được `customer_state` là geographic role, dùng map.
- Nếu không, dùng bar chart trước cho chắc.

Tooltip:

- `SUM(total_orders)`
- `SUM(gmv)`
- `AVG(on_time_delivery_rate)`
- `AVG(avg_review_score)`

### Sheet 7: Category vs Delivery/Review

Nếu muốn nâng cấp dashboard:

- Dùng `fact_order_items` join `dim_products`, hoặc tạo thêm dbt mart sau.
- Không nên join phức tạp ngay trong dashboard đầu tiên.

## 7. Dashboard Layout Gợi Ý

Tạo dashboard tên:

```text
Olist Executive Overview
```

Kích thước:

- Desktop: `Automatic` hoặc `1200 x 900`.
- Nếu muốn demo đẹp trên laptop: `1200 x 800`.

Layout:

```text
Header: Olist Executive Overview

Row 1: KPI cards
  Total GMV | Total Payment | AOV | On-Time Delivery Rate

Row 2:
  Monthly GMV Trend

Row 3:
  Top Product Categories | Seller Performance

Row 4:
  Delivery Performance By Geography
```

Filter nên đặt bên phải hoặc trên cùng:

- Month range
- Product category
- Customer state

Với dashboard đầu tiên, chỉ cần filter `month_start_date` và `customer_state` là đủ.

## 8. Dashboard Thứ Hai Nên Làm

Sau dashboard executive, làm thêm:

```text
Olist Operations & Delivery
```

Tập trung vào:

- On-time delivery rate
- Delivery time
- Estimated vs actual delivery
- Review score
- Customer state/city

Dùng bảng:

- `agg_delivery_performance`
- `fact_orders`
- `dim_customers`
- `dim_date`

## 9. Lưu Ý Về Grain

Không join tùy tiện các bảng aggregate với fact trong Tableau.

Ví dụ không nên:

```text
agg_monthly_sales join fact_orders
```

Lý do: dễ bị nhân bản metric nếu join sai grain.

Quy tắc:

- Dashboard overview dùng aggregate marts.
- Drill-down chi tiết dùng fact + dim.
- Nếu cần một góc nhìn mới, nên tạo thêm dbt mart thay vì xử lý join phức tạp trong Tableau.

## 10. Refresh Workflow

Khi có dữ liệu mới:

1. Trigger hoặc chờ schedule DAG `e_commerce_elt`.
2. Airflow chạy extract/upsert.
3. Cosmos chạy dbt models và dbt tests.
4. Email success được gửi sau khi dbt tests pass.
5. Tableau refresh data source từ PostgreSQL `warehouse`.

Trong Tableau Desktop:

- Nếu dùng Live connection: dashboard đọc dữ liệu mới khi refresh view.
- Nếu dùng Extract: cần refresh extract sau khi DAG success.

Khuyến nghị cho project demo:

- Dùng `Live` để dễ chứng minh pipeline cập nhật warehouse.
- Khi publish lên Tableau Public/Server, cân nhắc `Extract`.

## 11. Checklist Trước Khi Demo

- DAG `e_commerce_elt` chạy success.
- Task `dbt_transform.dbt_test` pass.
- Email success đã gửi.
- Tableau kết nối được PostgreSQL `localhost:5433`.
- Tableau đang đọc schema `warehouse`.
- Dashboard có ít nhất:
  - 4 KPI cards
  - 1 trend chart
  - 1 category chart
  - 1 seller chart
  - 1 delivery geography chart

