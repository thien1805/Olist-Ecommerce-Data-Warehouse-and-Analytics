-- Marts: dim_sellers — final dimension table
{{ config(materialized='table') }}

select
    row_number() over (order by seller_id) as seller_key,
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state,
    current_date as last_updated
from {{ ref('stg_sellers') }}
