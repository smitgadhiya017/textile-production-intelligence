-- ============================================================================
-- TEXTILE PRODUCTION WASTE, DEFECT & MACHINE INTELLIGENCE SYSTEM
-- Script: 06_data_validation.sql
-- Description: Comprehensive data validation suite verifying row counts,
--              Primary Key uniqueness, Foreign Key referential integrity,
--              chronological consistency, quantitative bounds, and financial
--              reconciliation across all 26 tables.
-- ============================================================================

-- ============================================================================
-- 1. TABLE ROW COUNTS AUDIT
-- ============================================================================

SELECT 'locations' AS table_name, COUNT(*) AS record_count, CASE WHEN COUNT(*) BETWEEN 30 AND 80 THEN 'PASS' ELSE 'FAIL' END AS status FROM locations
UNION ALL SELECT 'machine_types', COUNT(*), CASE WHEN COUNT(*) BETWEEN 8 AND 15 THEN 'PASS' ELSE 'FAIL' END FROM machine_types
UNION ALL SELECT 'shifts', COUNT(*), CASE WHEN COUNT(*) BETWEEN 3 AND 6 THEN 'PASS' ELSE 'FAIL' END FROM shifts
UNION ALL SELECT 'defect_types', COUNT(*), CASE WHEN COUNT(*) BETWEEN 15 AND 30 THEN 'PASS' ELSE 'FAIL' END FROM defect_types
UNION ALL SELECT 'plants', COUNT(*), CASE WHEN COUNT(*) BETWEEN 5 AND 10 THEN 'PASS' ELSE 'FAIL' END FROM plants
UNION ALL SELECT 'products', COUNT(*), CASE WHEN COUNT(*) BETWEEN 40 AND 100 THEN 'PASS' ELSE 'FAIL' END FROM products
UNION ALL SELECT 'materials', COUNT(*), CASE WHEN COUNT(*) BETWEEN 40 AND 80 THEN 'PASS' ELSE 'FAIL' END FROM materials
UNION ALL SELECT 'suppliers', COUNT(*), CASE WHEN COUNT(*) BETWEEN 80 AND 200 THEN 'PASS' ELSE 'FAIL' END FROM suppliers
UNION ALL SELECT 'customers', COUNT(*), CASE WHEN COUNT(*) BETWEEN 150 AND 300 THEN 'PASS' ELSE 'FAIL' END FROM customers
UNION ALL SELECT 'production_lines', COUNT(*), CASE WHEN COUNT(*) BETWEEN 15 AND 40 THEN 'PASS' ELSE 'FAIL' END FROM production_lines
UNION ALL SELECT 'employees', COUNT(*), CASE WHEN COUNT(*) BETWEEN 300 AND 800 THEN 'PASS' ELSE 'FAIL' END FROM employees
UNION ALL SELECT 'machines', COUNT(*), CASE WHEN COUNT(*) BETWEEN 100 AND 200 THEN 'PASS' ELSE 'FAIL' END FROM machines
UNION ALL SELECT 'customer_orders', COUNT(*), CASE WHEN COUNT(*) BETWEEN 1500 AND 4000 THEN 'PASS' ELSE 'FAIL' END FROM customer_orders
UNION ALL SELECT 'purchase_orders', COUNT(*), CASE WHEN COUNT(*) BETWEEN 1000 AND 2500 THEN 'PASS' ELSE 'FAIL' END FROM purchase_orders
UNION ALL SELECT 'purchase_order_items', COUNT(*), CASE WHEN COUNT(*) BETWEEN 2500 AND 6000 THEN 'PASS' ELSE 'FAIL' END FROM purchase_order_items
UNION ALL SELECT 'material_batches', COUNT(*), CASE WHEN COUNT(*) BETWEEN 1000 AND 3000 THEN 'PASS' ELSE 'FAIL' END FROM material_batches
UNION ALL SELECT 'production_orders', COUNT(*), CASE WHEN COUNT(*) BETWEEN 2000 AND 4000 THEN 'PASS' ELSE 'FAIL' END FROM production_orders
UNION ALL SELECT 'production_runs', COUNT(*), CASE WHEN COUNT(*) BETWEEN 8000 AND 15000 THEN 'PASS' ELSE 'FAIL' END FROM production_runs
UNION ALL SELECT 'material_consumption', COUNT(*), CASE WHEN COUNT(*) BETWEEN 10000 AND 20000 THEN 'PASS' ELSE 'FAIL' END FROM material_consumption
UNION ALL SELECT 'fabric_rolls', COUNT(*), CASE WHEN COUNT(*) BETWEEN 10000 AND 20000 THEN 'PASS' ELSE 'FAIL' END FROM fabric_rolls
UNION ALL SELECT 'quality_inspections', COUNT(*), CASE WHEN COUNT(*) BETWEEN 10000 AND 20000 THEN 'PASS' ELSE 'FAIL' END FROM quality_inspections
UNION ALL SELECT 'defect_records', COUNT(*), CASE WHEN COUNT(*) BETWEEN 15000 AND 30000 THEN 'PASS' ELSE 'FAIL' END FROM defect_records
UNION ALL SELECT 'rework_records', COUNT(*), CASE WHEN COUNT(*) BETWEEN 2000 AND 7000 THEN 'PASS' ELSE 'FAIL' END FROM rework_records
UNION ALL SELECT 'machine_downtime', COUNT(*), CASE WHEN COUNT(*) BETWEEN 5000 AND 12000 THEN 'PASS' ELSE 'FAIL' END FROM machine_downtime
UNION ALL SELECT 'machine_maintenance', COUNT(*), CASE WHEN COUNT(*) BETWEEN 2000 AND 6000 THEN 'PASS' ELSE 'FAIL' END FROM machine_maintenance
UNION ALL SELECT 'production_waste', COUNT(*), CASE WHEN COUNT(*) BETWEEN 5000 AND 12000 THEN 'PASS' ELSE 'FAIL' END FROM production_waste;

