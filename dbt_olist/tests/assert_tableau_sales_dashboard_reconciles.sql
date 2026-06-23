with dashboard_totals as (
    select
        round(sum(gmv)::numeric, 2) as dashboard_gmv,
        round(sum(allocated_payment_value)::numeric, 2) as dashboard_payment_value
    from {{ ref('mart_tableau_sales_dashboard') }}
),

fact_totals as (
    select
        round(sum(order_items_total)::numeric, 2) as fact_gmv,
        round(sum(payment_value_total)::numeric, 2) as fact_payment_value
    from {{ ref('fact_orders') }}
)

select
    dashboard_gmv,
    fact_gmv,
    dashboard_payment_value,
    fact_payment_value
from dashboard_totals
cross join fact_totals
where abs(dashboard_gmv - fact_gmv) > 0.01
   or abs(dashboard_payment_value - fact_payment_value) > 0.01
