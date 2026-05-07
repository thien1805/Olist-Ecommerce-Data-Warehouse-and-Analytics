-- Intermediate: Products enriched with category translation
with products as (
    select * from {{ ref('stg_products') }}
),

categories as (
    select * from {{ ref('stg_category_translation') }}
)

select
    p.product_id,
    p.product_category_name,
    coalesce(c.product_category_name_english, 'Unknown') as product_category_name_english,
    p.product_name_length,
    p.product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
from products p
left join categories c on p.product_category_name = c.product_category_name
