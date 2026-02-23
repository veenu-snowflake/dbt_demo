# OpenFlow Analytics - dbt Project

A dbt project for transforming data loaded by OpenFlow into Snowflake.

## Project Structure

```
openflow_analytics/
├── dbt_project.yml              # Project configuration
├── profiles.yml.template        # Connection template (copy to profiles.yml)
│
├── models/
│   ├── sources.yml              # Source definitions
│   ├── generic_tests.yml        # Generic tests (not_null, unique, etc.)
│   │
│   ├── raw/                     # Raw layer (views)
│   │   ├── raw_postgres__country.sql
│   │   ├── raw_postgres__customer_loyalty.sql
│   │   └── raw_sharepoint__documents.sql
│   │
│   ├── int/                     # Intermediate layer (views)
│   │   └── int_sharepoint__documents.sql
│   │
│   └── reporting/               # Reporting layer (tables)
│       └── rpt_document_summary.sql
│
└── tests/                       # Singular tests (custom SQL)
    ├── assert_positive_file_sizes.sql
    ├── assert_no_future_dates.sql
    ├── assert_modified_after_created.sql
    └── assert_report_totals_match.sql
```

## Data Lineage

```
PostgreSQL ──► raw_postgres__country ──────────────────────► (standalone)
PostgreSQL ──► raw_postgres__customer_loyalty ─────────────► (standalone)
SharePoint ──► raw_sharepoint__documents ──► int_sharepoint__documents ──► rpt_document_summary
```

## Setup

1. Copy the template profile:
   ```bash
   cp profiles.yml.template profiles.yml
   ```

2. Set environment variables:
   ```bash
   export SNOWFLAKE_ACCOUNT="your-account"
   export SNOWFLAKE_USER="your-user"
   export SNOWFLAKE_PASSWORD="your-password"
   ```

3. Deploy and run:
   ```bash
   # Deploy
   snow dbt deploy openflow_analytics --source . --database POSTGRES_REPLICA --schema DBT_PROJECTS --connection your-connection --force

   # Run models
   snow dbt execute --connection your-connection --database POSTGRES_REPLICA --schema DBT_PROJECTS openflow_analytics run

   # Run tests
   snow dbt execute --connection your-connection --database POSTGRES_REPLICA --schema DBT_PROJECTS openflow_analytics test
   ```

## CI/CD

This project uses GitHub Actions for CI/CD. The pipeline:

| Trigger | Action |
|---------|--------|
| Push to `develop` | Lint + Compile |
| PR to `main` | Lint + Compile + Run + Test |
| Push to `main` | Deploy to Production (with approval) |

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `SNOWFLAKE_ACCOUNT` | Snowflake account identifier |
| `SNOWFLAKE_USER` | Snowflake username |
| `SNOWFLAKE_PASSWORD` | Snowflake password |
| `SNOWFLAKE_ROLE` | Snowflake role (e.g., ACCOUNTADMIN) |
| `SNOWFLAKE_WAREHOUSE` | Snowflake warehouse name |

## Tests

| Type | Count | Location |
|------|-------|----------|
| Generic Tests | 15 | `models/generic_tests.yml` |
| Singular Tests | 4 | `tests/*.sql` |

Run all tests:
```bash
snow dbt execute --connection your-connection --database POSTGRES_REPLICA --schema DBT_PROJECTS openflow_analytics test
```

## Version
v1.0.0
# Trigger rebuild
