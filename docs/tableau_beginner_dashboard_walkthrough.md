# Tableau Beginner Walkthrough: Làm Dashboard Olist Đẹp Và Dễ Demo

Tài liệu này dành cho người lần đầu dùng Tableau. Mục tiêu là tạo một dashboard nhìn giống kiểu executive dashboard trên Tableau Public: có KPI cards, biểu đồ xu hướng, top category, seller performance, delivery performance và filter tương tác.

## 1. Hiểu Đúng Khái Niệm Trong Tableau

Trong Tableau có 3 khái niệm dễ nhầm:

| Thành phần | Ý nghĩa | Dùng khi nào |
| --- | --- | --- |
| Data Source | Nơi kết nối dữ liệu, ví dụ PostgreSQL table | Kết nối `warehouse.mart_tableau_sales_dashboard` |
| Worksheet | Một biểu đồ hoặc một bảng phân tích | Một line chart, một bar chart, một KPI card |
| Dashboard | Một trang ghép nhiều worksheet lại | Trang executive overview có nhiều KPI và chart |

Nếu bạn nói "1 sheet chứa nhiều thông số", trong Tableau có 2 cách:

- Cách 1: Một `worksheet` chứa nhiều metric bằng `Measure Names` và `Measure Values`.
- Cách 2: Một `dashboard page` chứa nhiều worksheet nhỏ. Cách này đẹp hơn, dễ trang trí hơn và giống Tableau Public hơn.

Khuyến nghị cho project này: dùng **Dashboard** làm trang chính, bên trong có nhiều worksheet.

## 2. Thiết Kế Dashboard Mục Tiêu

Tên dashboard:

```text
Olist Executive Overview
```

Mục tiêu người xem:

- Nhìn 5 giây đầu biết business đang tốt hay xấu.
- Biết GMV và payment theo tháng.
- Biết top ngành hàng.
- Biết seller nào đóng góp cao.
- Biết khu vực nào giao hàng tốt hoặc chậm.

Layout gợi ý:

```text
Header
  Olist Executive Overview
  Last refresh / Business date

KPI row
  Total GMV | Payment Total | AOV | On-Time Rate | Avg Review

Main row
  Monthly GMV Trend

Bottom row
  Top Categories | Top Sellers | Delivery by State

Filter panel
  Month range | State | Category
```

## 3. Chuẩn Bị Trước Khi Mở Tableau

Đảm bảo các service đang chạy:

```bash
docker compose ps
```

Đảm bảo DAG đã chạy thành công:

```text
e_commerce_elt -> success
dbt_transform.dbt_test -> success
send_success_email -> success
```

Tableau sẽ đọc PostgreSQL warehouse:

| Field | Value |
| --- | --- |
| Server | `localhost` |
| Port | `5433` |
| Database | `postgres` |
| Username | `admin` |
| Password | `admin` |
| Schema | `warehouse` |

Dashboard chính nên dùng bảng:

```text
warehouse.mart_tableau_sales_dashboard
```

Bảng này được tạo riêng để KPI cards và charts dùng chung filter trong Tableau.

## 4. Kết Nối PostgreSQL Trong Tableau

1. Mở Tableau Desktop.
2. Ở màn hình đầu, chọn `Connect` -> `To a Server` -> `PostgreSQL`.
3. Điền:

```text
Server: localhost
Port: 5433
Database: postgres
Username: admin
Password: admin
SSL: None
```

4. Click `Sign In`.
5. Ở Data Source page, chọn schema `warehouse`.

Nếu chưa thấy PostgreSQL connector, cài PostgreSQL driver cho Tableau rồi mở lại Tableau.

## 5. Cách Chọn Bảng Cho Dashboard Đầu Tiên

Với người mới, đừng join nhiều bảng trong Tableau. Kéo duy nhất bảng này vào canvas:

```text
mart_tableau_sales_dashboard
```

Lý do:

- KPI cards và charts có thể dùng chung filter.
- Không cần tự join fact/dim.
- Có sẵn month, category, seller, customer geography.
- Có `allocated_payment_value` để payment không bị nhân bản theo order item.

Các bảng aggregate như `agg_monthly_sales`, `agg_product_category_performance`, `agg_seller_performance`, `agg_delivery_performance` vẫn hữu ích để kiểm tra số liệu hoặc làm dashboard phụ. Nhưng dashboard chính nên dùng `mart_tableau_sales_dashboard`.

## 5.1. Calculated Fields Bắt Buộc

Sau khi connect `mart_tableau_sales_dashboard`, tạo các calculated fields sau trong Tableau.

