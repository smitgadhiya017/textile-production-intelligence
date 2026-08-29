-- ============================================================================
-- TEXTILE PRODUCTION WASTE, DEFECT & MACHINE INTELLIGENCE SYSTEM
-- Script: 02_create_tables.sql
-- Description: DDL script creating all 26 normalized relational tables (3NF)
--              with comprehensive Primary Keys, Foreign Keys, Unique Keys,
--              NOT NULL constraints, and CHECK constraints.
-- ============================================================================

-- Drop tables in reverse hierarchical dependency order if re-executing
DROP TABLE IF EXISTS rework_records CASCADE;
DROP TABLE IF EXISTS defect_records CASCADE;
DROP TABLE IF EXISTS quality_inspections CASCADE;
DROP TABLE IF EXISTS fabric_rolls CASCADE;
DROP TABLE IF EXISTS production_waste CASCADE;
DROP TABLE IF EXISTS material_consumption CASCADE;
DROP TABLE IF EXISTS machine_downtime CASCADE;
DROP TABLE IF EXISTS machine_maintenance CASCADE;
DROP TABLE IF EXISTS production_runs CASCADE;
DROP TABLE IF EXISTS production_orders CASCADE;
DROP TABLE IF EXISTS material_batches CASCADE;
DROP TABLE IF EXISTS purchase_order_items CASCADE;
DROP TABLE IF EXISTS purchase_orders CASCADE;
DROP TABLE IF EXISTS customer_orders CASCADE;
DROP TABLE IF EXISTS machines CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS production_lines CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;
DROP TABLE IF EXISTS materials CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS plants CASCADE;
DROP TABLE IF EXISTS defect_types CASCADE;
DROP TABLE IF EXISTS shifts CASCADE;
DROP TABLE IF EXISTS machine_types CASCADE;
DROP TABLE IF EXISTS locations CASCADE;

-- ============================================================================
-- 1. MASTER TABLES (LEVEL 0 - ZERO FOREIGN KEY DEPENDENCIES)
-- ============================================================================

