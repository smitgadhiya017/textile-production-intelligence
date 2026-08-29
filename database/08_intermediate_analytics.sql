-- ============================================================================
-- TEXTILE PRODUCTION WASTE, DEFECT & MACHINE INTELLIGENCE SYSTEM
-- Script: 08_intermediate_analytics.sql
-- Description: 20 Intermediate SQL Business Queries utilizing multi-table JOINs,
--              nested subqueries, correlated subqueries, EXISTS/NOT EXISTS,
--              conditional aggregations, and statistical sample-size filters.
-- ============================================================================

-- ============================================================================
-- QUERY 21: Machine Defect Rate vs Machine-Type Fleet Benchmark
-- ============================================================================

SELECT 
    m.machine_id,
    m.machine_code,
    m.machine_name,
    mt.type_name,
    COUNT(DISTINCT pr.run_id) AS total_runs,
    COUNT(dr.defect_id) AS total_defects_detected,
    ROUND(COUNT(dr.defect_id) * 1.0 / NULLIF(COUNT(DISTINCT pr.run_id), 0), 3) AS machine_defects_per_run,
    type_bench.type_avg_defects_per_run,
    ROUND((COUNT(dr.defect_id) * 1.0 / NULLIF(COUNT(DISTINCT pr.run_id), 0)) - type_bench.type_avg_defects_per_run, 3) AS variance_from_type_avg
FROM machines m
JOIN machine_types mt ON m.machine_type_id = mt.machine_type_id
JOIN production_runs pr ON m.machine_id = pr.machine_id
LEFT JOIN fabric_rolls fr ON pr.run_id = fr.run_id
LEFT JOIN defect_records dr ON fr.roll_id = dr.roll_id
JOIN (
    SELECT 
        m_inner.machine_type_id,
        ROUND(COUNT(dr_inner.defect_id) * 1.0 / NULLIF(COUNT(DISTINCT pr_inner.run_id), 0), 3) AS type_avg_defects_per_run
    FROM machines m_inner
    JOIN production_runs pr_inner ON m_inner.machine_id = pr_inner.machine_id
    LEFT JOIN fabric_rolls fr_inner ON pr_inner.run_id = fr_inner.run_id
    LEFT JOIN defect_records dr_inner ON fr_inner.roll_id = dr_inner.roll_id
    GROUP BY m_inner.machine_type_id
) type_bench ON m.machine_type_id = type_bench.machine_type_id
GROUP BY m.machine_id, m.machine_code, m.machine_name, mt.type_name, type_bench.type_avg_defects_per_run
HAVING COUNT(DISTINCT pr.run_id) >= 30
ORDER BY variance_from_type_avg DESC
LIMIT 15;

-- ============================================================================
-- QUERY 22: Supplier Defect Association Rate via Batch-to-Roll Trace
-- ============================================================================

SELECT 
    s.supplier_id,
    s.supplier_code,
    s.supplier_name,
    s.credit_rating,
    COUNT(DISTINCT mb.batch_id) AS distinct_batches_consumed,
    ROUND(SUM(pr.actual_meters), 2) AS total_traceable_meters_produced,
    COUNT(dr.defect_id) AS downstream_defects_recorded,
    ROUND((COUNT(dr.defect_id) * 1000.0) / NULLIF(SUM(pr.actual_meters), 0), 2) AS defects_per_1000_meters,
    ROUND(SUM(CASE WHEN mb.quality_status = 'Rejected' THEN 1.0 ELSE 0.0 END) / COUNT(DISTINCT mb.batch_id) * 100.0, 2) AS initial_rejection_rate_pct
FROM suppliers s
JOIN material_batches mb ON s.supplier_id = mb.supplier_id
JOIN material_consumption mc ON mb.batch_id = mc.batch_id
JOIN production_runs pr ON mc.run_id = pr.run_id
JOIN fabric_rolls fr ON pr.run_id = fr.run_id
LEFT JOIN defect_records dr ON fr.roll_id = dr.roll_id
GROUP BY s.supplier_id, s.supplier_code, s.supplier_name, s.credit_rating
HAVING COUNT(DISTINCT mb.batch_id) >= 10
ORDER BY defects_per_1000_meters DESC
LIMIT 15;