### Total GMV

```text
SUM([gmv])
```

### Payment Total

```text
SUM([allocated_payment_value])
```

Không dùng payment order-level trực tiếp ở item-grain. Field `allocated_payment_value` đã được dbt xử lý để không double-count.

### Order Count

```text
COUNTD([order_id])
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

Format là Percentage.

### Average Review Score

```text
AVG([avg_review_score])
```

## 6. Làm Sheet KPI Cards

### Cách Đẹp Nhất: Mỗi KPI Là Một Worksheet

Cách này hơi nhiều worksheet nhưng dashboard đẹp và dễ format.

Tạo 5 worksheet:

```text
KPI - Total GMV
KPI - Payment Total
KPI - AOV
KPI - On-Time Rate
KPI - Avg Review
```

### 6.1. KPI - Total GMV

Data source: `mart_tableau_sales_dashboard`

Các bước:

1. Tạo worksheet mới.
2. Đổi tên sheet thành `KPI - Total GMV`.
3. Kéo calculated field `Total GMV` vào `Text` trong Marks.
4. Format currency.
5. Trong Marks, chọn `Text`.
6. Click `Text` -> `Edit Label`.
7. Sửa label thành:

```text
Total GMV
<Total GMV>
```

Format:

- Chữ `Total GMV`: size 10-12, màu xám.
- Số GMV: size 22-28, bold, màu xanh đậm.
- Align center.
- Ẩn title nếu đặt title ở dashboard card.

### 6.2. KPI - Payment Total

Tương tự Total GMV:

- Dùng calculated field `Payment Total`.
- Label:

```text
Payment Total
<Payment Total>
```

### 6.3. KPI - AOV

Dùng:

```text
Average Order Value
```

Label:

```text
Average Order Value
<Average Order Value>
```

### 6.4. KPI - On-Time Rate

Dùng:

```text
On-Time Delivery Rate
```

Format field thành percentage.

Label:

```text
On-Time Delivery
<On-Time Delivery Rate>
```

### 6.5. KPI - Avg Review

Dùng:

```text
Average Review Score
```

Label:

```text
Avg Review Score
<Average Review Score>
```

## 7. Nếu Muốn Một Worksheet Chứa Nhiều KPI

Nếu bắt buộc làm một worksheet duy nhất chứa nhiều thông số:

1. Tạo sheet `KPI Overview`.
2. Kéo `Measure Names` vào `Columns`.
3. Kéo `Measure Values` vào `Text`.
4. Kéo `Measure Names` vào `Filters`.
5. Chỉ chọn:

```text
Total GMV
Payment Total
Average Order Value
On-Time Delivery Rate
Average Review Score
```

6. Format từng measure trong `Measure Values`.

Nhược điểm:

- Khó format mỗi KPI như một card riêng.
- Chữ và số dễ lệch nếu nhiều metric.
- Ít đẹp hơn so với đặt 5 KPI worksheet vào dashboard.

Vì vậy, để dashboard đẹp như Tableau Public, nên dùng nhiều KPI worksheet nhỏ trong một dashboard.

## 8. Làm Sheet Monthly GMV Trend

Data source: `mart_tableau_sales_dashboard`

Các bước:

1. Tạo worksheet `Monthly GMV Trend`.
2. Kéo `month_start_date` vào `Columns`.
3. Kéo calculated field `Total GMV` vào `Rows`.
4. Marks chọn `Line`.
5. Click `month_start_date` trên Columns:
   - Chọn dạng `Month` hoặc `Exact Date`.
   - Nên dùng continuous date để line chart mượt.
6. Kéo thêm vào Tooltip:
   - `allocated_payment_value`
   - calculated field `Average Order Value`
   - calculated field `On-Time Delivery Rate`
   - calculated field `Average Review Score`

Format:

- Line màu xanh `#2563EB`.
- Tăng line thickness nếu cần.
- Ẩn gridline đậm.
- Title: `Monthly GMV Trend`.

Tooltip gợi ý:

```text
Month: <month_start_date>
GMV: <Total GMV>
Payment: <Payment Total>
AOV: <Average Order Value>
On-Time Rate: <On-Time Delivery Rate>
Avg Review: <Average Review Score>
```

## 9. Làm Sheet Top Product Categories

Data source: `mart_tableau_sales_dashboard`

Các bước:

1. Tạo worksheet `Top Product Categories`.
2. Kéo `product_category_name_english` vào `Rows`.
3. Kéo calculated field `Total GMV` vào `Columns`.
4. Marks chọn `Bar`.
5. Sort descending.
6. Filter Top 10:
   - Click `product_category_name_english` -> `Filter`.
   - Tab `Top`.
   - Chọn `By field`.
   - Top `10` by calculated field `Total GMV`.

