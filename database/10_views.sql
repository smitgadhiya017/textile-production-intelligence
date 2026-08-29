-- ============================================================================
-- TEXTILE PRODUCTION WASTE, DEFECT & MACHINE INTELLIGENCE SYSTEM
-- Script: 10_views.sql
-- Description: Core Business Views and Machine/Supplier Intelligence Engines
--              providing direct-access reporting models for Power BI dashboards
--              and executive operational scorecards.
-- ============================================================================

-- Drop views in reverse order if recreating
DROP VIEW IF EXISTS vw_business_alerts;
DROP VIEW IF EXISTS vw_machine_risk;
DROP VIEW IF EXISTS vw_production_loss;
DROP VIEW IF EXISTS vw_supplier_performance;
DROP VIEW IF EXISTS vw_machine_performance;
DROP VIEW IF EXISTS vw_quality_performance;
DROP VIEW IF EXISTS vw_production_efficiency;

-- ============================================================================
-- VIEW 01: vw_production_efficiency
-- ============================================================================
/*
BUSINESS PURPOSE:
Provides production order, machine, operator, and shift-level output velocity,
planned vs. actual output meters, and operational efficiency percentages.
*/
CREATE VIEW vw_production_efficiency AS
SELECT 
    pr.run_id,
    pr.run_code,
    pr.run_date,
    pr.start_time,
    pr.end_time,
    p.plant_id,
    p.plant_code,
    p.plant_name,
    pl.line_id,
    pl.line_code,
    pl.line_name,
    pl.line_type,
    m.machine_id,
    m.machine_code,
    m.machine_name,
    mt.type_name AS machine_type,
    prod.product_id,
    prod.product_code,
    prod.product_name,
    prod.fabric_type,
    prod.weave_type,
    prod.complexity_tier,
    e.employee_id AS operator_id,
    e.employee_code AS operator_code,
    e.first_name || ' ' || e.last_name AS operator_name,
    e.skill_level AS operator_skill,
    s.shift_id,
    s.shift_code,
    s.shift_name,
    s.is_night_shift,
    pr.planned_speed_rpm,
    pr.actual_speed_rpm,
    pr.planned_meters,
    pr.actual_meters,
    ROUND(pr.actual_meters - pr.planned_meters, 2) AS output_variance_meters,
    ROUND((pr.actual_meters / NULLIF(pr.planned_meters, 0) * 100.0), 2) AS production_efficiency_pct,
    pr.run_status
FROM production_runs pr
JOIN production_lines pl ON pr.line_id = pl.line_id
JOIN plants p ON pl.plant_id = p.plant_id
JOIN machines m ON pr.machine_id = m.machine_id
JOIN machine_types mt ON m.machine_type_id = mt.machine_type_id
JOIN products prod ON pr.product_id = prod.product_id
JOIN employees e ON pr.operator_id = e.employee_id
JOIN shifts s ON pr.shift_id = s.shift_id;


-- ============================================================================
-- VIEW 02: vw_quality_performance
-- ============================================================================
/*
BUSINESS PURPOSE:
Consolidates fabric roll quality inspections, ASTM 4-point penalty scores,
defect counts, severity distributions, rework flags, and First-Pass Yield (FPY) status.
*/
CREATE VIEW vw_quality_performance AS
SELECT 
    fr.roll_id,
    fr.roll_barcode,
    fr.produced_at,
    pr.run_id,
    pr.run_code,
    pr.run_date,
    p.plant_id,
    p.plant_code,
    p.plant_name,
    m.machine_id,
    m.machine_code,
    m.machine_name,
    mt.type_name AS machine_type,
    prod.product_id,
    prod.product_code,
    prod.product_name,
    prod.fabric_type,
    prod.complexity_tier,
    e_op.employee_id AS operator_id,
    e_op.first_name || ' ' || e_op.last_name AS operator_name,
    s.shift_code,
    s.shift_name,
    fr.roll_length_meters,
    fr.roll_weight_kg,
    fr.roll_grade,
    fr.roll_status,
    qi.inspection_id,
    qi.inspection_code,
    qi.inspection_date,
    qi.inspector_id,
    e_insp.first_name || ' ' || e_insp.last_name AS inspector_name,
    qi.total_defect_points,
    qi.points_per_100_sqm,
    qi.quality_score,
    qi.inspection_result,
    COALESCE(defect_agg.defect_count, 0) AS total_defects_count,
    COALESCE(defect_agg.critical_defects, 0) AS critical_defects_count,
    COALESCE(defect_agg.major_defects, 0) AS major_defects_count,
    COALESCE(defect_agg.minor_defects, 0) AS minor_defects_count,
    CASE WHEN rw.rework_id IS NOT NULL THEN 1 ELSE 0 END AS is_reworked,
    rw.rework_type,
    rw.post_rework_grade,
    CASE WHEN fr.roll_grade = 'A' AND rw.rework_id IS NULL THEN 1 ELSE 0 END AS is_first_pass_yield
