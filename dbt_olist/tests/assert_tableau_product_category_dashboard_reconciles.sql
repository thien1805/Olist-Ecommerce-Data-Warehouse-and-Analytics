with product_dashboard_totals as (
    select
        round(sum(gmv)::numeric, 2) as product_dashboard_gmv,
        round(sum(allocated_payment_value)::numeric, 2) as product_dashboard_payment_value
    from {{ ref('mart_tableau_product_category_dashboard') }}
),

sales_item_totals as (
    select
        round(sum(gmv)::numeric, 2) as sales_item_gmv,
        round(sum(allocated_payment_value)::numeric, 2) as sales_item_payment_value
    from {{ ref('mart_tableau_sales_dashboard') }}
    where order_item_id <> 0
)

select
    product_dashboard_gmv,
    sales_item_gmv,
    product_dashboard_payment_value,
    sales_item_payment_value
from product_dashboard_totals
cross join sales_item_totals
where abs(product_dashboard_gmv - sales_item_gmv) > 0.01
   or abs(product_dashboard_payment_value - sales_item_payment_value) > 0.01
