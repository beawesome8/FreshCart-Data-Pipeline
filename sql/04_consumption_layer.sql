USE ROLE SYSADMIN;
USE DATABASE freshcart_db;
USE WAREHOUSE freshcart_wh;
USE SCHEMA consumption_sch;

-- ============================================================
-- DATE_DIM
-- ============================================================
CREATE OR REPLACE TABLE consumption_sch.date_dim AS
WITH RECURSIVE date_cte AS (
    SELECT DATE(MIN(order_date)) AS cal_date FROM clean_sch.orders
    UNION ALL
    SELECT DATEADD('day', 1, cal_date) FROM date_cte
    WHERE cal_date < (SELECT DATE(MAX(order_date)) FROM clean_sch.orders)
)
SELECT
    HASH(cal_date) AS date_dim_sk,
    cal_date AS calendar_date,
    YEAR(cal_date) AS year,
    MONTH(cal_date) AS month,
    DAY(cal_date) AS day,
    DAYNAME(cal_date) AS day_name
FROM date_cte;

-- ============================================================
-- LOCATION_DIM (SCD2)
-- ============================================================
CREATE TABLE IF NOT EXISTS consumption_sch.location_dim (
  location_dim_sk NUMBER AUTOINCREMENT PRIMARY KEY,
  location_id     NUMBER NOT NULL,
  city            STRING,
  state           STRING,
  zipcode         STRING,
  active_flag     BOOLEAN,
  eff_start_date  TIMESTAMP_NTZ,
  eff_end_date    TIMESTAMP_NTZ,
  is_current      BOOLEAN
);

UPDATE consumption_sch.location_dim d
SET eff_end_date = CURRENT_TIMESTAMP(), is_current = FALSE
FROM clean_sch.location s
WHERE d.location_id = s.location_id AND d.is_current = TRUE
  AND (d.city != s.city OR d.state != s.state OR NVL(d.zipcode,'') != NVL(s.zipcode,'') OR d.active_flag != s.active_flag);

INSERT INTO consumption_sch.location_dim (location_id, city, state, zipcode, active_flag, eff_start_date, eff_end_date, is_current)
SELECT s.location_id, s.city, s.state, s.zipcode, s.active_flag, CURRENT_TIMESTAMP(), NULL, TRUE
FROM clean_sch.location s
LEFT JOIN consumption_sch.location_dim d ON s.location_id = d.location_id AND d.is_current = TRUE
WHERE d.location_id IS NULL;

-- ============================================================
-- CUSTOMER_DIM (SCD2)
-- ============================================================
CREATE TABLE IF NOT EXISTS consumption_sch.customer_dim (
  customer_dim_sk NUMBER AUTOINCREMENT PRIMARY KEY,
  customer_id     NUMBER NOT NULL,
  name            STRING,
  mobile          STRING,
  email           STRING,
  gender          STRING,
  dob             DATE,
  eff_start_date  TIMESTAMP_NTZ,
  eff_end_date    TIMESTAMP_NTZ,
  is_current      BOOLEAN
);

UPDATE consumption_sch.customer_dim d
SET eff_end_date = CURRENT_TIMESTAMP(), is_current = FALSE
FROM clean_sch.customer s
WHERE d.customer_id = s.customer_id AND d.is_current = TRUE
  AND (NVL(d.name,'')!=NVL(s.name,'') OR NVL(d.mobile,'')!=NVL(s.mobile,'') OR NVL(d.email,'')!=NVL(s.email,'')
       OR NVL(d.gender,'')!=NVL(s.gender,'') OR NVL(d.dob, '1900-01-01')!=NVL(s.dob, '1900-01-01'));

INSERT INTO consumption_sch.customer_dim (customer_id, name, mobile, email, gender, dob, eff_start_date, eff_end_date, is_current)
SELECT s.customer_id, s.name, s.mobile, s.email, s.gender, s.dob, CURRENT_TIMESTAMP(), NULL, TRUE
FROM clean_sch.customer s
LEFT JOIN consumption_sch.customer_dim d ON s.customer_id = d.customer_id AND d.is_current = TRUE
WHERE d.customer_id IS NULL;

-- ============================================================
-- RESTAURANT_DIM (SCD2)
-- ============================================================
CREATE TABLE IF NOT EXISTS consumption_sch.restaurant_dim (
  restaurant_dim_sk NUMBER AUTOINCREMENT PRIMARY KEY,
  restaurant_id     NUMBER NOT NULL,
  name              STRING,
  cuisine_type      STRING,
  pricing_for_two   NUMBER(10,2),
  location_id       NUMBER,
  active_flag       BOOLEAN,
  open_status       STRING,
  eff_start_date    TIMESTAMP_NTZ,
  eff_end_date      TIMESTAMP_NTZ,
  is_current        BOOLEAN
);

