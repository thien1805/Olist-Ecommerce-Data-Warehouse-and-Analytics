-- Staging: Products — fill nulls
with source as (
    select * from {{ source('staging', 'stg_products') }}
)

select
    product_id,
    product_category_name,
    product_name_length,
    product_description_length,
    product_photos_qty,
    coalesce(product_weight_g, 0)::numeric as product_weight_g,
    coalesce(product_length_cm, 0)::numeric as product_length_cm,
    coalesce(product_height_cm, 0)::numeric as product_height_cm,
    coalesce(product_width_cm, 0)::numeric as product_width_cm
from source
