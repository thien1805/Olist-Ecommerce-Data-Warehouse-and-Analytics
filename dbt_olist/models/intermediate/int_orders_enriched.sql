-- Intermediate: Orders enriched with items, payments, and customer zip code
with orders as (
    select * from {{ ref('stg_orders') }}
),

order_items as (
    select * from {{ ref('stg_order_items') }}
),

payments as (
    select * from {{ ref('stg_payments') }}
),

customers as (
    select customer_id, customer_zip_code_prefix
    from {{ ref('stg_customers') }}
)

select
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    oi.product_id,
    oi.seller_id,
    oi.price,
    oi.freight_value,
    p.payment_sequential,
    p.payment_type,
    p.payment_installments,
    p.payment_value,
    c.customer_zip_code_prefix,
    -- Calculated metrics
    oi.price * oi.freight_value as total_amount,
    extract(epoch from (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400.0 as delivery_time_days,
    extract(epoch from (o.order_estimated_delivery_date - o.order_purchase_timestamp)) / 86400.0 as estimated_delivery_time_days
from orders o
left join order_items oi on o.order_id = oi.order_id
left join payments p on o.order_id = p.order_id
left join customers c on o.customer_id = c.customer_id
