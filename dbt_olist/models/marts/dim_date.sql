-- Marts: dim_date — date dimension generated entirely in SQL
{{ config(materialized='table') }}

with date_spine as (
    select generate_series(
        '2016-01-01'::date,
        '2026-12-31'::date,
        '1 day'::interval
    )::date as date_key
)

select
    date_key,
    extract(day from date_key)::int as day,
    extract(month from date_key)::int as month,
    extract(year from date_key)::int as year,
    extract(quarter from date_key)::int as quarter,
    extract(dow from date_key)::int as day_of_week,
    trim(to_char(date_key, 'Day')) as day_name,
    trim(to_char(date_key, 'Month')) as month_name,
    case when extract(dow from date_key) in (0, 6) then true else false end as is_weekend
from date_spine
