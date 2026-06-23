-- Core mart: order-level fact table
{{ config(materialized='table') }}

with enriched_orders as (
    select * from {{ ref('int_orders_enriched') }}
),

dim_customers as (
    select customer_id, customer_key from {{ ref('dim_customers') }}
),

dim_geolocation as (
    select geolocation_zip_code_prefix, geolocation_key from {{ ref('dim_geolocation') }}
)

select
    eo.order_id,
    dc.customer_key,
    dg.geolocation_key,
    eo.order_purchase_timestamp::date as order_date_key,
    eo.order_status,
    eo.order_purchase_timestamp,
    eo.order_approved_at,
    eo.order_delivered_carrier_date,
    eo.order_delivered_customer_date,
    eo.order_estimated_delivery_date,
    eo.order_item_count,
    eo.distinct_product_count,
    eo.distinct_seller_count,
    eo.item_price_total,
    eo.freight_value_total,
    eo.order_items_total,
    eo.payment_count,
    eo.payment_value_total,
    eo.max_payment_installments,
    eo.payment_types,
    eo.credit_card_value,
    eo.boleto_value,
    eo.voucher_value,
    eo.debit_card_value,
    eo.review_count,
    eo.avg_review_score,
    eo.min_review_score,
    eo.max_review_score,
    eo.delivery_time_days,
    eo.estimated_delivery_time_days,
    eo.is_delivered_on_time
from enriched_orders eo
left join dim_customers dc on eo.customer_id = dc.customer_id
left join dim_geolocation dg on eo.customer_zip_code_prefix = dg.geolocation_zip_code_prefix