UPDATE consumption_sch.restaurant_dim d
SET eff_end_date = CURRENT_TIMESTAMP(), is_current = FALSE
FROM clean_sch.restaurant s
WHERE d.restaurant_id = s.restaurant_id AND d.is_current = TRUE
  AND (NVL(d.name,'')!=NVL(s.name,'') OR NVL(d.cuisine_type,'')!=NVL(s.cuisine_type,'')
       OR NVL(d.pricing_for_two,0)!=NVL(s.pricing_for_two,0) OR d.location_id!=s.location_id
       OR d.active_flag!=s.active_flag OR NVL(d.open_status,'')!=NVL(s.open_status,''));

INSERT INTO consumption_sch.restaurant_dim (restaurant_id, name, cuisine_type, pricing_for_two, location_id, active_flag, open_status, eff_start_date, eff_end_date, is_current)
SELECT s.restaurant_id, s.name, s.cuisine_type, s.pricing_for_two, s.location_id, s.active_flag, s.open_status, CURRENT_TIMESTAMP(), NULL, TRUE
FROM clean_sch.restaurant s
LEFT JOIN consumption_sch.restaurant_dim d ON s.restaurant_id = d.restaurant_id AND d.is_current = TRUE
WHERE d.restaurant_id IS NULL;

-- ============================================================
-- MENU_DIM (SCD2)
-- ============================================================
CREATE TABLE IF NOT EXISTS consumption_sch.menu_dim (
  menu_dim_sk    NUMBER AUTOINCREMENT PRIMARY KEY,
  menu_id        NUMBER NOT NULL,
  restaurant_id  NUMBER,
  item_name      STRING,
  price          NUMBER(10,2),
  category       STRING,
  item_type      STRING,
  eff_start_date TIMESTAMP_NTZ,
  eff_end_date   TIMESTAMP_NTZ,
  is_current     BOOLEAN
);

UPDATE consumption_sch.menu_dim d
SET eff_end_date = CURRENT_TIMESTAMP(), is_current = FALSE
FROM clean_sch.menu s
WHERE d.menu_id = s.menu_id AND d.is_current = TRUE
  AND (NVL(d.price,0)!=NVL(s.price,0) OR NVL(d.category,'')!=NVL(s.category,'') OR NVL(d.item_type,'')!=NVL(s.item_type,''));

INSERT INTO consumption_sch.menu_dim (menu_id, restaurant_id, item_name, price, category, item_type, eff_start_date, eff_end_date, is_current)
SELECT s.menu_id, s.restaurant_id, s.item_name, s.price, s.category, s.item_type, CURRENT_TIMESTAMP(), NULL, TRUE
FROM clean_sch.menu s
LEFT JOIN consumption_sch.menu_dim d ON s.menu_id = d.menu_id AND d.is_current = TRUE
WHERE d.menu_id IS NULL;

-- ============================================================
-- DELIVERY_AGENT_DIM (SCD2)
-- ============================================================
CREATE TABLE IF NOT EXISTS consumption_sch.delivery_agent_dim (
  delivery_agent_dim_sk NUMBER AUTOINCREMENT PRIMARY KEY,
  delivery_agent_id     NUMBER NOT NULL,
  name                  STRING,
  vehicle_type          STRING,
  location_id           NUMBER,
  status                STRING,
  rating                NUMBER(4,2),
  eff_start_date        TIMESTAMP_NTZ,
  eff_end_date          TIMESTAMP_NTZ,
  is_current            BOOLEAN
);

UPDATE consumption_sch.delivery_agent_dim d
SET eff_end_date = CURRENT_TIMESTAMP(), is_current = FALSE
FROM clean_sch.delivery_agent s
WHERE d.delivery_agent_id = s.delivery_agent_id AND d.is_current = TRUE
  AND (NVL(d.status,'')!=NVL(s.status,'') OR NVL(d.rating,0)!=NVL(s.rating,0));

INSERT INTO consumption_sch.delivery_agent_dim (delivery_agent_id, name, vehicle_type, location_id, status, rating, eff_start_date, eff_end_date, is_current)
SELECT s.delivery_agent_id, s.name, s.vehicle_type, s.location_id, s.status, s.rating, CURRENT_TIMESTAMP(), NULL, TRUE
FROM clean_sch.delivery_agent s
LEFT JOIN consumption_sch.delivery_agent_dim d ON s.delivery_agent_id = d.delivery_agent_id AND d.is_current = TRUE
WHERE d.delivery_agent_id IS NULL;

-- ============================================================
-- CUSTOMER_ADDRESS_DIM (SCD1 — deliberate, see README)
-- ============================================================
CREATE TABLE IF NOT EXISTS consumption_sch.customer_address_dim (
  customer_address_dim_sk NUMBER AUTOINCREMENT PRIMARY KEY,
  address_id               NUMBER NOT NULL UNIQUE,
  customer_id               NUMBER,
  city                       STRING,
  state                      STRING,
  address_type               STRING
);

MERGE INTO consumption_sch.customer_address_dim AS target
USING clean_sch.customer_address AS source
ON target.address_id = source.address_id
WHEN MATCHED THEN UPDATE SET
    target.customer_id = source.customer_id, target.city = source.city,
    target.state = source.state, target.address_type = source.address_type
