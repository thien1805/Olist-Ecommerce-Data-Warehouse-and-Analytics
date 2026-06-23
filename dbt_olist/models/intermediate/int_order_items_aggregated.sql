-- Intermediate: order item metrics at order grain
with order_items as (
    select * from {{ ref('stg_order_items') }}
)

select
    order_id,
    count(*) as order_item_count,
    count(distinct product_id) as distinct_product_count,
    count(distinct seller_id) as distinct_seller_count,
    sum(price) as item_price_total,
    sum(freight_value) as freight_value_total,
    sum(price + freight_value) as order_items_total
from order_items
group by order_id
