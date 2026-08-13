USE ROLE SYSADMIN;
USE DATABASE freshcart_db;
USE WAREHOUSE freshcart_wh;
USE SCHEMA stage_sch;

-- 1. LOCATION (FK anchor — build first)
CREATE TABLE IF NOT EXISTS stage_sch.location (
  location_id TEXT, city TEXT, state TEXT, zipcode TEXT, active_flag TEXT,
  created_date TEXT, modified_date TEXT,
  _stg_file_name TEXT, _stg_load_ts TIMESTAMP, _copy_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);
CREATE STREAM IF NOT EXISTS stage_sch.location_stm ON TABLE stage_sch.location APPEND_ONLY = TRUE;

-- 2. CUSTOMER (FK anchor — build second)
CREATE TABLE IF NOT EXISTS stage_sch.customer (
  customer_id TEXT, name TEXT, mobile TEXT, email TEXT, gender TEXT, dob TEXT,
  created_date TEXT, modified_date TEXT,
  _stg_file_name TEXT, _stg_load_ts TIMESTAMP, _copy_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);
CREATE STREAM IF NOT EXISTS stage_sch.customer_stm ON TABLE stage_sch.customer APPEND_ONLY = TRUE;

-- 3. RESTAURANT (depends on location_id existing conceptually — not FK-enforced at this layer)
CREATE TABLE IF NOT EXISTS stage_sch.restaurant (
  restaurant_id TEXT, name TEXT, cuisine_type TEXT, pricing_for_two TEXT,
  restaurant_phone TEXT, operating_hours TEXT, location_id TEXT,
  active_flag TEXT, open_status TEXT,
  created_date TEXT, modified_date TEXT,
  _stg_file_name TEXT, _stg_load_ts TIMESTAMP, _copy_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);
CREATE STREAM IF NOT EXISTS stage_sch.restaurant_stm ON TABLE stage_sch.restaurant APPEND_ONLY = TRUE;

-- 4. MENU (depends on restaurant_id)
CREATE TABLE IF NOT EXISTS stage_sch.menu (
  menu_id TEXT, restaurant_id TEXT, item_name TEXT, description TEXT,
  price TEXT, category TEXT, availability TEXT, item_type TEXT,
  created_date TEXT, modified_date TEXT,
  _stg_file_name TEXT, _stg_load_ts TIMESTAMP, _copy_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);
CREATE STREAM IF NOT EXISTS stage_sch.menu_stm ON TABLE stage_sch.menu APPEND_ONLY = TRUE;

-- 5. DELIVERY_AGENT (depends on location_id)
CREATE TABLE IF NOT EXISTS stage_sch.delivery_agent (
  delivery_agent_id TEXT, name TEXT, phone TEXT, vehicle_type TEXT,
  location_id TEXT, status TEXT, gender TEXT, rating TEXT,
  created_date TEXT, modified_date TEXT,
  _stg_file_name TEXT, _stg_load_ts TIMESTAMP, _copy_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);
CREATE STREAM IF NOT EXISTS stage_sch.delivery_agent_stm ON TABLE stage_sch.delivery_agent APPEND_ONLY = TRUE;

-- 6. CUSTOMER_ADDRESS (depends on customer_id)
CREATE TABLE IF NOT EXISTS stage_sch.customer_address (
  address_id TEXT, customer_id TEXT, flat_no TEXT, house_no TEXT, floor TEXT,
  building TEXT, landmark TEXT, locality TEXT, city TEXT, state TEXT, pincode TEXT,
  coordinates TEXT, primary_flag TEXT, address_type TEXT,
  created_date TEXT, modified_date TEXT,
  _stg_file_name TEXT, _stg_load_ts TIMESTAMP, _copy_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);
CREATE STREAM IF NOT EXISTS stage_sch.customer_address_stm ON TABLE stage_sch.customer_address APPEND_ONLY = TRUE;

-- 7. ORDERS (depends on customer_id, restaurant_id)
CREATE TABLE IF NOT EXISTS stage_sch.orders (
  order_id TEXT, customer_id TEXT, restaurant_id TEXT, order_date TEXT,
  total_amount TEXT, status TEXT, payment_method TEXT,
  created_date TEXT, modified_date TEXT,
  _stg_file_name TEXT, _stg_load_ts TIMESTAMP, _copy_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);
CREATE STREAM IF NOT EXISTS stage_sch.orders_stm ON TABLE stage_sch.orders APPEND_ONLY = TRUE;

-- 8. ORDER_ITEM (depends on order_id, menu_id — build last, most dependent)
CREATE TABLE IF NOT EXISTS stage_sch.order_item (
  order_item_id TEXT, order_id TEXT, menu_id TEXT, quantity TEXT,
  price TEXT, subtotal TEXT,
  created_date TEXT, modified_date TEXT,
  _stg_file_name TEXT, _stg_load_ts TIMESTAMP, _copy_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);
CREATE STREAM IF NOT EXISTS stage_sch.order_item_stm ON TABLE stage_sch.order_item APPEND_ONLY = TRUE;

-- Verification
SHOW TABLES IN SCHEMA stage_sch;
SHOW STREAMS IN SCHEMA stage_sch;