WHEN NOT MATCHED THEN INSERT (address_id, customer_id, city, state, address_type)
VALUES (source.address_id, source.customer_id, source.city, source.state, source.address_type);

-- ============================================================
-- ORDER_ITEM_FACT — includes delivery link from the start
-- ============================================================
CREATE TABLE IF NOT EXISTS consumption_sch.order_item_fact (
  order_item_fact_sk    NUMBER AUTOINCREMENT PRIMARY KEY,
  order_item_id          NUMBER NOT NULL UNIQUE,
  order_id                NUMBER,
  customer_dim_sk           NUMBER,
  restaurant_dim_sk         NUMBER,
  location_dim_sk           NUMBER,
  menu_dim_sk               NUMBER,
  date_dim_sk               NUMBER,
  delivery_agent_dim_sk     NUMBER,
  delivery_status            STRING,
  estimated_time              STRING,
  quantity                     NUMBER,
  price                         NUMBER(10,2),
  subtotal                       NUMBER(10,2),
  order_status                    STRING,
  payment_method                   STRING
);

MERGE INTO consumption_sch.order_item_fact AS target
USING (
    SELECT
        oi.order_item_id, oi.order_id,
        cd.customer_dim_sk, rd.restaurant_dim_sk, ld.location_dim_sk,
        md.menu_dim_sk, dd.date_dim_sk, da.delivery_agent_dim_sk,
        dl.delivery_status, dl.estimated_time,
        oi.quantity, oi.price, oi.subtotal,
        o.status AS order_status, o.payment_method
    FROM clean_sch.order_item oi
    JOIN clean_sch.orders o                ON oi.order_id = o.order_id
    JOIN clean_sch.delivery dl             ON o.order_id = dl.order_id
    JOIN consumption_sch.customer_dim cd         ON o.customer_id = cd.customer_id AND cd.is_current = TRUE
    JOIN consumption_sch.restaurant_dim rd       ON o.restaurant_id = rd.restaurant_id AND rd.is_current = TRUE
    JOIN consumption_sch.location_dim ld         ON rd.location_id = ld.location_id AND ld.is_current = TRUE
    JOIN consumption_sch.menu_dim md             ON oi.menu_id = md.menu_id AND md.is_current = TRUE
    JOIN consumption_sch.date_dim dd             ON dd.calendar_date = DATE(o.order_date)
    JOIN consumption_sch.delivery_agent_dim da   ON dl.delivery_agent_id = da.delivery_agent_id AND da.is_current = TRUE
) AS source
ON target.order_item_id = source.order_item_id
WHEN MATCHED THEN UPDATE SET
    target.customer_dim_sk = source.customer_dim_sk, target.restaurant_dim_sk = source.restaurant_dim_sk,
    target.location_dim_sk = source.location_dim_sk, target.menu_dim_sk = source.menu_dim_sk,
    target.date_dim_sk = source.date_dim_sk, target.delivery_agent_dim_sk = source.delivery_agent_dim_sk,
    target.delivery_status = source.delivery_status, target.estimated_time = source.estimated_time,
    target.quantity = source.quantity, target.price = source.price, target.subtotal = source.subtotal,
    target.order_status = source.order_status, target.payment_method = source.payment_method
WHEN NOT MATCHED THEN INSERT (
    order_item_id, order_id, customer_dim_sk, restaurant_dim_sk, location_dim_sk,
    menu_dim_sk, date_dim_sk, delivery_agent_dim_sk, delivery_status, estimated_time,
    quantity, price, subtotal, order_status, payment_method
) VALUES (
    source.order_item_id, source.order_id, source.customer_dim_sk, source.restaurant_dim_sk,
    source.location_dim_sk, source.menu_dim_sk, source.date_dim_sk, source.delivery_agent_dim_sk,
    source.delivery_status, source.estimated_time, source.quantity, source.price, source.subtotal,
    source.order_status, source.payment_method
);

-- ============================================================
-- Verify
-- ============================================================
SELECT 'date_dim' t, COUNT(*) FROM consumption_sch.date_dim
UNION ALL SELECT 'location_dim', COUNT(*) FROM consumption_sch.location_dim
UNION ALL SELECT 'customer_dim', COUNT(*) FROM consumption_sch.customer_dim
UNION ALL SELECT 'restaurant_dim', COUNT(*) FROM consumption_sch.restaurant_dim
UNION ALL SELECT 'menu_dim', COUNT(*) FROM consumption_sch.menu_dim
UNION ALL SELECT 'delivery_agent_dim', COUNT(*) FROM consumption_sch.delivery_agent_dim
UNION ALL SELECT 'customer_address_dim', COUNT(*) FROM consumption_sch.customer_address_dim
UNION ALL SELECT 'order_item_fact_total', COUNT(*) FROM consumption_sch.order_item_fact
UNION ALL SELECT 'order_item_fact_with_delivery', COUNT(delivery_agent_dim_sk) FROM consumption_sch.order_item_fact
ORDER BY t;