CREATE TABLE locations (
    location_id SERIAL PRIMARY KEY,
    location_name VARCHAR(100) NOT NULL,
    address_line1 VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state_province VARCHAR(100) NOT NULL,
    country VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE machine_types (
    machine_type_id SERIAL PRIMARY KEY,
    type_code VARCHAR(20) NOT NULL UNIQUE,
    type_name VARCHAR(100) NOT NULL,
    process_stage VARCHAR(50) NOT NULL,
    standard_speed_rpm INTEGER NOT NULL CHECK (standard_speed_rpm > 0),
    power_consumption_kwh NUMERIC(8, 2) NOT NULL CHECK (power_consumption_kwh > 0.00),
    expected_lifespan_years INTEGER NOT NULL CHECK (expected_lifespan_years > 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_mt_process_stage CHECK (process_stage IN ('Spinning', 'Weaving', 'Knitting', 'Dyeing', 'Printing', 'Finishing'))
);

CREATE TABLE shifts (
    shift_id SERIAL PRIMARY KEY,
    shift_code VARCHAR(10) NOT NULL UNIQUE,
    shift_name VARCHAR(50) NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    duration_hours NUMERIC(4, 2) NOT NULL CHECK (duration_hours > 0.00 AND duration_hours <= 24.00),
    is_night_shift BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE defect_types (
    defect_type_id SERIAL PRIMARY KEY,
    defect_code VARCHAR(20) NOT NULL UNIQUE,
    defect_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    severity_level VARCHAR(20) NOT NULL,
    standard_penalty_points INTEGER NOT NULL,
    standard_scrapping_cost_per_defect NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (standard_scrapping_cost_per_defect >= 0.00),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_defect_category CHECK (category IN ('Yarn Defect', 'Weaving Defect', 'Knitting Defect', 'Dyeing Defect', 'Finishing Defect', 'Handling Defect')),
    CONSTRAINT chk_defect_severity CHECK (severity_level IN ('Minor', 'Major', 'Critical')),
    CONSTRAINT chk_defect_penalty_points CHECK (standard_penalty_points IN (1, 2, 3, 4))
);

-- ============================================================================
-- 2. MASTER TABLES (LEVEL 1 - SINGLE FK DEPENDENCIES)
-- ============================================================================

CREATE TABLE plants (
    plant_id SERIAL PRIMARY KEY,
    plant_code VARCHAR(20) NOT NULL UNIQUE,
    plant_name VARCHAR(100) NOT NULL,
    location_id INTEGER NOT NULL REFERENCES locations(location_id) ON DELETE RESTRICT,
    manager_name VARCHAR(100) NOT NULL,
    total_capacity_meters_per_day NUMERIC(12, 2) NOT NULL CHECK (total_capacity_meters_per_day > 0.00),
    operational_status VARCHAR(20) NOT NULL DEFAULT 'Active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_plant_status CHECK (operational_status IN ('Active', 'Maintenance', 'Decommissioned'))
);

CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_code VARCHAR(30) NOT NULL UNIQUE,
    product_name VARCHAR(150) NOT NULL,
    fabric_type VARCHAR(50) NOT NULL,
    weave_type VARCHAR(50) NOT NULL,
    density_gsm NUMERIC(8, 2) NOT NULL CHECK (density_gsm > 0.00),
    standard_cost_per_meter NUMERIC(10, 2) NOT NULL CHECK (standard_cost_per_meter > 0.00),
    selling_price_per_meter NUMERIC(10, 2) NOT NULL CHECK (selling_price_per_meter > 0.00),
    complexity_tier VARCHAR(20) NOT NULL DEFAULT 'Medium',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_prod_fabric_type CHECK (fabric_type IN ('Cotton', 'Denim', 'Polyester', 'Viscose', 'Rayon', 'Linen', 'Cotton Blend', 'Synthetic Fabric', 'Knitted Fabric', 'Dyed Fabric', 'Printed Fabric')),
    CONSTRAINT chk_prod_complexity CHECK (complexity_tier IN ('Low', 'Medium', 'High', 'Extreme')),
    CONSTRAINT chk_prod_price_gt_cost CHECK (selling_price_per_meter >= standard_cost_per_meter)
);

CREATE TABLE materials (
    material_id SERIAL PRIMARY KEY,
    material_code VARCHAR(30) NOT NULL UNIQUE,
    material_name VARCHAR(150) NOT NULL,
    category VARCHAR(50) NOT NULL,
    subcategory VARCHAR(50) NOT NULL,
    unit_of_measure VARCHAR(20) NOT NULL,
    standard_unit_cost NUMERIC(10, 2) NOT NULL CHECK (standard_unit_cost > 0.00),
    density_linear_count VARCHAR(30),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_mat_category CHECK (category IN ('Yarn', 'Greige Fabric', 'Dye', 'Sizing Chemical', 'Finishing Agent', 'Auxiliary Chemical')),
    CONSTRAINT chk_mat_uom CHECK (unit_of_measure IN ('kg', 'meters', 'liters', 'grams'))
);

CREATE TABLE suppliers (
    supplier_id SERIAL PRIMARY KEY,
    supplier_code VARCHAR(30) NOT NULL UNIQUE,
    supplier_name VARCHAR(150) NOT NULL,
    location_id INTEGER NOT NULL REFERENCES locations(location_id) ON DELETE RESTRICT,
    contact_email VARCHAR(100) NOT NULL,
    phone VARCHAR(50),
    payment_terms_days INTEGER NOT NULL DEFAULT 30 CHECK (payment_terms_days >= 0),
    credit_rating VARCHAR(10) NOT NULL DEFAULT 'A',
    is_preferred BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_supplier_credit_rating CHECK (credit_rating IN ('AAA', 'AA', 'A', 'BBB', 'BB', 'B', 'CCC'))
);

CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    customer_code VARCHAR(30) NOT NULL UNIQUE,
    customer_name VARCHAR(150) NOT NULL,
    location_id INTEGER NOT NULL REFERENCES locations(location_id) ON DELETE RESTRICT,
    segment VARCHAR(50) NOT NULL,
    credit_limit NUMERIC(12, 2) NOT NULL DEFAULT 50000.00 CHECK (credit_limit >= 0.00),
    discount_percentage NUMERIC(5, 2) NOT NULL DEFAULT 0.00 CHECK (discount_percentage >= 0.00 AND discount_percentage <= 100.00),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_cust_segment CHECK (segment IN ('Fast Fashion', 'Luxury', 'Industrial', 'Wholesale', 'Direct Retail'))
);

-- ============================================================================
-- 3. MASTER TABLES (LEVEL 2 - MULTI-FK MASTER DEPENDENCIES)
-- ============================================================================

CREATE TABLE production_lines (
    line_id SERIAL PRIMARY KEY,
    line_code VARCHAR(20) NOT NULL UNIQUE,
    line_name VARCHAR(100) NOT NULL,
    plant_id INTEGER NOT NULL REFERENCES plants(plant_id) ON DELETE RESTRICT,
    line_type VARCHAR(50) NOT NULL,
    daily_target_meters NUMERIC(10, 2) NOT NULL CHECK (daily_target_meters > 0.00),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_line_type CHECK (line_type IN ('Spinning', 'Weaving', 'Knitting', 'Dyeing', 'Printing', 'Finishing'))
);

CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    employee_code VARCHAR(20) NOT NULL UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    plant_id INTEGER NOT NULL REFERENCES plants(plant_id) ON DELETE RESTRICT,
    role VARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL,
    skill_level VARCHAR(20) NOT NULL DEFAULT 'Intermediate',
    hourly_labor_rate NUMERIC(8, 2) NOT NULL CHECK (hourly_labor_rate > 0.00),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_emp_role CHECK (role IN ('Operator', 'Technician', 'Inspector', 'Supervisor', 'Line Manager')),
    CONSTRAINT chk_emp_skill CHECK (skill_level IN ('Junior', 'Intermediate', 'Senior', 'Master'))
);

