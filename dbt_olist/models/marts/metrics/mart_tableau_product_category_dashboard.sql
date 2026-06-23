-- Metrics mart: Tableau-friendly product category dashboard at order item grain.
-- Grain: one row per order item with product, seller, customer, delivery, and review context.
{{ config(materialized='table') }}

with sales as (
    select * from {{ ref('mart_tableau_sales_dashboard') }}
)

select
    order_id,
    order_item_id,
    customer_key,
    product_key,
    seller_key,
    order_date_key,
    month_start_date,
    order_year,
    order_quarter,
    order_month,
    order_month_name,
    order_day_of_week,
    order_day_name,
    is_weekend,

    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    shipping_limit_date,

    product_category_name_english,
    product_category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    product_length_cm * product_height_cm * product_width_cm as product_volume_cm3,
    case
        when product_weight_g is null then 'Unknown'
        when product_weight_g < 500 then 'Light: < 500g'
        when product_weight_g < 2000 then 'Medium: 500g-2kg'
        when product_weight_g < 10000 then 'Heavy: 2kg-10kg'
        else 'Bulky: 10kg+'
    end as product_weight_bucket,

    seller_id,
    seller_city,
    seller_state,
    seller_zip_code_prefix,
    seller_city || ', ' || seller_state as seller_location,

    customer_id,
    customer_unique_id,
    customer_city,
    customer_state,
    customer_zip_code_prefix,
    customer_city || ', ' || customer_state as customer_location,

    item_price,
    freight_value,
    item_total_amount,
    gmv,
    allocated_payment_value,
    order_weight,
    order_item_count,
    distinct_product_count,
    distinct_seller_count,

    avg_review_score,
    min_review_score,
    max_review_score,
    delivery_time_days,
    estimated_delivery_time_days,
    is_delivered_on_time,
    is_delivered_on_time_int,
    is_delivered_order_int,
    is_canceled_order_int,
    case
        when is_delivered_on_time_int = 1 then 'On time'
        when is_delivered_on_time_int = 0 then 'Late'
        else 'Not delivered / unknown'
    end as delivery_status
from sales
where order_item_id <> 0
