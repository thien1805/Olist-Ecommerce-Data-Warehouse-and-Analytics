# Hướng Dẫn Tạo Tableau Dashboard Từ Mart Sales

Tài liệu này hướng dẫn làm dashboard Tableau chính của project bằng bảng:

```text
warehouse.mart_tableau_sales_dashboard
```

Đây là mart được tạo riêng cho BI để KPI cards, charts và filters dùng chung một data source. Khi dùng bảng này, dashboard sẽ filter đồng bộ tốt hơn so với việc ghép nhiều bảng aggregate rời rạc.

## 1. Khi Nào Dùng Mart Này

Dùng `mart_tableau_sales_dashboard` cho dashboard tổng quan như:

- Executive overview
- Sales performance
- Product category performance
- Seller performance
- Delivery performance
- Customer geography analysis

Không nên dùng các bảng `agg_*` làm data source chính cho dashboard tương tác nhiều filter. Các bảng `agg_*` vẫn giữ lại để kiểm tra số liệu, làm dashboard phụ hoặc phục vụ phân tích riêng từng chủ đề.

## 2. Luồng Dữ Liệu

```text
MySQL source
  -> Airflow extract_and_upsert_to_staging
  -> PostgreSQL staging
  -> Cosmos + dbt build/test
  -> warehouse.mart_tableau_sales_dashboard
  -> Tableau dashboard
```

Trước khi mở Tableau, nên chạy xong DAG:

```text
e_commerce_elt
```

Trong Airflow, các bước nên thành công theo thứ tự:

```text
extract_and_upsert_to_staging
  -> dbt_transform
  -> send_success_email
```

Email success chỉ nên được gửi sau khi dbt transform và dbt test đã pass.

## 3. Kết Nối Tableau Với PostgreSQL

Trong Tableau Desktop:

1. Chọn `Connect` -> `To a Server` -> `PostgreSQL`.
2. Điền thông tin kết nối:

| Field | Value |
| --- | --- |
| Server | `localhost` |
| Port | `5433` |
| Database | `postgres` |
| Username | `admin` |
| Password | `admin` |
| SSL | None |

3. Sau khi đăng nhập, chọn schema:

```text
warehouse
```

4. Kéo duy nhất bảng này vào canvas:

```text
mart_tableau_sales_dashboard
```

Với dashboard chính, chưa cần join thêm bảng khác trong Tableau.

## 4. Hiểu Grain Của Mart

`mart_tableau_sales_dashboard` có grain chính là:

```text
1 row = 1 order item
```

Vì một order có thể có nhiều item, cần cẩn thận với các chỉ số ở cấp order như payment, review, delivery.

Các field quan trọng đã được xử lý sẵn:

| Field | Ý nghĩa | Cách dùng |
| --- | --- | --- |
| `gmv` | Giá trị bán hàng ở item-level | Dùng `SUM([gmv])` |
| `allocated_payment_value` | Payment đã phân bổ xuống item-level | Dùng `SUM([allocated_payment_value])` |
| `order_id` | Mã order | Dùng `COUNTD([order_id])` |
| `month_start_date` | Tháng đặt hàng | Dùng làm date filter chính |
| `product_category_name_english` | Category tiếng Anh | Dùng làm category filter |
| `customer_state`, `customer_city` | Khu vực khách hàng | Dùng cho map/filter |
| `seller_state`, `seller_city`, `seller_id` | Seller geography và seller drill-down | Dùng cho seller chart/filter |
| `is_delivered_on_time_int` | 1 là đúng hạn, 0 là trễ, null là không áp dụng | Dùng tính on-time rate |

Lưu ý quan trọng: không dùng `SUM([payment_value_total])` nếu có field đó trong data source item-level, vì payment order-level có thể bị nhân bản theo số item. Hãy dùng `allocated_payment_value`.

## 5. Tạo Calculated Fields

Trong Tableau, click phải ở Data pane -> `Create Calculated Field`.

### Total GMV

```text
SUM([gmv])
```

Format:

- Number format: Currency hoặc Number
- Decimal places: 0 hoặc 2

### Payment Total

```text
SUM([allocated_payment_value])
```

Format:

- Number format: Currency hoặc Number
- Decimal places: 0 hoặc 2

### Order Count

```text
COUNTD([order_id])
```

