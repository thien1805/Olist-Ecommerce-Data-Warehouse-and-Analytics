-- Staging: Product Category Name Translation
with source as (
    select * from {{ source('staging', 'stg_product_category_name_translation') }}
)

select
    product_category_name,
    product_category_name_english
from source
