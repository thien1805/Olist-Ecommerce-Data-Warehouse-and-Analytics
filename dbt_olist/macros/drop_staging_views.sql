-- Macro: Drop all views in staging_dbt schema
-- Được gọi trước extract để xóa dependency của views lên raw tables

{% macro drop_staging_views() %}
    {% set sql %}
        DROP SCHEMA IF EXISTS staging_dbt CASCADE;
        CREATE SCHEMA IF NOT EXISTS staging_dbt;
    {% endset %}
    {% do run_query(sql) %}
    {{ log("Dropped and recreated staging_dbt schema", info=True) }}
{% endmacro %}
