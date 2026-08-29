-- ============================================================================
-- TEXTILE PRODUCTION WASTE, DEFECT & MACHINE INTELLIGENCE SYSTEM
-- Script: 12_procedures.sql
-- Description: Core PL/pgSQL Stored Procedures orchestrating transactional
--              operational workflows: completing production runs, finalizing
--              maintenance jobs, logging production waste, and executing
--              corrective fabric roll rework.
-- ============================================================================

-- ============================================================================
-- PROCEDURE 01: sp_complete_production_run
-- ============================================================================
/*
BUSINESS PURPOSE:
Finalizes an active manufacturing run, records actual output meters and speed,
marks the run 'Completed', updates the parent work order's completed quantity,
and transitions work order status to 'Completed' if output meets target.
*/
CREATE OR REPLACE PROCEDURE sp_complete_production_run(
    p_run_id BIGINT,
    p_actual_meters NUMERIC,
    p_actual_speed_rpm INTEGER,
    p_end_time TIMESTAMP
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_prod_order_id BIGINT;
    v_planned_meters NUMERIC;
    v_start_time TIMESTAMP;
    v_target_meters NUMERIC;
    v_total_completed NUMERIC;
BEGIN
    -- 1. Validate Run Existence and Current Status
    SELECT prod_order_id, planned_meters, start_time
    INTO v_prod_order_id, v_planned_meters, v_start_time
    FROM production_runs
    WHERE run_id = p_run_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Run ID % not found in production_runs.', p_run_id;
    END IF;

    IF p_actual_meters IS NULL OR p_actual_meters < 0.00 THEN
        RAISE EXCEPTION 'Actual meters cannot be negative or NULL (Provided: %).', p_actual_meters;
    END IF;

    IF p_actual_speed_rpm IS NULL OR p_actual_speed_rpm <= 0 THEN
        RAISE EXCEPTION 'Actual operating speed must be > 0 RPM (Provided: %).', p_actual_speed_rpm;
    END IF;

    IF p_end_time <= v_start_time THEN
        RAISE EXCEPTION 'End time (%) must be greater than run start time (%).', p_end_time, v_start_time;
    END IF;

    -- 2. Update Production Run
    UPDATE production_runs
    SET actual_meters = p_actual_meters,
        actual_speed_rpm = p_actual_speed_rpm,
        end_time = p_end_time,
        run_status = 'Completed'
    WHERE run_id = p_run_id;

    -- 3. Update Parent Production Order Total Completed Quantity
    SELECT planned_quantity_meters, COALESCE(completed_quantity_meters, 0.00)
    INTO v_target_meters, v_total_completed
    FROM production_orders
    WHERE prod_order_id = v_prod_order_id;

    UPDATE production_orders
    SET completed_quantity_meters = v_total_completed + p_actual_meters,
        actual_end_date = p_end_time::DATE,
        order_status = CASE 
            WHEN (v_total_completed + p_actual_meters) >= v_target_meters THEN 'Completed'
            ELSE 'In Progress'
        END
    WHERE prod_order_id = v_prod_order_id;

    RAISE NOTICE 'Production Run % completed successfully with % meters output.', p_run_id, p_actual_meters;
END;
$$;


-- ============================================================================
-- PROCEDURE 02: sp_complete_machine_maintenance
-- ============================================================================
/*
BUSINESS PURPOSE:
Finalizes a scheduled or corrective maintenance job, calculates labor costs based
on technician rates, calculates total maintenance spend, marks job 'Completed',
and transitions the physical machine asset back to 'Operational' status.
*/
CREATE OR REPLACE PROCEDURE sp_complete_machine_maintenance(
    p_maintenance_id BIGINT,
    p_technician_hours NUMERIC,
    p_replacement_parts_cost NUMERIC,
    p_completion_date DATE,
    p_notes TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_machine_id INTEGER;
    v_technician_id INTEGER;
    v_hourly_rate NUMERIC;
    v_labor_cost NUMERIC;
    v_total_cost NUMERIC;
    v_sched_date DATE;
BEGIN
    -- 1. Validate Maintenance Record
    SELECT machine_id, technician_id, scheduled_date
    INTO v_machine_id, v_technician_id, v_sched_date
    FROM machine_maintenance
    WHERE maintenance_id = p_maintenance_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Maintenance ID % not found.', p_maintenance_id;
    END IF;

    IF p_technician_hours IS NULL OR p_technician_hours < 0.00 THEN
        RAISE EXCEPTION 'Technician hours cannot be negative (Provided: %).', p_technician_hours;
    END IF;

    IF p_replacement_parts_cost IS NULL OR p_replacement_parts_cost < 0.00 THEN
        RAISE EXCEPTION 'Replacement parts cost cannot be negative (Provided: %).', p_replacement_parts_cost;
    END IF;

    IF p_completion_date < v_sched_date THEN
        RAISE EXCEPTION 'Completion date (%) cannot precede scheduled date (%).', p_completion_date, v_sched_date;
    END IF;

    -- 2. Fetch Technician Hourly Labor Rate
    SELECT hourly_labor_rate
    INTO v_hourly_rate
    FROM employees
    WHERE employee_id = v_technician_id;

    v_labor_cost := ROUND(p_technician_hours * COALESCE(v_hourly_rate, 30.00), 2);
    v_total_cost := ROUND(v_labor_cost + p_replacement_parts_cost, 2);

    -- 3. Update Maintenance Record
    UPDATE machine_maintenance
    SET technician_hours = p_technician_hours,
        labor_cost = v_labor_cost,
        replacement_parts_cost = p_replacement_parts_cost,
        total_maintenance_cost = v_total_cost,
        completion_date = p_completion_date,
        maintenance_status = 'Completed',
        notes = COALESCE(p_notes, notes)
    WHERE maintenance_id = p_maintenance_id;

    -- 4. Restore Machine Status to Operational
    UPDATE machines
    SET status = 'Operational'
    WHERE machine_id = v_machine_id;

    RAISE NOTICE 'Maintenance job % completed. Total spend: $% (Labor: $%, Parts: $%). Machine % is Operational.',
        p_maintenance_id, v_total_cost, v_labor_cost, p_replacement_parts_cost, v_machine_id;
END;
$$;


-- ============================================================================
-- PROCEDURE 03: sp_record_production_waste
-- ============================================================================
/*
BUSINESS PURPOSE:
Logs a raw material scrap event for a specific run, fetches the standard unit cost,
computes total waste cost and net financial loss after scrap salvage recovery.
*/
CREATE OR REPLACE PROCEDURE sp_record_production_waste(
    p_run_id BIGINT,
    p_material_id INTEGER,
    p_waste_type VARCHAR,
    p_waste_quantity NUMERIC,
    p_salvage_recovery_value NUMERIC,
    p_recorded_at TIMESTAMP
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_unit_cost NUMERIC;
    v_uom VARCHAR(20);
    v_total_cost NUMERIC;
    v_net_loss NUMERIC;
    v_salvage NUMERIC;
BEGIN
    -- 1. Validate Run Existence
    IF NOT EXISTS (SELECT 1 FROM production_runs WHERE run_id = p_run_id) THEN
        RAISE EXCEPTION 'Production run % does not exist.', p_run_id;
    END IF;

    -- 2. Validate Material
    SELECT standard_unit_cost, unit_of_measure
    INTO v_unit_cost, v_uom
    FROM materials
    WHERE material_id = p_material_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Material ID % does not exist.', p_material_id;
    END IF;

    IF p_waste_quantity IS NULL OR p_waste_quantity <= 0.00 THEN
        RAISE EXCEPTION 'Waste quantity must be > 0 (Provided: %).', p_waste_quantity;
    END IF;

    v_salvage := COALESCE(p_salvage_recovery_value, 0.00);
    v_total_cost := ROUND(p_waste_quantity * v_unit_cost, 2);
    v_net_loss := ROUND(GREATEST(0.00, v_total_cost - v_salvage), 2);

    -- 3. Insert Waste Record
    INSERT INTO production_waste (
        run_id,
        material_id,
        waste_type,
        waste_quantity,
        unit_of_measure,
        unit_cost,
        total_waste_cost,
        salvage_recovery_value,
        net_financial_loss,
        recorded_at
    ) VALUES (
        p_run_id,
        p_material_id,
        p_waste_type,
        p_waste_quantity,
        v_uom,
        v_unit_cost,
        v_total_cost,
        v_salvage,
        v_net_loss,
        COALESCE(p_recorded_at, CURRENT_TIMESTAMP)
    );

    RAISE NOTICE 'Waste logged: % % of Material % (Gross Cost: $%, Net Loss: $%).',
        p_waste_quantity, v_uom, p_material_id, v_total_cost, v_net_loss;
END;
$$;


-- ============================================================================
-- PROCEDURE 04: sp_process_fabric_roll_rework
-- ============================================================================
/*
BUSINESS PURPOSE:
Executes a quality rework job on a defective roll, records labor and chemical
costs, and updates the physical fabric roll's grade and operational stock status.
*/
CREATE OR REPLACE PROCEDURE sp_process_fabric_roll_rework(
    p_roll_id BIGINT,
    p_defect_id BIGINT,
    p_operator_id INTEGER,
    p_rework_type VARCHAR,
    p_technician_hours NUMERIC,
    p_additional_chemical_cost NUMERIC,
    p_post_rework_grade VARCHAR,
    p_rework_date DATE,
    p_notes TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_grade VARCHAR(10);
    v_rework_result VARCHAR(20);
    v_new_roll_status VARCHAR(20);
BEGIN
    -- 1. Validate Roll Existence
    SELECT roll_grade
    INTO v_current_grade
    FROM fabric_rolls
    WHERE roll_id = p_roll_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Fabric roll % not found.', p_roll_id;
    END IF;

    IF p_post_rework_grade NOT IN ('A', 'B', 'C', 'Scrap') THEN
        RAISE EXCEPTION 'Invalid post-rework grade: %. Must be A, B, C, or Scrap.', p_post_rework_grade;
    END IF;

    -- 2. Determine Outcome Result
    IF p_post_rework_grade = 'A' THEN
        v_rework_result := 'Successful';
        v_new_roll_status := 'In Stock';
    ELSIF p_post_rework_grade = 'B' AND v_current_grade IN ('C', 'Scrap') THEN
        v_rework_result := 'Successful';
        v_new_roll_status := 'In Stock';
    ELSIF p_post_rework_grade = 'Scrap' THEN
        v_rework_result := 'Failed';
        v_new_roll_status := 'Scrapped';
    ELSE
        v_rework_result := 'Partial Improvement';
        v_new_roll_status := 'In Stock';
    END IF;

    -- 3. Insert Rework Job Record
    INSERT INTO rework_records (
        roll_id,
        defect_id,
        rework_date,
        rework_type,
        operator_id,
        technician_hours,
        additional_chemical_cost,
        pre_rework_grade,
        post_rework_grade,
        rework_result,
        notes
    ) VALUES (
        p_roll_id,
        p_defect_id,
        COALESCE(p_rework_date, CURRENT_DATE),
        p_rework_type,
        p_operator_id,
        p_technician_hours,
        COALESCE(p_additional_chemical_cost, 0.00),
        v_current_grade,
        p_post_rework_grade,
        v_rework_result,
        p_notes
    );

    -- 4. Update Roll Status and Grade
    UPDATE fabric_rolls
    SET roll_grade = p_post_rework_grade,
        roll_status = v_new_roll_status
    WHERE roll_id = p_roll_id;

    RAISE NOTICE 'Roll % reworked via %. Grade updated from % to %. Status: %.',
        p_roll_id, p_rework_type, v_current_grade, p_post_rework_grade, v_new_roll_status;
END;
$$;
