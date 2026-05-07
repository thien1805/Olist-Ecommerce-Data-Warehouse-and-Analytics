-- Marts: dim_payments — final dimension table
{{ config(materialized='table') }}

select
    row_number() over (order by order_id, payment_sequential) as payment_key,
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
from {{ ref('stg_payments') }}