-- ============================================================================
-- QUERY 23: Production Lines with Chronic Output Deficits
-- ============================================================================

SELECT 
    p.plant_name,
    pl.line_code,
    pl.line_name,
    pl.line_type,
    COUNT(pr.run_id) AS total_runs_executed,
    ROUND(SUM(pr.planned_meters), 2) AS total_planned_meters,
    ROUND(SUM(pr.actual_meters), 2) AS total_actual_meters,
    ROUND(SUM(pr.actual_meters) - SUM(pr.planned_meters), 2) AS output_shortfall_meters,
    ROUND((SUM(pr.actual_meters) / NULLIF(SUM(pr.planned_meters), 0) * 100.0), 2) AS line_efficiency_pct
FROM plants p
JOIN production_lines pl ON p.plant_id = pl.plant_id
JOIN production_runs pr ON pl.line_id = pr.line_id
GROUP BY p.plant_name, pl.line_code, pl.line_name, pl.line_type
HAVING COUNT(pr.run_id) >= 100 AND (SUM(pr.actual_meters) / NULLIF(SUM(pr.planned_meters), 0) * 100.0) < 98.50
ORDER BY line_efficiency_pct ASC;

-- ============================================================================
-- QUERY 24: Unplanned Machine Breakdowns: MTBF and MTTR Calculation
-- ============================================================================

SELECT 
    mt.type_code,
    mt.type_name,
    mt.process_stage,
    COUNT(DISTINCT m.machine_id) AS installed_machines_count,
    ROUND(SUM(run_data.total_run_hours), 2) AS total_operating_hours,
    COUNT(md.downtime_id) AS total_unplanned_breakdowns,
    ROUND(SUM(md.duration_hours), 2) AS total_repair_downtime_hours,
    ROUND(SUM(run_data.total_run_hours) / NULLIF(COUNT(md.downtime_id), 0), 2) AS mtbf_hours_between_failures,
    ROUND(SUM(md.duration_hours) / NULLIF(COUNT(md.downtime_id), 0), 2) AS mttr_hours_to_repair
FROM machine_types mt
JOIN machines m ON mt.machine_type_id = m.machine_type_id
LEFT JOIN (
    SELECT 
        machine_id,
        SUM(8.0) AS total_run_hours
    FROM production_runs
    GROUP BY machine_id
) run_data ON m.machine_id = run_data.machine_id
LEFT JOIN machine_downtime md ON m.machine_id = md.machine_id AND md.downtime_category = 'Unplanned Breakdown'
GROUP BY mt.type_code, mt.type_name, mt.process_stage
ORDER BY mtbf_hours_between_failures ASC;

-- ============================================================================
-- QUERY 25: First-Pass Yield (FPY) by Product Complexity Tier
-- ============================================================================

SELECT 
    prod.complexity_tier,
    COUNT(DISTINCT prod.product_id) AS total_products,
    COUNT(fr.roll_id) AS total_rolls_produced,
    SUM(CASE WHEN fr.roll_grade = 'A' AND rw.rework_id IS NULL THEN 1 ELSE 0 END) AS first_pass_perfect_rolls,
    SUM(CASE WHEN rw.rework_id IS NOT NULL THEN 1 ELSE 0 END) AS reworked_rolls_count,
    SUM(CASE WHEN fr.roll_grade = 'Scrap' THEN 1 ELSE 0 END) AS scrapped_rolls_count,
    ROUND((SUM(CASE WHEN fr.roll_grade = 'A' AND rw.rework_id IS NULL THEN 1.0 ELSE 0.0 END) / COUNT(fr.roll_id) * 100.0), 2) AS first_pass_yield_fpy_pct,
    ROUND((SUM(CASE WHEN rw.rework_id IS NOT NULL THEN 1.0 ELSE 0.0 END) / COUNT(fr.roll_id) * 100.0), 2) AS rework_rate_pct
