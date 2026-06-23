-- Metrics mart: monthly sales KPIs for BI dashboards
{{ config(materialized='table') }}

with orders as (
    select * from {{ ref('fact_orders') }}
)

select
    date_trunc('month', order_date_key)::date as month_start_date,
    count(*) as total_orders,
    count(*) filter (where order_status = 'delivered') as delivered_orders,
    count(*) filter (where order_status = 'canceled') as canceled_orders,
    sum(order_items_total) as gmv,
    sum(payment_value_total) as payment_value_total,
    avg(order_items_total) as average_order_value,
    avg(delivery_time_days) as avg_delivery_time_days,
    avg(avg_review_score) as avg_review_score,
    avg(
        case
            when is_delivered_on_time is true then 1.0
            when is_delivered_on_time is false then 0.0
            else null
        end
    ) as on_time_delivery_rate
from orders
group by 1