-- ============================================================================
-- 4. MASTER ASSETS & ORDERS (LEVEL 3)
-- ============================================================================

CREATE TABLE machines (
    machine_id SERIAL PRIMARY KEY,
    machine_code VARCHAR(30) NOT NULL UNIQUE,
    machine_name VARCHAR(100) NOT NULL,
    machine_type_id INTEGER NOT NULL REFERENCES machine_types(machine_type_id) ON DELETE RESTRICT,
    line_id INTEGER NOT NULL REFERENCES production_lines(line_id) ON DELETE RESTRICT,
    serial_number VARCHAR(100) NOT NULL UNIQUE,
    model_number VARCHAR(100) NOT NULL,
    manufacturer VARCHAR(100) NOT NULL,
    installation_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Operational',
    hourly_overhead_cost NUMERIC(10, 2) NOT NULL CHECK (hourly_overhead_cost >= 0.00),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_machine_status CHECK (status IN ('Operational', 'Under Maintenance', 'Offline', 'Decommissioned'))
);

CREATE TABLE customer_orders (
    order_id BIGSERIAL PRIMARY KEY,
    order_number VARCHAR(30) NOT NULL UNIQUE,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    product_id INTEGER NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    order_date DATE NOT NULL,
    promised_delivery_date DATE NOT NULL,
    actual_dispatch_date DATE,
    ordered_meters NUMERIC(12, 2) NOT NULL CHECK (ordered_meters > 0.00),
    unit_selling_price NUMERIC(10, 2) NOT NULL CHECK (unit_selling_price > 0.00),
    order_status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_cust_order_dates CHECK (promised_delivery_date >= order_date),
    CONSTRAINT chk_cust_order_dispatch CHECK (actual_dispatch_date IS NULL OR actual_dispatch_date >= order_date),
    CONSTRAINT chk_cust_order_status CHECK (order_status IN ('Pending', 'In Production', 'Fulfilled', 'Delayed', 'Cancelled'))
);