FROM products prod
JOIN fabric_rolls fr ON prod.product_id = fr.product_id
LEFT JOIN rework_records rw ON fr.roll_id = rw.roll_id
GROUP BY prod.complexity_tier
ORDER BY CASE prod.complexity_tier WHEN 'Low' THEN 1 WHEN 'Medium' THEN 2 WHEN 'High' THEN 3 ELSE 4 END;

-- ============================================================================
-- QUERY 26: Operators Achieving Superior Quality & Efficiency
-- ============================================================================

SELECT 
    e.employee_id,
    e.employee_code,
    e.first_name || ' ' || e.last_name AS operator_name,
    p.plant_name,
    e.skill_level,
    COUNT(DISTINCT pr.run_id) AS runs_completed,
    ROUND(SUM(pr.actual_meters), 2) AS total_meters_produced,
    ROUND(AVG(pr.actual_meters / NULLIF(pr.planned_meters, 0) * 100.0), 2) AS avg_efficiency_pct,
    ROUND(SUM(CASE WHEN fr.roll_grade = 'A' THEN 1.0 ELSE 0.0 END) / COUNT(fr.roll_id) * 100.0, 2) AS grade_a_percentage
FROM employees e
JOIN plants p ON e.plant_id = p.plant_id
JOIN production_runs pr ON e.employee_id = pr.operator_id
JOIN fabric_rolls fr ON pr.run_id = fr.run_id
WHERE e.role = 'Operator'
GROUP BY e.employee_id, e.employee_code, e.first_name, e.last_name, p.plant_name, e.skill_level
HAVING COUNT(DISTINCT pr.run_id) >= 25 
   AND AVG(pr.actual_meters / NULLIF(pr.planned_meters, 0) * 100.0) >= 100.0
   AND (SUM(CASE WHEN fr.roll_grade = 'A' THEN 1.0 ELSE 0.0 END) / COUNT(fr.roll_id) * 100.0) >= 92.0
ORDER BY grade_a_percentage DESC, avg_efficiency_pct DESC
LIMIT 15;

-- ============================================================================
-- QUERY 27: Production Runs Generating Abnormal Waste (High-Waste Outliers)
-- ============================================================================

SELECT 
    pr.run_id,
    pr.run_code,
    pr.run_date,
    p.plant_name,
    m.machine_code,
    prod.product_name,
    e.first_name || ' ' || e.last_name AS operator_name,
    pw.waste_type,
    pw.waste_quantity,
    pw.unit_of_measure,
    pw.net_financial_loss AS run_waste_loss_usd,
    ROUND((SELECT AVG(net_financial_loss) FROM production_waste), 2) AS enterprise_avg_loss_usd,
    ROUND(pw.net_financial_loss / (SELECT AVG(net_financial_loss) FROM production_waste), 2) AS times_above_average
FROM production_waste pw
JOIN production_runs pr ON pw.run_id = pr.run_id
JOIN machines m ON pr.machine_id = m.machine_id
JOIN production_lines pl ON m.line_id = pl.line_id
JOIN plants p ON pl.plant_id = p.plant_id
JOIN products prod ON pr.product_id = prod.product_id
JOIN employees e ON pr.operator_id = e.employee_id
WHERE pw.net_financial_loss > 2.0 * (SELECT AVG(net_financial_loss) FROM production_waste)
ORDER BY pw.net_financial_loss DESC
LIMIT 20;

-- ============================================================================
-- QUERY 28: Machines with High Corrective Maintenance to Preventive Ratio
-- ============================================================================

