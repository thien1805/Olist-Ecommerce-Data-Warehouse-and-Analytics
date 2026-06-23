-- Metrics mart: delivery performance by customer geography
{{ config(materialized='table') }}

with orders as (
    select * from {{ ref('fact_orders') }}
),

customers as (
    select * from {{ ref('dim_customers') }}
)

select
    c.customer_state,
    c.customer_city,
    count(*) as total_orders,
    count(*) filter (where o.order_status = 'delivered') as delivered_orders,
    avg(o.delivery_time_days) as avg_delivery_time_days,
    avg(o.estimated_delivery_time_days) as avg_estimated_delivery_time_days,
    avg(
        case
            when o.is_delivered_on_time is true then 1.0
            when o.is_delivered_on_time is false then 0.0
            else null
        end
    ) as on_time_delivery_rate,
    sum(o.order_items_total) as gmv,
    avg(o.avg_review_score) as avg_review_score
from orders o
left join customers c on o.customer_key = c.customer_key
group by 1, 2
