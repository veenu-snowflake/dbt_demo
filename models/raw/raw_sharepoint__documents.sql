with source as (
    select * from {{ source('sharepoint_replica', 'doc_metadata') }}
)

select * from source