SELECT 
    m.machine_id,
    m.machine_code,
    m.machine_name,
    p.plant_name,
    m.manufacturer,
    m.installation_date,
    COUNT(mm.maintenance_id) AS total_maintenance_events,
    ROUND(SUM(mm.total_maintenance_cost), 2) AS total_spend_usd,
    ROUND(SUM(CASE WHEN mm.maintenance_type IN ('Corrective', 'Emergency') THEN mm.total_maintenance_cost ELSE 0 END), 2) AS reactive_spend_usd,
    ROUND(SUM(CASE WHEN mm.maintenance_type = 'Preventive' THEN mm.total_maintenance_cost ELSE 0 END), 2) AS preventive_spend_usd,
    ROUND(SUM(CASE WHEN mm.maintenance_type IN ('Corrective', 'Emergency') THEN mm.total_maintenance_cost ELSE 0.0 END) / NULLIF(SUM(mm.total_maintenance_cost), 0) * 100.0, 2) AS reactive_cost_ratio_pct
FROM machines m
JOIN production_lines pl ON m.line_id = pl.line_id
JOIN plants p ON pl.plant_id = p.plant_id
JOIN machine_maintenance mm ON m.machine_id = mm.machine_id
WHERE mm.maintenance_status = 'Completed'
GROUP BY m.machine_id, m.machine_code, m.machine_name, p.plant_name, m.manufacturer, m.installation_date
HAVING SUM(mm.total_maintenance_cost) >= 5000.0
   AND (SUM(CASE WHEN mm.maintenance_type IN ('Corrective', 'Emergency') THEN mm.total_maintenance_cost ELSE 0.0 END) / NULLIF(SUM(mm.total_maintenance_cost), 0) * 100.0) >= 60.0
ORDER BY reactive_cost_ratio_pct DESC, total_spend_usd DESC;

-- ============================================================================
-- QUERY 29: Customer Orders Experiencing Manufacturing Delays
-- ============================================================================

SELECT 
    co.order_number,
    c.customer_name,
    c.segment,
    p.product_name,
    co.ordered_meters,
    co.order_date,
    co.promised_delivery_date,
    co.actual_dispatch_date,
    co.order_status,
    ROUND(co.ordered_meters * co.unit_selling_price, 2) AS total_order_value_usd,
    CASE 
        WHEN co.actual_dispatch_date IS NOT NULL THEN (JULIANDAY(co.actual_dispatch_date) - JULIANDAY(co.promised_delivery_date))
        ELSE (JULIANDAY('2025-12-31') - JULIANDAY(co.promised_delivery_date))
    END AS days_delayed
FROM customer_orders co
JOIN customers c ON co.customer_id = c.customer_id
JOIN products p ON co.product_id = p.product_id
WHERE (co.actual_dispatch_date > co.promised_delivery_date) OR co.order_status = 'Delayed'
ORDER BY days_delayed DESC
LIMIT 20;

-- ============================================================================
-- QUERY 30: Material Batches Consumed with Zero Quality Defects (Clean Batches)
-- ============================================================================

SELECT 
    mb.batch_id,
    mb.batch_code,
    s.supplier_name,
    m.material_name,
    mb.initial_quantity,
    mb.unit_of_measure,
    mb.received_date,
    COUNT(DISTINCT mc.run_id) AS runs_supported,
    ROUND(SUM(pr.actual_meters), 2) AS total_meters_produced
FROM material_batches mb
JOIN suppliers s ON mb.supplier_id = s.supplier_id
JOIN materials m ON mb.material_id = m.material_id
JOIN material_consumption mc ON mb.batch_id = mc.batch_id
JOIN production_runs pr ON mc.run_id = pr.run_id
WHERE mb.quality_status = 'Accepted'
  AND NOT EXISTS (
      SELECT 1 
      FROM fabric_rolls fr
      JOIN defect_records dr ON fr.roll_id = dr.roll_id
      WHERE fr.run_id = pr.run_id
  )
GROUP BY mb.batch_id, mb.batch_code, s.supplier_name, m.material_name, mb.initial_quantity, mb.unit_of_measure, mb.received_date
HAVING COUNT(DISTINCT mc.run_id) >= 1
ORDER BY total_meters_produced DESC
LIMIT 15;

-- ============================================================================
-- QUERY 31: Monthly Waste Cost as a Percentage of Gross Production Value
-- ============================================================================

