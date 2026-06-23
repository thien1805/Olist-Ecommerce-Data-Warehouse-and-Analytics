-- Every order item fact row should resolve to customer, product, and seller dimensions.
select *
from {{ ref('fact_order_items') }}
where customer_key is null
   or product_key is null
   or seller_key is null
