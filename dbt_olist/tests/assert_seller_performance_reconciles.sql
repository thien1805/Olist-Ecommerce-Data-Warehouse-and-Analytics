-- Seller aggregate totals must reconcile to fact_order_items joined with dim_sellers.
with fact_seller as (
    select
        s.seller_id,
        count(*) as expected_order_item_count,
        count(distinct oi.order_id) as expected_order_count,
        sum(oi.item_total_amount) as expected_total_amount
    from {{ ref('fact_order_items') }} oi
    left join {{ ref('dim_sellers') }} s on oi.seller_key = s.seller_key
    group by 1
),

agg as (
    select
        seller_id,
        order_item_count,
        order_count,
        total_amount
    from {{ ref('agg_seller_performance') }}
)

select
    a.seller_id,
    a.order_item_count,
    f.expected_order_item_count,
    a.order_count,
    f.expected_order_count,
    a.total_amount,
    f.expected_total_amount
from agg a
left join fact_seller f on a.seller_id = f.seller_id
where a.order_item_count != f.expected_order_item_count
   or a.order_count != f.expected_order_count
   or abs(coalesce(a.total_amount, 0) - coalesce(f.expected_total_amount, 0)) > 0.01
