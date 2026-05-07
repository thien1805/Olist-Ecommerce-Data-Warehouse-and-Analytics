-- Marts: dim_products — final dimension table
{{ config(materialized='table') }}

select
    row_number() over (order by product_id) as product_key,
    product_id,
    product_category_name,
    product_category_name_english,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    current_date as last_updated
from {{ ref('int_products_joined') }}
