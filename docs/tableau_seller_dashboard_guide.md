# Hướng Dẫn Tạo Tableau Seller Performance Dashboard

Tài liệu này hướng dẫn tạo dashboard phân tích seller bằng mart:

```text
warehouse.mart_tableau_seller_dashboard
```

Mart này có grain:

```text
1 row = 1 order item của seller
```

Vì vậy trong Tableau nên dùng `COUNTD(order_id)` cho số đơn hàng, không dùng `COUNT(order_id)`.

## 1. Mục Tiêu Dashboard

Seller dashboard nên trả lời:

- Seller nào tạo GMV cao nhất?
- Seller ở state/city nào hoạt động tốt?
- Seller nào có review thấp hoặc giao hàng trễ?
- GMV của seller thay đổi theo tháng như thế nào?
- Category nào đang đóng góp nhiều nhất cho seller performance?

Tên dashboard gợi ý:

```text
Olist Seller Performance
```

## 2. Data Source

Trong Tableau, chọn schema `warehouse`, kéo bảng:

```text
mart_tableau_seller_dashboard
```

Không cần join thêm bảng khác.

## 3. Calculated Fields

Tạo các calculated fields sau trong Tableau.

### Total GMV

```text
SUM([gmv])
```

### Payment Total

```text
SUM([allocated_payment_value])
```

### Seller Count

```text
COUNTD([seller_id])
```

### Order Count

```text
COUNTD([order_id])
```

### Average GMV per Seller

```text
SUM([gmv]) / COUNTD([seller_id])
```

### Average Order Value

```text
SUM([gmv]) / COUNTD([order_id])
```

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

Format thành Percentage.

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

Không nên dùng `AVG(avg_review_score)` nếu muốn KPI ổn hơn, vì mart ở item-level.

## 4. Layout Dashboard

Dùng `Tiled`, tạo một `Vertical Container` cha trước.

```text
Header
  Olist Seller Performance
  Seller revenue, delivery and review quality

Filter row
  Month | Seller State | Seller City | Category | Customer State | Order Status

KPI row
  Total GMV | Seller Count | Order Count | Avg GMV per Seller | On-Time Rate | Avg Review

Main row
  Monthly Seller GMV Trend | Top Sellers by GMV

Bottom row
  Seller State Performance | Review vs Delivery Time
```

Item hierarchy nên giống:

```text
Tiled
  Vertical Container
    Text - Header
    Horizontal Container - Filter Row
    Horizontal Container - KPI Row
    Horizontal Container - Main Row
    Horizontal Container - Bottom Row
```

Mỗi row ngang phải là `Horizontal Container`. Sau khi kéo sheet vào container, chọn container -> menu nhỏ -> `Distribute Contents Evenly`.

## 5. Filters Nên Có

Tạo filter từ một sheet bất kỳ dùng `mart_tableau_seller_dashboard`, rồi `Show Filter`.

| Filter | Field | Kiểu hiển thị |
| --- | --- | --- |
| Month | `month_start_date` | Range of Dates hoặc Multiple Values Dropdown |
| Seller State | `seller_state` | Multiple Values Dropdown |
| Seller City | `seller_city` | Multiple Values Dropdown |
| Category | `product_category_name_english` | Multiple Values Dropdown |
| Customer State | `customer_state` | Multiple Values Dropdown |
| Order Status | `order_status` | Multiple Values Dropdown |

Sau khi filter hiện trên dashboard:

```text
Apply to Worksheets -> All Using This Data Source
```

## 6. KPI Cards

Tạo các sheet:

```text
KPI - Seller Total GMV
KPI - Seller Count
KPI - Seller Order Count
KPI - Avg GMV per Seller
KPI - Seller On-Time Rate
KPI - Seller Avg Review
```

Mỗi KPI:

1. Kéo calculated field vào `Text`.
2. Marks chọn `Text`.
3. Format tên KPI nhỏ, số KPI lớn.
4. Bỏ `Show Title` khi kéo vào dashboard nếu bị chiếm chỗ.

## 7. Monthly Seller GMV Trend

Tên sheet:

```text
Monthly Seller GMV Trend
```

Các bước:

1. Kéo `month_start_date` vào Columns.
2. Kéo `gmv` vào Rows.
3. Marks chọn `Line`.
4. Kéo `seller_state` hoặc `product_category_name_english` vào Color nếu muốn so sánh.
5. Nếu chart quá rối, bỏ Color và dùng filter.

Tooltip:

```text
Month: <MONTH(month_start_date)>
GMV: <SUM(gmv)>
Payment: <SUM(allocated_payment_value)>
Orders: <COUNTD(order_id)>
Sellers: <COUNTD(seller_id)>
```

## 8. Top Sellers By GMV

Tên sheet:

```text
Top Sellers by GMV
```

Các bước:

1. Kéo `seller_id` vào Rows.
2. Kéo `gmv` vào Columns.
3. Sort descending.
4. Kéo `seller_state` vào Color hoặc Tooltip.
5. Tạo Top N filter: Top 10 hoặc Top 20 theo `SUM(gmv)`.

Tooltip:

```text
Seller: <seller_id>
Location: <seller_location>
GMV: <SUM(gmv)>
Orders: <COUNTD(order_id)>
On-Time Rate: <On-Time Delivery Rate>
Avg Review: <Weighted Avg Review Score>
```

## 9. Seller State Performance

Tên sheet:

```text
Seller State Performance
```

Các bước:

1. Kéo `seller_state` vào Rows.
2. Kéo `gmv` vào Columns.
3. Kéo `Seller Count` vào Tooltip.
4. Kéo `On-Time Delivery Rate` vào Color.
5. Sort descending theo `SUM(gmv)`.

Chart này cho biết state nào có seller đóng góp GMV mạnh và chất lượng giao hàng tốt.

## 10. Review Vs Delivery Time

Tên sheet:

```text
Review vs Delivery Time
```

Các bước:

1. Kéo `delivery_time_days` vào Columns.
2. Kéo `avg_review_score` vào Rows.
3. Kéo `seller_id` vào Detail.
4. Kéo `gmv` vào Size.
5. Kéo `seller_state` vào Color.
6. Marks chọn `Circle`.

Mục tiêu: phát hiện seller có GMV lớn nhưng delivery chậm hoặc review thấp.

## 11. Dashboard Actions

Nên thêm action:

```text
Dashboard -> Actions -> Add Action -> Filter
```

Action 1:

```text
Name: Filter by Seller
Source: Top Sellers by GMV
Target: Monthly Seller GMV Trend, Seller State Performance, Review vs Delivery Time, KPI cards
Run on: Select
Clearing selection: Show all values
```

Action 2:

```text
Name: Filter by Seller State
Source: Seller State Performance
Target: Top Sellers by GMV, Monthly Seller GMV Trend, Review vs Delivery Time, KPI cards
Run on: Select
Clearing selection: Show all values
```

## 12. Kiểm Tra Số Liệu

Chạy test:

```bash
docker exec dbt dbt build --select mart_tableau_seller_dashboard assert_tableau_seller_dashboard_reconciles
```

Trong Tableau:

- `Total GMV` dùng `SUM(gmv)`.
- `Order Count` dùng `COUNTD(order_id)`.
- `Seller Count` dùng `COUNTD(seller_id)`.
- Filter phải apply `All Using This Data Source`.
- Click seller/state phải làm KPI và chart khác thay đổi.

