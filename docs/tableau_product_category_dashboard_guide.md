# Hướng Dẫn Tạo Tableau Product Category Dashboard

Tài liệu này hướng dẫn tạo dashboard phân tích ngành hàng bằng mart:

```text
warehouse.mart_tableau_product_category_dashboard
```

Mart này có grain:

```text
1 row = 1 order item thuộc một product category
```

Dashboard này nên dùng riêng data source trên để filter đồng bộ và tránh join phức tạp trong Tableau.

## 1. Mục Tiêu Dashboard

Product Category dashboard nên trả lời:

- Category nào tạo GMV cao nhất?
- Category nào tăng/giảm theo tháng?
- Category nào có freight share cao?
- Category nào review thấp?
- Category nào giao hàng chậm hoặc có on-time rate thấp?

Tên dashboard gợi ý:

```text
Olist Product Category Performance
```

## 2. Data Source

Trong Tableau, chọn schema `warehouse`, kéo bảng:

```text
mart_tableau_product_category_dashboard
```

Không join thêm bảng khác trong dashboard này.

## 3. Calculated Fields

### Total GMV

```text
SUM([gmv])
```

### Payment Total

```text
SUM([allocated_payment_value])
```

### Category Count

```text
COUNTD([product_category_name_english])
```

### Order Count

```text
COUNTD([order_id])
```

### Average Order Value

```text
SUM([gmv]) / COUNTD([order_id])
```

### Average Item Price

```text
AVG([item_price])
```

### Freight Share

```text
SUM([freight_value]) / SUM([gmv])
```

Format thành Percentage.

### On-Time Delivery Rate

```text
COUNTD(
    IF [is_delivered_on_time_int] = 1 THEN [order_id] END
)
/
COUNTD(
    IF NOT ISNULL([is_delivered_on_time_int]) THEN [order_id] END
)
```

### Weighted Avg Review Score

```text
SUM(
    IF NOT ISNULL([avg_review_score])
    THEN [avg_review_score] * [order_weight]
    END
)
/
SUM(
    IF NOT ISNULL([avg_review_score])
    THEN [order_weight]
    END
)
```

## 4. Layout Dashboard

Dùng `Tiled` và tạo `Vertical Container` cha.

```text
Header
  Olist Product Category Performance
  Category revenue, freight, review and delivery quality

Filter row
  Month | Category | Product Weight Bucket | Customer State | Seller State | Order Status

KPI row
  Total GMV | Category Count | Order Count | AOV | Freight Share | Avg Review

Main row
  Monthly Category GMV Trend | Top Categories by GMV

Bottom row
  Freight Share by Category | Review and Delivery by Category
```

Để xếp ngang:

1. Tạo `Vertical Container` trước.
2. Kéo `Horizontal Container` vào cho từng row.
3. Kéo filters/sheets vào đúng horizontal container.
4. Chọn container -> `Distribute Contents Evenly`.

## 5. Filters Nên Có

| Filter | Field | Kiểu hiển thị |
| --- | --- | --- |
| Month | `month_start_date` | Range of Dates hoặc Multiple Values Dropdown |
| Category | `product_category_name_english` | Multiple Values Dropdown |
| Weight Bucket | `product_weight_bucket` | Multiple Values Dropdown |
| Customer State | `customer_state` | Multiple Values Dropdown |
| Seller State | `seller_state` | Multiple Values Dropdown |
| Order Status | `order_status` | Multiple Values Dropdown |

Sau khi filter hiện trên dashboard:

```text
Apply to Worksheets -> All Using This Data Source
```

## 6. KPI Cards

Tạo các sheet:

```text
KPI - Category Total GMV
KPI - Category Count
KPI - Category Order Count
KPI - Category AOV
KPI - Freight Share
KPI - Category Avg Review
```

Format gợi ý:

- Tên KPI: size 10-12, màu xám.
- Số KPI: size 24-30, bold.
- Bỏ `Show Title` khi đưa vào dashboard.

## 7. Monthly Category GMV Trend

Tên sheet:

```text
Monthly Category GMV Trend
```

Các bước:

1. Kéo `month_start_date` vào Columns.
2. Kéo `gmv` vào Rows.
3. Marks chọn `Line`.
4. Kéo `product_category_name_english` vào Color nếu chỉ chọn vài category.
5. Nếu quá nhiều line, bỏ Color và dùng category filter.

Tooltip:

```text
Month: <MONTH(month_start_date)>
Category: <product_category_name_english>
GMV: <SUM(gmv)>
Orders: <COUNTD(order_id)>
Freight Share: <Freight Share>
Avg Review: <Weighted Avg Review Score>
```

## 8. Top Categories By GMV

Tên sheet:

```text
Top Categories by GMV
```

Các bước:

1. Kéo `product_category_name_english` vào Rows.
2. Kéo `gmv` vào Columns.
3. Sort descending.
4. Tạo Top N filter: Top 10 hoặc Top 15 theo `SUM(gmv)`.
5. Kéo `Freight Share` và `Weighted Avg Review Score` vào Tooltip.

## 9. Freight Share By Category

Tên sheet:

```text
Freight Share by Category
```

Các bước:

1. Kéo `product_category_name_english` vào Rows.
2. Kéo `Freight Share` vào Columns.
3. Sort descending.
4. Kéo `gmv` vào Tooltip.
5. Kéo `product_weight_bucket` vào Color nếu muốn thấy nhóm trọng lượng.

Chart này giúp tìm category có chi phí vận chuyển cao so với GMV.

## 10. Review And Delivery By Category

Tên sheet:

```text
Review and Delivery by Category
```

Các bước:

1. Kéo `On-Time Delivery Rate` vào Columns.
2. Kéo `Weighted Avg Review Score` vào Rows.
3. Kéo `product_category_name_english` vào Detail.
4. Kéo `gmv` vào Size.
5. Kéo `product_weight_bucket` vào Color.
6. Marks chọn `Circle`.

Ý nghĩa:

- Góc phải trên: category tốt, giao đúng hạn và review cao.
- Góc phải dưới: giao đúng hạn nhưng review thấp.
- Góc trái dưới: category cần chú ý vì vừa giao kém vừa review thấp.

## 11. Product Weight Bucket

Mart đã có sẵn field:

```text
product_weight_bucket
```

Các nhóm:

```text
Unknown
Light: < 500g
Medium: 500g-2kg
Heavy: 2kg-10kg
Bulky: 10kg+
```

Có thể dùng field này làm filter hoặc chart phụ:

```text
GMV by Product Weight Bucket
```

## 12. Dashboard Actions

Action 1:

```text
Dashboard -> Actions -> Add Action -> Filter
Name: Filter by Category
Source: Top Categories by GMV
Target: Monthly Category GMV Trend, Freight Share by Category, Review and Delivery by Category, KPI cards
Run on: Select
Clearing selection: Show all values
```

Action 2:

```text
Name: Filter by Weight Bucket
Source: GMV by Product Weight Bucket
Target: Top Categories by GMV, Monthly Category GMV Trend, KPI cards
Run on: Select
Clearing selection: Show all values
```

## 13. Kiểm Tra Số Liệu

Chạy test:

```bash
docker exec dbt dbt build --select mart_tableau_product_category_dashboard assert_tableau_product_category_dashboard_reconciles
```

Trong Tableau:

- `Total GMV` dùng `SUM(gmv)`.
- `Order Count` dùng `COUNTD(order_id)`.
- `Category Count` dùng `COUNTD(product_category_name_english)`.
- `Freight Share` dùng `SUM(freight_value) / SUM(gmv)`.
- Filters apply `All Using This Data Source`.

