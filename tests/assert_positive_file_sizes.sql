-- Singular Test: Ensure all file sizes are positive
-- FAILS if any rows are returned (i.e., negative file sizes exist)

select
    doc_id,
    file_name,
    file_size
from {{ ref('int_sharepoint__documents') }}
where file_size < 0
