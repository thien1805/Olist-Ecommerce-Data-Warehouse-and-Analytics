-- Kiểm tra order_items không có order_id orphan (không tồn tại trong orders)
select oi.*
from {{ ref('stg_order_items') }} oi
left join {{ ref('stg_orders') }} o on oi.order_id = o.order_id
where o.order_id is null
