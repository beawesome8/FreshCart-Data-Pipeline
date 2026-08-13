-- FreshCart Phase 6: Reporting views for the Streamlit dashboard
-- FIXED vs. original: vw_delivery_performance had a fan-out bug (COUNT(DISTINCT order_id) vs
-- SUM(1) at fact-row grain produced delivered rates >100%). Now COUNT(DISTINCT ...) on both sides.

USE ROLE SYSADMIN;
USE DATABASE freshcart_db;
USE WAREHOUSE freshcart_wh;
USE SCHEMA consumption_sch;

-- Monthly revenue trend
CREATE OR REPLACE VIEW consumption_sch.vw_monthly_revenue AS
SELECT d.year, d.month, SUM(f.subtotal) AS total_revenue,
       COUNT(DISTINCT f.order_id) AS total_orders,
       ROUND(SUM(f.subtotal) / NULLIF(COUNT(DISTINCT f.order_id),0), 2) AS avg_order_value
FROM consumption_sch.order_item_fact f
JOIN consumption_sch.date_dim d ON f.date_dim_sk = d.date_dim_sk
GROUP BY d.year, d.month
ORDER BY d.year, d.month;

-- Revenue by cuisine
CREATE OR REPLACE VIEW consumption_sch.vw_revenue_by_cuisine AS
SELECT r.cuisine_type, SUM(f.subtotal) AS total_revenue, COUNT(DISTINCT f.order_id) AS total_orders
FROM consumption_sch.order_item_fact f
JOIN consumption_sch.restaurant_dim r ON f.restaurant_dim_sk = r.restaurant_dim_sk AND r.is_current = TRUE
GROUP BY r.cuisine_type
ORDER BY total_revenue DESC;

-- Delivery performance by agent — FIXED: COUNT(DISTINCT order_id) on both numerator and
-- denominator, since order_item_fact is at order-item grain and delivery is at order grain.
-- The old SUM(CASE WHEN...) version double/triple-counted orders with multiple line items.
CREATE OR REPLACE VIEW consumption_sch.vw_delivery_performance AS
SELECT
    da.name AS agent_name,
    da.vehicle_type,
    COUNT(DISTINCT f.order_id) AS total_deliveries,
    COUNT(DISTINCT CASE WHEN f.delivery_status = 'Delivered' THEN f.order_id END) AS delivered_count,
    COUNT(DISTINCT CASE WHEN f.delivery_status = 'Cancelled' THEN f.order_id END) AS cancelled_count,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN f.delivery_status = 'Delivered' THEN f.order_id END)
          / NULLIF(COUNT(DISTINCT f.order_id),0), 1) AS delivered_rate_pct,
    da.rating
FROM consumption_sch.order_item_fact f
JOIN consumption_sch.delivery_agent_dim da ON f.delivery_agent_dim_sk = da.delivery_agent_dim_sk AND da.is_current = TRUE
GROUP BY da.name, da.vehicle_type, da.rating
ORDER BY total_deliveries DESC;

-- Pipeline health — latest DQ status per table
CREATE OR REPLACE VIEW common.vw_latest_dq_status AS
SELECT table_name, rows_in, rows_out, null_check_status, fk_check_status, overall_status, run_ts
FROM common.dq_log
QUALIFY ROW_NUMBER() OVER (PARTITION BY table_name ORDER BY run_id DESC) = 1
ORDER BY table_name;

-- Warehouse cost — empty until ACCOUNT_USAGE catches up (~45min-3hr latency)
CREATE OR REPLACE VIEW common.vw_warehouse_cost AS
SELECT
    DATE_TRUNC('day', start_time) AS usage_date,
    warehouse_name,
    SUM(credits_used) AS credits_used
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE warehouse_name = 'FRESHCART_WH'
GROUP BY 1, 2
ORDER BY 1 DESC;

-- ============================================================
-- Verify
-- ============================================================
SELECT * FROM consumption_sch.vw_monthly_revenue;
SELECT * FROM consumption_sch.vw_delivery_performance ORDER BY delivered_rate_pct DESC;
SELECT * FROM common.vw_latest_dq_status;-- CI/CD trigger test
-- retest after chmod fix
-- retest after connection flag fix