CREATE TABLE purchase_orders (
    po_id BIGSERIAL PRIMARY KEY,
    po_number VARCHAR(30) NOT NULL UNIQUE,
    supplier_id INTEGER NOT NULL REFERENCES suppliers(supplier_id) ON DELETE RESTRICT,
    plant_id INTEGER NOT NULL REFERENCES plants(plant_id) ON DELETE RESTRICT,
    order_date DATE NOT NULL,
    expected_delivery_date DATE NOT NULL,
    actual_delivery_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'Approved',
    total_po_amount NUMERIC(14, 2) NOT NULL DEFAULT 0.00 CHECK (total_po_amount >= 0.00),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_po_dates CHECK (expected_delivery_date >= order_date),
    CONSTRAINT chk_po_actual_delivery CHECK (actual_delivery_date IS NULL OR actual_delivery_date >= order_date),
    CONSTRAINT chk_po_status CHECK (status IN ('Draft', 'Approved', 'Partially Received', 'Received', 'Closed', 'Cancelled'))
);

-- ============================================================================
-- 5. PROCUREMENT ITEMS & PRODUCTION PLANNING (LEVEL 4)
-- ============================================================================

CREATE TABLE purchase_order_items (
    po_item_id BIGSERIAL PRIMARY KEY,
    po_id BIGINT NOT NULL REFERENCES purchase_orders(po_id) ON DELETE CASCADE,
    material_id INTEGER NOT NULL REFERENCES materials(material_id) ON DELETE RESTRICT,
    ordered_quantity NUMERIC(12, 2) NOT NULL CHECK (ordered_quantity > 0.00),
    received_quantity NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (received_quantity >= 0.00),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price > 0.00),
    line_total NUMERIC(12, 2) NOT NULL CHECK (line_total >= 0.00),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE production_orders (
    prod_order_id BIGSERIAL PRIMARY KEY,
    prod_order_number VARCHAR(30) NOT NULL UNIQUE,
    customer_order_id BIGINT REFERENCES customer_orders(order_id) ON DELETE SET NULL,
    product_id INTEGER NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    plant_id INTEGER NOT NULL REFERENCES plants(plant_id) ON DELETE RESTRICT,
    order_date DATE NOT NULL,
    target_start_date DATE NOT NULL,
    target_end_date DATE NOT NULL,
    actual_start_date DATE,
    actual_end_date DATE,
    planned_quantity_meters NUMERIC(12, 2) NOT NULL CHECK (planned_quantity_meters > 0.00),
    completed_quantity_meters NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (completed_quantity_meters >= 0.00),
    order_status VARCHAR(20) NOT NULL DEFAULT 'Scheduled',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_prod_order_target_dates CHECK (target_start_date >= order_date AND target_end_date >= target_start_date),
    CONSTRAINT chk_prod_order_actual_dates CHECK (actual_end_date IS NULL OR actual_start_date IS NULL OR actual_end_date >= actual_start_date),
    CONSTRAINT chk_prod_order_status CHECK (order_status IN ('Scheduled', 'In Progress', 'Completed', 'Partially Completed', 'Aborted'))
);

-- ============================================================================
-- 6. INVENTORY BATCHES (LEVEL 5)
-- ============================================================================

CREATE TABLE material_batches (
    batch_id BIGSERIAL PRIMARY KEY,
    batch_code VARCHAR(50) NOT NULL UNIQUE,
    po_item_id BIGINT NOT NULL REFERENCES purchase_order_items(po_item_id) ON DELETE RESTRICT,
    material_id INTEGER NOT NULL REFERENCES materials(material_id) ON DELETE RESTRICT,
    supplier_id INTEGER NOT NULL REFERENCES suppliers(supplier_id) ON DELETE RESTRICT,
    received_date DATE NOT NULL,
    initial_quantity NUMERIC(12, 2) NOT NULL CHECK (initial_quantity > 0.00),
    remaining_quantity NUMERIC(12, 2) NOT NULL CHECK (remaining_quantity >= 0.00),
    unit_of_measure VARCHAR(20) NOT NULL,
    quality_status VARCHAR(20) NOT NULL DEFAULT 'Accepted',
    batch_rejection_reason TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_batch_quality_status CHECK (quality_status IN ('Accepted', 'Quarantined', 'Rejected')),
    CONSTRAINT chk_batch_rem_lte_init CHECK (remaining_quantity <= initial_quantity)
);