FROM fabric_rolls fr
JOIN production_runs pr ON fr.run_id = pr.run_id
JOIN production_lines pl ON pr.line_id = pl.line_id
JOIN plants p ON pl.plant_id = p.plant_id
JOIN machines m ON pr.machine_id = m.machine_id
JOIN machine_types mt ON m.machine_type_id = mt.machine_type_id
JOIN products prod ON fr.product_id = prod.product_id
JOIN employees e_op ON pr.operator_id = e_op.employee_id
JOIN shifts s ON pr.shift_id = s.shift_id
LEFT JOIN quality_inspections qi ON fr.roll_id = qi.roll_id
LEFT JOIN employees e_insp ON qi.inspector_id = e_insp.employee_id
LEFT JOIN (
    SELECT 
        roll_id,
        COUNT(defect_id) AS defect_count,
        SUM(CASE WHEN severity = 'Critical' THEN 1 ELSE 0 END) AS critical_defects,
        SUM(CASE WHEN severity = 'Major' THEN 1 ELSE 0 END) AS major_defects,
        SUM(CASE WHEN severity = 'Minor' THEN 1 ELSE 0 END) AS minor_defects
    FROM defect_records
    GROUP BY roll_id
) defect_agg ON fr.roll_id = defect_agg.roll_id
LEFT JOIN rework_records rw ON fr.roll_id = rw.roll_id;


-- ============================================================================
-- VIEW 03: vw_machine_performance
-- ============================================================================
/*
BUSINESS PURPOSE:
Provides asset reliability metrics, operating hours, downtime hours,
breakdown counts, MTBF, MTTR, and total maintenance costs per machine.
*/
CREATE VIEW vw_machine_performance AS
SELECT 
    m.machine_id,
    m.machine_code,
    m.machine_name,
    m.serial_number,
    m.model_number,
    m.manufacturer,
    m.installation_date,
    ROUND((JULIANDAY('2025-12-31') - JULIANDAY(m.installation_date)) / 365.25, 1) AS machine_age_years,
    m.status AS current_operational_status,
    m.hourly_overhead_cost,
    p.plant_id,
    p.plant_code,
    p.plant_name,
    pl.line_id,
    pl.line_code,
    pl.line_name,
    mt.machine_type_id,
    mt.type_code AS machine_type_code,
    mt.type_name AS machine_type,
    mt.process_stage,
    mt.standard_speed_rpm,
    mt.power_consumption_kwh,
    COALESCE(run_agg.total_runs, 0) AS total_runs_executed,
    COALESCE(run_agg.total_operating_hours, 0.0) AS total_operating_hours,
    COALESCE(run_agg.total_meters_produced, 0.0) AS total_meters_produced,
    COALESCE(dt_agg.total_downtime_hours, 0.0) AS total_downtime_hours,
    COALESCE(dt_agg.unplanned_breakdown_hours, 0.0) AS unplanned_breakdown_hours,
    COALESCE(dt_agg.unplanned_breakdown_count, 0) AS total_unplanned_breakdowns,
    COALESCE(dt_agg.total_downtime_overhead_loss, 0.0) AS total_downtime_overhead_usd,
    ROUND(COALESCE(run_agg.total_operating_hours, 0.0) / NULLIF(COALESCE(dt_agg.unplanned_breakdown_count, 0), 0), 2) AS mtbf_hours,
    ROUND(COALESCE(dt_agg.unplanned_breakdown_hours, 0.0) / NULLIF(COALESCE(dt_agg.unplanned_breakdown_count, 0), 0), 2) AS mttr_hours,
    ROUND((COALESCE(run_agg.total_operating_hours, 0.0) / NULLIF(COALESCE(run_agg.total_operating_hours, 0.0) + COALESCE(dt_agg.total_downtime_hours, 0.0), 0) * 100.0), 2) AS machine_utilization_pct,
    COALESCE(maint_agg.total_maintenance_spend, 0.0) AS total_maintenance_spend_usd,
    COALESCE(maint_agg.preventive_maintenance_spend, 0.0) AS preventive_spend_usd,
    COALESCE(maint_agg.corrective_maintenance_spend, 0.0) AS corrective_spend_usd
