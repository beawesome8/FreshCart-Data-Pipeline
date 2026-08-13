-- FreshCart Phase 2: Clean layer (typed tables + MERGE from streams + PII tagging)
-- Standard Edition. PII protection via secure views (Phase 4), tags here for discoverability.

USE ROLE SYSADMIN;
USE DATABASE freshcart_db;
USE WAREHOUSE freshcart_wh;
USE SCHEMA clean_sch;

-- ============================================================
-- LOCATION
-- ============================================================
CREATE TABLE IF NOT EXISTS clean_sch.location (
  location_sk    NUMBER AUTOINCREMENT PRIMARY KEY,
  location_id    NUMBER NOT NULL UNIQUE,
  city           STRING NOT NULL,
  state          STRING NOT NULL,
  zipcode        STRING,
  active_flag    BOOLEAN,
  created_dt     TIMESTAMP_NTZ,
  modified_dt    TIMESTAMP_NTZ,
  _stg_file_name STRING,
  _copy_ts       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

MERGE INTO clean_sch.location AS target
USING (
    SELECT
        TRY_CAST(location_id AS NUMBER) AS location_id,
        city, state, zipcode,
        CASE WHEN active_flag = 'Y' THEN TRUE ELSE FALSE END AS active_flag,
        TRY_TO_TIMESTAMP_NTZ(created_date) AS created_dt,
        TRY_TO_TIMESTAMP_NTZ(modified_date) AS modified_dt,
        _stg_file_name
    FROM stage_sch.location_stm
) AS source
ON target.location_id = source.location_id
WHEN MATCHED THEN UPDATE SET
    target.city = source.city, target.state = source.state, target.zipcode = source.zipcode,
    target.active_flag = source.active_flag, target.modified_dt = source.modified_dt
WHEN NOT MATCHED THEN INSERT (
    location_id, city, state, zipcode, active_flag, created_dt, modified_dt, _stg_file_name
) VALUES (
    source.location_id, source.city, source.state, source.zipcode,
    source.active_flag, source.created_dt, source.modified_dt, source._stg_file_name
);

-- ============================================================
-- CUSTOMER (PII tagged)
-- ============================================================
CREATE TABLE IF NOT EXISTS clean_sch.customer (
  customer_sk    NUMBER AUTOINCREMENT PRIMARY KEY,
  customer_id    NUMBER NOT NULL UNIQUE,
  name           STRING NOT NULL,
  mobile         STRING,
  email          STRING,
  gender         STRING,
  dob            DATE,
  created_dt     TIMESTAMP_NTZ,
  modified_dt    TIMESTAMP_NTZ,
  _stg_file_name STRING,
  _copy_ts       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

ALTER TABLE clean_sch.customer MODIFY COLUMN mobile SET TAG common.pii_tag = 'PII';
ALTER TABLE clean_sch.customer MODIFY COLUMN email  SET TAG common.pii_tag = 'EMAIL';
ALTER TABLE clean_sch.customer MODIFY COLUMN gender SET TAG common.pii_tag = 'PII';
ALTER TABLE clean_sch.customer MODIFY COLUMN dob    SET TAG common.pii_tag = 'PII';

MERGE INTO clean_sch.customer AS target
USING (
    SELECT
        TRY_CAST(customer_id AS NUMBER) AS customer_id,
        name, mobile, email, gender,
        TRY_TO_DATE(dob) AS dob,
        TRY_TO_TIMESTAMP_NTZ(created_date) AS created_dt,
        TRY_TO_TIMESTAMP_NTZ(modified_date) AS modified_dt,
        _stg_file_name
    FROM stage_sch.customer_stm
) AS source
ON target.customer_id = source.customer_id
WHEN MATCHED THEN UPDATE SET
    target.name = source.name, target.mobile = source.mobile, target.email = source.email,
    target.gender = source.gender, target.dob = source.dob, target.modified_dt = source.modified_dt
WHEN NOT MATCHED THEN INSERT (
    customer_id, name, mobile, email, gender, dob, created_dt, modified_dt, _stg_file_name
) VALUES (
    source.customer_id, source.name, source.mobile, source.email, source.gender,
    source.dob, source.created_dt, source.modified_dt, source._stg_file_name
);

-- ============================================================
-- RESTAURANT (PII tagged; FIXED: DD-MM-YYYY date format)
-- ============================================================
CREATE TABLE IF NOT EXISTS clean_sch.restaurant (
  restaurant_sk    NUMBER AUTOINCREMENT PRIMARY KEY,
  restaurant_id    NUMBER NOT NULL UNIQUE,
  name             STRING NOT NULL,
  cuisine_type     STRING,
  pricing_for_two  NUMBER(10,2),
  restaurant_phone STRING,
  operating_hours  STRING,
  location_id      NUMBER,
  active_flag      BOOLEAN,
  open_status      STRING,
  created_dt       TIMESTAMP_NTZ,
  modified_dt      TIMESTAMP_NTZ,
  _stg_file_name   STRING,
  _copy_ts         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

ALTER TABLE clean_sch.restaurant MODIFY COLUMN restaurant_phone SET TAG common.pii_tag = 'PII';

MERGE INTO clean_sch.restaurant AS target
USING (
    SELECT
        TRY_CAST(restaurant_id AS NUMBER) AS restaurant_id,
        name, cuisine_type,
        TRY_CAST(pricing_for_two AS NUMBER(10,2)) AS pricing_for_two,
        restaurant_phone, operating_hours,
        TRY_CAST(location_id AS NUMBER) AS location_id,
        CASE WHEN active_flag = 'Y' THEN TRUE ELSE FALSE END AS active_flag,
        open_status,
        TRY_TO_TIMESTAMP_NTZ(created_date, 'DD-MM-YYYY HH24:MI') AS created_dt,
        TRY_TO_TIMESTAMP_NTZ(modified_date, 'DD-MM-YYYY HH24:MI') AS modified_dt,
        _stg_file_name
    FROM stage_sch.restaurant_stm
) AS source
ON target.restaurant_id = source.restaurant_id
WHEN MATCHED THEN UPDATE SET
    target.name = source.name, target.cuisine_type = source.cuisine_type,
    target.pricing_for_two = source.pricing_for_two, target.restaurant_phone = source.restaurant_phone,
    target.operating_hours = source.operating_hours, target.location_id = source.location_id,
    target.active_flag = source.active_flag, target.open_status = source.open_status,
    target.modified_dt = source.modified_dt
WHEN NOT MATCHED THEN INSERT (
    restaurant_id, name, cuisine_type, pricing_for_two, restaurant_phone,
    operating_hours, location_id, active_flag, open_status, created_dt, modified_dt, _stg_file_name
) VALUES (
    source.restaurant_id, source.name, source.cuisine_type, source.pricing_for_two,
    source.restaurant_phone, source.operating_hours, source.location_id, source.active_flag,
    source.open_status, source.created_dt, source.modified_dt, source._stg_file_name
);

-- ============================================================
-- MENU
-- ============================================================
CREATE TABLE IF NOT EXISTS clean_sch.menu (
  menu_sk        NUMBER AUTOINCREMENT PRIMARY KEY,
  menu_id        NUMBER NOT NULL UNIQUE,
  restaurant_id  NUMBER NOT NULL,
  item_name      STRING NOT NULL,
  description    STRING,
  price          NUMBER(10,2),
  category       STRING,
  availability   BOOLEAN,
  item_type      STRING,
  created_dt     TIMESTAMP_NTZ,
  modified_dt    TIMESTAMP_NTZ,
  _stg_file_name STRING,
  _copy_ts       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

MERGE INTO clean_sch.menu AS target
USING (
    SELECT
        TRY_CAST(menu_id AS NUMBER) AS menu_id,
        TRY_CAST(restaurant_id AS NUMBER) AS restaurant_id,
        item_name, description,
        TRY_CAST(price AS NUMBER(10,2)) AS price,
        category,
        CASE WHEN LOWER(availability) = 'true' THEN TRUE ELSE FALSE END AS availability,
        item_type,
        TRY_TO_TIMESTAMP_NTZ(created_date) AS created_dt,
        TRY_TO_TIMESTAMP_NTZ(modified_date) AS modified_dt,
        _stg_file_name
    FROM stage_sch.menu_stm
) AS source
ON target.menu_id = source.menu_id
WHEN MATCHED THEN UPDATE SET
    target.restaurant_id = source.restaurant_id, target.item_name = source.item_name,
    target.description = source.description, target.price = source.price, target.category = source.category,
    target.availability = source.availability, target.item_type = source.item_type, target.modified_dt = source.modified_dt
WHEN NOT MATCHED THEN INSERT (
    menu_id, restaurant_id, item_name, description, price, category,
    availability, item_type, created_dt, modified_dt, _stg_file_name
) VALUES (
    source.menu_id, source.restaurant_id, source.item_name, source.description, source.price,
    source.category, source.availability, source.item_type, source.created_dt, source.modified_dt, source._stg_file_name
);

-- ============================================================
-- DELIVERY_AGENT (PII tagged)
-- ============================================================
CREATE TABLE IF NOT EXISTS clean_sch.delivery_agent (
  delivery_agent_sk NUMBER AUTOINCREMENT PRIMARY KEY,
  delivery_agent_id NUMBER NOT NULL UNIQUE,
  name              STRING NOT NULL,
  phone             STRING,
  vehicle_type      STRING,
  location_id       NUMBER,
  status            STRING,
  gender            STRING,
  rating            NUMBER(4,2),
  created_dt        TIMESTAMP_NTZ,
  modified_dt       TIMESTAMP_NTZ,
  _stg_file_name    STRING,
  _copy_ts          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

ALTER TABLE clean_sch.delivery_agent MODIFY COLUMN phone  SET TAG common.pii_tag = 'PII';
ALTER TABLE clean_sch.delivery_agent MODIFY COLUMN gender SET TAG common.pii_tag = 'PII';

MERGE INTO clean_sch.delivery_agent AS target
USING (
    SELECT
        TRY_CAST(delivery_agent_id AS NUMBER) AS delivery_agent_id,
        name, phone, vehicle_type,
        TRY_CAST(location_id AS NUMBER) AS location_id,
        status, gender,
        TRY_CAST(rating AS NUMBER(4,2)) AS rating,
        TRY_TO_TIMESTAMP_NTZ(created_date) AS created_dt,
        TRY_TO_TIMESTAMP_NTZ(modified_date) AS modified_dt,
        _stg_file_name
    FROM stage_sch.delivery_agent_stm
) AS source
ON target.delivery_agent_id = source.delivery_agent_id
WHEN MATCHED THEN UPDATE SET
    target.name = source.name, target.phone = source.phone, target.vehicle_type = source.vehicle_type,
    target.location_id = source.location_id, target.status = source.status, target.gender = source.gender,
    target.rating = source.rating, target.modified_dt = source.modified_dt
WHEN NOT MATCHED THEN INSERT (
    delivery_agent_id, name, phone, vehicle_type, location_id, status, gender, rating,
    created_dt, modified_dt, _stg_file_name
) VALUES (
    source.delivery_agent_id, source.name, source.phone, source.vehicle_type, source.location_id,
    source.status, source.gender, source.rating, source.created_dt, source.modified_dt, source._stg_file_name
);

-- ============================================================
-- CUSTOMER_ADDRESS
-- ============================================================
CREATE TABLE IF NOT EXISTS clean_sch.customer_address (
  customer_address_sk NUMBER AUTOINCREMENT PRIMARY KEY,
  address_id           NUMBER NOT NULL UNIQUE,
  customer_id          NUMBER NOT NULL,
  flat_no              STRING,
  house_no             STRING,
  floor                STRING,
  building              STRING,
  landmark             STRING,
  locality             STRING,
  city                 STRING,
  state                STRING,
  pincode              STRING,
  coordinates          STRING,
  primary_flag         BOOLEAN,
  address_type         STRING,
  created_dt           TIMESTAMP_NTZ,
  modified_dt          TIMESTAMP_NTZ,
  _stg_file_name       STRING,
  _copy_ts             TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

MERGE INTO clean_sch.customer_address AS target
USING (
    SELECT
        TRY_CAST(address_id AS NUMBER) AS address_id,
        TRY_CAST(customer_id AS NUMBER) AS customer_id,
        flat_no, house_no, floor, building, landmark, locality, city, state, pincode, coordinates,
        CASE WHEN primary_flag = 'Y' THEN TRUE ELSE FALSE END AS primary_flag,
        address_type,
        TRY_TO_TIMESTAMP_NTZ(created_date) AS created_dt,
        TRY_TO_TIMESTAMP_NTZ(modified_date) AS modified_dt,
        _stg_file_name
    FROM stage_sch.customer_address_stm
) AS source
ON target.address_id = source.address_id
WHEN MATCHED THEN UPDATE SET
    target.customer_id = source.customer_id,
    target.flat_no = source.flat_no, target.house_no = source.house_no, target.floor = source.floor,
    target.building = source.building, target.landmark = source.landmark, target.locality = source.locality,
    target.city = source.city, target.state = source.state, target.pincode = source.pincode,
    target.coordinates = source.coordinates, target.primary_flag = source.primary_flag,
    target.address_type = source.address_type, target.modified_dt = source.modified_dt
WHEN NOT MATCHED THEN INSERT (
    address_id, customer_id, flat_no, house_no, floor, building, landmark, locality, city, state,
    pincode, coordinates, primary_flag, address_type, created_dt, modified_dt, _stg_file_name
) VALUES (
    source.address_id, source.customer_id, source.flat_no, source.house_no, source.floor, source.building,
    source.landmark, source.locality, source.city, source.state, source.pincode, source.coordinates,
    source.primary_flag, source.address_type, source.created_dt, source.modified_dt, source._stg_file_name
);

-- ============================================================
-- ORDERS
-- ============================================================
CREATE TABLE IF NOT EXISTS clean_sch.orders (
  order_sk        NUMBER AUTOINCREMENT PRIMARY KEY,
  order_id        NUMBER NOT NULL UNIQUE,
  customer_id     NUMBER NOT NULL,
  restaurant_id   NUMBER NOT NULL,
  order_date      TIMESTAMP_NTZ,
  total_amount    NUMBER(10,2),
  status          STRING,
  payment_method  STRING,
  created_dt      TIMESTAMP_NTZ,
  modified_dt     TIMESTAMP_NTZ,
  _stg_file_name  STRING,
  _copy_ts        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

MERGE INTO clean_sch.orders AS target
USING (
    SELECT
        TRY_CAST(order_id AS NUMBER) AS order_id,
        TRY_CAST(customer_id AS NUMBER) AS customer_id,
        TRY_CAST(restaurant_id AS NUMBER) AS restaurant_id,
        TRY_TO_TIMESTAMP_NTZ(order_date) AS order_date,
        TRY_CAST(total_amount AS NUMBER(10,2)) AS total_amount,
        status, payment_method,
        TRY_TO_TIMESTAMP_NTZ(created_date) AS created_dt,
        TRY_TO_TIMESTAMP_NTZ(modified_date) AS modified_dt,
        _stg_file_name
    FROM stage_sch.orders_stm
) AS source
ON target.order_id = source.order_id
WHEN MATCHED THEN UPDATE SET
    target.customer_id = source.customer_id, target.restaurant_id = source.restaurant_id,
    target.order_date = source.order_date, target.total_amount = source.total_amount,
    target.status = source.status, target.payment_method = source.payment_method, target.modified_dt = source.modified_dt
WHEN NOT MATCHED THEN INSERT (
    order_id, customer_id, restaurant_id, order_date, total_amount, status, payment_method,
    created_dt, modified_dt, _stg_file_name
) VALUES (
    source.order_id, source.customer_id, source.restaurant_id, source.order_date, source.total_amount,
    source.status, source.payment_method, source.created_dt, source.modified_dt, source._stg_file_name
);

-- ============================================================
-- ORDER_ITEM
-- ============================================================
CREATE TABLE IF NOT EXISTS clean_sch.order_item (
  order_item_sk  NUMBER AUTOINCREMENT PRIMARY KEY,
  order_item_id  NUMBER NOT NULL UNIQUE,
  order_id       NUMBER NOT NULL,
  menu_id        NUMBER NOT NULL,
  quantity       NUMBER(5,0),
  price          NUMBER(10,2),
  subtotal       NUMBER(10,2),
  created_dt     TIMESTAMP_NTZ,
  modified_dt    TIMESTAMP_NTZ,
  _stg_file_name STRING,
  _copy_ts       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

MERGE INTO clean_sch.order_item AS target
USING (
    SELECT
        TRY_CAST(order_item_id AS NUMBER) AS order_item_id,
        TRY_CAST(order_id AS NUMBER) AS order_id,
        TRY_CAST(menu_id AS NUMBER) AS menu_id,
        TRY_CAST(quantity AS NUMBER(5,0)) AS quantity,
        TRY_CAST(price AS NUMBER(10,2)) AS price,
        TRY_CAST(subtotal AS NUMBER(10,2)) AS subtotal,
        TRY_TO_TIMESTAMP_NTZ(created_date) AS created_dt,
        TRY_TO_TIMESTAMP_NTZ(modified_date) AS modified_dt,
        _stg_file_name
    FROM stage_sch.order_item_stm
) AS source
ON target.order_item_id = source.order_item_id
WHEN MATCHED THEN UPDATE SET
    target.order_id = source.order_id, target.menu_id = source.menu_id, target.quantity = source.quantity,
    target.price = source.price, target.subtotal = source.subtotal, target.modified_dt = source.modified_dt
WHEN NOT MATCHED THEN INSERT (
    order_item_id, order_id, menu_id, quantity, price, subtotal, created_dt, modified_dt, _stg_file_name
) VALUES (
    source.order_item_id, source.order_id, source.menu_id, source.quantity, source.price, source.subtotal,
    source.created_dt, source.modified_dt, source._stg_file_name
);

-- ============================================================
-- DELIVERY
-- ============================================================
CREATE TABLE IF NOT EXISTS clean_sch.delivery (
  delivery_sk       NUMBER AUTOINCREMENT PRIMARY KEY,
  delivery_id       NUMBER NOT NULL UNIQUE,
  order_id          NUMBER NOT NULL,
  delivery_agent_id NUMBER NOT NULL,
  delivery_status   STRING,
  estimated_time    STRING,
  created_dt        TIMESTAMP_NTZ,
  modified_dt       TIMESTAMP_NTZ,
  _stg_file_name    STRING,
  _copy_ts          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

MERGE INTO clean_sch.delivery AS target
USING (
    SELECT
        TRY_CAST(delivery_id AS NUMBER) AS delivery_id,
        TRY_CAST(order_id AS NUMBER) AS order_id,
        TRY_CAST(delivery_agent_id AS NUMBER) AS delivery_agent_id,
        delivery_status, estimated_time,
        TRY_TO_TIMESTAMP_NTZ(created_date) AS created_dt,
        TRY_TO_TIMESTAMP_NTZ(modified_date) AS modified_dt,
        _stg_file_name
    FROM stage_sch.delivery_stm
) AS source
ON target.delivery_id = source.delivery_id
WHEN MATCHED THEN UPDATE SET
    target.delivery_status = source.delivery_status, target.estimated_time = source.estimated_time,
    target.modified_dt = source.modified_dt
WHEN NOT MATCHED THEN INSERT (
    delivery_id, order_id, delivery_agent_id, delivery_status, estimated_time, created_dt, modified_dt, _stg_file_name
) VALUES (
    source.delivery_id, source.order_id, source.delivery_agent_id, source.delivery_status,
    source.estimated_time, source.created_dt, source.modified_dt, source._stg_file_name
);

-- ============================================================
-- Verify
-- ============================================================
SELECT 'location' tbl, COUNT(*) FROM clean_sch.location
UNION ALL SELECT 'customer', COUNT(*) FROM clean_sch.customer
UNION ALL SELECT 'restaurant', COUNT(*) FROM clean_sch.restaurant
UNION ALL SELECT 'menu', COUNT(*) FROM clean_sch.menu
UNION ALL SELECT 'delivery_agent', COUNT(*) FROM clean_sch.delivery_agent
UNION ALL SELECT 'customer_address', COUNT(*) FROM clean_sch.customer_address
UNION ALL SELECT 'orders', COUNT(*) FROM clean_sch.orders
UNION ALL SELECT 'order_item', COUNT(*) FROM clean_sch.order_item
UNION ALL SELECT 'delivery', COUNT(*) FROM clean_sch.delivery
UNION ALL SELECT 'restaurant_null_dates', COUNT(*) FROM clean_sch.restaurant WHERE created_dt IS NULL
ORDER BY tbl;