-- ============================================================================
-- 7. PRODUCTION EXECUTION & MAINTENANCE (LEVEL 6)
-- ============================================================================

CREATE TABLE production_runs (
    run_id BIGSERIAL PRIMARY KEY,
    run_code VARCHAR(50) NOT NULL UNIQUE,
    prod_order_id BIGINT NOT NULL REFERENCES production_orders(prod_order_id) ON DELETE RESTRICT,
    machine_id INTEGER NOT NULL REFERENCES machines(machine_id) ON DELETE RESTRICT,
    line_id INTEGER NOT NULL REFERENCES production_lines(line_id) ON DELETE RESTRICT,
    product_id INTEGER NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    operator_id INTEGER NOT NULL REFERENCES employees(employee_id) ON DELETE RESTRICT,
    shift_id INTEGER NOT NULL REFERENCES shifts(shift_id) ON DELETE RESTRICT,
    run_date DATE NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    planned_speed_rpm INTEGER NOT NULL CHECK (planned_speed_rpm > 0),
    actual_speed_rpm INTEGER NOT NULL CHECK (actual_speed_rpm > 0),
    planned_meters NUMERIC(10, 2) NOT NULL CHECK (planned_meters > 0.00),
    actual_meters NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (actual_meters >= 0.00),
    run_status VARCHAR(20) NOT NULL DEFAULT 'Completed',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_run_time_order CHECK (end_time > start_time),
    CONSTRAINT chk_run_status CHECK (run_status IN ('In Progress', 'Completed', 'Interrupted', 'Terminated'))
);

CREATE TABLE machine_maintenance (
    maintenance_id BIGSERIAL PRIMARY KEY,
    maintenance_code VARCHAR(50) NOT NULL UNIQUE,
    machine_id INTEGER NOT NULL REFERENCES machines(machine_id) ON DELETE RESTRICT,
    maintenance_type VARCHAR(50) NOT NULL,
    scheduled_date DATE NOT NULL,
    completion_date DATE,
    technician_id INTEGER NOT NULL REFERENCES employees(employee_id) ON DELETE RESTRICT,
    technician_hours NUMERIC(6, 2) NOT NULL DEFAULT 0.00 CHECK (technician_hours >= 0.00),
    labor_cost NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (labor_cost >= 0.00),
    replacement_parts_cost NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (replacement_parts_cost >= 0.00),
    total_maintenance_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (total_maintenance_cost >= 0.00),
    maintenance_status VARCHAR(20) NOT NULL DEFAULT 'Scheduled',
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_maint_type CHECK (maintenance_type IN ('Preventive', 'Corrective', 'Predictive', 'Emergency', 'Calibration')),
    CONSTRAINT chk_maint_status CHECK (maintenance_status IN ('Scheduled', 'In Progress', 'Completed', 'Cancelled')),
    CONSTRAINT chk_maint_completion CHECK (completion_date IS NULL OR completion_date >= scheduled_date)
);

-- ============================================================================
-- 8. OPERATIONS LOGS, FABRIC ROLLS, DOWNTIME & WASTE (LEVEL 7)
-- ============================================================================

