-- FreshCart Snowflake setup: warehouse, schemas, governance objects, and PII role.
-- Standard Edition — no native masking/tagging assumptions beyond a plain object tag.

-- 1. Warehouse, cost-isolated
CREATE WAREHOUSE IF NOT EXISTS freshcart_wh
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

-- 2. Database + schemas
CREATE DATABASE IF NOT EXISTS freshcart_db;
USE DATABASE freshcart_db;
CREATE SCHEMA IF NOT EXISTS stage_sch;
CREATE SCHEMA IF NOT EXISTS clean_sch;
CREATE SCHEMA IF NOT EXISTS consumption_sch;
CREATE SCHEMA IF NOT EXISTS common;

USE WAREHOUSE freshcart_wh;
USE SCHEMA common;

-- 3. File format for CSV ingestion
CREATE FILE FORMAT IF NOT EXISTS common.csv_ff
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('', 'NULL');

-- 4. Internal stage (where you'll upload CSVs from Snowsight later)
CREATE STAGE IF NOT EXISTS stage_sch.csv_stg
  DIRECTORY = (ENABLE = TRUE);

-- 5. Governance object — tag only. NO secure view here.
--    Secure views get created in Phase 4, once consumption_sch tables exist.
CREATE TAG IF NOT EXISTS common.pii_tag
  ALLOWED_VALUES 'PII','EMAIL','PHONE'
  COMMENT = 'Classifies sensitive columns for masking (applied downstream via secure views)';

-- 6. Pipeline health log — empty for now, don't skip creating it
CREATE TABLE IF NOT EXISTS common.dq_log (
  run_id            NUMBER AUTOINCREMENT PRIMARY KEY,
  layer_transition  STRING,       -- e.g. 'stage_to_clean'
  table_name        STRING,
  rows_in           NUMBER,
  rows_out          NUMBER,
  null_check_status STRING,
  fk_check_status   STRING,
  overall_status    STRING,       -- PASS / FAIL
  run_ts            TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 7. A role for who's allowed to see unmasked PII (used by Phase 4 secure views)
USE ROLE SECURITYADMIN;
CREATE ROLE IF NOT EXISTS PII_VIEWER;
GRANT USAGE ON DATABASE freshcart_db TO ROLE PII_VIEWER;
GRANT USAGE ON WAREHOUSE freshcart_wh TO ROLE PII_VIEWER;
USE ROLE SYSADMIN;
USE DATABASE freshcart_db;
USE SCHEMA common;

-- 8. Verification — run these and read the actual result rows
SHOW SCHEMAS IN DATABASE freshcart_db;
SHOW TAGS IN SCHEMA common;
SELECT * FROM freshcart_db.common.dq_log;
