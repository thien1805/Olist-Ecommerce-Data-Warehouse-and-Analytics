-- Intermediate: orders enriched to one row per order
with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

order_items as (
    select * from {{ ref('int_order_items_aggregated') }}
),

payments as (
    select * from {{ ref('int_order_payments_aggregated') }}
),

reviews as (
    select * from {{ ref('int_order_reviews_aggregated') }}
)

select
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    coalesce(oi.order_item_count, 0) as order_item_count,
    coalesce(oi.distinct_product_count, 0) as distinct_product_count,
    coalesce(oi.distinct_seller_count, 0) as distinct_seller_count,
    coalesce(oi.item_price_total, 0) as item_price_total,
    coalesce(oi.freight_value_total, 0) as freight_value_total,
    coalesce(oi.order_items_total, 0) as order_items_total,
    coalesce(p.payment_count, 0) as payment_count,
    coalesce(p.payment_value_total, 0) as payment_value_total,
    p.max_payment_installments,
    p.payment_types,
    coalesce(p.credit_card_value, 0) as credit_card_value,
    coalesce(p.boleto_value, 0) as boleto_value,
    coalesce(p.voucher_value, 0) as voucher_value,
    coalesce(p.debit_card_value, 0) as debit_card_value,
    coalesce(r.review_count, 0) as review_count,
    r.avg_review_score,
    r.min_review_score,
    r.max_review_score,
    r.first_review_creation_date,
    r.last_review_answer_timestamp,
    extract(epoch from (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400.0 as delivery_time_days,
    extract(epoch from (o.order_estimated_delivery_date - o.order_purchase_timestamp)) / 86400.0 as estimated_delivery_time_days,
    case
        when o.order_delivered_customer_date is null then null
        when o.order_delivered_customer_date <= o.order_estimated_delivery_date then true
        else false
    end as is_delivered_on_time
from orders o
left join customers c on o.customer_id = c.customer_id
left join order_items oi on o.order_id = oi.order_id
left join payments p on o.order_id = p.order_id
left join reviews r on o.order_id = r.order_id
