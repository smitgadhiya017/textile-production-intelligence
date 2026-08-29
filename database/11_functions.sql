-- ============================================================================
-- TEXTILE PRODUCTION WASTE, DEFECT & MACHINE INTELLIGENCE SYSTEM
-- Script: 11_functions.sql
-- Description: Core PL/pgSQL & SQL Business Functions encapsulating deterministic
--              mathematical calculations for production efficiency, waste rates,
--              defect density, machine utilization, dynamic risk scoring,
--              supplier scoring, and financial loss rollups.
-- ============================================================================

-- ============================================================================
-- FUNCTION 01: fn_calculate_production_efficiency
-- ============================================================================
/*
BUSINESS PURPOSE:
Calculates the operational output efficiency percentage given actual and planned
meters, safeguarding against division-by-zero errors.
*/
CREATE OR REPLACE FUNCTION fn_calculate_production_efficiency(
    p_actual_meters NUMERIC,
    p_planned_meters NUMERIC
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_planned_meters IS NULL OR p_planned_meters <= 0.00 THEN
        RETURN 0.00;
    END IF;
    
    IF p_actual_meters IS NULL OR p_actual_meters < 0.00 THEN
        RETURN 0.00;
    END IF;
    
    RETURN ROUND((p_actual_meters / p_planned_meters) * 100.0, 2);
END;
$$;


-- ============================================================================
-- FUNCTION 02: fn_calculate_waste_percentage
-- ============================================================================
/*
BUSINESS PURPOSE:
Calculates the material waste percentage relative to total throughput (actual + waste).
*/
CREATE OR REPLACE FUNCTION fn_calculate_waste_percentage(
    p_waste_quantity NUMERIC,
    p_actual_quantity NUMERIC
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_total_input NUMERIC;
BEGIN
    IF p_waste_quantity IS NULL OR p_waste_quantity <= 0.00 THEN
        RETURN 0.00;
    END IF;
    
    v_total_input := COALESCE(p_actual_quantity, 0.00) + p_waste_quantity;
    
    IF v_total_input <= 0.00 THEN
        RETURN 0.00;
    END IF;
    
    RETURN ROUND((p_waste_quantity / v_total_input) * 100.0, 2);
END;
$$;


-- ============================================================================
-- FUNCTION 03: fn_calculate_defect_rate
-- ============================================================================
/*
BUSINESS PURPOSE:
Standardizes fabric defect incidence rating per 1,000 meters produced.
*/
CREATE OR REPLACE FUNCTION fn_calculate_defect_rate(
    p_defect_count BIGINT,
    p_total_meters NUMERIC
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_defect_count IS NULL OR p_defect_count <= 0 THEN
        RETURN 0.00;
    END IF;
    
    IF p_total_meters IS NULL OR p_total_meters <= 0.00 THEN
        RETURN 0.00;
    END IF;
    
    RETURN ROUND((p_defect_count * 1000.0) / p_total_meters, 2);
END;
$$;


-- ============================================================================
-- FUNCTION 04: fn_calculate_machine_utilization
-- ============================================================================
/*
BUSINESS PURPOSE:
Computes asset operational utilization percentage relative to operating run time
plus total downtime stoppages.
*/
CREATE OR REPLACE FUNCTION fn_calculate_machine_utilization(
    p_operating_hours NUMERIC,
    p_downtime_hours NUMERIC
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_total_hours NUMERIC;
BEGIN
    IF p_operating_hours IS NULL OR p_operating_hours <= 0.00 THEN
        RETURN 0.00;
    END IF;
    
    v_total_hours := p_operating_hours + COALESCE(p_downtime_hours, 0.00);
    
    IF v_total_hours <= 0.00 THEN
        RETURN 0.00;
    END IF;
    
    RETURN ROUND((p_operating_hours / v_total_hours) * 100.0, 2);
END;
$$;


-- ============================================================================
-- FUNCTION 05: fn_calculate_machine_risk_score
-- ============================================================================
/*
BUSINESS PURPOSE:
Dynamically evaluates a specific machine's 0-100 Operational Risk Score
based on live historical data for downtime, failure frequency, defect rate,
maintenance expenditure, and asset age.
*/
CREATE OR REPLACE FUNCTION fn_calculate_machine_risk_score(
    p_machine_id INTEGER
)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_downtime_hours NUMERIC := 0.00;
    v_breakdown_count INTEGER := 0;
    v_defect_count INTEGER := 0;
    v_maint_spend NUMERIC := 0.00;
    v_age_years NUMERIC := 0.00;
    v_max_dt NUMERIC;
    v_max_freq NUMERIC;
    v_max_def NUMERIC;
    v_max_maint NUMERIC;
    v_max_age NUMERIC;
    v_s_dt NUMERIC;
    v_s_freq NUMERIC;
    v_s_def NUMERIC;
    v_s_maint NUMERIC;
    v_s_age NUMERIC;
    v_risk_score NUMERIC;
BEGIN
    -- Get Machine Age
    SELECT COALESCE(ROUND((JULIANDAY('2025-12-31') - JULIANDAY(installation_date)) / 365.25, 1), 0.0)
    INTO v_age_years
    FROM machines WHERE machine_id = p_machine_id;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    -- Get Downtime and Breakdowns
    SELECT 
        COALESCE(SUM(duration_hours), 0.00),
        COUNT(downtime_id)
    INTO v_downtime_hours, v_breakdown_count
    FROM machine_downtime
    WHERE machine_id = p_machine_id AND downtime_category = 'Unplanned Breakdown';

    -- Get Defects
    SELECT COUNT(dr.defect_id)
    INTO v_defect_count
    FROM production_runs pr
    JOIN fabric_rolls fr ON pr.run_id = fr.run_id
    JOIN defect_records dr ON fr.roll_id = dr.roll_id
    WHERE pr.machine_id = p_machine_id;

    -- Get Maintenance Spend
    SELECT COALESCE(SUM(total_maintenance_cost), 0.00)
    INTO v_maint_spend
    FROM machine_maintenance
    WHERE machine_id = p_machine_id AND maintenance_status = 'Completed';

    -- Fleet Max Normalization Benchmarks
    v_max_dt := 250.00;
    v_max_freq := 120.00;
    v_max_def := 250.00;
    v_max_maint := 25000.00;
    v_max_age := 15.00;

    v_s_dt := LEAST(100.0, (v_downtime_hours / v_max_dt) * 100.0);
    v_s_freq := LEAST(100.0, (v_breakdown_count / v_max_freq) * 100.0);
    v_s_def := LEAST(100.0, (v_defect_count / v_max_def) * 100.0);
    v_s_maint := LEAST(100.0, (v_maint_spend / v_max_maint) * 100.0);
    v_s_age := LEAST(100.0, (v_age_years / v_max_age) * 100.0);

    v_risk_score := ROUND((0.30 * v_s_dt) + (0.25 * v_s_freq) + (0.20 * v_s_def) + (0.15 * v_s_maint) + (0.10 * v_s_age), 2);

    RETURN v_risk_score;
END;
$$;


-- ============================================================================
-- FUNCTION 06: fn_calculate_supplier_score
-- ============================================================================
/*
BUSINESS PURPOSE:
Calculates a vendor's Supplier Quality Index (SQI 0-100) dynamically from
historical batch acceptance rates, downstream defects, and scrap costs.
*/
CREATE OR REPLACE FUNCTION fn_calculate_supplier_score(
    p_supplier_id INTEGER
)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total_batches INTEGER := 0;
    v_rejected_batches INTEGER := 0;
    v_rejection_rate NUMERIC := 0.00;
    v_downstream_defects INTEGER := 0;
    v_po_spend NUMERIC := 0.00;
    v_waste_loss NUMERIC := 0.00;
    v_sqi NUMERIC := 100.00;
BEGIN
    SELECT 
        COUNT(DISTINCT mb.batch_id),
        SUM(CASE WHEN mb.quality_status = 'Rejected' THEN 1 ELSE 0 END)
    INTO v_total_batches, v_rejected_batches
    FROM material_batches mb
    WHERE mb.supplier_id = p_supplier_id;

    IF v_total_batches = 0 THEN
        RETURN 100.00;
    END IF;

    v_rejection_rate := (v_rejected_batches * 1.0 / v_total_batches) * 100.0;

    SELECT COUNT(DISTINCT dr.defect_id)
    INTO v_downstream_defects
    FROM material_batches mb
    JOIN material_consumption mc ON mb.batch_id = mc.batch_id
    JOIN production_runs pr ON mc.run_id = pr.run_id
    JOIN fabric_rolls fr ON pr.run_id = fr.run_id
    JOIN defect_records dr ON fr.roll_id = dr.roll_id
    WHERE mb.supplier_id = p_supplier_id;

    SELECT COALESCE(SUM(total_po_amount), 0.00)
    INTO v_po_spend
    FROM purchase_orders
    WHERE supplier_id = p_supplier_id;

    SELECT COALESCE(SUM(pw.net_financial_loss), 0.00)
    INTO v_waste_loss
    FROM material_batches mb
    JOIN material_consumption mc ON mb.batch_id = mc.batch_id
    JOIN production_waste pw ON mc.run_id = pw.run_id
    WHERE mb.supplier_id = p_supplier_id;

    v_sqi := 100.0 - (0.40 * v_rejection_rate + 0.35 * (v_downstream_defects * 1.0 / v_total_batches) + 0.05 * (v_waste_loss / NULLIF(v_po_spend, 0.0) * 100.0));

    RETURN ROUND(GREATEST(0.0, LEAST(100.0, v_sqi)), 2);
END;
$$;


-- ============================================================================
-- FUNCTION 07: fn_calculate_total_production_loss
-- ============================================================================
/*
BUSINESS PURPOSE:
Calculates the total financial loss for a single production run:
Material Waste + Defect Scrap + Secondary Rework + Unplanned Downtime Overhead.
*/
CREATE OR REPLACE FUNCTION fn_calculate_total_production_loss(
    p_run_id BIGINT
)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_waste_loss NUMERIC := 0.00;
    v_defect_loss NUMERIC := 0.00;
    v_rework_cost NUMERIC := 0.00;
    v_downtime_cost NUMERIC := 0.00;
BEGIN
    -- 1. Material Waste
    SELECT COALESCE(SUM(net_financial_loss), 0.00)
    INTO v_waste_loss
    FROM production_waste
    WHERE run_id = p_run_id;

    -- 2. Defect Scrap
    SELECT COALESCE(SUM(fr.roll_length_meters * p.standard_cost_per_meter), 0.00)
    INTO v_defect_loss
    FROM fabric_rolls fr
    JOIN products p ON fr.product_id = p.product_id
    WHERE fr.run_id = p_run_id AND fr.roll_grade = 'Scrap';

    -- 3. Rework
    SELECT COALESCE(SUM((rw.technician_hours * emp.hourly_labor_rate) + rw.additional_chemical_cost), 0.00)
    INTO v_rework_cost
    FROM fabric_rolls fr
    JOIN rework_records rw ON fr.roll_id = rw.roll_id
    JOIN employees emp ON rw.operator_id = emp.employee_id
    WHERE fr.run_id = p_run_id;

    -- 4. Downtime Overhead
    SELECT COALESCE(SUM(financial_downtime_cost), 0.00)
    INTO v_downtime_cost
    FROM machine_downtime
    WHERE run_id = p_run_id AND downtime_category = 'Unplanned Breakdown';

    RETURN ROUND(v_waste_loss + v_defect_loss + v_rework_cost + v_downtime_cost, 2);
END;
$$;
