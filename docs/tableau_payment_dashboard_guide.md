# Hướng Dẫn Tạo Tableau Payment Dashboard

Tài liệu này hướng dẫn tạo dashboard phân tích phương thức thanh toán bằng mart:

```text
warehouse.mart_tableau_payment_mix
```

Mart này được thiết kế riêng cho payment dashboard. Không dùng `mart_tableau_sales_dashboard` để làm payment method mix vì mart sales ở grain order item, dễ làm payment bị nhân bản.

## 1. Mục Tiêu Dashboard

Payment dashboard nên trả lời các câu hỏi:

- Tổng payment là bao nhiêu?
- Phương thức thanh toán nào được dùng nhiều nhất?
- Tỷ trọng payment theo `Credit Card`, `Boleto`, `Voucher`, `Debit Card` là bao nhiêu?
- Người mua thường trả một lần hay trả góp?
- Payment theo tháng thay đổi như thế nào?
- Bang/city nào tạo payment cao nhất?

Tên dashboard gợi ý:

```text
Olist Payment Overview
```

## 2. Data Source Cần Dùng

Trong Tableau, kết nối PostgreSQL:

| Field | Value |
| --- | --- |
| Server | `localhost` |
| Port | `5433` |
| Database | `postgres` |
| Username | `admin` |
| Password | `admin` |
| Schema | `warehouse` |

Kéo bảng này vào data source canvas:

```text
mart_tableau_payment_mix
```

Dashboard payment nên dùng data source này là chính.

## 3. Hiểu Grain Của Payment Mart

Grain của `mart_tableau_payment_mix` là:

```text
1 row = 1 payment sequence của 1 order
```

Ví dụ một order có thể thanh toán bằng 2 dòng:

```text
order_id = A
  payment_sequential = 1, payment_type = credit_card, payment_value = 100
  payment_sequential = 2, payment_type = voucher, payment_value = 20
```

Vì vậy:

- `SUM([payment_value])` là tổng payment đúng.
- `COUNTD([order_id])` là số đơn hàng có payment.
- `COUNT([payment_key])` là số payment transaction.
- `AVG([payment_installments])` là số kỳ trả góp trung bình theo payment row.

## 4. Field Quan Trọng

| Field | Ý nghĩa | Dùng để làm gì |
| --- | --- | --- |
| `payment_value` | Giá trị payment transaction | KPI tổng payment, trend, chart payment mix |
| `payment_type_label` | Tên payment đẹp để hiển thị | Pie/bar chart theo method |
| `payment_installments` | Số kỳ trả góp | KPI avg installments, histogram |
| `installment_bucket` | Nhóm kỳ trả góp | Bar chart theo bucket |
| `month_start_date` | Tháng đặt hàng | Trend/filter |
| `customer_state` | Bang của customer | Map/bar theo geography |
| `customer_city` | City của customer | Drill-down geography |
| `order_status` | Trạng thái order | Filter |
| `payment_share_of_order` | Tỷ trọng payment row trong order | Drill-down/debug |

## 5. Calculated Fields Cần Tạo

Trong Tableau, click phải ở Data pane -> `Create Calculated Field`.

### Payment Total

```text
SUM([payment_value])
```

### Payment Orders

```text
COUNTD([order_id])
```

### Payment Transactions

```text
COUNTD([payment_key])
```

### Average Payment Value

```text
SUM([payment_value]) / COUNTD([payment_key])
```

### Average Installments

```text
AVG([payment_installments])
```

### Payment Share

```text
SUM([payment_value]) / TOTAL(SUM([payment_value]))
```

Format `Payment Share` thành Percentage.

## 6. Layout Dashboard Gợi Ý

```text
Header
  Olist Payment Overview
  Payment method, installment and geography performance

Filter row
  Month | Payment Type | Installment Bucket | Customer State | Order Status

KPI row
  Payment Total | Payment Orders | Payment Transactions | Avg Payment Value | Avg Installments

Main row
  Monthly Payment Trend | Payment Method Mix

Bottom row
  Installment Buckets | Payment by Customer State
```

