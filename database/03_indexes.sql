-- ============================================================================
-- TEXTILE PRODUCTION WASTE, DEFECT & MACHINE INTELLIGENCE SYSTEM
-- Script: 03_indexes.sql
-- Description: Creates performance indexes on all 26 normalized tables.
--              Includes Foreign Key join accelerators, composite analytical
--              indexes, time-series lookup indexes, and partial indexes
--              for operational alert queries.
-- ============================================================================

-- ============================================================================
-- 1. FOREIGN KEY & JOIN ACCELERATION INDEXES (B-TREE)
-- ============================================================================

-- Master Tier Joins
CREATE INDEX IF NOT EXISTS idx_plants_location_id 
    ON plants(location_id);

CREATE INDEX IF NOT EXISTS idx_production_lines_plant_id 
    ON production_lines(plant_id);

CREATE INDEX IF NOT EXISTS idx_employees_plant_id 
    ON employees(plant_id);

CREATE INDEX IF NOT EXISTS idx_machines_line_id 
    ON machines(line_id);

CREATE INDEX IF NOT EXISTS idx_machines_type_id 
    ON machines(machine_type_id);

CREATE INDEX IF NOT EXISTS idx_suppliers_location_id 
    ON suppliers(location_id);

CREATE INDEX IF NOT EXISTS idx_customers_location_id 
    ON customers(location_id);

-- Procurement & Inventory Joins
CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_id 
    ON purchase_orders(supplier_id);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_plant_id 
    ON purchase_orders(plant_id);

CREATE INDEX IF NOT EXISTS idx_po_items_po_id 
    ON purchase_order_items(po_id);

CREATE INDEX IF NOT EXISTS idx_po_items_material_id 
    ON purchase_order_items(material_id);

CREATE INDEX IF NOT EXISTS idx_batches_po_item_id 
    ON material_batches(po_item_id);

CREATE INDEX IF NOT EXISTS idx_batches_material_id 
    ON material_batches(material_id);

CREATE INDEX IF NOT EXISTS idx_batches_supplier_id 
    ON material_batches(supplier_id);

-- Customer Orders & Production Planning Joins
CREATE INDEX IF NOT EXISTS idx_customer_orders_customer_id 
    ON customer_orders(customer_id);

CREATE INDEX IF NOT EXISTS idx_customer_orders_product_id 
    ON customer_orders(product_id);

CREATE INDEX IF NOT EXISTS idx_prod_orders_customer_order_id 
    ON production_orders(customer_order_id);

CREATE INDEX IF NOT EXISTS idx_prod_orders_product_id 
    ON production_orders(product_id);

CREATE INDEX IF NOT EXISTS idx_prod_orders_plant_id 
    ON production_orders(plant_id);

-- Production Execution Joins
CREATE INDEX IF NOT EXISTS idx_prod_runs_prod_order_id 
    ON production_runs(prod_order_id);

CREATE INDEX IF NOT EXISTS idx_prod_runs_machine_id 
    ON production_runs(machine_id);

CREATE INDEX IF NOT EXISTS idx_prod_runs_line_id 
    ON production_runs(line_id);

CREATE INDEX IF NOT EXISTS idx_prod_runs_product_id 
    ON production_runs(product_id);

CREATE INDEX IF NOT EXISTS idx_prod_runs_operator_id 
    ON production_runs(operator_id);

CREATE INDEX IF NOT EXISTS idx_prod_runs_shift_id 
    ON production_runs(shift_id);

-- Operational Execution & Output Joins
CREATE INDEX IF NOT EXISTS idx_material_consumption_run_id 
    ON material_consumption(run_id);

CREATE INDEX IF NOT EXISTS idx_material_consumption_batch_id 
    ON material_consumption(batch_id);

CREATE INDEX IF NOT EXISTS idx_material_consumption_material_id 
    ON material_consumption(material_id);

CREATE INDEX IF NOT EXISTS idx_fabric_rolls_run_id 
    ON fabric_rolls(run_id);

CREATE INDEX IF NOT EXISTS idx_fabric_rolls_product_id 
    ON fabric_rolls(product_id);

-- Quality & Defects Joins
CREATE INDEX IF NOT EXISTS idx_quality_inspections_roll_id 
    ON quality_inspections(roll_id);

CREATE INDEX IF NOT EXISTS idx_quality_inspections_inspector_id 
    ON quality_inspections(inspector_id);