### Average Order Value

```text
SUM([gmv]) / COUNTD([order_id])
```

Format:

- Number format: Currency hoặc Number
- Decimal places: 1 hoặc 2

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

Format:

- Percentage
- Decimal places: 1 hoặc 2

### Average Review Score

```text
AVG([avg_review_score])
```

Format:

- Number
- Decimal places: 2

### Freight Share

```text
SUM([freight_value]) / SUM([item_total_amount])
```

Format:

- Percentage
- Decimal places: 1 hoặc 2

## 6. Tạo Các KPI Cards

Tạo 5 worksheet riêng:

```text
KPI - Total GMV
KPI - Payment Total
KPI - AOV
KPI - On-Time Rate
KPI - Avg Review
```

Với mỗi KPI sheet:

1. Kéo calculated field vào `Text` trong Marks.
2. Chọn Marks type là `Text`.
3. Click `Text` -> `Edit Label`.
4. Format label thành 2 dòng: tên KPI nhỏ ở trên, giá trị lớn ở dưới.
5. Align center.
6. Ẩn gridlines, row dividers và column dividers.

Ví dụ label cho `KPI - Total GMV`:

```text
Total GMV
<Total GMV>
```

Gợi ý format:

| Thành phần | Format |
| --- | --- |
| Tên KPI | Size 10-12, màu xám |
| Giá trị KPI | Size 24-30, bold |
| Background worksheet | Trắng hoặc rất nhạt |
| Border | Mỏng, màu xám nhạt |

## 7. Tạo Sheet Monthly GMV Trend

Tên sheet:

```text
Monthly GMV Trend
```

Các bước:

1. Kéo `month_start_date` vào Columns.
2. Chọn `MONTH(month_start_date)` dạng continuous hoặc exact month.
3. Kéo `gmv` vào Rows.
4. Đảm bảo aggregation là `SUM(gmv)`.
5. Marks chọn `Line`.
6. Kéo `allocated_payment_value` vào Tooltip để so sánh payment.
7. Format trục Y thành Number hoặc Currency.

Tooltip gợi ý:

```text
Month: <MONTH(month_start_date)>
GMV: <SUM(gmv)>
Payment: <SUM(allocated_payment_value)>
Orders: <COUNTD(order_id)>
```

## 8. Tạo Sheet Top Categories

Tên sheet:

```text
Top Categories by GMV
```

Các bước:

1. Kéo `product_category_name_english` vào Rows.
2. Kéo `gmv` vào Columns.
3. Sort descending theo `SUM(gmv)`.
4. Marks chọn `Bar`.
5. Kéo `gmv` vào Label nếu muốn hiện số.
6. Tạo filter Top N:
   - Kéo `product_category_name_english` vào Filters.
   - Chọn tab `Top`.
   - Chọn `By field`.
   - Top `10` by `SUM(gmv)`.

Gợi ý màu:

- Top category dùng màu xanh đậm.
- Các bar còn lại dùng xanh nhạt hoặc xám xanh.

## 9. Tạo Sheet Top Sellers

Tên sheet:

```text
Top Sellers by GMV
```

Các bước:

1. Kéo `seller_id` vào Rows.
2. Kéo `gmv` vào Columns.
3. Sort descending.
4. Kéo `seller_state` vào Color hoặc Tooltip.
5. Kéo `Order Count` vào Tooltip.
6. Tạo Top N filter tương tự category, ví dụ Top 10 seller.

Tooltip gợi ý:

```text
Seller: <seller_id>
State: <seller_state>
GMV: <SUM(gmv)>
Orders: <COUNTD(order_id)>
Avg Review: <AVG(avg_review_score)>
```

## 10. Tạo Sheet Delivery By State

Tên sheet:

```text
Delivery by Customer State
```

Các bước:

1. Kéo `customer_state` vào Rows.
2. Kéo `On-Time Delivery Rate` vào Columns.
3. Marks chọn `Bar`.
4. Format `On-Time Delivery Rate` thành Percentage.
5. Sort descending hoặc ascending tùy mục tiêu:
   - Descending để xem state giao tốt nhất.
   - Ascending để phát hiện state giao chậm.
6. Kéo `Order Count`, `Average Review Score`, `Total GMV` vào Tooltip.

Có thể dùng màu theo on-time rate:

