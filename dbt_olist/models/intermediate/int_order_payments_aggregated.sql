-- Intermediate: payment metrics at order grain
with payments as (
    select * from {{ ref('stg_payments') }}
)

select
    order_id,
    count(*) as payment_count,
    sum(payment_value) as payment_value_total,
    max(payment_installments) as max_payment_installments,
    string_agg(distinct payment_type, ', ' order by payment_type) as payment_types,
    sum(case when payment_type = 'credit_card' then payment_value else 0 end) as credit_card_value,
    sum(case when payment_type = 'boleto' then payment_value else 0 end) as boleto_value,
    sum(case when payment_type = 'voucher' then payment_value else 0 end) as voucher_value,
    sum(case when payment_type = 'debit_card' then payment_value else 0 end) as debit_card_value
from payments
group by order_id