SELECT 
    prod_m.prod_year,
    prod_m.prod_month,
    prod_m.total_meters_produced,
    prod_m.gross_production_cost_usd,
    COALESCE(waste_m.net_waste_loss_usd, 0.0) AS net_waste_loss_usd,
    ROUND((COALESCE(waste_m.net_waste_loss_usd, 0.0) / NULLIF(prod_m.gross_production_cost_usd, 0) * 100.0), 2) AS waste_loss_pct_of_prod_cost
FROM (
    SELECT 
        SUBSTR(pr.run_date, 1, 4) AS prod_year,
        SUBSTR(pr.run_date, 6, 2) AS prod_month,
        ROUND(SUM(pr.actual_meters), 2) AS total_meters_produced,
        ROUND(SUM(pr.actual_meters * p.standard_cost_per_meter), 2) AS gross_production_cost_usd
    FROM production_runs pr
    JOIN products p ON pr.product_id = p.product_id
    GROUP BY SUBSTR(pr.run_date, 1, 4), SUBSTR(pr.run_date, 6, 2)
) prod_m
LEFT JOIN (
    SELECT 
        SUBSTR(recorded_at, 1, 4) AS waste_year,
        SUBSTR(recorded_at, 6, 2) AS waste_month,
        ROUND(SUM(net_financial_loss), 2) AS net_waste_loss_usd
    FROM production_waste
    GROUP BY SUBSTR(recorded_at, 1, 4), SUBSTR(recorded_at, 6, 2)
) waste_m ON prod_m.prod_year = waste_m.waste_year AND prod_m.prod_month = waste_m.waste_month
ORDER BY prod_m.prod_year, prod_m.prod_month;

-- ============================================================================
-- QUERY 32: Shift Performance Comparison: Defect Rate vs Waste Generation
-- ============================================================================

SELECT 
    s.shift_code,
    s.shift_name,
    COUNT(DISTINCT pr.run_id) AS total_runs,
    ROUND(SUM(pr.actual_meters), 2) AS total_meters_produced,
    ROUND(SUM(CASE WHEN fr.roll_grade = 'A' THEN 1.0 ELSE 0.0 END) / COUNT(fr.roll_id) * 100.0, 2) AS first_pass_grade_a_pct,
    COUNT(DISTINCT dr.defect_id) AS total_defects,
    ROUND((COUNT(DISTINCT dr.defect_id) * 1000.0) / NULLIF(SUM(pr.actual_meters), 0), 2) AS defects_per_1000m,
    ROUND(COALESCE(SUM(pw.net_financial_loss), 0.0), 2) AS total_waste_loss_usd,
    ROUND(COALESCE(SUM(md.duration_hours), 0.0), 2) AS total_downtime_hours
FROM shifts s
JOIN production_runs pr ON s.shift_id = pr.shift_id
LEFT JOIN fabric_rolls fr ON pr.run_id = fr.run_id
LEFT JOIN defect_records dr ON fr.roll_id = dr.roll_id
LEFT JOIN production_waste pw ON pr.run_id = pw.run_id
LEFT JOIN machine_downtime md ON pr.run_id = md.run_id
GROUP BY s.shift_code, s.shift_name, s.shift_id
ORDER BY s.shift_id;

-- ============================================================================
-- QUERY 33: Most Expensive Single Defect Instances Scrapped
-- ============================================================================

SELECT 
    dr.defect_id,
    fr.roll_barcode,
    p.plant_name,
    prod.product_name,
    dt.defect_name,
    dt.category AS defect_category,
    dr.severity,
    fr.roll_length_meters,
    ROUND(fr.roll_length_meters * prod.standard_cost_per_meter, 2) AS scrapped_roll_cost_usd,
    dr.detected_at