-- ============================================================================
-- 2. PRIMARY KEY UNIQUENESS & NOT NULL AUDIT
-- ============================================================================

SELECT 'PK Uniqueness Check: locations' AS check_name, COUNT(*) - COUNT(DISTINCT location_id) AS duplicate_count, CASE WHEN COUNT(*) = COUNT(DISTINCT location_id) THEN 'PASS' ELSE 'FAIL' END AS status FROM locations
UNION ALL SELECT 'PK Uniqueness Check: machines', COUNT(*) - COUNT(DISTINCT machine_id), CASE WHEN COUNT(*) = COUNT(DISTINCT machine_id) THEN 'PASS' ELSE 'FAIL' END FROM machines
UNION ALL SELECT 'PK Uniqueness Check: employees', COUNT(*) - COUNT(DISTINCT employee_id), CASE WHEN COUNT(*) = COUNT(DISTINCT employee_id) THEN 'PASS' ELSE 'FAIL' END FROM employees
UNION ALL SELECT 'PK Uniqueness Check: customer_orders', COUNT(*) - COUNT(DISTINCT order_id), CASE WHEN COUNT(*) = COUNT(DISTINCT order_id) THEN 'PASS' ELSE 'FAIL' END FROM customer_orders
UNION ALL SELECT 'PK Uniqueness Check: production_orders', COUNT(*) - COUNT(DISTINCT prod_order_id), CASE WHEN COUNT(*) = COUNT(DISTINCT prod_order_id) THEN 'PASS' ELSE 'FAIL' END FROM production_orders
UNION ALL SELECT 'PK Uniqueness Check: production_runs', COUNT(*) - COUNT(DISTINCT run_id), CASE WHEN COUNT(*) = COUNT(DISTINCT run_id) THEN 'PASS' ELSE 'FAIL' END FROM production_runs
UNION ALL SELECT 'PK Uniqueness Check: fabric_rolls', COUNT(*) - COUNT(DISTINCT roll_id), CASE WHEN COUNT(*) = COUNT(DISTINCT roll_id) THEN 'PASS' ELSE 'FAIL' END FROM fabric_rolls
UNION ALL SELECT 'PK Uniqueness Check: quality_inspections', COUNT(*) - COUNT(DISTINCT inspection_id), CASE WHEN COUNT(*) = COUNT(DISTINCT inspection_id) THEN 'PASS' ELSE 'FAIL' END FROM quality_inspections
UNION ALL SELECT 'PK Uniqueness Check: defect_records', COUNT(*) - COUNT(DISTINCT defect_id), CASE WHEN COUNT(*) = COUNT(DISTINCT defect_id) THEN 'PASS' ELSE 'FAIL' END FROM defect_records;

