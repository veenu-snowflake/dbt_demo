with source as (
    select * from {{ source('postgres_replica', 'country') }}
)

select * from source
