-- Kiểm tra payment_value phải > 0
select *
from {{ ref('stg_payments') }}
where payment_value < 0