-- ============================================================================
-- 3. UNIQUE BUSINESS KEYS INTEGRITY AUDIT
-- ============================================================================

SELECT 'Unique Key: plant_code' AS business_key, COUNT(*) - COUNT(DISTINCT plant_code) AS duplicates FROM plants
UNION ALL SELECT 'Unique Key: machine_code', COUNT(*) - COUNT(DISTINCT machine_code) FROM machines
UNION ALL SELECT 'Unique Key: employee_code', COUNT(*) - COUNT(DISTINCT employee_code) FROM employees
UNION ALL SELECT 'Unique Key: product_code', COUNT(*) - COUNT(DISTINCT product_code) FROM products
UNION ALL SELECT 'Unique Key: material_code', COUNT(*) - COUNT(DISTINCT material_code) FROM materials
UNION ALL SELECT 'Unique Key: supplier_code', COUNT(*) - COUNT(DISTINCT supplier_code) FROM suppliers
UNION ALL SELECT 'Unique Key: batch_code', COUNT(*) - COUNT(DISTINCT batch_code) FROM material_batches
UNION ALL SELECT 'Unique Key: run_code', COUNT(*) - COUNT(DISTINCT run_code) FROM production_runs
UNION ALL SELECT 'Unique Key: roll_barcode', COUNT(*) - COUNT(DISTINCT roll_barcode) FROM fabric_rolls
UNION ALL SELECT 'Unique Key: inspection_code', COUNT(*) - COUNT(DISTINCT inspection_code) FROM quality_inspections
UNION ALL SELECT 'Unique Key: maintenance_code', COUNT(*) - COUNT(DISTINCT maintenance_code) FROM machine_maintenance;

-- ============================================================================
-- 4. FOREIGN KEY REFERENTIAL INTEGRITY AUDIT (ZERO ORPHAN RECORDS)
-- ============================================================================

-- Orphan Check on Production Runs -> Machines
SELECT 'Orphan Check: production_runs.machine_id' AS fk_check, COUNT(*) AS orphan_count, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status 
FROM production_runs pr LEFT JOIN machines m ON pr.machine_id = m.machine_id WHERE m.machine_id IS NULL
UNION ALL
-- Orphan Check on Production Runs -> Employees (Operators)
SELECT 'Orphan Check: production_runs.operator_id', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END 
FROM production_runs pr LEFT JOIN employees e ON pr.operator_id = e.employee_id WHERE e.employee_id IS NULL
UNION ALL
-- Orphan Check on Material Consumption -> Batches
SELECT 'Orphan Check: material_consumption.batch_id', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END 
FROM material_consumption mc LEFT JOIN material_batches mb ON mc.batch_id = mb.batch_id WHERE mb.batch_id IS NULL
UNION ALL
-- Orphan Check on Fabric Rolls -> Production Runs
SELECT 'Orphan Check: fabric_rolls.run_id', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END 
FROM fabric_rolls fr LEFT JOIN production_runs pr ON fr.run_id = pr.run_id WHERE pr.run_id IS NULL
UNION ALL
-- Orphan Check on Quality Inspections -> Fabric Rolls
SELECT 'Orphan Check: quality_inspections.roll_id', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END 
FROM quality_inspections qi LEFT JOIN fabric_rolls fr ON qi.roll_id = fr.roll_id WHERE fr.roll_id IS NULL
UNION ALL
-- Orphan Check on Defect Records -> Defect Types
SELECT 'Orphan Check: defect_records.defect_type_id', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END 
FROM defect_records dr LEFT JOIN defect_types dt ON dr.defect_type_id = dt.defect_type_id WHERE dt.defect_type_id IS NULL
UNION ALL
-- Orphan Check on Rework Records -> Fabric Rolls
SELECT 'Orphan Check: rework_records.roll_id', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END 
FROM rework_records rr LEFT JOIN fabric_rolls fr ON rr.roll_id = fr.roll_id WHERE fr.roll_id IS NULL
UNION ALL
-- Orphan Check on Machine Downtime -> Machines
SELECT 'Orphan Check: machine_downtime.machine_id', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END 
FROM machine_downtime md LEFT JOIN machines m ON md.machine_id = m.machine_id WHERE m.machine_id IS NULL
UNION ALL
-- Orphan Check on Machine Maintenance -> Machines
SELECT 'Orphan Check: machine_maintenance.machine_id', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END 
FROM machine_maintenance mm LEFT JOIN machines m ON mm.machine_id = m.machine_id WHERE m.machine_id IS NULL
UNION ALL
-- Orphan Check on Production Waste -> Materials
SELECT 'Orphan Check: production_waste.material_id', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END 
FROM production_waste pw LEFT JOIN materials m ON pw.material_id = m.material_id WHERE m.material_id IS NULL;

