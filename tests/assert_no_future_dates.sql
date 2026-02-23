-- Singular Test: Ensure no documents have future creation dates
-- FAILS if any rows are returned

select
    doc_id,
    file_name,
    created_on
from {{ ref('int_sharepoint__documents') }}
where created_on > current_timestamp()
