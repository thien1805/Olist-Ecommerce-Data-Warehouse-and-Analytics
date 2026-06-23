with seller_dashboard_totals as (
    select
        round(sum(gmv)::numeric, 2) as seller_dashboard_gmv,
        round(sum(allocated_payment_value)::numeric, 2) as seller_dashboard_payment_value
    from {{ ref('mart_tableau_seller_dashboard') }}
),

sales_item_totals as (
    select
        round(sum(gmv)::numeric, 2) as sales_item_gmv,
        round(sum(allocated_payment_value)::numeric, 2) as sales_item_payment_value
    from {{ ref('mart_tableau_sales_dashboard') }}
    where order_item_id <> 0
      and seller_id <> 'Unknown'
)

select
    seller_dashboard_gmv,
    sales_item_gmv,
    seller_dashboard_payment_value,
    sales_item_payment_value
from seller_dashboard_totals
cross join sales_item_totals
where abs(seller_dashboard_gmv - sales_item_gmv) > 0.01
   or abs(seller_dashboard_payment_value - sales_item_payment_value) > 0.01
