-- Metrics mart: one Tableau-friendly data source for synchronized dashboard filters.
-- Grain: one row per order item.
{{ config(materialized='table') }}

with order_items as (
    select * from {{ ref('fact_order_items') }}
),

orders as (
    select * from {{ ref('fact_orders') }}
),

customers as (
    select * from {{ ref('dim_customers') }}
),

products as (
    select * from {{ ref('dim_products') }}
),

sellers as (
    select * from {{ ref('dim_sellers') }}
),

dates as (
    select * from {{ ref('dim_date') }}
),

dashboard_rows as (
    select
        oi.order_id,
        oi.order_item_id,
        oi.customer_key,
        oi.product_key,
        oi.seller_key,
        oi.order_date_key,
        oi.shipping_limit_date,
        oi.price as item_price,
        oi.freight_value,
        oi.item_total_amount,
        oi.item_total_amount as gmv,
        case
            when coalesce(o.order_items_total, 0) > 0
                then oi.item_total_amount / o.order_items_total * coalesce(o.payment_value_total, 0)
            when coalesce(o.order_item_count, 0) > 0
                then coalesce(o.payment_value_total, 0) / o.order_item_count
            else 0
        end as allocated_payment_value,
        case
            when coalesce(o.order_item_count, 0) > 0 then 1.0 / o.order_item_count
            else null
        end as order_weight
    from order_items oi
    left join orders o on oi.order_id = o.order_id

    union all

    select
        o.order_id,
        0 as order_item_id,
        o.customer_key,
        null as product_key,
        null as seller_key,
        o.order_date_key,
        null as shipping_limit_date,
        0::numeric as item_price,
        0::numeric as freight_value,
        coalesce(o.order_items_total, 0) as item_total_amount,
        coalesce(o.order_items_total, 0) as gmv,
        coalesce(o.payment_value_total, 0) as allocated_payment_value,
        1.0 as order_weight
    from orders o
    where not exists (
        select 1
        from order_items oi
        where oi.order_id = o.order_id
    )
)

select
    dr.order_id,
    dr.order_item_id,
    dr.customer_key,
    dr.product_key,
    dr.seller_key,
    o.geolocation_key,
    dr.order_date_key,
    date_trunc('month', dr.order_date_key)::date as month_start_date,
    d.year as order_year,
    d.quarter as order_quarter,
    d.month as order_month,
    d.month_name as order_month_name,
    d.day_of_week as order_day_of_week,
    d.day_name as order_day_name,
    d.is_weekend,

    o.order_status,
    dr.shipping_limit_date,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    c.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    c.customer_zip_code_prefix,

    coalesce(p.product_category_name_english, 'Unknown') as product_category_name_english,
    coalesce(p.product_category_name, 'unknown') as product_category_name,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,

    coalesce(s.seller_id, 'Unknown') as seller_id,
    coalesce(s.seller_city, 'Unknown') as seller_city,
    coalesce(s.seller_state, 'Unknown') as seller_state,
    s.seller_zip_code_prefix,

    dr.item_price,
    dr.freight_value,
    dr.item_total_amount,
    dr.gmv,
    dr.allocated_payment_value,
    dr.order_weight,

    o.order_item_count,
    o.distinct_product_count,
    o.distinct_seller_count,
    o.payment_count,
    o.max_payment_installments,
    o.payment_types,
    o.credit_card_value,
    o.boleto_value,
    o.voucher_value,
    o.debit_card_value,

    o.review_count,
    o.avg_review_score,
    o.min_review_score,
    o.max_review_score,
    o.delivery_time_days,
    o.estimated_delivery_time_days,
    o.is_delivered_on_time,
    case
        when o.is_delivered_on_time is true then 1
        when o.is_delivered_on_time is false then 0
        else null
    end as is_delivered_on_time_int,
    case when o.order_status = 'delivered' then 1 else 0 end as is_delivered_order_int,
    case when o.order_status = 'canceled' then 1 else 0 end as is_canceled_order_int
from dashboard_rows dr
left join orders o on dr.order_id = o.order_id
left join customers c on dr.customer_key = c.customer_key
left join products p on dr.product_key = p.product_key
left join sellers s on dr.seller_key = s.seller_key
left join dates d on dr.order_date_key = d.date_key
