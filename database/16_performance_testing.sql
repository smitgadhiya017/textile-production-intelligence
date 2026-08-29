-- ============================================================================
-- TEXTILE PRODUCTION WASTE, DEFECT & MACHINE INTELLIGENCE SYSTEM
-- Script: 16_performance_testing.sql
-- Description: Query Performance Optimization & Execution Plan Benchmarking Suite.
--              Compares query execution plans, scan strategies (Seq Scan vs. Index Scan),
--              and execution latency across 5 core analytical query workloads.
-- ============================================================================

-- ============================================================================
-- BENCHMARK 01: Fabric Roll Quality Inspection & Defect Breakdown
-- ============================================================================
/*
QUERY DESCRIPTION:
Joins fabric_rolls, quality_inspections, and defect_records across 15k+ rolls
filtering for Grade 'Scrap' or 'C' rolls.

OPTIMIZATION STRATEGY:
- Targeted Indexes: idx_fr_run, idx_qi_roll, idx_dr_roll, idx_fr_grade_status
- Scan Transformation: Replaces sequential table scans with B-Tree Index Scans.
*/

EXPLAIN ANALYZE
SELECT 
    fr.roll_barcode,
    fr.roll_grade,
    fr.roll_status,
    qi.quality_score,
    qi.inspection_result,
    COUNT(dr.defect_id) AS total_defects,
    SUM(dr.defect_points) AS total_penalty_points
FROM fabric_rolls fr
JOIN quality_inspections qi ON fr.roll_id = qi.roll_id
LEFT JOIN defect_records dr ON fr.roll_id = dr.roll_id
WHERE fr.roll_grade IN ('C', 'Scrap')
GROUP BY fr.roll_id, fr.roll_barcode, fr.roll_grade, fr.roll_status, qi.quality_score, qi.inspection_result;


-- ============================================================================
-- BENCHMARK 02: Machine Downtime & Failure Root Cause Aggregation
-- ============================================================================
/*
QUERY DESCRIPTION:
Aggregates 4,500+ downtime stoppage records by machine, root cause category,
and calculates total financial downtime cost.

OPTIMIZATION STRATEGY:
- Targeted Indexes: idx_md_machine, idx_md_category, idx_machines_line
- Scan Transformation: Direct Index Scan on (machine_id, downtime_category).
*/

EXPLAIN ANALYZE
SELECT 
    m.machine_code,
    m.machine_name,
    mt.type_name,
    md.root_cause_category,
    COUNT(md.downtime_id) AS incident_count,
    ROUND(SUM(md.duration_hours), 2) AS total_downtime_hours,
    ROUND(SUM(md.financial_downtime_cost), 2) AS total_downtime_loss_usd
FROM machine_downtime md
JOIN machines m ON md.machine_id = m.machine_id
JOIN machine_types mt ON m.machine_type_id = mt.machine_type_id
WHERE md.downtime_category = 'Unplanned Breakdown'
GROUP BY m.machine_id, m.machine_code, m.machine_name, mt.type_name, md.root_cause_category
ORDER BY total_downtime_loss_usd DESC;


-- ============================================================================
-- BENCHMARK 03: Raw Material Batch Traceability & Downstream Scrap Join
-- ============================================================================
/*
QUERY DESCRIPTION:
Multi-table 5-level join tracing material batches from suppliers through consumption
to production waste loss.

OPTIMIZATION STRATEGY:
- Targeted Indexes: idx_mb_supplier, idx_mc_batch, idx_mc_run, idx_pw_run
- Scan Transformation: Nested Loop / Hash Join with Index Range Scans on batch_id and run_id.
*/

EXPLAIN ANALYZE
SELECT 
    s.supplier_code,
    s.supplier_name,
    mat.material_code,
    mat.material_name,
    COUNT(DISTINCT mb.batch_id) AS total_batches_delivered,
    ROUND(SUM(mc.consumed_quantity), 2) AS total_kg_consumed,
    ROUND(SUM(pw.net_financial_loss), 2) AS total_downstream_scrap_usd
FROM suppliers s
JOIN material_batches mb ON s.supplier_id = mb.supplier_id
JOIN materials mat ON mb.material_id = mat.material_id
JOIN material_consumption mc ON mb.batch_id = mc.batch_id
JOIN production_runs pr ON mc.run_id = pr.run_id
JOIN production_waste pw ON pr.run_id = pw.run_id
GROUP BY s.supplier_id, s.supplier_code, s.supplier_name, mat.material_id, mat.material_code, mat.material_name;


-- ============================================================================
-- BENCHMARK 04: Date-Range Filtered Financial Loss Rollup
-- ============================================================================
/*
QUERY DESCRIPTION:
Aggregates waste losses, scrap, and downtime overhead over specific calendar quarters.

OPTIMIZATION STRATEGY:
- Targeted Indexes: idx_pr_date, idx_pw_recorded, idx_md_start_time
- Scan Transformation: Index Range Scan on date boundaries eliminating full table scans.
*/

EXPLAIN ANALYZE
SELECT 
    p.plant_code,
    p.plant_name,
    COUNT(DISTINCT pr.run_id) AS total_runs_filtered,
    ROUND(SUM(pw.net_financial_loss), 2) AS total_waste_loss_usd
FROM plants p
JOIN production_lines pl ON p.plant_id = pl.plant_id
JOIN production_runs pr ON pl.line_id = pr.line_id
JOIN production_waste pw ON pr.run_id = pw.run_id
WHERE pr.run_date BETWEEN '2024-01-01' AND '2024-12-31'
GROUP BY p.plant_id, p.plant_code, p.plant_name;


-- ============================================================================
-- BENCHMARK 05: Operator & Shift Production Efficiency Matrix
-- ============================================================================
/*
QUERY DESCRIPTION:
Evaluates operational efficiency percentage across 10,000 runs grouped by operator,
shift, and machine type.

OPTIMIZATION STRATEGY:
- Targeted Indexes: idx_pr_operator, idx_pr_shift, idx_pr_machine
- Scan Transformation: Fast Index Lookup with Covering Index aggregation.
*/

EXPLAIN ANALYZE
SELECT 
    e.employee_code,
    e.first_name || ' ' || e.last_name AS operator_name,
    s.shift_name,
    COUNT(pr.run_id) AS runs_completed,
    ROUND(AVG((pr.actual_meters / pr.planned_meters) * 100.0), 2) AS avg_efficiency_pct,
    ROUND(SUM(pr.actual_meters), 2) AS total_meters_produced
FROM employees e
JOIN production_runs pr ON e.employee_id = pr.operator_id
JOIN shifts s ON pr.shift_id = s.shift_id
GROUP BY e.employee_id, e.employee_code, e.first_name, e.last_name, s.shift_id, s.shift_name;
