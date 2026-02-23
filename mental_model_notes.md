# dbt Mental Model Notes

A comprehensive guide to understanding dbt (data build tool) on Snowflake.

---

## Table of Contents
1. [What is dbt?](#1-what-is-dbt)
2. [Project Structure](#2-project-structure)
3. [What Can/Cannot Be Changed](#3-what-cancannot-be-changed)
4. [Core Concepts](#4-core-concepts)
5. [How ref() and source() Work](#5-how-ref-and-source-work)
6. [Schema Naming Convention](#6-schema-naming-convention)
7. [Tests](#7-tests)
8. [Profiles and Environments](#8-profiles-and-environments)
9. [CI/CD Pipeline](#9-cicd-pipeline)
10. [Common Errors & Fixes](#10-common-errors--fixes)

---

## 1. What is dbt?

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           WHERE DBT FITS                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Raw Data Sources          Transform (dbt)              Analytics          │
│   ════════════════          ═══════════════              ═════════          │
│                                                                              │
│   ┌──────────┐             ┌──────────────┐            ┌──────────┐         │
│   │PostgreSQL│────────────►│              │───────────►│Dashboards│         │
│   └──────────┘             │              │            └──────────┘         │
│                            │   Snowflake  │                                  │
│   ┌──────────┐             │   Warehouse  │            ┌──────────┐         │
│   │SharePoint│────────────►│              │───────────►│  Reports │         │
│   └──────────┘             │  (dbt runs   │            └──────────┘         │
│                            │   HERE)      │                                  │
│   ┌──────────┐             │              │            ┌──────────┐         │
│   │   APIs   │────────────►│              │───────────►│    ML    │         │
│   └──────────┘             └──────────────┘            └──────────┘         │
│                                                                              │
│         ELT                      T                          L               │
│     (OpenFlow)              (Transform)                 (Analytics)         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Points
- dbt = **SQL-based transformation tool**
- Runs **inside** the data warehouse (Snowflake)
- Uses **Jinja templating** for dynamic SQL
- **One file = One model = One table/view**

### dbt vs Other Tools

| Tool | Where it runs | Language | Use Case |
|------|---------------|----------|----------|
| **dbt** | Inside warehouse | SQL + Jinja | Transformations |
| **Kedro** | Outside warehouse | Python | ML pipelines |
| **OpenFlow** | Outside warehouse | NiFi | Data ingestion |

---

## 2. Project Structure

```
dbt_demo/
│
├── dbt_project.yml          # Project configuration (FIXED name)
├── profiles.yml             # Connection credentials (FIXED name, DON'T commit!)
├── profiles.yml.template    # Template for credentials (safe to commit)
│
├── models/                  # SQL transformations (folder name CONFIGURABLE)
│   ├── sources.yml          # Define raw data sources (name FLEXIBLE)
│   ├── generic_tests.yml    # Define tests (name FLEXIBLE, was schema.yml)
│   │
│   ├── raw/                 # Raw layer (folder name FLEXIBLE)
│   │   ├── raw_postgres__country.sql
│   │   ├── raw_postgres__customer_loyalty.sql
│   │   └── raw_sharepoint__documents.sql
│   │
│   ├── int/                 # Intermediate layer (folder name FLEXIBLE)
│   │   └── int_sharepoint__documents.sql
│   │
│   └── reporting/           # Reporting layer (folder name FLEXIBLE)
│       └── rpt_document_summary.sql
│
├── tests/                   # Custom SQL tests (folder name CONFIGURABLE)
│   ├── assert_positive_file_sizes.sql
│   ├── assert_no_future_dates.sql
│   ├── assert_modified_after_created.sql
│   └── assert_report_totals_match.sql
│
├── macros/                  # Reusable SQL snippets (folder name CONFIGURABLE)
├── seeds/                   # CSV files to load (folder name CONFIGURABLE)
│
└── .github/workflows/       # CI/CD pipeline
    └── dbt_cicd.yml
```

---

## 3. What Can/Cannot Be Changed

### FIXED (Cannot Change)

| Item | Why Fixed |
|------|-----------|
| `dbt_project.yml` | dbt looks for this exact filename |
| `profiles.yml` | dbt looks for this exact filename |
| Config keys in YAML | `name:`, `version:`, `profile:`, `model-paths:` etc. |
| Jinja syntax | `{{ }}`, `{% %}`, `ref()`, `source()` |

### FLEXIBLE (Can Change)

| Item | Example |
|------|---------|
| Folder names inside models/ | `raw/`, `staging/`, `marts/`, `gold/` |
| YAML filenames (except dbt_project.yml) | `sources.yml`, `schema.yml`, `tests.yml`, `anything.yml` |
| Model filenames | `my_model.sql`, `stg_customers.sql` |
| Source names | `postgres_replica`, `my_source`, `raw_data` |

### HOW TO CHANGE FOLDER NAMES

```yaml
# dbt_project.yml

# Change folder paths here:
model-paths: ["models"]      # Can change to ["sql_models"] or ["transformations"]
seed-paths: ["seeds"]        # Can change to ["csv_data"]
test-paths: ["tests"]        # Can change to ["validations"]
macro-paths: ["macros"]      # Can change to ["helpers"]

# Configure sub-folders:
models:
  openflow_analytics:        # Must match project name
    raw:                     # Folder name - can be anything
      +materialized: view
      +schema: raw
    staging:                 # Different folder name example
      +materialized: view
      +schema: staging
```

---

## 4. Core Concepts

### The Manifest (Internal Lookup Table)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              dbt MANIFEST                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   When you run `dbt compile` or `dbt run`:                                  │
│                                                                              │
│   1. dbt scans ALL .sql files in models/                                    │
│   2. Builds a manifest (lookup table):                                      │
│                                                                              │
│      ┌─────────────────────────────────────────────────────────────┐        │
│      │  Model Name                    │  Full Path                 │        │
│      ├───────────────────────────────────────────────────────────────        │
│      │  raw_postgres__country         │  DATABASE.SCHEMA_raw.TABLE │        │
│      │  int_sharepoint__documents     │  DATABASE.SCHEMA_int.TABLE │        │
│      │  rpt_document_summary          │  DATABASE.SCHEMA_rpt.TABLE │        │
│      └─────────────────────────────────────────────────────────────┘        │
│                                                                              │
│   3. When ref('model_name') is called, dbt looks up the full path           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Jinja Templating

```sql
-- {{ }} = Expression (outputs a value)
SELECT * FROM {{ ref('my_model') }}
-- Compiles to: SELECT * FROM DATABASE.SCHEMA.MY_MODEL

-- {% %} = Logic (no output)
{% if target.name == 'prod' %}
  -- production code
{% endif %}

-- {# #} = Comment (ignored)
{# This is a comment #}
```

---

## 5. How ref() and source() Work

### source() - For Raw External Tables

```sql
-- Syntax: source('source_name', 'table_name')
-- Two parameters: source name + table name

SELECT * FROM {{ source('postgres_replica', 'country') }}

-- Compiles to:
SELECT * FROM POSTGRES_REPLICA.TASTYBYTES.COUNTRY
--            └── database ──┘ └─ schema ─┘ └table┘
```

**Where is it defined?**
```yaml
# models/sources.yml
sources:
  - name: postgres_replica        # ← First parameter
    database: POSTGRES_REPLICA
    schema: TASTYBYTES
    tables:
      - name: country             # ← Second parameter
```

### ref() - For dbt Models

```sql
-- Syntax: ref('model_name')
-- One parameter: model filename (without .sql)

SELECT * FROM {{ ref('int_sharepoint__documents') }}

-- Compiles to:
SELECT * FROM POSTGRES_REPLICA.DBT_PROJECTS_int.INT_SHAREPOINT__DOCUMENTS
```

**How does ref() know the schema?**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ref() RESOLUTION                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ref('int_sharepoint__documents')                                          │
│          │                                                                   │
│          ▼                                                                   │
│   ┌──────────────────┐                                                       │
│   │ Search manifest  │                                                       │
│   │ for model name   │                                                       │
│   └────────┬─────────┘                                                       │
│            │                                                                 │
│            ▼                                                                 │
│   Found: models/int/int_sharepoint__documents.sql                           │
│            │                                                                 │
│            ▼                                                                 │
│   Check dbt_project.yml:                                                    │
│     models:                                                                  │
│       openflow_analytics:                                                    │
│         int:                     ← Folder name                              │
│           +schema: int           ← Schema suffix                            │
│            │                                                                 │
│            ▼                                                                 │
│   Final path: DATABASE.DBT_PROJECTS_int.INT_SHAREPOINT__DOCUMENTS           │
│                        └─ base ──┘└suf┘                                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### What if Multiple Tables Have Same Name?

```
models/
├── reporting/
│   ├── rpt_document_summary.sql      ← ref('rpt_document_summary')
│   └── rpt_customer_summary.sql      ← ref('rpt_customer_summary')
```

**ref() uses filename, not folder!** Each model must have a unique filename.

---

## 6. Schema Naming Convention

### Formula
```
Final Schema = profile_schema + "_" + folder_schema
```

### Example
```yaml
# profiles.yml
schema: DBT_PROJECTS          # Base schema

# dbt_project.yml
models:
  openflow_analytics:
    raw:
      +schema: raw            # Suffix
    int:
      +schema: int            # Suffix
    reporting:
      +schema: reporting      # Suffix
```

### Result
```
DBT_PROJECTS + "_" + raw       = DBT_PROJECTS_raw
DBT_PROJECTS + "_" + int       = DBT_PROJECTS_int
DBT_PROJECTS + "_" + reporting = DBT_PROJECTS_reporting
```

### Customizing Schema Names

Create a macro to override:
```sql
-- macros/generate_schema_name.sql
{% macro generate_schema_name(custom_schema_name, node) %}
    {% if custom_schema_name is none %}
        {{ target.schema }}
    {% else %}
        {{ custom_schema_name }}    {# Use exact name, no prefix #}
    {% endif %}
{% endmacro %}
```

---

## 7. Tests

### Two Types of Tests

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              TEST TYPES                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   GENERIC TESTS (YAML)                    SINGULAR TESTS (SQL)              │
│   ════════════════════                    ════════════════════              │
│                                                                              │
│   Location: models/*.yml                  Location: tests/*.sql             │
│                                                                              │
│   Built-in tests:                         Custom SQL logic:                 │
│   - not_null                              - Complex validations             │
│   - unique                                - Multi-table checks              │
│   - accepted_values                       - Business rules                  │
│   - relationships                                                           │
│                                                                              │
│   Example:                                Example:                          │
│   ┌────────────────────────┐              ┌────────────────────────┐        │
│   │ columns:               │              │ -- FAILS if returns    │        │
│   │   - name: doc_id       │              │ -- any rows            │        │
│   │     tests:             │              │ SELECT *               │        │
│   │       - unique         │              │ FROM {{ ref('x') }}    │        │
│   │       - not_null       │              │ WHERE amount < 0       │        │
│   └────────────────────────┘              └────────────────────────┘        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Generic Tests (models/generic_tests.yml)
```yaml
version: 2
models:
  - name: int_sharepoint__documents
    columns:
      - name: doc_id
        tests:
          - unique
          - not_null
      - name: document_type
        tests:
          - accepted_values:
              values: ['PDF', 'Word Document', 'Excel', 'PowerPoint', 'Other']
```

### Singular Tests (tests/*.sql)
```sql
-- tests/assert_positive_file_sizes.sql
-- Test FAILS if this query returns ANY rows

SELECT doc_id, file_name, file_size
FROM {{ ref('int_sharepoint__documents') }}
WHERE file_size < 0
```

---

## 8. Profiles and Environments

### Profile Structure (profiles.yml)

```yaml
snowflake:                    # Profile name (matches dbt_project.yml)
  target: dev                 # DEFAULT environment
  
  outputs:
    dev:                      # Development
      type: snowflake
      account: "xxx"
      schema: DBT_PROJECTS    # Base schema for dev
      
    qa:                       # QA/Testing
      type: snowflake
      account: "xxx"
      schema: DBT_PROJECTS_QA
      
    prod:                     # Production
      type: snowflake
      account: "xxx"
      schema: DBT_PROJECTS_PROD
```

### Selecting Environment

```bash
# Use default (target: dev)
dbt run

# Override to use QA
dbt run --target qa

# Override to use Production
dbt run --target prod
```

### Environment Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ENVIRONMENT FLOW                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   profiles.yml                                                               │
│        │                                                                     │
│        ▼                                                                     │
│   target: dev  ◄──── Default                                                │
│        │                                                                     │
│        │  --target qa                                                        │
│        │  --target prod                                                      │
│        ▼                                                                     │
│   ┌─────────┐      ┌─────────┐      ┌─────────┐                             │
│   │   DEV   │      │   QA    │      │  PROD   │                             │
│   │         │      │         │      │         │                             │
│   │DBT_PROJ │      │DBT_PROJ │      │DBT_PROJ │                             │
│   │ _raw    │      │ _QA_raw │      │_PROD_raw│                             │
│   │ _int    │      │ _QA_int │      │_PROD_int│                             │
│   │ _rpt    │      │ _QA_rpt │      │_PROD_rpt│                             │
│   └─────────┘      └─────────┘      └─────────┘                             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 9. CI/CD Pipeline

### Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CI/CD PIPELINE                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Push to GitHub                                                             │
│        │                                                                     │
│        ▼                                                                     │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                   │
│   │   LINT      │────►│   COMPILE   │────►│   DEPLOY    │                   │
│   │  (SQLFluff) │     │  & TEST     │     │   (Prod)    │                   │
│   └─────────────┘     └─────────────┘     └─────────────┘                   │
│         │                   │                   │                            │
│         ▼                   ▼                   ▼                            │
│   Check SQL            Deploy to CI        Deploy to Prod                   │
│   syntax               Run models          Run models                       │
│                        Run tests           Run tests                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### GitHub Secrets Required

| Secret | Description | Example |
|--------|-------------|---------|
| `SNOWFLAKE_ACCOUNT` | Account identifier | `SFSEAPAC-VYADAV_AWS_AU` |
| `SNOWFLAKE_USER` | Username | `VYADAV` |
| `SNOWFLAKE_PASSWORD` | Password | `********` |
| `SNOWFLAKE_ROLE` | Role | `ACCOUNTADMIN` |
| `SNOWFLAKE_WAREHOUSE` | Warehouse | `SNOWFLAKE_LEARNING_WH` |

### Authentication Options

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AUTHENTICATION METHODS                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   METHOD              │  USE CASE              │  SECRETS NEEDED            │
│   ════════════════════│════════════════════════│════════════════════════    │
│                       │                        │                            │
│   Username/Password   │  Simple setup          │  SNOWFLAKE_PASSWORD        │
│                       │  CI/CD pipelines       │                            │
│                       │                        │                            │
│   Key-Pair (JWT)      │  More secure           │  SNOWFLAKE_PRIVATE_KEY     │
│                       │  Production            │                            │
│                       │                        │                            │
│   External Browser    │  Local development     │  (interactive)             │
│                       │  SSO integration       │                            │
│                       │                        │                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Network Policy Issue

If you see: `IP is not allowed to access Snowflake`

```sql
-- Check current policy
SHOW PARAMETERS LIKE 'network_policy' IN ACCOUNT;

-- Add GitHub Actions IPs
ALTER NETWORK POLICY your_policy_name SET ALLOWED_IP_LIST = (
  'existing_ips',
  '4.148.0.0/16',    -- GitHub Actions
  '4.175.0.0/16',    -- GitHub Actions
  '20.102.0.0/16'    -- GitHub Actions
);

-- Get all GitHub IPs: https://api.github.com/meta
```

---

## 10. Common Errors & Fixes

### Error 1: Folder Mismatch
```
Configuration paths exist in your dbt_project.yml file which do not apply
```
**Fix:** Ensure folder names in `dbt_project.yml` match actual folders in `models/`

### Error 2: Source Not Found
```
Compilation Error: source 'postgres_replica' not found
```
**Fix:** Check `sources.yml` for typos, trailing spaces in names

### Error 3: Invalid Keys
```
Invalid config keys: 'macros', 'seeds'
```
**Fix:** Remove invalid sections from `dbt_project.yml`. Only use valid keys.

### Error 4: Schema Doesn't Exist
```
Schema 'DBT_PROJECTS_QA' does not exist
```
**Fix:** Either create the schema or change `target:` in `profiles.yml`

### Error 5: Wrong CTE Reference
```sql
-- WRONG: References CTE that doesn't have the transformations
SELECT * FROM source

-- CORRECT: Reference the transformed CTE
SELECT * FROM cleaned
```

### Error 6: Network Policy Block
```
IP/Token xxx.xxx.xxx.xxx is not allowed to access Snowflake
```
**Fix:** Add the IP to your Snowflake network policy

### Error 7: Authentication Failed
```
Could not connect to Snowflake backend after 2 attempt(s)
```
**Causes:**
- Wrong account format
- Wrong credentials
- Using password auth when account requires key-pair
- Config file permissions (need `chmod 0600`)

---

## Quick Reference

### Run Commands (Snowflake CLI)

```bash
# Deploy project to Snowflake
snow dbt deploy PROJECT_NAME --source ./path --database DB --schema SCHEMA --connection CONN --force

# Run all models
snow dbt execute --connection CONN --database DB --schema SCHEMA PROJECT_NAME run

# Run tests
snow dbt execute --connection CONN --database DB --schema SCHEMA PROJECT_NAME test

# Run specific model
snow dbt execute ... PROJECT_NAME run --select model_name

# Run model and all downstream
snow dbt execute ... PROJECT_NAME run --select model_name+
```

### Data Lineage

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DATA LINEAGE                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   SOURCES                RAW                 INT                REPORTING   │
│   (External)            (Views)             (Views)             (Tables)    │
│                                                                              │
│   PostgreSQL ──────► raw_postgres__country                                  │
│                                                                              │
│   PostgreSQL ──────► raw_postgres__customer_loyalty                         │
│                                                                              │
│   SharePoint ──────► raw_sharepoint__ ────► int_sharepoint__ ────► rpt_doc_ │
│                      documents              documents              summary  │
│                                                                              │
│        │                    │                    │                    │     │
│        │                    │                    │                    │     │
│    source()              source()             ref()               ref()     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Summary Checklist

- [ ] Understand dbt runs INSIDE the warehouse (Snowflake)
- [ ] One .sql file = One model = One table/view
- [ ] `source()` = external tables (2 params)
- [ ] `ref()` = dbt models (1 param)
- [ ] Schema = base_schema + "_" + folder_schema
- [ ] `dbt_project.yml` and `profiles.yml` are FIXED names
- [ ] Folder names and YAML filenames are FLEXIBLE
- [ ] Generic tests go in YAML files
- [ ] Singular tests go in SQL files (tests/ folder)
- [ ] CI/CD needs proper authentication and network policy
