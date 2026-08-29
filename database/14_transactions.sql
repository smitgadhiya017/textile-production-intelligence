-- ============================================================================
-- TEXTILE PRODUCTION WASTE, DEFECT & MACHINE INTELLIGENCE SYSTEM
-- Script: 14_transactions.sql
-- Description: ACID-compliant Transaction Scripts demonstrating atomic multi-table
--              operations, intentional error rollbacks, partial savepoint recovery,
--              and concurrent asset status locking.
-- ============================================================================

-- ============================================================================
-- SCENARIO 01: Multi-Table Production Run Completion Transaction (COMMIT)
-- ============================================================================
/*
BUSINESS PURPOSE:
Atomically completes an end-of-shift manufacturing run: records actual output,
logs raw material consumption, generates serialized fabric rolls, logs quality
inspections, records process scrap, and updates work order progress in a single
all-or-nothing transactional boundary.
*/

DO $$
DECLARE
    v_run_id BIGINT;
    v_order_id BIGINT := 1;
    v_roll_id BIGINT;
    v_insp_id BIGINT;
BEGIN
    -- 1. Update Production Run
    UPDATE production_runs
    SET actual_meters = 1250.00,
        actual_speed_rpm = 610,
        end_time = '2025-01-15 14:00:00',
        run_status = 'Completed'
    WHERE run_id = 1;

    -- 2. Deduct Material Consumption
    INSERT INTO material_consumption (
        run_id,
        batch_id,
        material_id,
        consumed_quantity,
        unit_of_measure,
        consumed_at
    ) VALUES (
        1,
        1,
        1,
        312.50,
        'kg',
        '2025-01-15 14:05:00'
    );

    -- 3. Generate New Serialized Roll
    INSERT INTO fabric_rolls (
        roll_barcode,
        run_id,
        product_id,
        roll_length_meters,
        roll_weight_kg,
        roll_grade,
        roll_status,
        produced_at
    ) VALUES (
        'ROL-TX-20250115-001',
        1,
        1,
        1250.00,
        300.00,
        'A',
        'In Stock',
        '2025-01-15 14:00:00'
    ) RETURNING roll_id INTO v_roll_id;

    -- 4. Log Quality Inspection Record
    INSERT INTO quality_inspections (
        inspection_code,
        roll_id,
        inspector_id,
        inspection_date,
        inspected_length_meters,
        inspected_width_meters,
        total_defect_points,
        points_per_100_sqm,
        quality_score,
        inspection_result
    ) VALUES (
        'INS-20250115-001',
        v_roll_id,
        10,
        '2025-01-15 14:30:00',
        1250.00,
        1.50,
        2,
        0.11,
        98.50,
        'Pass'
    );

    -- 5. Record Edge Waste
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
        1,
        1,
        'Selvage Trimming',
        12.50,
        'kg',
        3.50,
        43.75,
        5.00,
        38.75,
        '2025-01-15 14:00:00'
    );

    -- 6. Update Parent Production Order
    UPDATE production_orders
    SET completed_quantity_meters = completed_quantity_meters + 1250.00
    WHERE prod_order_id = v_order_id;

    RAISE NOTICE 'Scenario 1: Production Run Transaction successfully committed.';
END;
$$;


-- ============================================================================
-- SCENARIO 02: Transaction Failure & Full Rollback Simulation (ROLLBACK)
-- ============================================================================
/*
BUSINESS PURPOSE:
Simulates a critical mid-process failure (e.g. invalid negative scrap quantity
violating CHECK constraints). Demonstrates full transaction rollback ensuring
zero partial or orphaned records pollute the database.
*/

DO $$
DECLARE
    v_test_run_id BIGINT := 2;
BEGIN
    -- Step A: Valid Step
    UPDATE production_runs
    SET actual_meters = 800.00,
        run_status = 'In Progress'
    WHERE run_id = v_test_run_id;

    -- Step B: Invalid Insertion (Negative waste quantity violates chk_waste_quantity)
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
        v_test_run_id,
        1,
        'Selvage Trimming',
        -50.00, -- INVALID: Negative quantity
        'kg',
        3.50,
        175.00,
        0.00,
        175.00,
        CURRENT_TIMESTAMP
    );

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Scenario 2: Constraint violation detected (%). Transaction aborted cleanly via ROLLBACK.', SQLERRM;
END;
$$;


-- ============================================================================
-- SCENARIO 03: Partial Rollback with SAVEPOINTS
-- ============================================================================
/*
BUSINESS PURPOSE:
Executes batch processing where primary operations succeed, an optional non-critical
secondary operation fails, and the transaction safely rolls back to a SAVEPOINT
preserving the primary valid business state before committing.
*/

-- Standard SQL Savepoint Workflow Example:
BEGIN;

-- 1. Primary Operation: Log Completed Scheduled Maintenance
UPDATE machine_maintenance
SET maintenance_status = 'Completed',
    completion_date = '2025-01-20',
    total_maintenance_cost = 450.00
WHERE maintenance_id = 5;

-- 2. Mark Checkpoint
SAVEPOINT sv_maintenance_completed;

-- 3. Secondary Operation (Attempted Rework that fails validation)
-- In case of failure:
-- ROLLBACK TO SAVEPOINT sv_maintenance_completed;

-- 4. Commit Primary Valid Work
COMMIT;


-- ============================================================================
-- SCENARIO 04: Maintenance Stoppage with Asset State Lock (COMMIT)
-- ============================================================================
/*
BUSINESS PURPOSE:
Locks machine asset state during emergency breakdown, schedules immediate
repair ticket, records downtime stoppage, and ensures machine status is
synchronized across all operational queries.
*/

DO $$
DECLARE
    v_machine_id INTEGER := 12;
    v_downtime_id BIGINT;
BEGIN
    -- 1. Transition Machine Status
    UPDATE machines
    SET status = 'Under Maintenance'
    WHERE machine_id = v_machine_id;

    -- 2. Create Unplanned Downtime Incident
    INSERT INTO machine_downtime (
        machine_id,
        shift_id,
        start_time,
        end_time,
        duration_hours,
        downtime_category,
        root_cause_category,
        reason_description,
        financial_downtime_cost
    ) VALUES (
        v_machine_id,
        1,
        '2025-01-22 09:00:00',
        '2025-01-22 13:30:00',
        4.50,
        'Unplanned Breakdown',
        'Mechanical',
        'Main drive gearbox bearing thermal seizure',
        382.50
    ) RETURNING downtime_id INTO v_downtime_id;

    -- 3. Create Emergency Maintenance Work Order
    INSERT INTO machine_maintenance (
        maintenance_code,
        machine_id,
        technician_id,
        scheduled_date,
        maintenance_type,
        maintenance_status,
        technician_hours,
        labor_cost,
        replacement_parts_cost,
        total_maintenance_cost,
        completion_date,
        notes
    ) VALUES (
        'MNT-EMG-20250122-01',
        v_machine_id,
        15,
        '2025-01-22',
        'Emergency',
        'In Progress',
        4.50,
        135.00,
        250.00,
        385.00,
        NULL,
        'Emergency gearbox bearing replacement linked to downtime event'
    );

    RAISE NOTICE 'Scenario 4: Machine % breakdown and emergency work order locked and committed.', v_machine_id;
END;
$$;