Format:

- Bar màu xanh hoặc teal.
- Show label ở cuối bar.
- Ẩn gridline.
- Title: `Top Product Categories by GMV`.

## 10. Làm Sheet Top Sellers

Data source: `mart_tableau_sales_dashboard`

Các bước:

1. Tạo worksheet `Top Sellers`.
2. Kéo `seller_id` vào `Rows`.
3. Kéo calculated field `Total GMV` vào `Columns`.
4. Sort descending.
5. Filter Top 10 hoặc Top 20 seller.

Tooltip:

```text
Seller: <seller_id>
Total GMV: <Total GMV>
Item Price: <SUM(item_price_total)>
Freight: <SUM(freight_value_total)>
```

Design:

- Không cần hiển thị full seller id quá dài trên label.
- Có thể chỉ dùng tooltip để xem seller id.
- Nếu label quá rối, ẩn label và chỉ giữ axis.

## 11. Làm Sheet Delivery By State

Data source: `mart_tableau_sales_dashboard`

Option dễ làm nhất: bar chart.

Các bước:

1. Tạo worksheet `Delivery by State`.
2. Kéo `customer_state` vào `Rows`.
3. Kéo calculated field `On-Time Delivery Rate` vào `Columns`.
4. Format thành percentage.
5. Kéo calculated field `Order Count` vào `Label` hoặc Tooltip.
7. Kéo `avg_review_score` vào `Color`.

Design:

- Sort descending theo on-time rate.
- Dùng màu càng đậm càng tốt.
- Nếu màu khó hiểu, đổi Color thành calculated field `On-Time Delivery Rate`.

Tooltip:

```text
State: <customer_state>
Total Orders: <Order Count>
GMV: <Total GMV>
On-Time Rate: <On-Time Delivery Rate>
Avg Review: <Average Review Score>
```

## 12. Tạo Dashboard Page

1. Click icon `New Dashboard`.
2. Đổi tên thành `Olist Executive Overview`.
3. Bên trái, chọn Size:

```text
Fixed size: 1200 x 850
```

Nếu muốn responsive hơn:

```text
Size: Automatic
```

Nhưng để demo laptop đẹp, `1200 x 850` dễ kiểm soát hơn.

## 13. Layout Dashboard Chi Tiết

### 13.1. Tạo Header

Kéo `Text` object vào đầu dashboard.

Nội dung:

```text
Olist Executive Overview
Sales, seller, product category and delivery performance
```

Format:

- Title size 22-28, bold.
- Subtitle size 11-13, màu xám.
- Background có thể để trắng hoặc xanh rất nhạt.

### 13.2. Tạo KPI Row

1. Kéo `Horizontal Container` vào dưới header.
2. Kéo 5 KPI sheets vào container:
   - `KPI - Total GMV`
   - `KPI - Payment Total`
   - `KPI - AOV`
   - `KPI - On-Time Rate`
   - `KPI - Avg Review`
3. Với mỗi KPI sheet:
   - Hide title nếu label đã có tên metric.
   - Fit -> Entire View.
   - Set background trắng.
   - Add padding 8-12.

Trang trí card:

- Click từng sheet trong dashboard.
- Tab `Layout`.
- Thêm outer padding 6.
- Thêm border mỏng màu `#E5E7EB`.
- Có thể dùng background `#F8FAFC`.

### 13.3. Tạo Main Chart Row

Kéo `Monthly GMV Trend` vào dưới KPI row.

Format:

- Chiếm khoảng 35-40% chiều cao dashboard.
- Fit Width.
- Title rõ ràng.

### 13.4. Tạo Bottom Row

Kéo `Horizontal Container` dưới trend chart.

Đặt 3 sheets:

```text
Top Product Categories | Top Sellers | Delivery by State
```

Nếu màn hình nhỏ, có thể để 2 chart một dòng và delivery xuống dưới.

## 14. Thêm Filter Cho Dashboard

### 14.1. Month Filter

Trong sheet `Monthly GMV Trend`:

1. Kéo `month_start_date` vào Filters.
2. Chọn range of dates.
3. Trên dashboard, click chart -> menu nhỏ -> `Filters` -> chọn `month_start_date`.
4. Đổi filter style thành `Range Slider`.

### 14.2. State Filter

Trong sheet `Delivery by State`:

