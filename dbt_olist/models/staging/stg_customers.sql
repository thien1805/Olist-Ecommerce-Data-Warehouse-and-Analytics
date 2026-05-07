-- Staging: Customers — light cleaning only
with source as (
    select * from {{ source('staging', 'stg_customers') }}
)

select
    customer_id,
    customer_unique_id::text as customer_unique_id,
    lpad(customer_zip_code_prefix::text, 5, '0') as customer_zip_code_prefix,
    initcap(trim(customer_city)) as customer_city,
    upper(trim(customer_state)) as customer_state
from source