Nên tạo dashboard bằng `Tiled` layout trước để dễ canh.

## 7. Tạo KPI Cards

Tạo 5 worksheet:

```text
KPI - Payment Total
KPI - Payment Orders
KPI - Payment Transactions
KPI - Avg Payment Value
KPI - Avg Installments
```

Cách làm mỗi KPI:

1. Tạo worksheet mới.
2. Kéo calculated field vào `Text`.
3. Marks chọn `Text`.
4. Click `Text` -> `Edit Label`.
5. Format tên KPI nhỏ, số KPI lớn.
6. Align center.
7. Ẩn gridlines và headers nếu không cần.

Ví dụ label:

```text
Payment Total
<Payment Total>
```

Gợi ý format:

| Thành phần | Format |
| --- | --- |
| Tên KPI | Size 10-12, màu xám |
| Giá trị KPI | Size 24-30, bold |
| Nền | Trắng |
| Border | Xám nhạt |

## 8. Tạo Chart Payment Method Mix

Tên sheet:

```text
Payment Method Mix
```

Cách làm bar chart, dễ đọc hơn pie chart:

1. Kéo `payment_type_label` vào Rows.
2. Kéo `payment_value` vào Columns.
3. Đảm bảo aggregation là `SUM(payment_value)`.
4. Sort descending.
5. Kéo `payment_type_label` vào Color.
6. Kéo `Payment Share` vào Label hoặc Tooltip.

Tooltip gợi ý:

```text
Payment Type: <payment_type_label>
Payment Value: <SUM(payment_value)>
Payment Share: <Payment Share>
Orders: <COUNTD(order_id)>
Transactions: <COUNTD(payment_key)>
```

Nếu muốn làm donut/pie:

1. Marks chọn `Pie`.
2. Kéo `payment_type_label` vào Color.
3. Kéo `payment_value` vào Angle.
4. Kéo `Payment Share` vào Label.

Khuyến nghị: dashboard executive nên dùng bar chart vì dễ so sánh hơn.

## 9. Tạo Chart Monthly Payment Trend

Tên sheet:

```text
Monthly Payment Trend
```

Các bước:

1. Kéo `month_start_date` vào Columns.
2. Chọn `MONTH(month_start_date)`.
3. Kéo `payment_value` vào Rows.
4. Marks chọn `Line`.
5. Kéo `payment_type_label` vào Color nếu muốn xem trend theo method.
6. Nếu chart quá rối, bỏ Color và để payment type làm filter.

Tooltip gợi ý:

```text
Month: <MONTH(month_start_date)>
Payment Value: <SUM(payment_value)>
Orders: <COUNTD(order_id)>
Transactions: <COUNTD(payment_key)>
```

## 10. Tạo Chart Installment Buckets

Tên sheet:

```text
Payment by Installment Bucket
```

Các bước:

1. Kéo `installment_bucket` vào Rows.
2. Kéo `payment_value` vào Columns.
3. Sort theo thứ tự bucket nếu cần:
   - `1 installment`
   - `2-3 installments`
   - `4-6 installments`
   - `7-12 installments`
   - `13+ installments`
4. Kéo `Payment Share` vào Label.
5. Kéo `Average Payment Value` vào Tooltip.

Chart này giúp giải thích khách hàng thanh toán một lần hay trả góp nhiều.

## 11. Tạo Chart Payment By Customer State

Tên sheet:

```text
Payment by Customer State
```

Cách làm bar chart:

1. Kéo `customer_state` vào Rows.
2. Kéo `payment_value` vào Columns.
3. Sort descending.
4. Kéo `Payment Orders` vào Tooltip.
5. Kéo `Average Payment Value` vào Tooltip.

Cách làm map:

