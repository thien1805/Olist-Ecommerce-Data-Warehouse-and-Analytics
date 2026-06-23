-- fact_orders order item totals must equal summed staging order item amounts at order grain.
with order_items as (
    select
        order_id,
        sum(price) as expected_item_price_total,
        sum(freight_value) as expected_freight_value_total,
        sum(price + freight_value) as expected_order_items_total
    from {{ ref('stg_order_items') }}
    group by order_id
),

fact as (
    select
        order_id,
        item_price_total,
        freight_value_total,
        order_items_total
    from {{ ref('fact_orders') }}
)

select
    f.order_id,
    f.item_price_total,
    i.expected_item_price_total,
    f.freight_value_total,
    i.expected_freight_value_total,
    f.order_items_total,
    i.expected_order_items_total
from fact f
left join order_items i on f.order_id = i.order_id
where abs(coalesce(f.item_price_total, 0) - coalesce(i.expected_item_price_total, 0)) > 0.01
   or abs(coalesce(f.freight_value_total, 0) - coalesce(i.expected_freight_value_total, 0)) > 0.01
   or abs(coalesce(f.order_items_total, 0) - coalesce(i.expected_order_items_total, 0)) > 0.01
