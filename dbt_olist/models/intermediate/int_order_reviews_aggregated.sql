-- Intermediate: review metrics at order grain
with reviews as (
    select * from {{ ref('stg_order_reviews') }}
)

select
    order_id,
    count(*) as review_count,
    avg(review_score)::numeric(10, 2) as avg_review_score,
    min(review_score) as min_review_score,
    max(review_score) as max_review_score,
    min(review_creation_date) as first_review_creation_date,
    max(review_answer_timestamp) as last_review_answer_timestamp
from reviews
group by order_id
