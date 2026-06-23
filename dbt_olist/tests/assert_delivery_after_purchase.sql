-- Kiểm tra ngày giao hàng phải sau ngày mua
select *
from {{ ref('stg_orders') }}
where order_delivered_customer_date < order_purchase_timestamp
