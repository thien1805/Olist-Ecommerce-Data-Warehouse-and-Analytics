-- Metrics mart: product category performance for BI dashboards
{{ config(materialized='table') }}

with order_items as (
    select * from {{ ref('fact_order_items') }}
),

products as (
    select * from {{ ref('dim_products') }}
)

select
    coalesce(p.product_category_name_english, 'Unknown') as product_category_name_english,
    count(*) as order_item_count,
    count(distinct oi.order_id) as order_count,
    sum(oi.price) as item_price_total,
    sum(oi.freight_value) as freight_value_total,
    sum(oi.item_total_amount) as total_amount,
    avg(oi.price) as avg_item_price
from order_items oi
left join products p on oi.product_key = p.product_key
group by 1