- Xanh: tỷ lệ đúng hạn cao.
- Cam/đỏ: tỷ lệ đúng hạn thấp.

## 11. Tạo Sheet Payment Method Mix

Payment mix không nên lấy từ `mart_tableau_sales_dashboard`, vì mart đó ở item-level. Project đã có mart riêng:

```text
warehouse.mart_tableau_payment_mix
```

Grain của mart này là:

```text
1 row = 1 payment sequence của 1 order
```

Vì vậy trong mart này, `SUM([payment_value])` là phép tính đúng cho tổng payment theo phương thức thanh toán.

Tên sheet:

```text
Payment Method Mix
```

Data source:

```text
mart_tableau_payment_mix
```

Các bước tạo donut/pie chart:

1. Tạo worksheet mới.
2. Chọn data source `mart_tableau_payment_mix`.
3. Kéo `payment_type_label` vào `Color`.
4. Kéo `payment_value` vào `Angle`.
5. Kéo `payment_value` vào `Label`.
6. Marks chọn `Pie`.
7. Format `SUM(payment_value)` thành Number hoặc Currency.

Calculated field nên tạo:

```text
Payment Value
SUM([payment_value])
```

```text
Payment Share
SUM([payment_value]) / TOTAL(SUM([payment_value]))
```

Format `Payment Share` thành Percentage.

Tooltip gợi ý:

```text
Payment Type: <payment_type_label>
Payment Value: <SUM(payment_value)>
Payment Share: <Payment Share>
Orders: <COUNTD(order_id)>
```

Filter có thể dùng trong payment mix:

| Filter | Field |
| --- | --- |
| Month | `month_start_date` |
| Payment Type | `payment_type_label` |
| Installment Bucket | `installment_bucket` |
| Customer State | `customer_state` |
| Order Status | `order_status` |

Nếu đặt `Payment Method Mix` chung dashboard với các sheet từ `mart_tableau_sales_dashboard`, lưu ý filter `Apply to Worksheets -> All Using This Data Source` sẽ chỉ áp dụng trong từng data source. Cách đơn giản nhất là tạo một dashboard/tab riêng cho payment mix. Nếu muốn đặt chung một dashboard, hãy thêm filter/action riêng cho `mart_tableau_payment_mix` hoặc dùng dashboard action theo các field chung như `month_start_date`, `customer_state`, `order_status`.

## 12. Ghép Dashboard

Tạo Dashboard mới:

```text
Olist Executive Overview
```

Size gợi ý:

```text
Automatic
```

hoặc fixed size để demo:

```text
1200 x 850
```

Layout gợi ý:

```text
Header
  Title + subtitle

Filter row
  Month range | Category | Customer State | Seller State

KPI row
  Total GMV | Payment Total | AOV | On-Time Rate | Avg Review

Main row
  Monthly GMV Trend

Bottom row
  Top Categories | Top Sellers | Delivery by State
```

Nên dùng `Tiled` layout trước, chưa cần dùng `Floating` nhiều. `Floating` dễ đẹp nhưng cũng dễ lệch layout khi đổi màn hình.

## 13. Thêm Filters Đồng Bộ

Các filter nên dùng:

| Filter | Field |
| --- | --- |
| Month | `month_start_date` |
| Category | `product_category_name_english` |
| Customer State | `customer_state` |
| Customer City | `customer_city` |
| Seller State | `seller_state` |
| Seller City | `seller_city` |
| Seller | `seller_id` |
| Order Status | `order_status` |

Cách thêm filter:

1. Mở một worksheet bất kỳ đang dùng mart.
2. Kéo field vào Filters.
3. Right click field filter -> `Show Filter`.
4. Quay lại Dashboard.
5. Trên filter dropdown, chọn `Apply to Worksheets` -> `All Using This Data Source`.

Vì tất cả sheet đều dùng `mart_tableau_sales_dashboard`, filter sẽ đồng bộ trên toàn dashboard.

## 14. Thêm Dashboard Actions

Nên thêm action để dashboard tương tác tốt hơn.

### Category Click Filter

1. Vào Dashboard -> `Actions`.
2. Chọn `Add Action` -> `Filter`.
3. Name:

```text
Filter by Category
```

4. Source sheet:

```text
Top Categories by GMV
```

