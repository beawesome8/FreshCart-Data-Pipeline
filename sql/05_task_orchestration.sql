-- FreshCart Phase 5: Task orchestration (stage->clean->DQ->consumption, chained + scheduled)
-- FIXED vs. original: restaurant date format; delivery table was missing from sp_dq_checks entirely.

USE ROLE SYSADMIN;
USE DATABASE freshcart_db;
USE WAREHOUSE freshcart_wh;
USE SCHEMA common;

-- ============================================================
-- PROCEDURE 1: stage -> clean
-- ============================================================
CREATE OR REPLACE PROCEDURE common.sp_clean_layer()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
  MERGE INTO clean_sch.location AS target
  USING (SELECT TRY_CAST(location_id AS NUMBER) location_id, city, state, zipcode,
                CASE WHEN active_flag='Y' THEN TRUE ELSE FALSE END active_flag,
                TRY_TO_TIMESTAMP_NTZ(created_date) created_dt, TRY_TO_TIMESTAMP_NTZ(modified_date) modified_dt, _stg_file_name
         FROM stage_sch.location_stm) source
  ON target.location_id = source.location_id
  WHEN MATCHED THEN UPDATE SET target.city=source.city, target.state=source.state, target.zipcode=source.zipcode,
       target.active_flag=source.active_flag, target.modified_dt=source.modified_dt
  WHEN NOT MATCHED THEN INSERT (location_id,city,state,zipcode,active_flag,created_dt,modified_dt,_stg_file_name)
       VALUES (source.location_id,source.city,source.state,source.zipcode,source.active_flag,source.created_dt,source.modified_dt,source._stg_file_name);

  MERGE INTO clean_sch.customer AS target
  USING (SELECT TRY_CAST(customer_id AS NUMBER) customer_id, name, mobile, email, gender,
                TRY_TO_DATE(dob) dob, TRY_TO_TIMESTAMP_NTZ(created_date) created_dt, TRY_TO_TIMESTAMP_NTZ(modified_date) modified_dt, _stg_file_name
         FROM stage_sch.customer_stm) source
  ON target.customer_id = source.customer_id
  WHEN MATCHED THEN UPDATE SET target.name=source.name, target.mobile=source.mobile, target.email=source.email,
       target.gender=source.gender, target.dob=source.dob, target.modified_dt=source.modified_dt
  WHEN NOT MATCHED THEN INSERT (customer_id,name,mobile,email,gender,dob,created_dt,modified_dt,_stg_file_name)
       VALUES (source.customer_id,source.name,source.mobile,source.email,source.gender,source.dob,source.created_dt,source.modified_dt,source._stg_file_name);

  -- RESTAURANT: FIXED date format 'DD-MM-YYYY HH24:MI'
  MERGE INTO clean_sch.restaurant AS target
  USING (SELECT TRY_CAST(restaurant_id AS NUMBER) restaurant_id, name, cuisine_type,
                TRY_CAST(pricing_for_two AS NUMBER(10,2)) pricing_for_two, restaurant_phone, operating_hours,
                TRY_CAST(location_id AS NUMBER) location_id,
                CASE WHEN active_flag='Y' THEN TRUE ELSE FALSE END active_flag, open_status,
                TRY_TO_TIMESTAMP_NTZ(created_date, 'DD-MM-YYYY HH24:MI') created_dt,
                TRY_TO_TIMESTAMP_NTZ(modified_date, 'DD-MM-YYYY HH24:MI') modified_dt, _stg_file_name
         FROM stage_sch.restaurant_stm) source
  ON target.restaurant_id = source.restaurant_id
  WHEN MATCHED THEN UPDATE SET target.name=source.name, target.cuisine_type=source.cuisine_type,
       target.pricing_for_two=source.pricing_for_two, target.restaurant_phone=source.restaurant_phone,
       target.operating_hours=source.operating_hours, target.location_id=source.location_id,
       target.active_flag=source.active_flag, target.open_status=source.open_status, target.modified_dt=source.modified_dt
  WHEN NOT MATCHED THEN INSERT (restaurant_id,name,cuisine_type,pricing_for_two,restaurant_phone,operating_hours,location_id,active_flag,open_status,created_dt,modified_dt,_stg_file_name)
       VALUES (source.restaurant_id,source.name,source.cuisine_type,source.pricing_for_two,source.restaurant_phone,source.operating_hours,source.location_id,source.active_flag,source.open_status,source.created_dt,source.modified_dt,source._stg_file_name);

  MERGE INTO clean_sch.menu AS target
  USING (SELECT TRY_CAST(menu_id AS NUMBER) menu_id, TRY_CAST(restaurant_id AS NUMBER) restaurant_id, item_name, description,
                TRY_CAST(price AS NUMBER(10,2)) price, category,
                CASE WHEN LOWER(availability)='true' THEN TRUE ELSE FALSE END availability, item_type,
                TRY_TO_TIMESTAMP_NTZ(created_date) created_dt, TRY_TO_TIMESTAMP_NTZ(modified_date) modified_dt, _stg_file_name
         FROM stage_sch.menu_stm) source
  ON target.menu_id = source.menu_id
  WHEN MATCHED THEN UPDATE SET target.restaurant_id=source.restaurant_id, target.item_name=source.item_name,
       target.description=source.description, target.price=source.price, target.category=source.category,
       target.availability=source.availability, target.item_type=source.item_type, target.modified_dt=source.modified_dt
  WHEN NOT MATCHED THEN INSERT (menu_id,restaurant_id,item_name,description,price,category,availability,item_type,created_dt,modified_dt,_stg_file_name)
       VALUES (source.menu_id,source.restaurant_id,source.item_name,source.description,source.price,source.category,source.availability,source.item_type,source.created_dt,source.modified_dt,source._stg_file_name);

  MERGE INTO clean_sch.delivery_agent AS target
  USING (SELECT TRY_CAST(delivery_agent_id AS NUMBER) delivery_agent_id, name, phone, vehicle_type,
                TRY_CAST(location_id AS NUMBER) location_id, status, gender, TRY_CAST(rating AS NUMBER(4,2)) rating,
                TRY_TO_TIMESTAMP_NTZ(created_date) created_dt, TRY_TO_TIMESTAMP_NTZ(modified_date) modified_dt, _stg_file_name
         FROM stage_sch.delivery_agent_stm) source
  ON target.delivery_agent_id = source.delivery_agent_id
  WHEN MATCHED THEN UPDATE SET target.name=source.name, target.phone=source.phone, target.vehicle_type=source.vehicle_type,
       target.location_id=source.location_id, target.status=source.status, target.gender=source.gender,
       target.rating=source.rating, target.modified_dt=source.modified_dt
  WHEN NOT MATCHED THEN INSERT (delivery_agent_id,name,phone,vehicle_type,location_id,status,gender,rating,created_dt,modified_dt,_stg_file_name)
       VALUES (source.delivery_agent_id,source.name,source.phone,source.vehicle_type,source.location_id,source.status,source.gender,source.rating,source.created_dt,source.modified_dt,source._stg_file_name);

  MERGE INTO clean_sch.customer_address AS target
  USING (SELECT TRY_CAST(address_id AS NUMBER) address_id, TRY_CAST(customer_id AS NUMBER) customer_id,
                flat_no, house_no, floor, building, landmark, locality, city, state, pincode, coordinates,
                CASE WHEN primary_flag='Y' THEN TRUE ELSE FALSE END primary_flag, address_type,
                TRY_TO_TIMESTAMP_NTZ(created_date) created_dt, TRY_TO_TIMESTAMP_NTZ(modified_date) modified_dt, _stg_file_name
         FROM stage_sch.customer_address_stm) source
  ON target.address_id = source.address_id
  WHEN MATCHED THEN UPDATE SET target.customer_id=source.customer_id, target.flat_no=source.flat_no, target.house_no=source.house_no,
       target.floor=source.floor, target.building=source.building, target.landmark=source.landmark, target.locality=source.locality,
       target.city=source.city, target.state=source.state, target.pincode=source.pincode, target.coordinates=source.coordinates,
       target.primary_flag=source.primary_flag, target.address_type=source.address_type, target.modified_dt=source.modified_dt
  WHEN NOT MATCHED THEN INSERT (address_id,customer_id,flat_no,house_no,floor,building,landmark,locality,city,state,pincode,coordinates,primary_flag,address_type,created_dt,modified_dt,_stg_file_name)
       VALUES (source.address_id,source.customer_id,source.flat_no,source.house_no,source.floor,source.building,source.landmark,source.locality,source.city,source.state,source.pincode,source.coordinates,source.primary_flag,source.address_type,source.created_dt,source.modified_dt,source._stg_file_name);

  MERGE INTO clean_sch.orders AS target
  USING (SELECT TRY_CAST(order_id AS NUMBER) order_id, TRY_CAST(customer_id AS NUMBER) customer_id, TRY_CAST(restaurant_id AS NUMBER) restaurant_id,
                TRY_TO_TIMESTAMP_NTZ(order_date) order_date, TRY_CAST(total_amount AS NUMBER(10,2)) total_amount, status, payment_method,
                TRY_TO_TIMESTAMP_NTZ(created_date) created_dt, TRY_TO_TIMESTAMP_NTZ(modified_date) modified_dt, _stg_file_name
         FROM stage_sch.orders_stm) source
  ON target.order_id = source.order_id
  WHEN MATCHED THEN UPDATE SET target.customer_id=source.customer_id, target.restaurant_id=source.restaurant_id,
       target.order_date=source.order_date, target.total_amount=source.total_amount, target.status=source.status,
       target.payment_method=source.payment_method, target.modified_dt=source.modified_dt
  WHEN NOT MATCHED THEN INSERT (order_id,customer_id,restaurant_id,order_date,total_amount,status,payment_method,created_dt,modified_dt,_stg_file_name)
       VALUES (source.order_id,source.customer_id,source.restaurant_id,source.order_date,source.total_amount,source.status,source.payment_method,source.created_dt,source.modified_dt,source._stg_file_name);

  MERGE INTO clean_sch.order_item AS target
  USING (SELECT TRY_CAST(order_item_id AS NUMBER) order_item_id, TRY_CAST(order_id AS NUMBER) order_id, TRY_CAST(menu_id AS NUMBER) menu_id,
                TRY_CAST(quantity AS NUMBER(5,0)) quantity, TRY_CAST(price AS NUMBER(10,2)) price, TRY_CAST(subtotal AS NUMBER(10,2)) subtotal,
                TRY_TO_TIMESTAMP_NTZ(created_date) created_dt, TRY_TO_TIMESTAMP_NTZ(modified_date) modified_dt, _stg_file_name
         FROM stage_sch.order_item_stm) source
  ON target.order_item_id = source.order_item_id
  WHEN MATCHED THEN UPDATE SET target.order_id=source.order_id, target.menu_id=source.menu_id, target.quantity=source.quantity,
       target.price=source.price, target.subtotal=source.subtotal, target.modified_dt=source.modified_dt
  WHEN NOT MATCHED THEN INSERT (order_item_id,order_id,menu_id,quantity,price,subtotal,created_dt,modified_dt,_stg_file_name)
       VALUES (source.order_item_id,source.order_id,source.menu_id,source.quantity,source.price,source.subtotal,source.created_dt,source.modified_dt,source._stg_file_name);

  MERGE INTO clean_sch.delivery AS target
  USING (SELECT TRY_CAST(delivery_id AS NUMBER) delivery_id, TRY_CAST(order_id AS NUMBER) order_id, TRY_CAST(delivery_agent_id AS NUMBER) delivery_agent_id,
                delivery_status, estimated_time, TRY_TO_TIMESTAMP_NTZ(created_date) created_dt, TRY_TO_TIMESTAMP_NTZ(modified_date) modified_dt, _stg_file_name
         FROM stage_sch.delivery_stm) source
  ON target.delivery_id = source.delivery_id
  WHEN MATCHED THEN UPDATE SET target.delivery_status=source.delivery_status, target.estimated_time=source.estimated_time, target.modified_dt=source.modified_dt
  WHEN NOT MATCHED THEN INSERT (delivery_id,order_id,delivery_agent_id,delivery_status,estimated_time,created_dt,modified_dt,_stg_file_name)
       VALUES (source.delivery_id,source.order_id,source.delivery_agent_id,source.delivery_status,source.estimated_time,source.created_dt,source.modified_dt,source._stg_file_name);

  RETURN 'clean layer refresh complete';
