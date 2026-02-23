-- Singular Test: Ensure report totals match source data
-- FAILS if counts don't match (returns rows if mismatch)

with report_total as (
    select sum(total_documents) as report_count
    from {{ ref('rpt_document_summary') }}
),

source_total as (
    select count(*) as source_count
    from {{ ref('int_sharepoint__documents') }}
)

select
    report_total.report_count,
    source_total.source_count,
    source_total.source_count - report_total.report_count as difference
from report_total, source_total
where report_total.report_count != source_total.source_count
