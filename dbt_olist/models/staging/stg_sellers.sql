-- Staging: Sellers — light cleaning
with source as (
    select * from {{ source('staging', 'stg_sellers') }}
)

select
    seller_id,
    lpad(seller_zip_code_prefix::text, 5, '0') as seller_zip_code_prefix,
    initcap(trim(seller_city)) as seller_city,
    upper(trim(seller_state)) as seller_state
from source
