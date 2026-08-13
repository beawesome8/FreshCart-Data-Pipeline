USE ROLE SYSADMIN;
USE DATABASE freshcart_db;
USE WAREHOUSE freshcart_wh;
USE SCHEMA common;

-- ============================================================
-- LOCATION (no FK)
-- ============================================================

INSERT INTO common.dq_log (layer_transition, table_name, rows_in, rows_out, null_check_status, fk_check_status, overall_status)
WITH row_counts AS (
    SELECT
        (SELECT COUNT(*) FROM stage_sch.location) AS rows_in,
        (SELECT COUNT(*) FROM clean_sch.location)  AS rows_out
),
null_check AS (
    -- location has no FK-in, and city/state are NOT NULL so a real failure would error the MERGE itself.
    -- Check the one nullable, typed field: zipcode — did any non-null stage value become null in clean?
    SELECT COUNT(*) AS bad_nulls
    FROM stage_sch.location s
    JOIN clean_sch.location c ON TRY_CAST(s.location_id AS NUMBER) = c.location_id
    WHERE s.zipcode IS NOT NULL AND c.zipcode IS NULL
)
SELECT
    'stage_to_clean',
    'location',
    rc.rows_in,
    rc.rows_out,
    CASE WHEN nc.bad_nulls = 0 THEN 'PASS' ELSE 'FAIL' END,
    'N/A',  -- location has no FK dependency to check
    CASE WHEN rc.rows_in = rc.rows_out AND nc.bad_nulls = 0 THEN 'PASS' ELSE 'FAIL' END
FROM row_counts rc, null_check nc;

SELECT * FROM common.dq_log ORDER BY run_id DESC LIMIT 1;

-- ============================================================
-- CUSTOMER (no FK)
-- ============================================================
INSERT INTO common.dq_log (layer_transition, table_name, rows_in, rows_out, null_check_status, fk_check_status, overall_status)
WITH row_counts AS (
    SELECT (SELECT COUNT(*) FROM stage_sch.customer) AS rows_in,
           (SELECT COUNT(*) FROM clean_sch.customer)  AS rows_out
),
null_check AS (
    SELECT COUNT(*) AS bad_nulls
    FROM stage_sch.customer s
    JOIN clean_sch.customer c ON TRY_CAST(s.customer_id AS NUMBER) = c.customer_id
    WHERE s.created_date IS NOT NULL AND c.created_dt IS NULL
)
SELECT 'stage_to_clean', 'customer', rc.rows_in, rc.rows_out,
       CASE WHEN nc.bad_nulls = 0 THEN 'PASS' ELSE 'FAIL' END,
       'N/A',
       CASE WHEN rc.rows_in = rc.rows_out AND nc.bad_nulls = 0 THEN 'PASS' ELSE 'FAIL' END
FROM row_counts rc, null_check nc;

-- ============================================================
-- RESTAURANT (FK -> location)
-- ============================================================
INSERT INTO common.dq_log (layer_transition, table_name, rows_in, rows_out, null_check_status, fk_check_status, overall_status)
WITH row_counts AS (
    SELECT (SELECT COUNT(*) FROM stage_sch.restaurant) AS rows_in,
           (SELECT COUNT(*) FROM clean_sch.restaurant)  AS rows_out
),
null_check AS (
    SELECT COUNT(*) AS bad_nulls
    FROM stage_sch.restaurant s
    JOIN clean_sch.restaurant c ON TRY_CAST(s.restaurant_id AS NUMBER) = c.restaurant_id
    WHERE s.created_date IS NOT NULL AND c.created_dt IS NULL
),
fk_check AS (
    SELECT COUNT(*) AS orphans
    FROM clean_sch.restaurant r
    LEFT JOIN clean_sch.location l ON r.location_id = l.location_id
    WHERE r.location_id IS NOT NULL AND l.location_id IS NULL
)
SELECT 'stage_to_clean', 'restaurant', rc.rows_in, rc.rows_out,
       CASE WHEN nc.bad_nulls = 0 THEN 'PASS' ELSE 'FAIL' END,
       CASE WHEN fk.orphans = 0 THEN 'PASS' ELSE 'FAIL' END,
       CASE WHEN rc.rows_in = rc.rows_out AND nc.bad_nulls = 0 AND fk.orphans = 0 THEN 'PASS' ELSE 'FAIL' END
FROM row_counts rc, null_check nc, fk_check fk;

