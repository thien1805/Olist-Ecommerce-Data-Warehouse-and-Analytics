-- Macro: Override dbt default schema generation
-- Mặc định dbt tạo schema = <default>_<custom>, ví dụ: warehouse_warehouse
-- Macro này trả về đúng tên custom schema khi được chỉ định

{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
