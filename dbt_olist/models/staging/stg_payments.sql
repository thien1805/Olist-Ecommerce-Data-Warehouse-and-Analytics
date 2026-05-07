-- Staging: Payments — light cleaning
with source as (
    select * from {{ source('staging', 'stg_payments') }}
)

select
    order_id,
    payment_sequential,
    lower(payment_type) as payment_type,
    coalesce(payment_installments, 1)::int as payment_installments,
    payment_value::numeric as payment_value
from source
