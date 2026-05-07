-- Marts: fact_orders — final fact table
{{ config(materialized='table') }}

with enriched_orders as (
    select * from {{ ref('int_orders_enriched') }}
),

dim_customers as (
    select customer_id, customer_key from {{ ref('dim_customers') }}
),

dim_products as (
    select product_id, product_key from {{ ref('dim_products') }}
),

dim_sellers as (
    select seller_id, seller_key from {{ ref('dim_sellers') }}
),

dim_geolocation as (
    select geolocation_zip_code_prefix, geolocation_key from {{ ref('dim_geolocation') }}
),

dim_payments as (
    select order_id, payment_sequential, payment_key from {{ ref('dim_payments') }}
)

select
    eo.order_id,
    dc.customer_key,
    dp.product_key,
    ds.seller_key,
    dg.geolocation_key,
    dpay.payment_key,
    eo.order_purchase_timestamp::date as order_date_key,
    eo.order_status,
    eo.price,
    eo.freight_value,
    eo.total_amount,
    eo.payment_value,
    eo.delivery_time_days,
    eo.estimated_delivery_time_days
from enriched_orders eo
left join dim_customers dc on eo.customer_id = dc.customer_id
left join dim_products dp on eo.product_id = dp.product_id
left join dim_sellers ds on eo.seller_id = ds.seller_id
left join dim_geolocation dg on eo.customer_zip_code_prefix = dg.geolocation_zip_code_prefix
left join dim_payments dpay
    on eo.order_id = dpay.order_id
    and eo.payment_sequential = dpay.payment_sequential