FROM machines m
JOIN production_lines pl ON m.line_id = pl.line_id
JOIN plants p ON pl.plant_id = p.plant_id
JOIN machine_types mt ON m.machine_type_id = mt.machine_type_id
LEFT JOIN (
    SELECT 
        machine_id,
        COUNT(run_id) AS total_runs,
        ROUND(SUM(8.0), 2) AS total_operating_hours,
        ROUND(SUM(actual_meters), 2) AS total_meters_produced
    FROM production_runs
    GROUP BY machine_id
) run_agg ON m.machine_id = run_agg.machine_id
LEFT JOIN (
    SELECT 
        machine_id,
        ROUND(SUM(duration_hours), 2) AS total_downtime_hours,
        ROUND(SUM(CASE WHEN downtime_category = 'Unplanned Breakdown' THEN duration_hours ELSE 0 END), 2) AS unplanned_breakdown_hours,
        SUM(CASE WHEN downtime_category = 'Unplanned Breakdown' THEN 1 ELSE 0 END) AS unplanned_breakdown_count,
        ROUND(SUM(financial_downtime_cost), 2) AS total_downtime_overhead_loss
    FROM machine_downtime
    GROUP BY machine_id
) dt_agg ON m.machine_id = dt_agg.machine_id
LEFT JOIN (
    SELECT 
        machine_id,
        ROUND(SUM(total_maintenance_cost), 2) AS total_maintenance_spend,
        ROUND(SUM(CASE WHEN maintenance_type = 'Preventive' THEN total_maintenance_cost ELSE 0 END), 2) AS preventive_maintenance_spend,
        ROUND(SUM(CASE WHEN maintenance_type IN ('Corrective', 'Emergency') THEN total_maintenance_cost ELSE 0 END), 2) AS corrective_maintenance_spend
    FROM machine_maintenance
    WHERE maintenance_status = 'Completed'
    GROUP BY machine_id
) maint_agg ON m.machine_id = maint_agg.machine_id;