-- ============================================================
-- MENU (FK -> restaurant)
-- ============================================================
INSERT INTO common.dq_log (layer_transition, table_name, rows_in, rows_out, null_check_status, fk_check_status, overall_status)
WITH row_counts AS (
    SELECT (SELECT COUNT(*) FROM stage_sch.menu) AS rows_in,
           (SELECT COUNT(*) FROM clean_sch.menu)  AS rows_out
),
null_check AS (
    SELECT COUNT(*) AS bad_nulls
    FROM stage_sch.menu s
    JOIN clean_sch.menu c ON TRY_CAST(s.menu_id AS NUMBER) = c.menu_id
    WHERE s.created_date IS NOT NULL AND c.created_dt IS NULL
),
fk_check AS (
    SELECT COUNT(*) AS orphans
    FROM clean_sch.menu m
    LEFT JOIN clean_sch.restaurant r ON m.restaurant_id = r.restaurant_id
    WHERE m.restaurant_id IS NOT NULL AND r.restaurant_id IS NULL
)
SELECT 'stage_to_clean', 'menu', rc.rows_in, rc.rows_out,
       CASE WHEN nc.bad_nulls = 0 THEN 'PASS' ELSE 'FAIL' END,
       CASE WHEN fk.orphans = 0 THEN 'PASS' ELSE 'FAIL' END,
       CASE WHEN rc.rows_in = rc.rows_out AND nc.bad_nulls = 0 AND fk.orphans = 0 THEN 'PASS' ELSE 'FAIL' END
FROM row_counts rc, null_check nc, fk_check fk;

-- ============================================================
-- DELIVERY_AGENT (FK -> location)
-- ============================================================
INSERT INTO common.dq_log (layer_transition, table_name, rows_in, rows_out, null_check_status, fk_check_status, overall_status)
WITH row_counts AS (
    SELECT (SELECT COUNT(*) FROM stage_sch.delivery_agent) AS rows_in,
           (SELECT COUNT(*) FROM clean_sch.delivery_agent)  AS rows_out
),
null_check AS (
    SELECT COUNT(*) AS bad_nulls
    FROM stage_sch.delivery_agent s
    JOIN clean_sch.delivery_agent c ON TRY_CAST(s.delivery_agent_id AS NUMBER) = c.delivery_agent_id
    WHERE s.created_date IS NOT NULL AND c.created_dt IS NULL
),
fk_check AS (
    SELECT COUNT(*) AS orphans
    FROM clean_sch.delivery_agent d
    LEFT JOIN clean_sch.location l ON d.location_id = l.location_id
    WHERE d.location_id IS NOT NULL AND l.location_id IS NULL
)
SELECT 'stage_to_clean', 'delivery_agent', rc.rows_in, rc.rows_out,
       CASE WHEN nc.bad_nulls = 0 THEN 'PASS' ELSE 'FAIL' END,
       CASE WHEN fk.orphans = 0 THEN 'PASS' ELSE 'FAIL' END,
       CASE WHEN rc.rows_in = rc.rows_out AND nc.bad_nulls = 0 AND fk.orphans = 0 THEN 'PASS' ELSE 'FAIL' END
FROM row_counts rc, null_check nc, fk_check fk;

-- ============================================================
-- CUSTOMER_ADDRESS (FK -> customer)
-- ============================================================
INSERT INTO common.dq_log (layer_transition, table_name, rows_in, rows_out, null_check_status, fk_check_status, overall_status)
WITH row_counts AS (
    SELECT (SELECT COUNT(*) FROM stage_sch.customer_address) AS rows_in,
           (SELECT COUNT(*) FROM clean_sch.customer_address)  AS rows_out
),
null_check AS (
    SELECT COUNT(*) AS bad_nulls
    FROM stage_sch.customer_address s
    JOIN clean_sch.customer_address c ON TRY_CAST(s.address_id AS NUMBER) = c.address_id
    WHERE s.created_date IS NOT NULL AND c.created_dt IS NULL
),
fk_check AS (
    SELECT COUNT(*) AS orphans
    FROM clean_sch.customer_address a
    LEFT JOIN clean_sch.customer cu ON a.customer_id = cu.customer_id
    WHERE a.customer_id IS NOT NULL AND cu.customer_id IS NULL
)
SELECT 'stage_to_clean', 'customer_address', rc.rows_in, rc.rows_out,
       CASE WHEN nc.bad_nulls = 0 THEN 'PASS' ELSE 'FAIL' END,
       CASE WHEN fk.orphans = 0 THEN 'PASS' ELSE 'FAIL' END,
       CASE WHEN rc.rows_in = rc.rows_out AND nc.bad_nulls = 0 AND fk.orphans = 0 THEN 'PASS' ELSE 'FAIL' END
FROM row_counts rc, null_check nc, fk_check fk;