CREATE INDEX IF NOT EXISTS idx_defect_records_inspection_id 
    ON defect_records(inspection_id);

CREATE INDEX IF NOT EXISTS idx_defect_records_roll_id 
    ON defect_records(roll_id);

CREATE INDEX IF NOT EXISTS idx_defect_records_type_id 
    ON defect_records(defect_type_id);

CREATE INDEX IF NOT EXISTS idx_rework_records_roll_id 
    ON rework_records(roll_id);

CREATE INDEX IF NOT EXISTS idx_rework_records_defect_id 
    ON rework_records(defect_id);

CREATE INDEX IF NOT EXISTS idx_rework_records_operator_id 
    ON rework_records(operator_id);

-- Machine Downtime, Maintenance & Waste Joins
CREATE INDEX IF NOT EXISTS idx_downtime_machine_id 
    ON machine_downtime(machine_id);

CREATE INDEX IF NOT EXISTS idx_downtime_run_id 
    ON machine_downtime(run_id);

CREATE INDEX IF NOT EXISTS idx_downtime_shift_id 
    ON machine_downtime(shift_id);

CREATE INDEX IF NOT EXISTS idx_maintenance_machine_id 
    ON machine_maintenance(machine_id);

CREATE INDEX IF NOT EXISTS idx_maintenance_technician_id 
    ON machine_maintenance(technician_id);

CREATE INDEX IF NOT EXISTS idx_waste_run_id 
    ON production_waste(run_id);

CREATE INDEX IF NOT EXISTS idx_waste_material_id 
    ON production_waste(material_id);

-- ============================================================================
-- 2. COMPOSITE ANALYTICAL & TIME-SERIES INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_prod_runs_machine_date 
    ON production_runs(machine_id, run_date);

CREATE INDEX IF NOT EXISTS idx_prod_runs_product_date 
    ON production_runs(product_id, run_date);

CREATE INDEX IF NOT EXISTS idx_prod_runs_operator_shift_date 
    ON production_runs(operator_id, shift_id, run_date);

CREATE INDEX IF NOT EXISTS idx_consumption_batch_date 
    ON material_consumption(batch_id, consumed_at);

CREATE INDEX IF NOT EXISTS idx_inspections_date_score 
    ON quality_inspections(inspection_date, quality_score);

CREATE INDEX IF NOT EXISTS idx_defects_type_detected 
    ON defect_records(defect_type_id, detected_at);

CREATE INDEX IF NOT EXISTS idx_downtime_machine_time 
    ON machine_downtime(machine_id, start_time, duration_hours);

CREATE INDEX IF NOT EXISTS idx_maintenance_machine_sched 
    ON machine_maintenance(machine_id, scheduled_date, maintenance_status);

CREATE INDEX IF NOT EXISTS idx_waste_material_recorded 
    ON production_waste(material_id, recorded_at, net_financial_loss);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_date 
    ON purchase_orders(supplier_id, order_date, status);

CREATE INDEX IF NOT EXISTS idx_batches_supplier_status 
    ON material_batches(supplier_id, quality_status, received_date);

-- ============================================================================
-- 3. PARTIAL INDEXES (OPERATIONAL ALERTS & ABNORMAL EVENT FILTERING)
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_part_runs_active 
    ON production_runs(run_id, machine_id, run_status) 
    WHERE run_status IN ('In Progress', 'Interrupted');

CREATE INDEX IF NOT EXISTS idx_part_inspections_failed 
    ON quality_inspections(roll_id, quality_score, inspection_date) 
    WHERE inspection_result = 'Fail';

CREATE INDEX IF NOT EXISTS idx_part_defects_critical 
    ON defect_records(defect_type_id, detected_at) 
    WHERE severity = 'Critical';

CREATE INDEX IF NOT EXISTS idx_part_downtime_unplanned 
    ON machine_downtime(machine_id, start_time, duration_hours) 
    WHERE downtime_category = 'Unplanned Breakdown';

CREATE INDEX IF NOT EXISTS idx_part_batches_rejected 
    ON material_batches(supplier_id, material_id, received_date) 
    WHERE quality_status = 'Rejected';

CREATE INDEX IF NOT EXISTS idx_part_cust_orders_delayed 
    ON customer_orders(order_id, customer_id, promised_delivery_date) 
    WHERE order_status IN ('Pending', 'In Production', 'Delayed');