FROM defect_records dr
JOIN fabric_rolls fr ON dr.roll_id = fr.roll_id
JOIN quality_inspections qi ON dr.inspection_id = qi.inspection_id
JOIN defect_types dt ON dr.defect_type_id = dt.defect_type_id
JOIN products prod ON fr.product_id = prod.product_id
JOIN production_runs pr ON fr.run_id = pr.run_id
JOIN production_lines pl ON pr.line_id = pl.line_id
JOIN plants p ON pl.plant_id = p.plant_id
WHERE fr.roll_grade = 'Scrap' AND dr.severity = 'Critical'
ORDER BY scrapped_roll_cost_usd DESC
LIMIT 20;

-- ============================================================================
-- QUERY 34: Supplier Quality Scorecard: Spend vs Net Production Loss
-- ============================================================================

SELECT 
    s.supplier_id,
    s.supplier_code,
    s.supplier_name,
    s.credit_rating,
    s.is_preferred,
    ROUND(SUM(DISTINCT po.total_po_amount), 2) AS total_procurement_spend_usd,
    COUNT(DISTINCT mb.batch_id) AS batches_delivered,
    ROUND(COALESCE(SUM(pw.net_financial_loss), 0.0), 2) AS total_downstream_waste_loss_usd,
    ROUND((COALESCE(SUM(pw.net_financial_loss), 0.0) / NULLIF(SUM(DISTINCT po.total_po_amount), 0) * 100.0), 2) AS waste_penalty_pct_of_spend
FROM suppliers s
JOIN purchase_orders po ON s.supplier_id = po.supplier_id
JOIN material_batches mb ON s.supplier_id = mb.supplier_id
LEFT JOIN material_consumption mc ON mb.batch_id = mc.batch_id
LEFT JOIN production_waste pw ON mc.run_id = pw.run_id
WHERE po.status = 'Received'
GROUP BY s.supplier_id, s.supplier_code, s.supplier_name, s.credit_rating, s.is_preferred
HAVING SUM(DISTINCT po.total_po_amount) >= 50000.0
ORDER BY waste_penalty_pct_of_spend DESC, total_downstream_waste_loss_usd DESC
LIMIT 15;

-- ============================================================================
-- QUERY 35: Machine Utilization Rate & Idle Time Analysis
-- ============================================================================

SELECT 
    p.plant_id,
    p.plant_code,
    p.plant_name,
    COUNT(DISTINCT m.machine_id) AS installed_machines,
    COUNT(DISTINCT pr.run_id) AS total_production_runs,
    ROUND(SUM(8.0), 2) AS total_operating_hours,
    ROUND(COALESCE(SUM(md.duration_hours), 0.0), 2) AS total_downtime_hours,
    ROUND((SUM(8.0) / NULLIF(SUM(8.0) + COALESCE(SUM(md.duration_hours), 0.0), 0) * 100.0), 2) AS estimated_utilization_rate_pct,
    ROUND(COALESCE(SUM(md.financial_downtime_cost), 0.0), 2) AS total_downtime_loss_usd
FROM plants p
JOIN production_lines pl ON p.plant_id = pl.plant_id
JOIN machines m ON pl.line_id = m.line_id
JOIN production_runs pr ON m.machine_id = pr.machine_id
LEFT JOIN machine_downtime md ON pr.run_id = md.run_id
GROUP BY p.plant_id, p.plant_code, p.plant_name
ORDER BY estimated_utilization_rate_pct DESC;

-- ============================================================================
-- QUERY 36: Fabric Products with Persistent High Defect Rates (> 8%)
-- ============================================================================

SELECT 
    prod.product_id,
    prod.product_code,
    prod.product_name,
    prod.fabric_type,
    prod.weave_type,
    prod.complexity_tier,
    COUNT(DISTINCT fr.roll_id) AS total_rolls_inspected,
    COUNT(DISTINCT dr.roll_id) AS defective_rolls_count,
    ROUND((COUNT(DISTINCT dr.roll_id) * 100.0) / NULLIF(COUNT(DISTINCT fr.roll_id), 0), 2) AS defective_roll_pct,
    ROUND(AVG(qi.quality_score), 2) AS avg_quality_score
