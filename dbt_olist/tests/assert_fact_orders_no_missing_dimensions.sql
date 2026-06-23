-- Every order fact row should resolve to customer and date dimensions.
select *
from {{ ref('fact_orders') }}
where customer_key is null
   or order_date_key is null