END;
$$;

-- ============================================================
-- PROCEDURE 2: DQ checks — FIXED: delivery block added (was missing entirely)
-- ============================================================
CREATE OR REPLACE PROCEDURE common.sp_dq_checks()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
  INSERT INTO common.dq_log (layer_transition, table_name, rows_in, rows_out, null_check_status, fk_check_status, overall_status)
  WITH rc AS (SELECT (SELECT COUNT(*) FROM stage_sch.location) rows_in, (SELECT COUNT(*) FROM clean_sch.location) rows_out),
       nc AS (SELECT COUNT(*) bad_nulls FROM stage_sch.location s JOIN clean_sch.location c ON TRY_CAST(s.location_id AS NUMBER)=c.location_id WHERE s.zipcode IS NOT NULL AND c.zipcode IS NULL)
  SELECT 'stage_to_clean','location',rc.rows_in,rc.rows_out, CASE WHEN nc.bad_nulls=0 THEN 'PASS' ELSE 'FAIL' END, 'N/A',
         CASE WHEN rc.rows_in=rc.rows_out AND nc.bad_nulls=0 THEN 'PASS' ELSE 'FAIL' END
  FROM rc, nc;

  INSERT INTO common.dq_log (layer_transition, table_name, rows_in, rows_out, null_check_status, fk_check_status, overall_status)
  WITH rc AS (SELECT (SELECT COUNT(*) FROM stage_sch.customer) rows_in, (SELECT COUNT(*) FROM clean_sch.customer) rows_out),
       nc AS (SELECT COUNT(*) bad_nulls FROM stage_sch.customer s JOIN clean_sch.customer c ON TRY_CAST(s.customer_id AS NUMBER)=c.customer_id WHERE s.created_date IS NOT NULL AND c.created_dt IS NULL)
  SELECT 'stage_to_clean','customer',rc.rows_in,rc.rows_out, CASE WHEN nc.bad_nulls=0 THEN 'PASS' ELSE 'FAIL' END, 'N/A',
         CASE WHEN rc.rows_in=rc.rows_out AND nc.bad_nulls=0 THEN 'PASS' ELSE 'FAIL' END
  FROM rc, nc;

  INSERT INTO common.dq_log (layer_transition, table_name, rows_in, rows_out, null_check_status, fk_check_status, fk_check_detail, overall_status)
  WITH rc AS (SELECT (SELECT COUNT(*) FROM stage_sch.restaurant) rows_in, (SELECT COUNT(*) FROM clean_sch.restaurant) rows_out),
       nc AS (SELECT COUNT(*) bad_nulls FROM stage_sch.restaurant s JOIN clean_sch.restaurant c ON TRY_CAST(s.restaurant_id AS NUMBER)=c.restaurant_id WHERE s.created_date IS NOT NULL AND c.created_dt IS NULL),
       fk AS (SELECT COUNT(*) orphans FROM clean_sch.restaurant r LEFT JOIN clean_sch.location l ON r.location_id=l.location_id WHERE r.location_id IS NOT NULL AND l.location_id IS NULL)
  SELECT 'stage_to_clean','restaurant',rc.rows_in,rc.rows_out, CASE WHEN nc.bad_nulls=0 THEN 'PASS' ELSE 'FAIL' END,
         CASE WHEN fk.orphans=0 THEN 'PASS' ELSE 'FAIL' END, 'location_id:'||CASE WHEN fk.orphans=0 THEN 'PASS' ELSE 'FAIL('||fk.orphans||')' END,
         CASE WHEN rc.rows_in=rc.rows_out AND nc.bad_nulls=0 AND fk.orphans=0 THEN 'PASS' ELSE 'FAIL' END
  FROM rc, nc, fk;

  INSERT INTO common.dq_log (layer_transition, table_name, rows_in, rows_out, null_check_status, fk_check_status, fk_check_detail, overall_status)
  WITH rc AS (SELECT (SELECT COUNT(*) FROM stage_sch.menu) rows_in, (SELECT COUNT(*) FROM clean_sch.menu) rows_out),
       nc AS (SELECT COUNT(*) bad_nulls FROM stage_sch.menu s JOIN clean_sch.menu c ON TRY_CAST(s.menu_id AS NUMBER)=c.menu_id WHERE s.created_date IS NOT NULL AND c.created_dt IS NULL),
       fk AS (SELECT COUNT(*) orphans FROM clean_sch.menu m LEFT JOIN clean_sch.restaurant r ON m.restaurant_id=r.restaurant_id WHERE m.restaurant_id IS NOT NULL AND r.restaurant_id IS NULL)
  SELECT 'stage_to_clean','menu',rc.rows_in,rc.rows_out, CASE WHEN nc.bad_nulls=0 THEN 'PASS' ELSE 'FAIL' END,
         CASE WHEN fk.orphans=0 THEN 'PASS' ELSE 'FAIL' END, 'restaurant_id:'||CASE WHEN fk.orphans=0 THEN 'PASS' ELSE 'FAIL('||fk.orphans||')' END,
         CASE WHEN rc.rows_in=rc.rows_out AND nc.bad_nulls=0 AND fk.orphans=0 THEN 'PASS' ELSE 'FAIL' END
  FROM rc, nc, fk;

  INSERT INTO common.dq_log (layer_transition, table_name, rows_in, rows_out, null_check_status, fk_check_status, fk_check_detail, overall_status)
  WITH rc AS (SELECT (SELECT COUNT(*) FROM stage_sch.delivery_agent) rows_in, (SELECT COUNT(*) FROM clean_sch.delivery_agent) rows_out),
       nc AS (SELECT COUNT(*) bad_nulls FROM stage_sch.delivery_agent s JOIN clean_sch.delivery_agent c ON TRY_CAST(s.delivery_agent_id AS NUMBER)=c.delivery_agent_id WHERE s.created_date IS NOT NULL AND c.created_dt IS NULL),
       fk AS (SELECT COUNT(*) orphans FROM clean_sch.delivery_agent d LEFT JOIN clean_sch.location l ON d.location_id=l.location_id WHERE d.location_id IS NOT NULL AND l.location_id IS NULL)
  SELECT 'stage_to_clean','delivery_agent',rc.rows_in,rc.rows_out, CASE WHEN nc.bad_nulls=0 THEN 'PASS' ELSE 'FAIL' END,
         CASE WHEN fk.orphans=0 THEN 'PASS' ELSE 'FAIL' END, 'location_id:'||CASE WHEN fk.orphans=0 THEN 'PASS' ELSE 'FAIL('||fk.orphans||')' END,
         CASE WHEN rc.rows_in=rc.rows_out AND nc.bad_nulls=0 AND fk.orphans=0 THEN 'PASS' ELSE 'FAIL' END
  FROM rc, nc, fk;

  INSERT INTO common.dq_log (layer_transition, table_name, rows_in, rows_out, null_check_status, fk_check_status, fk_check_detail, overall_status)
  WITH rc AS (SELECT (SELECT COUNT(*) FROM stage_sch.customer_address) rows_in, (SELECT COUNT(*) FROM clean_sch.customer_address) rows_out),
       nc AS (SELECT COUNT(*) bad_nulls FROM stage_sch.customer_address s JOIN clean_sch.customer_address c ON TRY_CAST(s.address_id AS NUMBER)=c.address_id WHERE s.created_date IS NOT NULL AND c.created_dt IS NULL),
       fk AS (SELECT COUNT(*) orphans FROM clean_sch.customer_address a LEFT JOIN clean_sch.customer cu ON a.customer_id=cu.customer_id WHERE a.customer_id IS NOT NULL AND cu.customer_id IS NULL)
  SELECT 'stage_to_clean','customer_address',rc.rows_in,rc.rows_out, CASE WHEN nc.bad_nulls=0 THEN 'PASS' ELSE 'FAIL' END,
         CASE WHEN fk.orphans=0 THEN 'PASS' ELSE 'FAIL' END, 'customer_id:'||CASE WHEN fk.orphans=0 THEN 'PASS' ELSE 'FAIL('||fk.orphans||')' END,
         CASE WHEN rc.rows_in=rc.rows_out AND nc.bad_nulls=0 AND fk.orphans=0 THEN 'PASS' ELSE 'FAIL' END
  FROM rc, nc, fk;

  INSERT INTO common.dq_log (layer_transition, table_name, rows_in, rows_out, null_check_status, fk_check_status, fk_check_detail, overall_status)
  WITH rc AS (SELECT (SELECT COUNT(*) FROM stage_sch.orders) rows_in, (SELECT COUNT(*) FROM clean_sch.orders) rows_out),
       nc AS (SELECT COUNT(*) bad_nulls FROM stage_sch.orders s JOIN clean_sch.orders c ON TRY_CAST(s.order_id AS NUMBER)=c.order_id WHERE s.created_date IS NOT NULL AND c.created_dt IS NULL),
       fc AS (SELECT COUNT(*) orphans FROM clean_sch.orders o LEFT JOIN clean_sch.customer cu ON o.customer_id=cu.customer_id WHERE o.customer_id IS NOT NULL AND cu.customer_id IS NULL),
       fr AS (SELECT COUNT(*) orphans FROM clean_sch.orders o LEFT JOIN clean_sch.restaurant r ON o.restaurant_id=r.restaurant_id WHERE o.restaurant_id IS NOT NULL AND r.restaurant_id IS NULL)
  SELECT 'stage_to_clean','orders',rc.rows_in,rc.rows_out, CASE WHEN nc.bad_nulls=0 THEN 'PASS' ELSE 'FAIL' END,
         CASE WHEN fc.orphans=0 AND fr.orphans=0 THEN 'PASS' ELSE 'FAIL' END,
         'customer_id:'||CASE WHEN fc.orphans=0 THEN 'PASS' ELSE 'FAIL('||fc.orphans||')' END||';restaurant_id:'||CASE WHEN fr.orphans=0 THEN 'PASS' ELSE 'FAIL('||fr.orphans||')' END,
         CASE WHEN rc.rows_in=rc.rows_out AND nc.bad_nulls=0 AND fc.orphans=0 AND fr.orphans=0 THEN 'PASS' ELSE 'FAIL' END
  FROM rc, nc, fc, fr;

  INSERT INTO common.dq_log (layer_transition, table_name, rows_in, rows_out, null_check_status, fk_check_status, fk_check_detail, overall_status)
  WITH rc AS (SELECT (SELECT COUNT(*) FROM stage_sch.order_item) rows_in, (SELECT COUNT(*) FROM clean_sch.order_item) rows_out),
       nc AS (SELECT COUNT(*) bad_nulls FROM stage_sch.order_item s JOIN clean_sch.order_item c ON TRY_CAST(s.order_item_id AS NUMBER)=c.order_item_id WHERE s.created_date IS NOT NULL AND c.created_dt IS NULL),
       fo AS (SELECT COUNT(*) orphans FROM clean_sch.order_item oi LEFT JOIN clean_sch.orders o ON oi.order_id=o.order_id WHERE oi.order_id IS NOT NULL AND o.order_id IS NULL),
       fm AS (SELECT COUNT(*) orphans FROM clean_sch.order_item oi LEFT JOIN clean_sch.menu m ON oi.menu_id=m.menu_id WHERE oi.menu_id IS NOT NULL AND m.menu_id IS NULL)
  SELECT 'stage_to_clean','order_item',rc.rows_in,rc.rows_out, CASE WHEN nc.bad_nulls=0 THEN 'PASS' ELSE 'FAIL' END,
         CASE WHEN fo.orphans=0 AND fm.orphans=0 THEN 'PASS' ELSE 'FAIL' END,
         'order_id:'||CASE WHEN fo.orphans=0 THEN 'PASS' ELSE 'FAIL('||fo.orphans||')' END||';menu_id:'||CASE WHEN fm.orphans=0 THEN 'PASS' ELSE 'FAIL('||fm.orphans||')' END,
         CASE WHEN rc.rows_in=rc.rows_out AND nc.bad_nulls=0 AND fo.orphans=0 AND fm.orphans=0 THEN 'PASS' ELSE 'FAIL' END
  FROM rc, nc, fo, fm;

  -- DELIVERY: was missing from this procedure entirely until now
  INSERT INTO common.dq_log (layer_transition, table_name, rows_in, rows_out, null_check_status, fk_check_status, fk_check_detail, overall_status)
  WITH rc AS (SELECT (SELECT COUNT(*) FROM stage_sch.delivery) rows_in, (SELECT COUNT(*) FROM clean_sch.delivery) rows_out),
       nc AS (SELECT COUNT(*) bad_nulls FROM stage_sch.delivery s JOIN clean_sch.delivery c ON TRY_CAST(s.delivery_id AS NUMBER)=c.delivery_id WHERE s.created_date IS NOT NULL AND c.created_dt IS NULL),
       fo AS (SELECT COUNT(*) orphans FROM clean_sch.delivery d LEFT JOIN clean_sch.orders o ON d.order_id=o.order_id WHERE o.order_id IS NULL),
       fa AS (SELECT COUNT(*) orphans FROM clean_sch.delivery d LEFT JOIN clean_sch.delivery_agent a ON d.delivery_agent_id=a.delivery_agent_id WHERE a.delivery_agent_id IS NULL)
  SELECT 'stage_to_clean','delivery',rc.rows_in,rc.rows_out, CASE WHEN nc.bad_nulls=0 THEN 'PASS' ELSE 'FAIL' END,
         CASE WHEN fo.orphans=0 AND fa.orphans=0 THEN 'PASS' ELSE 'FAIL' END,
         'order_id:'||CASE WHEN fo.orphans=0 THEN 'PASS' ELSE 'FAIL('||fo.orphans||')' END||';delivery_agent_id:'||CASE WHEN fa.orphans=0 THEN 'PASS' ELSE 'FAIL('||fa.orphans||')' END,
         CASE WHEN rc.rows_in=rc.rows_out AND nc.bad_nulls=0 AND fo.orphans=0 AND fa.orphans=0 THEN 'PASS' ELSE 'FAIL' END
  FROM rc, nc, fo, fa;

  RETURN 'dq checks complete';