5. Target sheets:

```text
Monthly GMV Trend
Top Sellers by GMV
Delivery by Customer State
KPI sheets
```

6. Run action on:

```text
Select
```

7. Clearing selection:

```text
Show all values
```

### Seller Click Filter

Tạo tương tự với source sheet:

```text
Top Sellers by GMV
```

Action này giúp click một seller để các KPI và chart khác đổi theo seller đó.

## 15. Trang Trí Dashboard

Gợi ý style:

| Thành phần | Gợi ý |
| --- | --- |
| Background | Trắng hoặc xám rất nhạt |
| Header title | Xanh lá hoặc xanh dương đậm |
| KPI cards | Nền trắng, border xám nhạt |
| Chart title | Ngắn, rõ business meaning |
| Font | Tableau Book hoặc font mặc định |
| Number format | Đồng bộ dấu phân cách hàng nghìn |
| Spacing | Dùng padding 8-16px |

Nên tránh:

- Quá nhiều màu khác nhau.
- Dùng nhiều chart 3D.
- Mỗi chart một data source khác nhau cho dashboard chính.
- Dùng `SUM(payment_value_total)` ở item-level.
- Để filter chỉ apply cho một worksheet.

## 16. Kiểm Tra Số Liệu

Sau khi làm xong dashboard, kiểm tra nhanh:

### Kiểm tra trong Tableau

1. Clear toàn bộ filter.
2. `Total GMV` phải xấp xỉ tổng `SUM(gmv)`.
3. `Payment Total` phải dùng `SUM(allocated_payment_value)`.
4. Click một category, tất cả KPI và charts phải đổi theo.
5. Click một seller, tất cả KPI và charts phải đổi theo.

### Kiểm tra bằng dbt

Trong Docker:

```bash
docker exec dbt dbt build --select mart_tableau_sales_dashboard
```

Chạy test reconcile:

```bash
docker exec dbt dbt test --select assert_tableau_sales_dashboard_reconciles
```

Test này kiểm tra tổng `gmv` và `allocated_payment_value` trong mart có khớp với `fact_orders` không.

## 17. Workflow Cập Nhật Dashboard Khi Có Data Mới

Khi có data mới:

1. Airflow chạy `extract_and_upsert_to_staging`.
2. dbt build lại các model warehouse.
3. dbt test pass.
4. Airflow gửi email success.
5. Mở Tableau và refresh data source.

Nếu dùng Tableau Extract:

```text
Data Source -> Extract -> Refresh
```

Nếu dùng Live Connection, Tableau sẽ đọc dữ liệu mới từ PostgreSQL khi query lại.

## 18. Khi Nào Cần Thêm Mart Mới

Không nên nhồi mọi thứ vào một mart duy nhất. Với dashboard hiện tại, `mart_tableau_sales_dashboard` là đủ tốt. Nhưng nên tạo thêm mart mới khi có nhu cầu riêng:

| Nhu cầu | Mart nên tạo |
| --- | --- |
| Payment method mix chuẩn | `mart_tableau_payment_mix` |
| Cohort khách hàng | `mart_customer_cohort` |
| Repeat purchase | `mart_customer_repeat_purchase` |
| Seller SLA chi tiết | `mart_seller_delivery_sla` |
| Product basket analysis | `mart_product_basket` |

Nguyên tắc:

- Dashboard tương tác tổng quan: dùng một mart rộng, filter đồng bộ.
- Dashboard chuyên sâu: tạo mart riêng đúng grain.
- Star schema vẫn là source of truth trong dbt.
- Aggregate marts dùng để tăng tốc, kiểm tra số liệu hoặc phục vụ dashboard ít tương tác.

## 19. Checklist Hoàn Thành

Trước khi demo dashboard, kiểm tra:

- Đã dùng data source `warehouse.mart_tableau_sales_dashboard`.
- KPI `Payment Total` dùng `allocated_payment_value`.
- `Order Count` dùng `COUNTD(order_id)`.
- Filters apply to `All Using This Data Source`.
- Click category/seller làm các chart khác thay đổi.
- Number format đồng bộ.
- Dashboard không còn vùng trắng quá lớn.
- `dbt build --select mart_tableau_sales_dashboard` pass.
- `assert_tableau_sales_dashboard_reconciles` pass.
