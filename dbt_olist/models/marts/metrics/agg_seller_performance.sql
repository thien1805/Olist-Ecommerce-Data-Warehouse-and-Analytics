-- Metrics mart: seller performance for BI dashboards
{{ config(materialized='table') }}

with order_items as (
    select * from {{ ref('fact_order_items') }}
),

sellers as (
    select * from {{ ref('dim_sellers') }}
)

select
    s.seller_id,
    s.seller_state,
    s.seller_city,
    count(*) as order_item_count,
    count(distinct oi.order_id) as order_count,
    sum(oi.price) as item_price_total,
    sum(oi.freight_value) as freight_value_total,
    sum(oi.item_total_amount) as total_amount
from order_items oi
left join sellers s on oi.seller_key = s.seller_key
group by 1, 2, 3
