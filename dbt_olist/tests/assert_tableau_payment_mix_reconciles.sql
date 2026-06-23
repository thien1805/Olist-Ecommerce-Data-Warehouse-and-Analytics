with payment_mix_totals as (
    select
        round(sum(payment_value)::numeric, 2) as payment_mix_value
    from {{ ref('mart_tableau_payment_mix') }}
),

fact_totals as (
    select
        round(sum(payment_value_total)::numeric, 2) as fact_payment_value
    from {{ ref('fact_orders') }}
)

select
    payment_mix_value,
    fact_payment_value
from payment_mix_totals
cross join fact_totals
where abs(payment_mix_value - fact_payment_value) > 0.01
