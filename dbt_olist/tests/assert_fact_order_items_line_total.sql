-- fact_order_items.item_total_amount must equal price + freight_value.
select
    order_id,
    order_item_id,
    price,
    freight_value,
    item_total_amount
from {{ ref('fact_order_items') }}
where abs(coalesce(item_total_amount, 0) - (coalesce(price, 0) + coalesce(freight_value, 0))) > 0.01
