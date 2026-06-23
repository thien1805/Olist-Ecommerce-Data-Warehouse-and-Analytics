-- Product category aggregate totals must reconcile to fact_order_items joined with dim_products.
with fact_category as (
    select
        coalesce(p.product_category_name_english, 'Unknown') as product_category_name_english,
        count(*) as expected_order_item_count,
        count(distinct oi.order_id) as expected_order_count,
        sum(oi.item_total_amount) as expected_total_amount
    from {{ ref('fact_order_items') }} oi
    left join {{ ref('dim_products') }} p on oi.product_key = p.product_key
    group by 1
),

agg as (
    select
        product_category_name_english,
        order_item_count,
        order_count,
        total_amount
    from {{ ref('agg_product_category_performance') }}
)

select
    a.product_category_name_english,
    a.order_item_count,
    f.expected_order_item_count,
    a.order_count,
    f.expected_order_count,
    a.total_amount,
    f.expected_total_amount
from agg a
left join fact_category f
    on a.product_category_name_english = f.product_category_name_english
where a.order_item_count != f.expected_order_item_count
   or a.order_count != f.expected_order_count
   or abs(coalesce(a.total_amount, 0) - coalesce(f.expected_total_amount, 0)) > 0.01
