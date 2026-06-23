-- Core mart: order item-level fact table
{{ config(materialized='table') }}

with order_items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select order_id, customer_id, order_status, order_purchase_timestamp
    from {{ ref('stg_orders') }}
),

customers as (
    select customer_id, customer_key
    from {{ ref('dim_customers') }}
),

products as (
    select product_id, product_key
    from {{ ref('dim_products') }}
),

sellers as (
    select seller_id, seller_key
    from {{ ref('dim_sellers') }}
)

select
    oi.order_id,
    oi.order_item_id,
    c.customer_key,
    p.product_key,
    s.seller_key,
    o.order_purchase_timestamp::date as order_date_key,
    o.order_status,
    oi.shipping_limit_date,
    oi.price,
    oi.freight_value,
    oi.price + oi.freight_value as item_total_amount
from order_items oi
left join orders o on oi.order_id = o.order_id
left join customers c on o.customer_id = c.customer_id
left join products p on oi.product_id = p.product_id
left join sellers s on oi.seller_id = s.seller_id
