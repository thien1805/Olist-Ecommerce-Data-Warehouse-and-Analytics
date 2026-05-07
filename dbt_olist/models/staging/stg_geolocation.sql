-- Staging: Geolocation — deduplicate by zip code
with source as (
    select * from {{ source('staging', 'stg_geolocation') }}
),

deduplicated as (
    select distinct on (geolocation_zip_code_prefix)
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
    from source
    order by geolocation_zip_code_prefix
)

select
    lpad(geolocation_zip_code_prefix::text, 5, '0') as geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    initcap(trim(geolocation_city)) as geolocation_city,
    upper(trim(geolocation_state)) as geolocation_state
from deduplicated
