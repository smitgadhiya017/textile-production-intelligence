-- ============================================================================
-- TEXTILE PRODUCTION WASTE, DEFECT & MACHINE INTELLIGENCE SYSTEM
-- Script: 13_triggers.sql
-- Description: Automated PL/pgSQL Triggers enforcing real-time data integrity,
--              automated financial scrap calculations, machine asset status
--              synchronization, and quality quarantine downgrades.
-- ============================================================================

-- ============================================================================
-- TRIGGER 01: trg_calculate_waste_net_loss
-- ============================================================================
/*
BUSINESS PURPOSE:
Enforces financial consistency on production waste. Before any insert or update,
automatically looks up the material's standard unit cost, calculates gross waste
cost, and derives net financial loss after salvage value recovery.
*/
CREATE OR REPLACE FUNCTION fn_trg_calculate_waste_net_loss()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_mat_cost NUMERIC;
    v_uom VARCHAR(20);
BEGIN
    -- Fetch Material Standard Cost if not provided
    IF NEW.unit_cost IS NULL OR NEW.unit_cost <= 0.00 THEN
        SELECT standard_unit_cost, unit_of_measure
        INTO v_mat_cost, v_uom
        FROM materials
        WHERE material_id = NEW.material_id;

        NEW.unit_cost := COALESCE(v_mat_cost, 0.00);
        IF NEW.unit_of_measure IS NULL THEN
            NEW.unit_of_measure := v_uom;
        END IF;
    END IF;

    -- Calculate Gross Waste Cost
    NEW.total_waste_cost := ROUND(NEW.waste_quantity * NEW.unit_cost, 2);

    -- Calculate Net Financial Loss after Salvage Recovery
    NEW.salvage_recovery_value := COALESCE(NEW.salvage_recovery_value, 0.00);
    NEW.net_financial_loss := ROUND(GREATEST(0.00, NEW.total_waste_cost - NEW.salvage_recovery_value), 2);

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_calculate_waste_net_loss ON production_waste;
CREATE TRIGGER trg_calculate_waste_net_loss
BEFORE INSERT OR UPDATE ON production_waste
FOR EACH ROW
EXECUTE FUNCTION fn_trg_calculate_waste_net_loss();


-- ============================================================================
-- TRIGGER 02: trg_update_machine_status_on_downtime
-- ============================================================================
/*
BUSINESS PURPOSE:
Synchronizes physical machine operational status in real-time. When an unplanned
breakdown downtime event is inserted, updates the machine's status to 'Under Maintenance'.
When the stoppage end_time is populated, restores the machine's status to 'Operational'.
*/
CREATE OR REPLACE FUNCTION fn_trg_update_machine_status_on_downtime()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- On new downtime incident
        IF NEW.end_time IS NULL THEN
            UPDATE machines
            SET status = 'Under Maintenance'
            WHERE machine_id = NEW.machine_id;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        -- When breakdown incident is resolved and end_time is set
        IF OLD.end_time IS NULL AND NEW.end_time IS NOT NULL THEN
            UPDATE machines
            SET status = 'Operational'
            WHERE machine_id = NEW.machine_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_machine_status_on_downtime ON machine_downtime;
CREATE TRIGGER trg_update_machine_status_on_downtime
AFTER INSERT OR UPDATE ON machine_downtime
FOR EACH ROW
EXECUTE FUNCTION fn_trg_update_machine_status_on_downtime();


-- ============================================================================
-- TRIGGER 03: trg_update_roll_grade_on_defects
-- ============================================================================
/*
BUSINESS PURPOSE:
Automated Quality Firewall: Whenever a 'Critical' severity defect is logged on
a fabric roll, immediately downgrades the roll grade to 'Scrap' and quarantines
the inventory status to prevent accidental dispatch to customers.
*/
CREATE OR REPLACE FUNCTION fn_trg_update_roll_grade_on_defects()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.severity = 'Critical' THEN
        UPDATE fabric_rolls
        SET roll_grade = 'Scrap',
            roll_status = 'Quarantined'
        WHERE roll_id = NEW.roll_id;
    ELSIF NEW.severity = 'Major' THEN
        -- Downgrade Grade A rolls with Major defects to Grade B
        UPDATE fabric_rolls
        SET roll_grade = CASE WHEN roll_grade = 'A' THEN 'B' ELSE roll_grade END,
            roll_status = 'Quarantined'
        WHERE roll_id = NEW.roll_id AND roll_grade = 'A';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_roll_grade_on_defects ON defect_records;
CREATE TRIGGER trg_update_roll_grade_on_defects
AFTER INSERT ON defect_records
FOR EACH ROW
EXECUTE FUNCTION fn_trg_update_roll_grade_on_defects();


-- ============================================================================
-- TRIGGER 04: trg_validate_preventive_maintenance_schedule
-- ============================================================================
/*
BUSINESS PURPOSE:
Enforces preventive maintenance chronology. Prevents scheduling maintenance
with invalid completion dates before the scheduled initiation date.
*/
CREATE OR REPLACE FUNCTION fn_trg_validate_maintenance_chronology()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.completion_date IS NOT NULL AND NEW.scheduled_date IS NOT NULL THEN
        IF NEW.completion_date < NEW.scheduled_date THEN
            RAISE EXCEPTION 'Validation Failed: Completion date (%) cannot precede scheduled date (%).',
                NEW.completion_date, NEW.scheduled_date;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_maintenance_chronology ON machine_maintenance;
CREATE TRIGGER trg_validate_maintenance_chronology
BEFORE INSERT OR UPDATE ON machine_maintenance
FOR EACH ROW
EXECUTE FUNCTION fn_trg_validate_maintenance_chronology();
