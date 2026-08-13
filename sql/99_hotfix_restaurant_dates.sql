-- FreshCart hotfix: repair clean_sch.restaurant rows with NULL created_dt/modified_dt.
-- Root cause: stage_sch.restaurant.created_date landed in Snowflake as 'DD-MM-YYYY HH24:MI'
-- while every other table's dates landed as 'YYYY-MM-DD HH24:MI:SS'. TRY_TO_TIMESTAMP_NTZ()
-- with no explicit format silently returned NULL for all 25 rows instead of erroring — caught
-- by the Phase 3 DQ gate, not by the pipeline itself. This is a one-time repair for data that
-- was already loaded before sql/02_clean_layer.sql and sql/05_task_orchestration.sql were
-- corrected with an explicit format string. Re-running the corrected files handles this
-- correctly going forward; this script only fixes what's already sitting in the table.

USE ROLE SYSADMIN;
USE DATABASE freshcart_db;
USE WAREHOUSE freshcart_wh;

UPDATE clean_sch.restaurant target
SET created_dt = TRY_TO_TIMESTAMP_NTZ(s.created_date, 'DD-MM-YYYY HH24:MI'),
    modified_dt = TRY_TO_TIMESTAMP_NTZ(s.modified_date, 'DD-MM-YYYY HH24:MI')
FROM stage_sch.restaurant s
WHERE target.restaurant_id = TRY_CAST(s.restaurant_id AS NUMBER);

-- Verify the repair
SELECT COUNT(*) AS remaining_null_dates FROM clean_sch.restaurant WHERE created_dt IS NULL;  -- expect 0

-- Re-run the DQ check for this one table and confirm it now passes
CALL common.sp_dq_checks();
SELECT * FROM common.dq_log WHERE table_name = 'restaurant' ORDER BY run_id DESC LIMIT 1;  -- expect PASS

-- Confirm the delivery-performance view fix too, while you're verifying
SELECT * FROM consumption_sch.vw_delivery_performance ORDER BY delivered_rate_pct DESC LIMIT 5;  -- expect max <= 100.0