-- ============================================================================
-- 5. CHRONOLOGICAL LIFECYCLE & TEMPORAL CONSISTENCY AUDIT
-- ============================================================================

-- Check: PO Expected Delivery Date >= Order Date
SELECT 'Temporal Check: PO Expected >= Order Date' AS test_name, COUNT(*) AS violations, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM purchase_orders WHERE expected_delivery_date < order_date
UNION ALL
-- Check: PO Actual Delivery Date >= Order Date
SELECT 'Temporal Check: PO Actual >= Order Date', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM purchase_orders WHERE actual_delivery_date IS NOT NULL AND actual_delivery_date < order_date
UNION ALL
-- Check: Production Order Target End Date >= Target Start Date
SELECT 'Temporal Check: Work Order Target End >= Start Date', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM production_orders WHERE target_end_date < target_start_date
UNION ALL
-- Check: Production Run End Time > Start Time
SELECT 'Temporal Check: Run End Time > Start Time', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM production_runs WHERE end_time <= start_time
UNION ALL
-- Check: Machine Downtime End Time > Start Time
SELECT 'Temporal Check: Downtime End Time > Start Time', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM machine_downtime WHERE end_time <= start_time
UNION ALL
-- Check: Quality Inspection Date >= Fabric Roll Produced At
SELECT 'Temporal Check: Inspection Date >= Roll Produced Time', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM quality_inspections qi JOIN fabric_rolls fr ON qi.roll_id = fr.roll_id WHERE qi.inspection_date < fr.produced_at
UNION ALL
-- Check: Maintenance Completion Date >= Scheduled Date
SELECT 'Temporal Check: Maintenance Completion >= Scheduled Date', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM machine_maintenance WHERE completion_date IS NOT NULL AND completion_date < scheduled_date;

-- ============================================================================
-- 6. QUANTITATIVE DOMAIN & NUMERICAL BOUNDS AUDIT
-- ============================================================================

-- Check: Quality Score bound within 0.00 and 100.00
SELECT 'Domain Check: Quality Score Between 0 and 100' AS test_name, COUNT(*) AS violations, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM quality_inspections WHERE quality_score < 0.00 OR quality_score > 100.00
UNION ALL
-- Check: Defect Points strictly in (1, 2, 3, 4)
SELECT 'Domain Check: Defect Points in (1,2,3,4)', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM defect_records WHERE defect_points NOT IN (1, 2, 3, 4)
UNION ALL
-- Check: All Produced Roll Lengths > 0
SELECT 'Domain Check: Fabric Roll Length > 0', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM fabric_rolls WHERE roll_length_meters <= 0.00
UNION ALL
-- Check: Waste Quantities > 0
SELECT 'Domain Check: Waste Quantity > 0', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM production_waste WHERE waste_quantity <= 0.00
UNION ALL
-- Check: Production Speeds > 0
SELECT 'Domain Check: Machine Run Speeds > 0', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM production_runs WHERE actual_speed_rpm <= 0 OR planned_speed_rpm <= 0;

-- ============================================================================
-- 7. FINANCIAL RECONCILIATION & VALUE CONSISTENCY AUDIT
-- ============================================================================

-- Check: Waste Financial Loss Consistency (net_loss = total_cost - salvage)
SELECT 'Financial Check: Net Waste Loss Calculation' AS test_name, COUNT(*) AS discrepancy_count, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM production_waste WHERE ABS(net_financial_loss - (total_waste_cost - salvage_recovery_value)) > 0.02
UNION ALL
-- Check: Maintenance Total Cost Consistency (total = labor + parts)
SELECT 'Financial Check: Total Maintenance Cost Calculation', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM machine_maintenance WHERE ABS(total_maintenance_cost - (labor_cost + replacement_parts_cost)) > 0.02
UNION ALL
-- Check: Product Selling Price >= Standard Manufacturing Cost
SELECT 'Financial Check: Product Price >= Cost', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM products WHERE selling_price_per_meter < standard_cost_per_meter;