END;
$$;

-- ============================================================
-- PROCEDURE 3: clean -> consumption (skipped if latest DQ batch has any FAIL)
-- ============================================================
CREATE OR REPLACE PROCEDURE common.sp_consumption_layer()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
  fail_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO :fail_count
  FROM common.dq_log
  WHERE run_ts >= DATEADD('minute', -5, CURRENT_TIMESTAMP())
    AND overall_status = 'FAIL';

  IF (:fail_count > 0) THEN
    RETURN 'SKIPPED: ' || :fail_count || ' DQ failure(s) in the latest check batch. Consumption layer not refreshed.';
  END IF;

  UPDATE consumption_sch.location_dim d SET eff_end_date=CURRENT_TIMESTAMP(), is_current=FALSE
  FROM clean_sch.location s WHERE d.location_id=s.location_id AND d.is_current=TRUE
    AND (d.city!=s.city OR d.state!=s.state OR NVL(d.zipcode,'')!=NVL(s.zipcode,'') OR d.active_flag!=s.active_flag);
  INSERT INTO consumption_sch.location_dim (location_id,city,state,zipcode,active_flag,eff_start_date,eff_end_date,is_current)
  SELECT s.location_id,s.city,s.state,s.zipcode,s.active_flag,CURRENT_TIMESTAMP(),NULL,TRUE
  FROM clean_sch.location s LEFT JOIN consumption_sch.location_dim d ON s.location_id=d.location_id AND d.is_current=TRUE
  WHERE d.location_id IS NULL;

  UPDATE consumption_sch.customer_dim d SET eff_end_date=CURRENT_TIMESTAMP(), is_current=FALSE
  FROM clean_sch.customer s WHERE d.customer_id=s.customer_id AND d.is_current=TRUE
    AND (NVL(d.name,'')!=NVL(s.name,'') OR NVL(d.mobile,'')!=NVL(s.mobile,'') OR NVL(d.email,'')!=NVL(s.email,'')
         OR NVL(d.gender,'')!=NVL(s.gender,'') OR NVL(d.dob,'1900-01-01')!=NVL(s.dob,'1900-01-01'));
  INSERT INTO consumption_sch.customer_dim (customer_id,name,mobile,email,gender,dob,eff_start_date,eff_end_date,is_current)
  SELECT s.customer_id,s.name,s.mobile,s.email,s.gender,s.dob,CURRENT_TIMESTAMP(),NULL,TRUE
  FROM clean_sch.customer s LEFT JOIN consumption_sch.customer_dim d ON s.customer_id=d.customer_id AND d.is_current=TRUE
  WHERE d.customer_id IS NULL;

  UPDATE consumption_sch.restaurant_dim d SET eff_end_date=CURRENT_TIMESTAMP(), is_current=FALSE
  FROM clean_sch.restaurant s WHERE d.restaurant_id=s.restaurant_id AND d.is_current=TRUE
    AND (NVL(d.name,'')!=NVL(s.name,'') OR NVL(d.cuisine_type,'')!=NVL(s.cuisine_type,'')
         OR NVL(d.pricing_for_two,0)!=NVL(s.pricing_for_two,0) OR d.location_id!=s.location_id
         OR d.active_flag!=s.active_flag OR NVL(d.open_status,'')!=NVL(s.open_status,''));
  INSERT INTO consumption_sch.restaurant_dim (restaurant_id,name,cuisine_type,pricing_for_two,location_id,active_flag,open_status,eff_start_date,eff_end_date,is_current)
  SELECT s.restaurant_id,s.name,s.cuisine_type,s.pricing_for_two,s.location_id,s.active_flag,s.open_status,CURRENT_TIMESTAMP(),NULL,TRUE
  FROM clean_sch.restaurant s LEFT JOIN consumption_sch.restaurant_dim d ON s.restaurant_id=d.restaurant_id AND d.is_current=TRUE
  WHERE d.restaurant_id IS NULL;

  UPDATE consumption_sch.menu_dim d SET eff_end_date=CURRENT_TIMESTAMP(), is_current=FALSE
  FROM clean_sch.menu s WHERE d.menu_id=s.menu_id AND d.is_current=TRUE
    AND (NVL(d.price,0)!=NVL(s.price,0) OR NVL(d.category,'')!=NVL(s.category,'') OR NVL(d.item_type,'')!=NVL(s.item_type,''));
  INSERT INTO consumption_sch.menu_dim (menu_id,restaurant_id,item_name,price,category,item_type,eff_start_date,eff_end_date,is_current)
  SELECT s.menu_id,s.restaurant_id,s.item_name,s.price,s.category,s.item_type,CURRENT_TIMESTAMP(),NULL,TRUE
  FROM clean_sch.menu s LEFT JOIN consumption_sch.menu_dim d ON s.menu_id=d.menu_id AND d.is_current=TRUE
  WHERE d.menu_id IS NULL;

  UPDATE consumption_sch.delivery_agent_dim d SET eff_end_date=CURRENT_TIMESTAMP(), is_current=FALSE
  FROM clean_sch.delivery_agent s WHERE d.delivery_agent_id=s.delivery_agent_id AND d.is_current=TRUE
    AND (NVL(d.status,'')!=NVL(s.status,'') OR NVL(d.rating,0)!=NVL(s.rating,0));
  INSERT INTO consumption_sch.delivery_agent_dim (delivery_agent_id,name,vehicle_type,location_id,status,rating,eff_start_date,eff_end_date,is_current)
  SELECT s.delivery_agent_id,s.name,s.vehicle_type,s.location_id,s.status,s.rating,CURRENT_TIMESTAMP(),NULL,TRUE
  FROM clean_sch.delivery_agent s LEFT JOIN consumption_sch.delivery_agent_dim d ON s.delivery_agent_id=d.delivery_agent_id AND d.is_current=TRUE
  WHERE d.delivery_agent_id IS NULL;

  MERGE INTO consumption_sch.customer_address_dim AS target
  USING clean_sch.customer_address AS source ON target.address_id=source.address_id
  WHEN MATCHED THEN UPDATE SET target.customer_id=source.customer_id, target.city=source.city, target.state=source.state, target.address_type=source.address_type
  WHEN NOT MATCHED THEN INSERT (address_id,customer_id,city,state,address_type) VALUES (source.address_id,source.customer_id,source.city,source.state,source.address_type);

  MERGE INTO consumption_sch.order_item_fact AS target
  USING (
    SELECT oi.order_item_id, oi.order_id, cd.customer_dim_sk, rd.restaurant_dim_sk, ld.location_dim_sk,
           md.menu_dim_sk, dd.date_dim_sk, da.delivery_agent_dim_sk, dl.delivery_status, dl.estimated_time,
           oi.quantity, oi.price, oi.subtotal, o.status order_status, o.payment_method
    FROM clean_sch.order_item oi
    JOIN clean_sch.orders o ON oi.order_id=o.order_id
    JOIN clean_sch.delivery dl ON o.order_id=dl.order_id
    JOIN consumption_sch.customer_dim cd ON o.customer_id=cd.customer_id AND cd.is_current=TRUE
    JOIN consumption_sch.restaurant_dim rd ON o.restaurant_id=rd.restaurant_id AND rd.is_current=TRUE
    JOIN consumption_sch.location_dim ld ON rd.location_id=ld.location_id AND ld.is_current=TRUE
    JOIN consumption_sch.menu_dim md ON oi.menu_id=md.menu_id AND md.is_current=TRUE
    JOIN consumption_sch.date_dim dd ON dd.calendar_date=DATE(o.order_date)
    JOIN consumption_sch.delivery_agent_dim da ON dl.delivery_agent_id=da.delivery_agent_id AND da.is_current=TRUE
  ) AS source
  ON target.order_item_id = source.order_item_id
  WHEN MATCHED THEN UPDATE SET target.customer_dim_sk=source.customer_dim_sk, target.restaurant_dim_sk=source.restaurant_dim_sk,
       target.location_dim_sk=source.location_dim_sk, target.menu_dim_sk=source.menu_dim_sk, target.date_dim_sk=source.date_dim_sk,
       target.delivery_agent_dim_sk=source.delivery_agent_dim_sk, target.delivery_status=source.delivery_status,
       target.estimated_time=source.estimated_time, target.quantity=source.quantity, target.price=source.price,
       target.subtotal=source.subtotal, target.order_status=source.order_status, target.payment_method=source.payment_method
  WHEN NOT MATCHED THEN INSERT (order_item_id,order_id,customer_dim_sk,restaurant_dim_sk,location_dim_sk,menu_dim_sk,date_dim_sk,delivery_agent_dim_sk,delivery_status,estimated_time,quantity,price,subtotal,order_status,payment_method)
       VALUES (source.order_item_id,source.order_id,source.customer_dim_sk,source.restaurant_dim_sk,source.location_dim_sk,source.menu_dim_sk,source.date_dim_sk,source.delivery_agent_dim_sk,source.delivery_status,source.estimated_time,source.quantity,source.price,source.subtotal,source.order_status,source.payment_method);

  RETURN 'consumption layer refresh complete';
END;
$$;

-- ============================================================
-- TASKS: chained, scheduled daily
-- ============================================================
CREATE OR REPLACE TASK common.task_clean_layer
  WAREHOUSE = freshcart_wh
  SCHEDULE = 'USING CRON 0 2 * * * UTC'
AS
  CALL common.sp_clean_layer();

CREATE OR REPLACE TASK common.task_dq_checks
  WAREHOUSE = freshcart_wh
  AFTER common.task_clean_layer
AS
  CALL common.sp_dq_checks();

CREATE OR REPLACE TASK common.task_consumption_layer
  WAREHOUSE = freshcart_wh
  AFTER common.task_dq_checks
AS
  CALL common.sp_consumption_layer();

-- Children resume before root — Snowflake requires this order for a task DAG.
ALTER TASK common.task_consumption_layer RESUME;
ALTER TASK common.task_dq_checks RESUME;
ALTER TASK common.task_clean_layer RESUME;