-- ============================================================
-- ORDERS (FK -> customer AND restaurant, now with granular detail)
-- ============================================================
INSERT INTO common.dq_log (layer_transition, table_name, rows_in, rows_out, null_check_status, fk_check_status, fk_check_detail, overall_status)
WITH row_counts AS (
    SELECT (SELECT COUNT(*) FROM stage_sch.orders) AS rows_in,
           (SELECT COUNT(*) FROM clean_sch.orders)  AS rows_out
),
null_check AS (
    SELECT COUNT(*) AS bad_nulls
    FROM stage_sch.orders s
    JOIN clean_sch.orders c ON TRY_CAST(s.order_id AS NUMBER) = c.order_id
    WHERE s.created_date IS NOT NULL AND c.created_dt IS NULL
),
fk_customer AS (
    SELECT COUNT(*) AS orphans
    FROM clean_sch.orders o LEFT JOIN clean_sch.customer cu ON o.customer_id = cu.customer_id
    WHERE o.customer_id IS NOT NULL AND cu.customer_id IS NULL
),
fk_restaurant AS (
    SELECT COUNT(*) AS orphans
    FROM clean_sch.orders o LEFT JOIN clean_sch.restaurant r ON o.restaurant_id = r.restaurant_id
    WHERE o.restaurant_id IS NOT NULL AND r.restaurant_id IS NULL
)
SELECT 'stage_to_clean', 'orders', rc.rows_in, rc.rows_out,
       CASE WHEN nc.bad_nulls = 0 THEN 'PASS' ELSE 'FAIL' END,
       CASE WHEN fc.orphans = 0 AND fr.orphans = 0 THEN 'PASS' ELSE 'FAIL' END,
       'customer_id:' || CASE WHEN fc.orphans = 0 THEN 'PASS' ELSE 'FAIL(' || fc.orphans || ')' END
       || ';restaurant_id:' || CASE WHEN fr.orphans = 0 THEN 'PASS' ELSE 'FAIL(' || fr.orphans || ')' END,
       CASE WHEN rc.rows_in = rc.rows_out AND nc.bad_nulls = 0 AND fc.orphans = 0 AND fr.orphans = 0 THEN 'PASS' ELSE 'FAIL' END
FROM row_counts rc, null_check nc, fk_customer fc, fk_restaurant fr;

-- ============================================================
-- ORDER_ITEM (FK -> orders AND menu, now with granular detail)
-- ============================================================
INSERT INTO common.dq_log (layer_transition, table_name, rows_in, rows_out, null_check_status, fk_check_status, fk_check_detail, overall_status)
WITH row_counts AS (
    SELECT (SELECT COUNT(*) FROM stage_sch.order_item) AS rows_in,
           (SELECT COUNT(*) FROM clean_sch.order_item)  AS rows_out
),
null_check AS (
    SELECT COUNT(*) AS bad_nulls
    FROM stage_sch.order_item s
    JOIN clean_sch.order_item c ON TRY_CAST(s.order_item_id AS NUMBER) = c.order_item_id
    WHERE s.created_date IS NOT NULL AND c.created_dt IS NULL
),
fk_order AS (
    SELECT COUNT(*) AS orphans
    FROM clean_sch.order_item oi LEFT JOIN clean_sch.orders o ON oi.order_id = o.order_id
    WHERE oi.order_id IS NOT NULL AND o.order_id IS NULL
),
fk_menu AS (
    SELECT COUNT(*) AS orphans
    FROM clean_sch.order_item oi LEFT JOIN clean_sch.menu m ON oi.menu_id = m.menu_id
    WHERE oi.menu_id IS NOT NULL AND m.menu_id IS NULL
)
SELECT 'stage_to_clean', 'order_item', rc.rows_in, rc.rows_out,
       CASE WHEN nc.bad_nulls = 0 THEN 'PASS' ELSE 'FAIL' END,
       CASE WHEN fo.orphans = 0 AND fm.orphans = 0 THEN 'PASS' ELSE 'FAIL' END,
       'order_id:' || CASE WHEN fo.orphans = 0 THEN 'PASS' ELSE 'FAIL(' || fo.orphans || ')' END
       || ';menu_id:' || CASE WHEN fm.orphans = 0 THEN 'PASS' ELSE 'FAIL(' || fm.orphans || ')' END,
       CASE WHEN rc.rows_in = rc.rows_out AND nc.bad_nulls = 0 AND fo.orphans = 0 AND fm.orphans = 0 THEN 'PASS' ELSE 'FAIL' END
FROM row_counts rc, null_check nc, fk_order fo, fk_menu fm;

-- ============================================================
-- Verify the full log
-- ============================================================
SELECT * FROM common.dq_log ORDER BY run_id;