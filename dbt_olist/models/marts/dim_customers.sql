-- Marts: dim_customers — final dimension table
{{ config(materialized='table') }}

select
    row_number() over (order by customer_id) as customer_key,
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    current_date as effective_date,
    (current_date + interval '10 years')::date as end_date,
    true as is_current
from {{ ref('stg_customers') }}
