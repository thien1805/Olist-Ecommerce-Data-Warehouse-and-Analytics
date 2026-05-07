-- Marts: dim_geolocation — final dimension table
{{ config(materialized='table') }}

select
    row_number() over (order by geolocation_zip_code_prefix) as geolocation_key,
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
from {{ ref('stg_geolocation') }}