1. Kéo `customer_state` vào Filters.
2. Show Filter.
3. Trong dashboard, đổi filter thành `Dropdown` hoặc `Single Value List`.

### 14.3. Dùng Chart Làm Filter

Để dashboard tương tác:

1. Click sheet `Delivery by State` trong dashboard.
2. Click icon `Use as Filter`.
3. Khi user click một state, các chart liên quan cùng data source sẽ được lọc.

Lưu ý: nếu mỗi chart dùng data source khác nhau, filter action có thể không áp dụng hết. Với dashboard đầu tiên, cứ dùng filter riêng cho từng data source là dễ nhất.

## 15. Trang Trí Cho Giống Dashboard Tableau Public

### 15.1. Màu Sắc

Palette gợi ý:

| Mục | Màu |
| --- | --- |
| Primary blue | `#2563EB` |
| Success green | `#16A34A` |
| Text dark | `#1F2937` |
| Text muted | `#64748B` |
| Border | `#E5E7EB` |
| Background | `#F8FAFC` |

Không nên dùng quá nhiều màu. Dashboard executive nên sạch và dễ đọc.

### 15.2. Font

Gợi ý:

- Title: 22-28
- Section title: 14-18
- Axis/label: 9-11
- KPI number: 22-30

### 15.3. Spacing

Trong dashboard:

- Dùng container để căn chỉnh.
- Dùng padding 8-16.
- Không để các chart dính sát nhau.
- Không dùng quá nhiều border đậm.

### 15.4. Tooltip

Tooltip nên viết rõ, không để mặc định quá xấu.

Ví dụ tooltip cho category:

```text
Category: <product_category_name_english>
Total GMV: <Total GMV>
Item Price: <SUM(item_price_total)>
Freight: <SUM(freight_value_total)>
```

## 16. Checklist Khi Làm Xong

Dashboard nên có:

- Header rõ ràng.
- 5 KPI cards.
- 1 line chart GMV theo tháng.
- 1 bar chart top category.
- 1 bar chart top seller.
- 1 delivery chart theo state/city.
- Ít nhất 1 filter thời gian.
- Tooltip đã sửa lại.
- Không có chart nào bị chữ chồng lên nhau.
- Không có bảng quá rộng làm tràn màn hình.

## 17. Lỗi Người Mới Hay Gặp

### Không thấy schema warehouse

Kiểm tra DAG/dbt đã chạy chưa:

```bash
docker exec dbt dbt build
```

### Tableau không connect được PostgreSQL

Kiểm tra container:

```bash
docker compose ps
```

Kiểm tra port:

```text
localhost:5433
```

Không dùng `5432` vì trong Docker compose project đang map PostgreSQL warehouse ra `5433`.

### Chart bị sai số

Nguyên nhân thường gặp:

- Join sai grain trong Tableau.
- Join aggregate mart với fact table.
- Dùng `SUM` cho ratio như `on_time_delivery_rate`.

Cách sửa:

- Ratio dùng `AVG`.
- Tổng tiền dùng `SUM`.
- Dashboard đầu tiên nên dùng aggregate marts độc lập, không join lung tung.

### Dashboard nhìn rối

Cách sửa:

- Giảm số chart trên một dashboard.
- Chia thành 2 dashboard:
  - Executive Overview
  - Delivery Operations
- Dùng filter thay vì show quá nhiều bảng chi tiết.

## 18. Tham Khảo Design Pattern

Một số pattern từ Tableau Public và Tableau docs nên học theo:

- Dashboard executive nên bắt đầu từ audience và KPI quan trọng nhất.
- Dashboard không nên nhồi quá nhiều view trên một trang; nếu nhiều câu hỏi phân tích, tách thành nhiều dashboard.
- Dùng chart làm filter để tăng tương tác.
- Dùng layout đơn giản, predictable, ít màu và dễ scan.

Nguồn tham khảo:

- Tableau Sales Dashboard Examples and Templates: https://www.tableau.com/dashboard/sales-dashboard-examples-and-templates
- Tableau Dashboard Examples: https://www.tableau.com/dashboard/dashboard-examples
- Tableau Dashboard Showcase: https://www.tableau.com/data-insights/dashboard-showcase
- Tableau Help - Best Practices for Effective Dashboards: https://help.tableau.com/current/pro/desktop/en-us/dashboards_best_practices.htm
- Tableau Help - Create a Dashboard: https://help.tableau.com/current/pro/desktop/en-us/dashboards_create.htm
- Tableau Help - Actions and Dashboards: https://help.tableau.com/current/pro/desktop/en-us/actions_dashboards.htm
