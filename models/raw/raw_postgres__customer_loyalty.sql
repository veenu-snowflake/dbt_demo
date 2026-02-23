with source as (
    select * from {{ source('postgres_replica', 'customer_loyalty') }}
)

select * from source
