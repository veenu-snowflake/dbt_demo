with documents as (
    select * from {{ ref('int_sharepoint__documents') }}
),

aggregated as (
    select
        document_type,
        count(*) as total_documents,
        sum(file_size) as total_size_bytes,
        round(sum(file_size_kb), 2) as total_size_kb,
        round(sum(file_size_mb), 2) as total_size_mb,
        round(avg(file_size_kb), 2) as avg_size_kb,
        min(file_size_kb) as smallest_file_kb,
        max(file_size_kb) as largest_file_kb,
        min(created_on) as earliest_document,
        max(modified_on) as latest_modified,
        current_timestamp() as _aggregated_at
    
    from documents
    group by document_type
)

select * from aggregated
order by total_documents desc