FROM products prod
JOIN fabric_rolls fr ON prod.product_id = fr.product_id
JOIN quality_inspections qi ON fr.roll_id = qi.roll_id
LEFT JOIN defect_records dr ON fr.roll_id = dr.roll_id
GROUP BY prod.product_id, prod.product_code, prod.product_name, prod.fabric_type, prod.weave_type, prod.complexity_tier
HAVING COUNT(DISTINCT fr.roll_id) >= 200
   AND (COUNT(DISTINCT dr.roll_id) * 100.0 / NULLIF(COUNT(DISTINCT fr.roll_id), 0)) >= 8.0
ORDER BY defective_roll_pct DESC;

-- ============================================================================
-- QUERY 37: Unplanned Downtime Root Cause Frequency by Machine Age Group
-- ============================================================================

SELECT 
    CASE 
        WHEN m.installation_date >= '2019-01-01' THEN 'Modern (< 5 Years)'
        ELSE 'Aging (>= 5 Years)'
    END AS machine_age_bracket,
    md.root_cause_category,
    COUNT(md.downtime_id) AS stoppage_incidents,
    ROUND(SUM(md.duration_hours), 2) AS total_downtime_hours,
    ROUND(AVG(md.duration_hours), 2) AS avg_downtime_hours_per_incident,
    ROUND(SUM(md.financial_downtime_cost), 2) AS total_downtime_overhead_usd
FROM machine_downtime md
JOIN machines m ON md.machine_id = m.machine_id
WHERE md.downtime_category = 'Unplanned Breakdown'
GROUP BY 
    CASE WHEN m.installation_date >= '2019-01-01' THEN 'Modern (< 5 Years)' ELSE 'Aging (>= 5 Years)' END,
    md.root_cause_category
ORDER BY machine_age_bracket, total_downtime_hours DESC;

-- ============================================================================
-- QUERY 38: Rework Cost Impact & Post-Rework Quality Grade Recovery
-- ============================================================================

SELECT 
    rw.pre_rework_grade,
    rw.post_rework_grade,
    COUNT(rw.rework_id) AS total_rework_jobs,
    ROUND(SUM(rw.technician_hours * e.hourly_labor_rate), 2) AS total_rework_labor_cost_usd,
    ROUND(SUM(rw.additional_chemical_cost), 2) AS total_rework_chemical_cost_usd,
    ROUND(SUM((rw.technician_hours * e.hourly_labor_rate) + rw.additional_chemical_cost), 2) AS total_rework_expenditure_usd,
    ROUND(AVG((rw.technician_hours * e.hourly_labor_rate) + rw.additional_chemical_cost), 2) AS avg_cost_per_rework_job_usd
FROM rework_records rw
JOIN employees e ON rw.operator_id = e.employee_id
GROUP BY rw.pre_rework_grade, rw.post_rework_grade
ORDER BY rw.pre_rework_grade, total_rework_jobs DESC;

-- ============================================================================
-- QUERY 39: Customer Return & Order Fulfillment Integrity Check
-- ============================================================================

SELECT 
    c.customer_id,
    c.customer_code,
    c.customer_name,
    c.segment,
    c.credit_limit,
    COUNT(co.order_id) AS total_placed_orders,
    SUM(CASE WHEN co.order_status = 'Fulfilled' THEN 1 ELSE 0 END) AS fulfilled_orders,
    SUM(CASE WHEN co.order_status = 'Delayed' OR (co.actual_dispatch_date > co.promised_delivery_date) THEN 1 ELSE 0 END) AS delayed_orders,
    ROUND(SUM(CASE WHEN co.order_status = 'Delayed' OR (co.actual_dispatch_date > co.promised_delivery_date) THEN 1.0 ELSE 0.0 END) / COUNT(co.order_id) * 100.0, 2) AS delay_rate_pct,
    ROUND(SUM(co.ordered_meters * co.unit_selling_price), 2) AS total_customer_spend_usd
