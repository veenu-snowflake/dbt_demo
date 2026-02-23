-- Singular Test: Ensure modified date is not before created date
-- FAILS if any rows are returned

select
    doc_id,
    file_name,
    created_on,
    modified_on
from {{ ref('int_sharepoint__documents') }}
where modified_on < created_on