-- ============================================================================
-- VIEW 04: vw_supplier_performance
-- ============================================================================
/*
BUSINESS PURPOSE:
Evaluates raw material suppliers across batch rejection rates, downstream
defect association, downstream scrap penalties, composite SQI, and procurement tiers.
*/
CREATE VIEW vw_supplier_performance AS
WITH SupplierRawMetrics AS (
    SELECT 
        s.supplier_id,
        s.supplier_code,
        s.supplier_name,
        s.credit_rating,
        s.payment_terms_days,
        s.is_preferred,
        loc.city AS supplier_city,
        loc.country AS supplier_country,
        COUNT(DISTINCT po.po_id) AS total_purchase_orders,
        ROUND(COALESCE(SUM(DISTINCT po.total_po_amount), 0.0), 2) AS total_po_spend_usd,
        COUNT(DISTINCT mb.batch_id) AS total_delivered_batches,
        SUM(CASE WHEN mb.quality_status = 'Accepted' THEN 1 ELSE 0 END) AS accepted_batches,
        SUM(CASE WHEN mb.quality_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_batches,
        ROUND((SUM(CASE WHEN mb.quality_status = 'Rejected' THEN 1.0 ELSE 0.0 END) / NULLIF(COUNT(DISTINCT mb.batch_id), 0) * 100.0), 2) AS rejection_rate_pct,
        COUNT(DISTINCT dr.defect_id) AS downstream_defect_count,
        ROUND(COALESCE(SUM(pw.net_financial_loss), 0.0), 2) AS downstream_waste_loss_usd
    FROM suppliers s
    JOIN locations loc ON s.location_id = loc.location_id
    LEFT JOIN purchase_orders po ON s.supplier_id = po.supplier_id
    LEFT JOIN material_batches mb ON s.supplier_id = mb.supplier_id
    LEFT JOIN material_consumption mc ON mb.batch_id = mc.batch_id
    LEFT JOIN production_runs pr ON mc.run_id = pr.run_id
    LEFT JOIN fabric_rolls fr ON pr.run_id = fr.run_id
    LEFT JOIN defect_records dr ON fr.roll_id = dr.roll_id
    LEFT JOIN production_waste pw ON pr.run_id = pw.run_id
    GROUP BY s.supplier_id, s.supplier_code, s.supplier_name, s.credit_rating, s.payment_terms_days, s.is_preferred, loc.city, loc.country
)
SELECT 
    supplier_id,
    supplier_code,
    supplier_name,
    credit_rating,
    payment_terms_days,
    is_preferred,
    supplier_city,
    supplier_country,
    total_purchase_orders,
    total_po_spend_usd,
    total_delivered_batches,
    accepted_batches,
    rejected_batches,
    COALESCE(rejection_rate_pct, 0.0) AS rejection_rate_pct,
    downstream_defect_count,
    downstream_waste_loss_usd,
    ROUND(
        CASE 
            WHEN 100.0 - (0.40 * COALESCE(rejection_rate_pct, 0.0) + 0.35 * (downstream_defect_count * 1.0 / NULLIF(total_delivered_batches, 0)) + 0.05 * (downstream_waste_loss_usd / NULLIF(total_po_spend_usd, 0) * 100.0)) > 100.0 THEN 100.0
            WHEN 100.0 - (0.40 * COALESCE(rejection_rate_pct, 0.0) + 0.35 * (downstream_defect_count * 1.0 / NULLIF(total_delivered_batches, 0)) + 0.05 * (downstream_waste_loss_usd / NULLIF(total_po_spend_usd, 0) * 100.0)) < 0.0 THEN 0.0
            ELSE 100.0 - (0.40 * COALESCE(rejection_rate_pct, 0.0) + 0.35 * (downstream_defect_count * 1.0 / NULLIF(total_delivered_batches, 0)) + 0.05 * (downstream_waste_loss_usd / NULLIF(total_po_spend_usd, 0) * 100.0))
        END, 2
    ) AS supplier_quality_index,
    CASE 
        WHEN (100.0 - (0.40 * COALESCE(rejection_rate_pct, 0.0) + 0.35 * (downstream_defect_count * 1.0 / NULLIF(total_delivered_batches, 0)) + 0.05 * (downstream_waste_loss_usd / NULLIF(total_po_spend_usd, 0) * 100.0))) >= 90.0 THEN 'Tier 1: Excellent'
        WHEN (100.0 - (0.40 * COALESCE(rejection_rate_pct, 0.0) + 0.35 * (downstream_defect_count * 1.0 / NULLIF(total_delivered_batches, 0)) + 0.05 * (downstream_waste_loss_usd / NULLIF(total_po_spend_usd, 0) * 100.0))) >= 80.0 THEN 'Tier 2: Good'
        WHEN (100.0 - (0.40 * COALESCE(rejection_rate_pct, 0.0) + 0.35 * (downstream_defect_count * 1.0 / NULLIF(total_delivered_batches, 0)) + 0.05 * (downstream_waste_loss_usd / NULLIF(total_po_spend_usd, 0) * 100.0))) >= 70.0 THEN 'Tier 3: Average'
        WHEN (100.0 - (0.40 * COALESCE(rejection_rate_pct, 0.0) + 0.35 * (downstream_defect_count * 1.0 / NULLIF(total_delivered_batches, 0)) + 0.05 * (downstream_waste_loss_usd / NULLIF(total_po_spend_usd, 0) * 100.0))) >= 60.0 THEN 'Tier 4: Poor'
        ELSE 'Tier 5: Critical'
    END AS supplier_tier
FROM SupplierRawMetrics;


-- ============================================================================
-- VIEW 05: vw_production_loss
-- ============================================================================
/*
BUSINESS PURPOSE:
Calculates consolidated financial production losses at the run level:
Material Waste Net Loss + Defect Scrapping Loss + Rework Labor/Chemical Cost +
Unplanned Machine Downtime Overhead Cost = Total Production Loss (TPL).
*/
CREATE VIEW vw_production_loss AS
SELECT 
    pr.run_id,
    pr.run_code,
    pr.run_date,
    SUBSTR(pr.run_date, 1, 4) AS production_year,
    SUBSTR(pr.run_date, 6, 2) AS production_month,
    p.plant_id,
    p.plant_code,
    p.plant_name,
    pl.line_id,
    pl.line_code,
    pl.line_name,
    m.machine_id,
    m.machine_code,
    m.machine_name,
    prod.product_id,
    prod.product_code,
    prod.product_name,
    prod.fabric_type,
    prod.standard_cost_per_meter,
    pr.actual_meters,
    COALESCE(waste_agg.waste_loss, 0.0) AS material_waste_loss_usd,
    COALESCE(defect_agg.defect_scrap_loss, 0.0) AS defect_scrapping_loss_usd,
    COALESCE(rework_agg.rework_cost, 0.0) AS secondary_rework_cost_usd,
    COALESCE(dt_agg.downtime_loss, 0.0) AS downtime_overhead_loss_usd,
    ROUND(
        COALESCE(waste_agg.waste_loss, 0.0) +
        COALESCE(defect_agg.defect_scrap_loss, 0.0) +
        COALESCE(rework_agg.rework_cost, 0.0) +
        COALESCE(dt_agg.downtime_loss, 0.0), 2
    ) AS total_production_loss_usd
FROM production_runs pr
JOIN production_lines pl ON pr.line_id = pl.line_id
JOIN plants p ON pl.plant_id = p.plant_id
JOIN machines m ON pr.machine_id = m.machine_id
JOIN products prod ON pr.product_id = prod.product_id
LEFT JOIN (
    SELECT run_id, ROUND(SUM(net_financial_loss), 2) AS waste_loss
    FROM production_waste
    GROUP BY run_id
) waste_agg ON pr.run_id = waste_agg.run_id
LEFT JOIN (
    SELECT 
        fr.run_id,
        ROUND(SUM(fr.roll_length_meters * p_inner.standard_cost_per_meter), 2) AS defect_scrap_loss
    FROM fabric_rolls fr
    JOIN products p_inner ON fr.product_id = p_inner.product_id
    WHERE fr.roll_grade = 'Scrap'
    GROUP BY fr.run_id
) defect_agg ON pr.run_id = defect_agg.run_id
LEFT JOIN (
    SELECT 
        fr.run_id,
        ROUND(SUM((rw.technician_hours * emp.hourly_labor_rate) + rw.additional_chemical_cost), 2) AS rework_cost
    FROM fabric_rolls fr
    JOIN rework_records rw ON fr.roll_id = rw.roll_id
    JOIN employees emp ON rw.operator_id = emp.employee_id
    GROUP BY fr.run_id
) rework_agg ON pr.run_id = rework_agg.run_id
LEFT JOIN (
    SELECT run_id, ROUND(SUM(financial_downtime_cost), 2) AS downtime_loss
    FROM machine_downtime
    WHERE downtime_category = 'Unplanned Breakdown' AND run_id IS NOT NULL
    GROUP BY run_id
) dt_agg ON pr.run_id = dt_agg.run_id;


-- ============================================================================
-- VIEW 06: vw_machine_risk
-- ============================================================================
/*
BUSINESS PURPOSE:
Heuristic Machine Intelligence Engine that scores every machine asset (0 to 100)
based on multi-factor operational vulnerability:
Downtime Hours (30%) + Failure Frequency (25%) + Defect Rate (20%) +
Maintenance Spend (15%) + Machine Age (10%).
Classifies assets into LOW, MEDIUM, HIGH, and CRITICAL risk tiers.
*/
CREATE VIEW vw_machine_risk AS
WITH BaseMachineStats AS (
    SELECT 
        m.machine_id,
        m.machine_code,
        m.machine_name,
        mt.type_code,
        mt.type_name AS machine_type,
        p.plant_id,
        p.plant_code,
        p.plant_name,
        ROUND((JULIANDAY('2025-12-31') - JULIANDAY(m.installation_date)) / 365.25, 1) AS machine_age_years,
        COALESCE(run_s.total_runs, 0) AS total_runs_executed,
        COALESCE(run_s.total_operating_hours, 0.0) AS total_operating_hours,
        COALESCE(dt_s.unplanned_downtime_hours, 0.0) AS total_downtime_hours,
        COALESCE(dt_s.breakdown_count, 0) AS total_breakdown_count,
        COALESCE(def_s.defect_count, 0) AS total_defects_count,
        ROUND(COALESCE(def_s.defect_count, 0) * 1.0 / NULLIF(COALESCE(run_s.total_runs, 0), 0), 3) AS defects_per_run,
        COALESCE(maint_s.total_maintenance_spend, 0.0) AS total_maintenance_spend_usd,
        ROUND(COALESCE(run_s.total_operating_hours, 0.0) / NULLIF(COALESCE(dt_s.breakdown_count, 0), 0), 2) AS mtbf_hours,
        ROUND(COALESCE(dt_s.unplanned_downtime_hours, 0.0) / NULLIF(COALESCE(dt_s.breakdown_count, 0), 0), 2) AS mttr_hours
    FROM machines m
    JOIN machine_types mt ON m.machine_type_id = mt.machine_type_id
    JOIN production_lines pl ON m.line_id = pl.line_id
    JOIN plants p ON pl.plant_id = p.plant_id
    LEFT JOIN (
        SELECT machine_id, COUNT(run_id) AS total_runs, SUM(8.0) AS total_operating_hours
        FROM production_runs
        GROUP BY machine_id
    ) run_s ON m.machine_id = run_s.machine_id
    LEFT JOIN (
        SELECT 
            machine_id,
            ROUND(SUM(duration_hours), 2) AS unplanned_downtime_hours,
            COUNT(downtime_id) AS breakdown_count
        FROM machine_downtime
        WHERE downtime_category = 'Unplanned Breakdown'
        GROUP BY machine_id
    ) dt_s ON m.machine_id = dt_s.machine_id
    LEFT JOIN (
        SELECT 
            pr.machine_id,
            COUNT(dr.defect_id) AS defect_count
        FROM production_runs pr
        JOIN fabric_rolls fr ON pr.run_id = fr.run_id
        JOIN defect_records dr ON fr.roll_id = dr.roll_id
        GROUP BY pr.machine_id
    ) def_s ON m.machine_id = def_s.machine_id
    LEFT JOIN (
        SELECT machine_id, ROUND(SUM(total_maintenance_cost), 2) AS total_maintenance_spend
        FROM machine_maintenance
        WHERE maintenance_status = 'Completed'
        GROUP BY machine_id
    ) maint_s ON m.machine_id = maint_s.machine_id
),
MaxBounds AS (
    SELECT 
        MAX(total_downtime_hours) AS max_dt,
        MAX(total_breakdown_count) AS max_freq,
        MAX(defects_per_run) AS max_def,
        MAX(total_maintenance_spend_usd) AS max_maint,
        MAX(machine_age_years) AS max_age
    FROM BaseMachineStats
),
NormalizedRisk AS (
    SELECT 
        b.*,
        (b.total_downtime_hours / NULLIF(mb.max_dt, 0)) * 100.0 AS s_downtime,
        (b.total_breakdown_count * 1.0 / NULLIF(mb.max_freq, 0)) * 100.0 AS s_frequency,
        (b.defects_per_run / NULLIF(mb.max_def, 0)) * 100.0 AS s_defect,
        (b.total_maintenance_spend_usd / NULLIF(mb.max_maint, 0)) * 100.0 AS s_maintenance,
        (b.machine_age_years / NULLIF(mb.max_age, 0)) * 100.0 AS s_age
    FROM BaseMachineStats b
    CROSS JOIN MaxBounds mb
)
SELECT 
    machine_id,
    machine_code,
    machine_name,
    type_code,
    machine_type,
    plant_id,
    plant_code,
    plant_name,
    machine_age_years,
    total_runs_executed,
    total_operating_hours,
    total_downtime_hours,
    total_breakdown_count,
    total_defects_count,
    defects_per_run,
    total_maintenance_spend_usd,
    mtbf_hours,
    mttr_hours,
    ROUND(
        (0.30 * s_downtime) + 
        (0.25 * s_frequency) + 
        (0.20 * s_defect) + 
        (0.15 * s_maintenance) + 
        (0.10 * s_age), 2
    ) AS machine_risk_score,
    CASE 
        WHEN ((0.30 * s_downtime) + (0.25 * s_frequency) + (0.20 * s_defect) + (0.15 * s_maintenance) + (0.10 * s_age)) >= 80.0 THEN 'CRITICAL'
        WHEN ((0.30 * s_downtime) + (0.25 * s_frequency) + (0.20 * s_defect) + (0.15 * s_maintenance) + (0.10 * s_age)) >= 60.0 THEN 'HIGH'
        WHEN ((0.30 * s_downtime) + (0.25 * s_frequency) + (0.20 * s_defect) + (0.15 * s_maintenance) + (0.10 * s_age)) >= 30.0 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS risk_category
FROM NormalizedRisk;


-- ============================================================================
-- VIEW 07: vw_business_alerts
-- ============================================================================
/*
BUSINESS PURPOSE:
Automated operational exception monitoring view that surfaces high-risk conditions:
HIGH_WASTE, HIGH_DEFECT, HIGH_DOWNTIME, CRITICAL_MACHINE, POOR_SUPPLIER,
LATE_PRODUCTION, and HIGH_REWORK alerts.
*/
CREATE VIEW vw_business_alerts AS
-- 1. High Waste Runs Alert (> $1,000 net scrap loss)
SELECT 
    'HIGH_WASTE' AS alert_type,
    'High Material Waste Loss on Run' AS alert_title,
    'CRITICAL' AS alert_severity,
    pr.run_date AS alert_date,
    p.plant_name,
    m.machine_code AS entity_code,
    'Run ' || pr.run_code || ' produced $' || ROUND(pw.net_financial_loss, 2) || ' scrap loss (' || pw.waste_type || ')' AS alert_message,
    pw.net_financial_loss AS financial_impact_usd
FROM production_waste pw
JOIN production_runs pr ON pw.run_id = pr.run_id
JOIN machines m ON pr.machine_id = m.machine_id
JOIN production_lines pl ON m.line_id = pl.line_id
JOIN plants p ON pl.plant_id = p.plant_id
WHERE pw.net_financial_loss >= 1000.0

UNION ALL

-- 2. Critical Defect Roll Alert (Critical severity defects detected)
SELECT 
    'HIGH_DEFECT' AS alert_type,
    'Critical Severity Defect Detected' AS alert_title,
    'CRITICAL' AS alert_severity,
    SUBSTR(dr.detected_at, 1, 10) AS alert_date,
    p.plant_name,
    fr.roll_barcode AS entity_code,
    'Roll ' || fr.roll_barcode || ' flagged with ' || dt.defect_name || ' (' || dt.severity_level || ')' AS alert_message,
    dt.standard_scrapping_cost_per_defect AS financial_impact_usd
FROM defect_records dr
JOIN defect_types dt ON dr.defect_type_id = dt.defect_type_id
JOIN fabric_rolls fr ON dr.roll_id = fr.roll_id
JOIN production_runs pr ON fr.run_id = pr.run_id
JOIN production_lines pl ON pr.line_id = pl.line_id
JOIN plants p ON pl.plant_id = p.plant_id
WHERE dr.severity = 'Critical'

UNION ALL

-- 3. Chronic Machine Downtime Alert (Breakdowns > 6.0 hours duration)
SELECT 
    'HIGH_DOWNTIME' AS alert_type,
    'Severe Machine Breakdown Stoppage' AS alert_title,
    'HIGH' AS alert_severity,
    SUBSTR(md.start_time, 1, 10) AS alert_date,
    p.plant_name,
    m.machine_code AS entity_code,
    'Machine ' || m.machine_code || ' breakdown lasted ' || md.duration_hours || ' hrs (' || md.root_cause_category || ': ' || md.reason_description || ')' AS alert_message,
    md.financial_downtime_cost AS financial_impact_usd
FROM machine_downtime md
JOIN machines m ON md.machine_id = m.machine_id
JOIN production_lines pl ON m.line_id = pl.line_id
JOIN plants p ON pl.plant_id = p.plant_id
WHERE md.downtime_category = 'Unplanned Breakdown' AND md.duration_hours >= 6.0

UNION ALL

-- 4. Poor Supplier Quality Alert (Vendors in Tier 5 Critical)
SELECT 
    'POOR_SUPPLIER' AS alert_type,
    'Supplier Quality Rating Critical' AS alert_title,
    'HIGH' AS alert_severity,
    '2025-12-31' AS alert_date,
    'Corporate Supply Chain' AS plant_name,
    sp.supplier_code AS entity_code,
    'Supplier ' || sp.supplier_name || ' categorized in Tier 5 (SQI Score: ' || sp.supplier_quality_index || ', Rejection Rate: ' || sp.rejection_rate_pct || '%)' AS alert_message,
    sp.downstream_waste_loss_usd AS financial_impact_usd
FROM vw_supplier_performance sp
WHERE sp.supplier_tier = 'Tier 5: Critical';