CREATE TABLE material_consumption (
    consumption_id BIGSERIAL PRIMARY KEY,
    run_id BIGINT NOT NULL REFERENCES production_runs(run_id) ON DELETE CASCADE,
    batch_id BIGINT NOT NULL REFERENCES material_batches(batch_id) ON DELETE RESTRICT,
    material_id INTEGER NOT NULL REFERENCES materials(material_id) ON DELETE RESTRICT,
    consumed_quantity NUMERIC(12, 2) NOT NULL CHECK (consumed_quantity > 0.00),
    unit_of_measure VARCHAR(20) NOT NULL,
    consumed_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE fabric_rolls (
    roll_id BIGSERIAL PRIMARY KEY,
    roll_barcode VARCHAR(50) NOT NULL UNIQUE,
    run_id BIGINT NOT NULL REFERENCES production_runs(run_id) ON DELETE RESTRICT,
    product_id INTEGER NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    roll_length_meters NUMERIC(10, 2) NOT NULL CHECK (roll_length_meters > 0.00),
    roll_weight_kg NUMERIC(10, 2) NOT NULL CHECK (roll_weight_kg > 0.00),
    roll_grade VARCHAR(10) NOT NULL DEFAULT 'A',
    roll_status VARCHAR(20) NOT NULL DEFAULT 'In Stock',
    produced_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_roll_grade CHECK (roll_grade IN ('A', 'B', 'C', 'Scrap')),
    CONSTRAINT chk_roll_status CHECK (roll_status IN ('In Stock', 'Dispatched', 'Rework', 'Scrapped', 'Quarantined'))
);

CREATE TABLE machine_downtime (
    downtime_id BIGSERIAL PRIMARY KEY,
    machine_id INTEGER NOT NULL REFERENCES machines(machine_id) ON DELETE RESTRICT,
    run_id BIGINT REFERENCES production_runs(run_id) ON DELETE SET NULL,
    shift_id INTEGER NOT NULL REFERENCES shifts(shift_id) ON DELETE RESTRICT,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    duration_hours NUMERIC(8, 2) NOT NULL CHECK (duration_hours > 0.00),
    downtime_category VARCHAR(50) NOT NULL,
    reason_description TEXT NOT NULL,
    root_cause_category VARCHAR(50) NOT NULL,
    financial_downtime_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (financial_downtime_cost >= 0.00),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_downtime_time CHECK (end_time > start_time),
    CONSTRAINT chk_downtime_cat CHECK (downtime_category IN ('Unplanned Breakdown', 'Setup & Changeover', 'Operator Delay', 'Preventive Stoppage', 'Material Shortage', 'Power Interruption')),
    CONSTRAINT chk_downtime_root_cause CHECK (root_cause_category IN ('Mechanical', 'Electrical', 'Sensor/Pneumatic', 'Raw Material Jam', 'Operational', 'External Utility'))
);

CREATE TABLE production_waste (
    waste_id BIGSERIAL PRIMARY KEY,
    run_id BIGINT NOT NULL REFERENCES production_runs(run_id) ON DELETE CASCADE,
    material_id INTEGER NOT NULL REFERENCES materials(material_id) ON DELETE RESTRICT,
    waste_type VARCHAR(50) NOT NULL,
    waste_quantity NUMERIC(10, 2) NOT NULL CHECK (waste_quantity > 0.00),
    unit_of_measure VARCHAR(20) NOT NULL,
    unit_cost NUMERIC(10, 2) NOT NULL CHECK (unit_cost > 0.00),
    total_waste_cost NUMERIC(12, 2) NOT NULL CHECK (total_waste_cost >= 0.00),
    salvage_recovery_value NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (salvage_recovery_value >= 0.00),
    net_financial_loss NUMERIC(12, 2) NOT NULL CHECK (net_financial_loss >= 0.00),
    recorded_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_waste_type CHECK (waste_type IN ('Selvage Trimming', 'Sizing Loss', 'Off-Shade Dye Dumping', 'Yarn Bobbin Scrap', 'Fabric Off-Cut', 'Seam Scrap', 'Defective Yarn Slub Scrap')),
    CONSTRAINT chk_waste_loss_valid CHECK (net_financial_loss >= total_waste_cost - salvage_recovery_value - 0.01)
);

-- ============================================================================
-- 9. QUALITY INSPECTION & DEFECTS (LEVEL 8 & 9)
-- ============================================================================

CREATE TABLE quality_inspections (
    inspection_id BIGSERIAL PRIMARY KEY,
    inspection_code VARCHAR(50) NOT NULL UNIQUE,
    roll_id BIGINT NOT NULL UNIQUE REFERENCES fabric_rolls(roll_id) ON DELETE CASCADE,
    inspector_id INTEGER NOT NULL REFERENCES employees(employee_id) ON DELETE RESTRICT,
    inspection_date TIMESTAMP NOT NULL,
    inspected_length_meters NUMERIC(10, 2) NOT NULL CHECK (inspected_length_meters > 0.00),
    inspected_width_meters NUMERIC(6, 2) NOT NULL CHECK (inspected_width_meters > 0.00),
    total_defect_points INTEGER NOT NULL DEFAULT 0 CHECK (total_defect_points >= 0),
    points_per_100_sqm NUMERIC(8, 2) NOT NULL DEFAULT 0.00 CHECK (points_per_100_sqm >= 0.00),
    quality_score NUMERIC(5, 2) NOT NULL CHECK (quality_score >= 0.00 AND quality_score <= 100.00),
    inspection_result VARCHAR(20) NOT NULL,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_insp_result CHECK (inspection_result IN ('Pass', 'Conditional Pass', 'Fail'))
);

CREATE TABLE defect_records (
    defect_id BIGSERIAL PRIMARY KEY,
    inspection_id BIGINT NOT NULL REFERENCES quality_inspections(inspection_id) ON DELETE CASCADE,
    roll_id BIGINT NOT NULL REFERENCES fabric_rolls(roll_id) ON DELETE CASCADE,
    defect_type_id INTEGER NOT NULL REFERENCES defect_types(defect_type_id) ON DELETE RESTRICT,
    position_meters NUMERIC(10, 2) NOT NULL CHECK (position_meters >= 0.00),
    defect_length_meters NUMERIC(6, 2) NOT NULL CHECK (defect_length_meters > 0.00),
    defect_points INTEGER NOT NULL CHECK (defect_points IN (1, 2, 3, 4)),
    detected_at TIMESTAMP NOT NULL,
    severity VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_defect_rec_severity CHECK (severity IN ('Minor', 'Major', 'Critical'))
);

-- ============================================================================
-- 10. REWORK RECORDS (LEVEL 10)
-- ============================================================================

CREATE TABLE rework_records (
    rework_id BIGSERIAL PRIMARY KEY,
    roll_id BIGINT NOT NULL REFERENCES fabric_rolls(roll_id) ON DELETE CASCADE,
    defect_id BIGINT REFERENCES defect_records(defect_id) ON DELETE SET NULL,
    rework_date DATE NOT NULL,
    rework_type VARCHAR(50) NOT NULL,
    operator_id INTEGER NOT NULL REFERENCES employees(employee_id) ON DELETE RESTRICT,
    technician_hours NUMERIC(6, 2) NOT NULL CHECK (technician_hours > 0.00),
    additional_chemical_cost NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (additional_chemical_cost >= 0.00),
    pre_rework_grade VARCHAR(10) NOT NULL,
    post_rework_grade VARCHAR(10) NOT NULL,
    rework_result VARCHAR(20) NOT NULL,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_rework_type CHECK (rework_type IN ('Re-Washing', 'Mending/Darning', 'Re-Dyeing', 'Re-Finishing', 'Shearing', 'Stenter Alignment')),
    CONSTRAINT chk_rework_pre_grade CHECK (pre_rework_grade IN ('B', 'C', 'Scrap')),
    CONSTRAINT chk_rework_post_grade CHECK (post_rework_grade IN ('A', 'B', 'C', 'Scrap')),
    CONSTRAINT chk_rework_result CHECK (rework_result IN ('Successful', 'Partial Improvement', 'Failed'))
);
