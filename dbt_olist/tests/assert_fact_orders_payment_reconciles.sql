-- fact_orders.payment_value_total must equal summed staging payment value at order grain.
with payments as (
    select
        order_id,
        sum(payment_value) as expected_payment_value
    from {{ ref('stg_payments') }}
    group by order_id
),

fact as (
    select
        order_id,
        payment_value_total
    from {{ ref('fact_orders') }}
)

select
    f.order_id,
    f.payment_value_total,
    p.expected_payment_value
from fact f
left join payments p on f.order_id = p.order_id
where abs(coalesce(f.payment_value_total, 0) - coalesce(p.expected_payment_value, 0)) > 0.01
