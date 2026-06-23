-- Metrics mart: Tableau-friendly payment mix at payment transaction grain.
-- Grain: one row per order payment sequence.
{{ config(materialized='table') }}

with payments as (
    select * from {{ ref('dim_payments') }}
),

orders as (
    select * from {{ ref('fact_orders') }}
),

customers as (
    select * from {{ ref('dim_customers') }}
),

dates as (
    select * from {{ ref('dim_date') }}
)

select
    p.payment_key,
    p.order_id,
    p.payment_sequential,
    p.payment_type,
    case
        when p.payment_type = 'credit_card' then 'Credit Card'
        when p.payment_type = 'boleto' then 'Boleto'
        when p.payment_type = 'voucher' then 'Voucher'
        when p.payment_type = 'debit_card' then 'Debit Card'
        when p.payment_type = 'not_defined' then 'Not Defined'
        else initcap(replace(coalesce(p.payment_type, 'unknown'), '_', ' '))
    end as payment_type_label,
    p.payment_installments,
    case
        when p.payment_installments <= 1 then '1 installment'
        when p.payment_installments between 2 and 3 then '2-3 installments'
        when p.payment_installments between 4 and 6 then '4-6 installments'
        when p.payment_installments between 7 and 12 then '7-12 installments'
        else '13+ installments'
    end as installment_bucket,
    p.payment_value,

    o.customer_key,
    o.geolocation_key,
    o.order_date_key,
    date_trunc('month', o.order_date_key)::date as month_start_date,
    d.year as order_year,
    d.quarter as order_quarter,
    d.month as order_month,
    d.month_name as order_month_name,
    d.day_of_week as order_day_of_week,
    d.day_name as order_day_name,
    d.is_weekend,

    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    c.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    c.customer_zip_code_prefix,

    o.order_items_total,
    o.payment_value_total,
    case
        when coalesce(o.payment_value_total, 0) > 0
            then p.payment_value / o.payment_value_total
        else null
    end as payment_share_of_order,
    o.avg_review_score,
    o.delivery_time_days,
    o.is_delivered_on_time
from payments p
left join orders o on p.order_id = o.order_id
left join customers c on o.customer_key = c.customer_key
left join dates d on o.order_date_key = d.date_key
