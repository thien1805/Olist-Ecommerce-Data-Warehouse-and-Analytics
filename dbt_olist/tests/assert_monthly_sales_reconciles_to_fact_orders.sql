-- agg_monthly_sales.gmv must reconcile to fact_orders.order_items_total by month.
with fact_monthly as (
    select
        date_trunc('month', order_date_key)::date as month_start_date,
        count(*) as expected_total_orders,
        sum(order_items_total) as expected_gmv,
        sum(payment_value_total) as expected_payment_value_total
    from {{ ref('fact_orders') }}
    group by 1
),

agg as (
    select
        month_start_date,
        total_orders,
        gmv,
        payment_value_total
    from {{ ref('agg_monthly_sales') }}
)

select
    a.month_start_date,
    a.total_orders,
    f.expected_total_orders,
    a.gmv,
    f.expected_gmv,
    a.payment_value_total,
    f.expected_payment_value_total
from agg a
left join fact_monthly f on a.month_start_date = f.month_start_date
where a.total_orders != f.expected_total_orders
   or abs(coalesce(a.gmv, 0) - coalesce(f.expected_gmv, 0)) > 0.01
   or abs(coalesce(a.payment_value_total, 0) - coalesce(f.expected_payment_value_total, 0)) > 0.01
