with source as (
    select * from {{ ref('raw_sharepoint__documents') }}
),

cleaned as (
    select
        doc_id,
        file_id,
        file_name,
        file_mimetype,
        file_size,
        
        case 
            when file_mimetype = 'application/pdf' then 'PDF'
            when file_mimetype like '%wordprocessing%' then 'Word Document'
            when file_mimetype like '%spreadsheet%' then 'Excel'
            when file_mimetype like '%presentation%' then 'PowerPoint'
            else 'Other'
        end as document_type,
        
        round(file_size / 1024, 2) as file_size_kb,
        round(file_size / 1024 / 1024, 2) as file_size_mb,
        source as data_source,
        created_on,
        modified_on,
        current_timestamp() as _loaded_at
    
    from source
)

select * from cleaned