1. Đảm bảo Tableau nhận `customer_state` là geographic field.
2. Kéo `customer_state` vào view.
3. Kéo `payment_value` vào Color.
4. Kéo `payment_value` vào Size.

Nếu map không nhận đúng Brazil state, dùng bar chart sẽ ổn định hơn cho demo.

## 12. Thêm Filters

Các filter nên có:

| Filter | Field |
| --- | --- |
| Month | `month_start_date` |
| Payment Type | `payment_type_label` |
| Installment Bucket | `installment_bucket` |
| Customer State | `customer_state` |
| Order Status | `order_status` |

Cách apply filter:

1. Mở một worksheet dùng `mart_tableau_payment_mix`.
2. Kéo field vào Filters.
3. Right click filter -> `Show Filter`.
4. Về Dashboard.
5. Trên dropdown của filter, chọn `Apply to Worksheets` -> `All Using This Data Source`.

Vì các sheet payment đều dùng cùng `mart_tableau_payment_mix`, filter sẽ đồng bộ.

## 13. Thêm Dashboard Actions

Nên thêm action để click chart này lọc chart khác.

### Click Payment Method

1. Vào Dashboard -> `Actions`.
2. Chọn `Add Action` -> `Filter`.
3. Name:

```text
Filter by Payment Method
```

4. Source sheet:

```text
Payment Method Mix
```

5. Target sheets:

```text
Monthly Payment Trend
Payment by Installment Bucket
Payment by Customer State
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

### Click Customer State

Tạo action tương tự với source sheet:

```text
Payment by Customer State
```

Action này giúp click một bang để xem payment method và installment mix của bang đó.

## 14. Có Nên Ghép Payment Dashboard Với Sales Dashboard Không?

Có thể ghép, nhưng nên hiểu rõ:

- Sales dashboard dùng `mart_tableau_sales_dashboard`, grain order item.
- Payment dashboard dùng `mart_tableau_payment_mix`, grain payment transaction.

Nếu ghép chung một dashboard, filter `Apply to All Using This Data Source` chỉ đồng bộ trong từng data source. Vì vậy cách dễ demo nhất là:

```text
Dashboard 1: Olist Executive Overview
  Data source: mart_tableau_sales_dashboard

Dashboard 2: Olist Payment Overview
  Data source: mart_tableau_payment_mix
```

Nếu vẫn muốn đặt chung một dashboard, nên chỉ dùng các filter chung:

- `month_start_date`
- `customer_state`
- `order_status`

Và cần tạo filter riêng cho từng data source.

## 15. Kiểm Tra Số Liệu

Chạy dbt test:

```bash
docker exec dbt dbt build --select mart_tableau_payment_mix assert_tableau_payment_mix_reconciles
```

Test reconcile kiểm tra:

```text
SUM(mart_tableau_payment_mix.payment_value)
=
SUM(fact_orders.payment_value_total)
```

Nếu test pass thì payment total trong dashboard có thể tin được.

Trong Tableau, kiểm tra nhanh:

1. Clear toàn bộ filter.
2. KPI `Payment Total` phải bằng `SUM(payment_value)`.
3. Payment method chart cộng lại phải bằng KPI `Payment Total`.
4. Khi click `Credit Card`, KPI và các chart khác phải đổi theo.
5. Khi chọn tháng/state, tất cả payment sheets phải đổi theo.

## 16. Checklist Hoàn Thành

Trước khi demo:

- Data source là `warehouse.mart_tableau_payment_mix`.
- Payment Total dùng `SUM(payment_value)`.
- Payment Orders dùng `COUNTD(order_id)`.
- Payment Transactions dùng `COUNTD(payment_key)`.
- Filters apply to `All Using This Data Source`.
- Có ít nhất 5 KPI cards.
- Có chart payment method mix.
- Có chart monthly payment trend.
- Có chart installment bucket.
- Có chart payment by state.
- dbt test reconcile pass.