FROM customers c
JOIN customer_orders co ON c.customer_id = co.customer_id
GROUP BY c.customer_id, c.customer_code, c.customer_name, c.segment, c.credit_limit
HAVING COUNT(co.order_id) >= 10
ORDER BY delay_rate_pct DESC, total_customer_spend_usd DESC
LIMIT 15;

-- ============================================================================
-- QUERY 40: Total Enterprise Operational Loss Decomposition
-- ============================================================================

SELECT 
    '1. Material Waste Net Loss' AS loss_component,
    ROUND(SUM(net_financial_loss), 2) AS total_financial_loss_usd,
    ROUND(SUM(net_financial_loss) * 100.0 / (
        (SELECT SUM(net_financial_loss) FROM production_waste) +
        (SELECT SUM(financial_downtime_cost) FROM machine_downtime WHERE downtime_category = 'Unplanned Breakdown') +
        (SELECT SUM(total_maintenance_cost) FROM machine_maintenance WHERE maintenance_type IN ('Corrective', 'Emergency')) +
        (SELECT SUM((rw.technician_hours * emp.hourly_labor_rate) + rw.additional_chemical_cost) FROM rework_records rw JOIN employees emp ON rw.operator_id = emp.employee_id)
    ), 2) AS percentage_of_total_loss
FROM production_waste
UNION ALL
SELECT 
    '2. Unplanned Machine Downtime Overhead',
    ROUND(SUM(financial_downtime_cost), 2),
    ROUND(SUM(financial_downtime_cost) * 100.0 / (
        (SELECT SUM(net_financial_loss) FROM production_waste) +
        (SELECT SUM(financial_downtime_cost) FROM machine_downtime WHERE downtime_category = 'Unplanned Breakdown') +
        (SELECT SUM(total_maintenance_cost) FROM machine_maintenance WHERE maintenance_type IN ('Corrective', 'Emergency')) +
        (SELECT SUM((rw.technician_hours * emp.hourly_labor_rate) + rw.additional_chemical_cost) FROM rework_records rw JOIN employees emp ON rw.operator_id = emp.employee_id)
    ), 2)
FROM machine_downtime
WHERE downtime_category = 'Unplanned Breakdown'
UNION ALL
SELECT 
    '3. Reactive & Emergency Maintenance Spend',
    ROUND(SUM(total_maintenance_cost), 2),
    ROUND(SUM(total_maintenance_cost) * 100.0 / (
        (SELECT SUM(net_financial_loss) FROM production_waste) +
        (SELECT SUM(financial_downtime_cost) FROM machine_downtime WHERE downtime_category = 'Unplanned Breakdown') +
        (SELECT SUM(total_maintenance_cost) FROM machine_maintenance WHERE maintenance_type IN ('Corrective', 'Emergency')) +
        (SELECT SUM((rw.technician_hours * emp.hourly_labor_rate) + rw.additional_chemical_cost) FROM rework_records rw JOIN employees emp ON rw.operator_id = emp.employee_id)
    ), 2)
FROM machine_maintenance
WHERE maintenance_type IN ('Corrective', 'Emergency')
UNION ALL
SELECT 
    '4. Fabric Rework Labor & Chemical Spend',
    ROUND(SUM((rw.technician_hours * e.hourly_labor_rate) + rw.additional_chemical_cost), 2),
    ROUND(SUM((rw.technician_hours * e.hourly_labor_rate) + rw.additional_chemical_cost) * 100.0 / (
        (SELECT SUM(net_financial_loss) FROM production_waste) +
        (SELECT SUM(financial_downtime_cost) FROM machine_downtime WHERE downtime_category = 'Unplanned Breakdown') +
        (SELECT SUM(total_maintenance_cost) FROM machine_maintenance WHERE maintenance_type IN ('Corrective', 'Emergency')) +
        (SELECT SUM((rw.technician_hours * emp.hourly_labor_rate) + rw.additional_chemical_cost) FROM rework_records rw JOIN employees emp ON rw.operator_id = emp.employee_id)
    ), 2)
FROM rework_records rw
JOIN employees e ON rw.operator_id = e.employee_id;
