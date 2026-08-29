-- ============================================================================
-- TEXTILE PRODUCTION WASTE, DEFECT & MACHINE INTELLIGENCE SYSTEM
-- Script: 09_advanced_analytics.sql
-- Description: 30 Advanced SQL Analytical Queries (Queries 41 to 70) utilizing
--              Multi-Stage CTEs, Window Functions (ROW_NUMBER, RANK, DENSE_RANK,
--              LAG, LEAD), Cumulative Running Totals, 3-Month Moving Averages,
--              Month-over-Month (MoM) Deltas, Pareto 80/20 Distributions,
--              and Consecutive Trend Anomaly Detection.
-- ============================================================================

-- ============================================================================
-- QUERY 41: Month-over-Month (MoM) Fabric Production Growth & Speed Delta
-- ============================================================================

WITH MonthlyProduction AS (
    SELECT 
        SUBSTR(run_date, 1, 4) AS prod_year,
        SUBSTR(run_date, 6, 2) AS prod_month,
        ROUND(SUM(actual_meters), 2) AS total_meters,
        ROUND(SUM(planned_meters), 2) AS planned_meters,
        ROUND(AVG(actual_speed_rpm), 0) AS avg_speed_rpm
    FROM production_runs
    WHERE run_status = 'Completed'
    GROUP BY SUBSTR(run_date, 1, 4), SUBSTR(run_date, 6, 2)
)
SELECT 
    prod_year,
    prod_month,
    total_meters,
    LAG(total_meters, 1) OVER (ORDER BY prod_year, prod_month) AS prev_month_meters,
    ROUND(total_meters - LAG(total_meters, 1) OVER (ORDER BY prod_year, prod_month), 2) AS mom_net_growth_meters,
    ROUND(((total_meters - LAG(total_meters, 1) OVER (ORDER BY prod_year, prod_month)) / 
          NULLIF(LAG(total_meters, 1) OVER (ORDER BY prod_year, prod_month), 0)) * 100.0, 2) AS mom_growth_pct,
    avg_speed_rpm,
    avg_speed_rpm - LAG(avg_speed_rpm, 1) OVER (ORDER BY prod_year, prod_month) AS mom_speed_rpm_delta
FROM MonthlyProduction
ORDER BY prod_year, prod_month;

-- ============================================================================
-- QUERY 42: Top-Producing Machine per Plant using ROW_NUMBER()
-- ============================================================================

WITH PlantMachineTotals AS (
    SELECT 
        p.plant_id,
        p.plant_code,
        p.plant_name,
        m.machine_id,
        m.machine_code,
        m.machine_name,
        mt.type_name,
        ROUND(SUM(pr.actual_meters), 2) AS total_meters_produced,
        COUNT(pr.run_id) AS total_runs_executed,
        ROW_NUMBER() OVER (PARTITION BY p.plant_id ORDER BY SUM(pr.actual_meters) DESC) AS plant_machine_rank
    FROM plants p
    JOIN production_lines pl ON p.plant_id = pl.plant_id
    JOIN machines m ON pl.line_id = m.line_id
    JOIN machine_types mt ON m.machine_type_id = mt.machine_type_id
    JOIN production_runs pr ON m.machine_id = pr.machine_id
    GROUP BY p.plant_id, p.plant_code, p.plant_name, m.machine_id, m.machine_code, m.machine_name, mt.type_name
)
SELECT 
    plant_code,
    plant_name,
    machine_code,
    machine_name,
    type_name,
    total_meters_produced,
    total_runs_executed
FROM PlantMachineTotals
WHERE plant_machine_rank = 1
ORDER BY total_meters_produced DESC;

-- ============================================================================
-- QUERY 43: Cumulative Running Total of Material Waste Cost
-- ============================================================================

WITH MonthlyWaste AS (
    SELECT 
        SUBSTR(recorded_at, 1, 4) AS waste_year,
        SUBSTR(recorded_at, 6, 2) AS waste_month,
        ROUND(SUM(net_financial_loss), 2) AS monthly_waste_loss_usd
    FROM production_waste
    GROUP BY SUBSTR(recorded_at, 1, 4), SUBSTR(recorded_at, 6, 2)
)
SELECT 
    waste_year,
    waste_month,
    monthly_waste_loss_usd,
    ROUND(SUM(monthly_waste_loss_usd) OVER (
        ORDER BY waste_year, waste_month 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2) AS cumulative_waste_loss_usd,
    ROUND((SUM(monthly_waste_loss_usd) OVER (
        ORDER BY waste_year, waste_month 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) / (SELECT SUM(net_financial_loss) FROM production_waste)) * 100.0, 2) AS cumulative_loss_pct_of_total
FROM MonthlyWaste
ORDER BY waste_year, waste_month;

-- ============================================================================
-- QUERY 44: 3-Month Moving Average of Material Waste Cost
-- ============================================================================

WITH MonthlyWasteLoss AS (
    SELECT 
        SUBSTR(recorded_at, 1, 4) AS waste_year,
        SUBSTR(recorded_at, 6, 2) AS waste_month,
        ROUND(SUM(net_financial_loss), 2) AS monthly_loss_usd
    FROM production_waste
    GROUP BY SUBSTR(recorded_at, 1, 4), SUBSTR(recorded_at, 6, 2)
)
SELECT 
    waste_year,
    waste_month,
    monthly_loss_usd,
    ROUND(AVG(monthly_loss_usd) OVER (
        ORDER BY waste_year, waste_month 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_3_months_usd,
    ROUND(monthly_loss_usd - AVG(monthly_loss_usd) OVER (
        ORDER BY waste_year, waste_month 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS variance_from_moving_avg_usd
FROM MonthlyWasteLoss
ORDER BY waste_year, waste_month;

-- ============================================================================
-- QUERY 45: Monthly Product Defect Rate Ranking with DENSE_RANK()
-- ============================================================================

WITH ProductQuarterlyDefects AS (
    SELECT 
        SUBSTR(pr.run_date, 1, 4) || '-Q' || ((CAST(SUBSTR(pr.run_date, 6, 2) AS INTEGER) - 1) / 3 + 1) AS prod_quarter,
        prod.product_code,
        prod.product_name,
        prod.fabric_type,
        COUNT(DISTINCT fr.roll_id) AS rolls_inspected,
        COUNT(DISTINCT dr.defect_id) AS defects_detected,
        ROUND((COUNT(DISTINCT dr.defect_id) * 1.0) / NULLIF(COUNT(DISTINCT fr.roll_id), 0), 3) AS defects_per_roll
    FROM products prod
    JOIN fabric_rolls fr ON prod.product_id = fr.product_id
    JOIN production_runs pr ON fr.run_id = pr.run_id
    LEFT JOIN defect_records dr ON fr.roll_id = dr.roll_id
    GROUP BY 
        SUBSTR(pr.run_date, 1, 4) || '-Q' || ((CAST(SUBSTR(pr.run_date, 6, 2) AS INTEGER) - 1) / 3 + 1),
        prod.product_code, prod.product_name, prod.fabric_type
    HAVING COUNT(DISTINCT fr.roll_id) >= 50
),
RankedProducts AS (
    SELECT 
        prod_quarter,
        product_code,
        product_name,
        fabric_type,
        rolls_inspected,
        defects_detected,
        defects_per_roll,
        DENSE_RANK() OVER (PARTITION BY prod_quarter ORDER BY defects_per_roll DESC) AS quarterly_defect_rank
    FROM ProductQuarterlyDefects
)
SELECT 
    prod_quarter,
    quarterly_defect_rank,
    product_code,
    product_name,
    fabric_type,
    rolls_inspected,
    defects_detected,
    defects_per_roll
FROM RankedProducts
WHERE quarterly_defect_rank <= 3
ORDER BY prod_quarter DESC, quarterly_defect_rank ASC;

-- ============================================================================
-- QUERY 46: Machines with 3 Consecutive Quarters of Increasing Downtime
-- ============================================================================

WITH MachineQuarterlyDowntime AS (
    SELECT 
        m.machine_id,
        m.machine_code,
        m.machine_name,
        p.plant_name,
        SUBSTR(md.start_time, 1, 4) || '-Q' || ((CAST(SUBSTR(md.start_time, 6, 2) AS INTEGER) - 1) / 3 + 1) AS dt_quarter,
        ROUND(SUM(md.duration_hours), 2) AS total_downtime_hours
    FROM machines m
    JOIN production_lines pl ON m.line_id = pl.line_id
    JOIN plants p ON pl.plant_id = p.plant_id
    JOIN machine_downtime md ON m.machine_id = md.machine_id
    WHERE md.downtime_category = 'Unplanned Breakdown'
    GROUP BY 
        m.machine_id, m.machine_code, m.machine_name, p.plant_name,
        SUBSTR(md.start_time, 1, 4) || '-Q' || ((CAST(SUBSTR(md.start_time, 6, 2) AS INTEGER) - 1) / 3 + 1)
),
LaggedDowntime AS (
    SELECT 
        machine_id,
        machine_code,
        machine_name,
        plant_name,
        dt_quarter,
        total_downtime_hours,
        LAG(total_downtime_hours, 1) OVER (PARTITION BY machine_id ORDER BY dt_quarter) AS prev_q1_hours,
        LAG(total_downtime_hours, 2) OVER (PARTITION BY machine_id ORDER BY dt_quarter) AS prev_q2_hours
    FROM MachineQuarterlyDowntime
)
SELECT 
    machine_code,
    machine_name,
    plant_name,
    dt_quarter AS current_quarter,
    total_downtime_hours AS current_q_hours,
    prev_q1_hours AS q_minus_1_hours,
    prev_q2_hours AS q_minus_2_hours,
    ROUND(total_downtime_hours - prev_q2_hours, 2) AS net_2q_downtime_surge_hours
FROM LaggedDowntime
WHERE prev_q1_hours IS NOT NULL 
  AND prev_q2_hours IS NOT NULL
  AND total_downtime_hours > prev_q1_hours 
  AND prev_q1_hours > prev_q2_hours
ORDER BY net_2q_downtime_surge_hours DESC;

-- ============================================================================
-- QUERY 47: Pareto 80/20 Analysis on Material Scrap Costs
-- ============================================================================

WITH MaterialWasteSummary AS (
    SELECT 
        m.material_id,
        m.material_code,
        m.material_name,
        m.category,
        ROUND(SUM(pw.net_financial_loss), 2) AS material_waste_loss_usd
    FROM materials m
    JOIN production_waste pw ON m.material_id = pw.material_id
    GROUP BY m.material_id, m.material_code, m.material_name, m.category
),
CumulativeWaste AS (
    SELECT 
        material_code,
        material_name,
        category,
        material_waste_loss_usd,
        ROUND(SUM(material_waste_loss_usd) OVER (ORDER BY material_waste_loss_usd DESC), 2) AS running_cumulative_loss_usd,
        ROUND((SUM(material_waste_loss_usd) OVER (ORDER BY material_waste_loss_usd DESC) / (SELECT SUM(net_financial_loss) FROM production_waste)) * 100.0, 2) AS cumulative_pct_of_total
    FROM MaterialWasteSummary
)
SELECT 
    material_code,
    material_name,
    category,
    material_waste_loss_usd,
    running_cumulative_loss_usd,
    cumulative_pct_of_total,
    CASE WHEN cumulative_pct_of_total <= 80.0 THEN 'Vital Few (Top 80%)' ELSE 'Useful Many (Remaining 20%)' END AS pareto_classification
FROM CumulativeWaste
ORDER BY material_waste_loss_usd DESC
LIMIT 20;

-- ============================================================================
-- QUERY 48: Operator Quality Performance vs Shift Peer Group Average
-- ============================================================================

WITH OperatorMetrics AS (
    SELECT 
        e.employee_id,
        e.employee_code,
        e.first_name || ' ' || e.last_name AS operator_name,
        p.plant_id,
        p.plant_name,
        s.shift_id,
        s.shift_name,
        COUNT(DISTINCT pr.run_id) AS total_runs,
        COUNT(dr.defect_id) AS total_defects,
        ROUND(COUNT(dr.defect_id) * 1.0 / NULLIF(COUNT(DISTINCT pr.run_id), 0), 3) AS operator_defects_per_run
    FROM employees e
    JOIN plants p ON e.plant_id = p.plant_id
    JOIN production_runs pr ON e.employee_id = pr.operator_id
    JOIN shifts s ON pr.shift_id = s.shift_id
    LEFT JOIN fabric_rolls fr ON pr.run_id = fr.run_id
    LEFT JOIN defect_records dr ON fr.roll_id = dr.roll_id
    WHERE e.role = 'Operator'
    GROUP BY e.employee_id, e.employee_code, e.first_name, e.last_name, p.plant_id, p.plant_name, s.shift_id, s.shift_name
    HAVING COUNT(DISTINCT pr.run_id) >= 20
)
SELECT 
    operator_name,
    plant_name,
    shift_name,
    total_runs,
    operator_defects_per_run,
    ROUND(AVG(operator_defects_per_run) OVER (PARTITION BY plant_id, shift_id), 3) AS shift_peer_avg_defects_per_run,
    ROUND(operator_defects_per_run - AVG(operator_defects_per_run) OVER (PARTITION BY plant_id, shift_id), 3) AS delta_from_shift_peer_avg,
    CASE 
        WHEN operator_defects_per_run < AVG(operator_defects_per_run) OVER (PARTITION BY plant_id, shift_id) THEN 'Outperforming Peers'
        ELSE 'Underperforming Peers'
    END AS peer_performance_status
FROM OperatorMetrics
ORDER BY delta_from_shift_peer_avg ASC
LIMIT 20;

-- ============================================================================
-- QUERY 49: Multi-Dimensional Root-Cause Association Analysis Matrix
-- ============================================================================

WITH InteractionMatrix AS (
    SELECT 
        mt.type_name AS machine_type,
        prod.fabric_type,
        m.category AS material_category,
        COUNT(DISTINCT pr.run_id) AS total_runs_observed,
        ROUND(SUM(pr.actual_meters), 2) AS total_meters_produced,
        COUNT(dr.defect_id) AS total_defects_recorded,
        ROUND((COUNT(dr.defect_id) * 1000.0) / NULLIF(SUM(pr.actual_meters), 0), 2) AS interaction_defects_per_1000m
    FROM machine_types mt
    JOIN machines mach ON mt.machine_type_id = mach.machine_type_id
    JOIN production_runs pr ON mach.machine_id = pr.machine_id
    JOIN products prod ON pr.product_id = prod.product_id
    JOIN material_consumption mc ON pr.run_id = mc.run_id
    JOIN materials m ON mc.material_id = m.material_id
    JOIN fabric_rolls fr ON pr.run_id = fr.run_id
    LEFT JOIN defect_records dr ON fr.roll_id = dr.roll_id
    GROUP BY mt.type_name, prod.fabric_type, m.category
    HAVING COUNT(DISTINCT pr.run_id) >= 25
)
SELECT 
    machine_type,
    fabric_type,
    material_category,
    total_runs_observed,
    total_meters_produced,
    total_defects_recorded,
    interaction_defects_per_1000m,
    ROUND((SELECT COUNT(*) * 1000.0 / SUM(actual_meters) FROM production_runs pr_all JOIN fabric_rolls fr_all ON pr_all.run_id = fr_all.run_id JOIN defect_records dr_all ON fr_all.roll_id = dr_all.roll_id), 2) AS factory_baseline_defects_per_1000m,
    ROUND(interaction_defects_per_1000m - (SELECT COUNT(*) * 1000.0 / SUM(actual_meters) FROM production_runs pr_all JOIN fabric_rolls fr_all ON pr_all.run_id = fr_all.run_id JOIN defect_records dr_all ON fr_all.roll_id = dr_all.roll_id), 2) AS variance_from_baseline
FROM InteractionMatrix
ORDER BY variance_from_baseline DESC
LIMIT 15;

-- ============================================================================
-- QUERY 50: Comprehensive Machine Operational Risk Ranking (0-100 Score)
-- ============================================================================

WITH MachineStats AS (
    SELECT 
        m.machine_id,
        m.machine_code,
        m.machine_name,
        mt.type_name,
        p.plant_name,
        ROUND((JULIANDAY('2025-12-31') - JULIANDAY(m.installation_date)) / 365.25, 1) AS machine_age_years,
        COALESCE(SUM(md.duration_hours), 0.0) AS total_downtime_hours,
        COUNT(DISTINCT md.downtime_id) AS total_breakdown_count,
        COALESCE(COUNT(DISTINCT dr.defect_id), 0) AS total_defect_count,
        COALESCE(SUM(mm.total_maintenance_cost), 0.0) AS total_maintenance_spend_usd
    FROM machines m
    JOIN machine_types mt ON m.machine_type_id = mt.machine_type_id
    JOIN production_lines pl ON m.line_id = pl.line_id
    JOIN plants p ON pl.plant_id = p.plant_id
    LEFT JOIN machine_downtime md ON m.machine_id = md.machine_id AND md.downtime_category = 'Unplanned Breakdown'
    LEFT JOIN production_runs pr ON m.machine_id = pr.machine_id
    LEFT JOIN fabric_rolls fr ON pr.run_id = fr.run_id
    LEFT JOIN defect_records dr ON fr.roll_id = dr.roll_id
    LEFT JOIN machine_maintenance mm ON m.machine_id = mm.machine_id
    GROUP BY m.machine_id, m.machine_code, m.machine_name, mt.type_name, p.plant_name, m.installation_date
),
NormalizedScores AS (
    SELECT 
        *,
        (total_downtime_hours / (SELECT MAX(total_downtime_hours) FROM MachineStats)) * 100.0 AS s_dt,
        (total_breakdown_count * 1.0 / (SELECT MAX(total_breakdown_count) FROM MachineStats)) * 100.0 AS s_freq,
        (total_defect_count * 1.0 / (SELECT MAX(total_defect_count) FROM MachineStats)) * 100.0 AS s_def,
        (total_maintenance_spend_usd / (SELECT MAX(total_maintenance_spend_usd) FROM MachineStats)) * 100.0 AS s_maint,
        (machine_age_years / (SELECT MAX(machine_age_years) FROM MachineStats)) * 100.0 AS s_age
    FROM MachineStats
)
SELECT 
    machine_code,
    machine_name,
    type_name,
    plant_name,
    machine_age_years,
    ROUND(total_downtime_hours, 1) AS total_downtime_hours,
    total_breakdown_count,
    total_defect_count,
    ROUND(total_maintenance_spend_usd, 2) AS total_maintenance_usd,
    ROUND((0.30 * s_dt) + (0.25 * s_freq) + (0.20 * s_def) + (0.15 * s_maint) + (0.10 * s_age), 2) AS machine_risk_score,
    CASE 
        WHEN ((0.30 * s_dt) + (0.25 * s_freq) + (0.20 * s_def) + (0.15 * s_maint) + (0.10 * s_age)) >= 80.0 THEN 'CRITICAL'
        WHEN ((0.30 * s_dt) + (0.25 * s_freq) + (0.20 * s_def) + (0.15 * s_maint) + (0.10 * s_age)) >= 60.0 THEN 'HIGH'
        WHEN ((0.30 * s_dt) + (0.25 * s_freq) + (0.20 * s_def) + (0.15 * s_maint) + (0.10 * s_age)) >= 30.0 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS risk_tier
FROM NormalizedScores
ORDER BY machine_risk_score DESC
LIMIT 20;

-- ============================================================================
-- QUERY 51: Lead Time Variance between Expected and Actual PO Delivery
-- ============================================================================

SELECT 
    s.supplier_id,
    s.supplier_code,
    s.supplier_name,
    s.credit_rating,
    COUNT(po.po_id) AS total_received_pos,
    ROUND(AVG(JULIANDAY(po.actual_delivery_date) - JULIANDAY(po.order_date)), 1) AS avg_lead_time_days,
    ROUND(AVG(JULIANDAY(po.actual_delivery_date) - JULIANDAY(po.expected_delivery_date)), 1) AS avg_delivery_delay_days,
    SUM(CASE WHEN po.actual_delivery_date > po.expected_delivery_date THEN 1 ELSE 0 END) AS late_deliveries_count,
    ROUND(SUM(CASE WHEN po.actual_delivery_date > po.expected_delivery_date THEN 1.0 ELSE 0.0 END) / COUNT(po.po_id) * 100.0, 2) AS late_delivery_pct
FROM suppliers s
JOIN purchase_orders po ON s.supplier_id = po.supplier_id
WHERE po.status = 'Received' AND po.actual_delivery_date IS NOT NULL
GROUP BY s.supplier_id, s.supplier_code, s.supplier_name, s.credit_rating
HAVING COUNT(po.po_id) >= 8
ORDER BY avg_delivery_delay_days DESC;

-- ============================================================================
-- QUERY 52: Defect Severity Ratio by Machine Manufacturer
-- ============================================================================

SELECT 
    m.manufacturer,
    COUNT(DISTINCT m.machine_id) AS machines_installed,
    COUNT(DISTINCT pr.run_id) AS runs_executed,
    COUNT(dr.defect_id) AS total_defects_logged,
    SUM(CASE WHEN dr.severity = 'Critical' THEN 1 ELSE 0 END) AS critical_defects,
    SUM(CASE WHEN dr.severity = 'Major' THEN 1 ELSE 0 END) AS major_defects,
    SUM(CASE WHEN dr.severity = 'Minor' THEN 1 ELSE 0 END) AS minor_defects,
    ROUND(SUM(CASE WHEN dr.severity = 'Critical' THEN 1.0 ELSE 0.0 END) / NULLIF(COUNT(dr.defect_id), 0) * 100.0, 2) AS critical_defect_pct
FROM machines m
JOIN production_runs pr ON m.machine_id = pr.machine_id
JOIN fabric_rolls fr ON pr.run_id = fr.run_id
LEFT JOIN defect_records dr ON fr.roll_id = dr.roll_id
GROUP BY m.manufacturer
ORDER BY critical_defect_pct DESC;

-- ============================================================================
-- QUERY 53: Production Runs Exceeding Planned Speed Standards (Over-Speeding Analysis)
-- ============================================================================

SELECT 
    pr.run_id,
    pr.run_code,
    m.machine_code,
    prod.product_name,
    pr.planned_speed_rpm,
    pr.actual_speed_rpm,
    pr.actual_speed_rpm - pr.planned_speed_rpm AS speed_excess_rpm,
    pr.actual_meters,
    COUNT(dr.defect_id) AS defects_logged,
    ROUND(COUNT(dr.defect_id) * 1000.0 / NULLIF(pr.actual_meters, 0), 2) AS defects_per_1000m
FROM production_runs pr
JOIN machines m ON pr.machine_id = m.machine_id
JOIN products prod ON pr.product_id = prod.product_id
LEFT JOIN fabric_rolls fr ON pr.run_id = fr.run_id
LEFT JOIN defect_records dr ON fr.roll_id = dr.roll_id
WHERE pr.actual_speed_rpm > pr.planned_speed_rpm
GROUP BY pr.run_id, pr.run_code, m.machine_code, prod.product_name, pr.planned_speed_rpm, pr.actual_speed_rpm, pr.actual_meters
HAVING COUNT(dr.defect_id) >= 2
ORDER BY speed_excess_rpm DESC, defects_per_1000m DESC
LIMIT 20;

-- ============================================================================
-- QUERY 54: Supplier Quality Index (SQI) and Performance Tier Classification
-- ============================================================================

WITH SupplierMetrics AS (
    SELECT 
        s.supplier_id,
        s.supplier_code,
        s.supplier_name,
        s.credit_rating,
        s.is_preferred,
        COUNT(DISTINCT mb.batch_id) AS total_batches,
        ROUND(SUM(CASE WHEN mb.quality_status = 'Rejected' THEN 1.0 ELSE 0.0 END) / COUNT(DISTINCT mb.batch_id) * 100.0, 2) AS rejection_rate_pct,
        COUNT(DISTINCT dr.defect_id) AS downstream_defects,
        ROUND(COALESCE(SUM(pw.net_financial_loss), 0.0), 2) AS downstream_waste_loss_usd
    FROM suppliers s
    JOIN material_batches mb ON s.supplier_id = mb.supplier_id
    LEFT JOIN material_consumption mc ON mb.batch_id = mc.batch_id
    LEFT JOIN production_runs pr ON mc.run_id = pr.run_id
    LEFT JOIN fabric_rolls fr ON pr.run_id = fr.run_id
    LEFT JOIN defect_records dr ON fr.roll_id = dr.roll_id
    LEFT JOIN production_waste pw ON pr.run_id = pw.run_id
    GROUP BY s.supplier_id, s.supplier_code, s.supplier_name, s.credit_rating, s.is_preferred
    HAVING COUNT(DISTINCT mb.batch_id) >= 5
),
ScoredSuppliers AS (
    SELECT 
        *,
        ROUND(
            CASE 
                WHEN 100.0 - (0.40 * rejection_rate_pct + 0.35 * (downstream_defects * 1.0 / total_batches) + 0.25 * (downstream_waste_loss_usd / 1000.0)) > 100.0 THEN 100.0
                WHEN 100.0 - (0.40 * rejection_rate_pct + 0.35 * (downstream_defects * 1.0 / total_batches) + 0.25 * (downstream_waste_loss_usd / 1000.0)) < 0.0 THEN 0.0
                ELSE 100.0 - (0.40 * rejection_rate_pct + 0.35 * (downstream_defects * 1.0 / total_batches) + 0.25 * (downstream_waste_loss_usd / 1000.0))
            END, 2
        ) AS sqi_score
    FROM SupplierMetrics
)
SELECT 
    supplier_code,
    supplier_name,
    credit_rating,
    is_preferred,
    total_batches,
    rejection_rate_pct,
    downstream_defects,
    downstream_waste_loss_usd,
    sqi_score,
    CASE 
        WHEN sqi_score >= 90.0 THEN 'Tier 1: Excellent'
        WHEN sqi_score >= 80.0 THEN 'Tier 2: Good'
        WHEN sqi_score >= 70.0 THEN 'Tier 3: Average'
        WHEN sqi_score >= 60.0 THEN 'Tier 4: Poor'
        ELSE 'Tier 5: Critical'
    END AS supplier_tier
FROM ScoredSuppliers
ORDER BY sqi_score ASC
LIMIT 20;

-- ============================================================================
-- QUERY 55: Financial Downtime Loss per Machine Operating Hour
-- ============================================================================

SELECT 
    m.machine_id,
    m.machine_code,
    m.machine_name,
    p.plant_name,
    mt.type_name,
    m.hourly_overhead_cost,
    ROUND(SUM(8.0), 2) AS estimated_operating_hours,
    ROUND(COALESCE(SUM(md.financial_downtime_cost), 0.0), 2) AS total_downtime_overhead_loss_usd,
    ROUND(COALESCE(SUM(md.financial_downtime_cost), 0.0) / NULLIF(SUM(8.0), 0), 2) AS downtime_loss_per_operating_hour
FROM machines m
JOIN machine_types mt ON m.machine_type_id = mt.machine_type_id
JOIN production_lines pl ON m.line_id = pl.line_id
JOIN plants p ON pl.plant_id = p.plant_id
JOIN production_runs pr ON m.machine_id = pr.machine_id
LEFT JOIN machine_downtime md ON pr.run_id = md.run_id
GROUP BY m.machine_id, m.machine_code, m.machine_name, p.plant_name, mt.type_name, m.hourly_overhead_cost
HAVING SUM(8.0) >= 100.0
ORDER BY downtime_loss_per_operating_hour DESC
LIMIT 15;

-- ============================================================================
-- QUERY 56: Rework Frequency and Scrap Conversion Rate by Shift
-- ============================================================================

SELECT 
    s.shift_code,
    s.shift_name,
    COUNT(DISTINCT fr.roll_id) AS total_rolls_produced,
    COUNT(DISTINCT rw.roll_id) AS total_reworked_rolls,
    ROUND((COUNT(DISTINCT rw.roll_id) * 100.0) / COUNT(DISTINCT fr.roll_id), 2) AS rework_rate_pct,
    SUM(CASE WHEN rw.post_rework_grade = 'Scrap' THEN 1 ELSE 0 END) AS failed_rework_scrapped_rolls,
    ROUND(SUM(CASE WHEN rw.post_rework_grade = 'Scrap' THEN 1.0 ELSE 0.0 END) / NULLIF(COUNT(DISTINCT rw.roll_id), 0) * 100.0, 2) AS rework_failure_scrap_pct
FROM shifts s
JOIN production_runs pr ON s.shift_id = pr.shift_id
JOIN fabric_rolls fr ON pr.run_id = fr.run_id
LEFT JOIN rework_records rw ON fr.roll_id = rw.roll_id
GROUP BY s.shift_code, s.shift_name, s.shift_id
ORDER BY s.shift_id;

-- ============================================================================
-- QUERY 57: Top 5 Highest Financial Loss Production Runs per Plant
-- ============================================================================

WITH RunLosses AS (
    SELECT 
        p.plant_id,
        p.plant_name,
        pr.run_id,
        pr.run_code,
        pr.run_date,
        m.machine_code,
        prod.product_name,
        ROUND(COALESCE(SUM(pw.net_financial_loss), 0.0) + 
              COALESCE(SUM(CASE WHEN fr.roll_grade = 'Scrap' THEN fr.roll_length_meters * prod.standard_cost_per_meter ELSE 0 END), 0.0), 2) AS total_run_loss_usd,
        ROW_NUMBER() OVER (
            PARTITION BY p.plant_id 
            ORDER BY (COALESCE(SUM(pw.net_financial_loss), 0.0) + 
                      COALESCE(SUM(CASE WHEN fr.roll_grade = 'Scrap' THEN fr.roll_length_meters * prod.standard_cost_per_meter ELSE 0 END), 0.0)) DESC
        ) AS rank_in_plant
    FROM plants p
    JOIN production_lines pl ON p.plant_id = pl.plant_id
    JOIN machines m ON pl.line_id = m.line_id
    JOIN production_runs pr ON m.machine_id = pr.machine_id
    JOIN products prod ON pr.product_id = prod.product_id
    LEFT JOIN production_waste pw ON pr.run_id = pw.run_id
    LEFT JOIN fabric_rolls fr ON pr.run_id = fr.run_id
    GROUP BY p.plant_id, p.plant_name, pr.run_id, pr.run_code, pr.run_date, m.machine_code, prod.product_name
)
SELECT 
    plant_name,
    rank_in_plant,
    run_code,
    run_date,
    machine_code,
    product_name,
    total_run_loss_usd
FROM RunLosses
WHERE rank_in_plant <= 5
ORDER BY plant_id, rank_in_plant;

-- ============================================================================
-- QUERY 58: Machine Maintenance Cost vs Machine Age Correlation
-- ============================================================================

SELECT 
    CASE 
        WHEN (JULIANDAY('2025-12-31') - JULIANDAY(m.installation_date)) / 365.25 < 4.0 THEN '1. New (0-3 Years)'
        WHEN (JULIANDAY('2025-12-31') - JULIANDAY(m.installation_date)) / 365.25 < 7.0 THEN '2. Mid-Life (4-6 Years)'
        WHEN (JULIANDAY('2025-12-31') - JULIANDAY(m.installation_date)) / 365.25 < 11.0 THEN '3. Mature (7-10 Years)'
        ELSE '4. Aging (> 10 Years)'
    END AS machine_age_cohort,
    COUNT(DISTINCT m.machine_id) AS machines_in_cohort,
    COUNT(mm.maintenance_id) AS total_maintenance_events,
    ROUND(SUM(mm.total_maintenance_cost), 2) AS total_maintenance_spend_usd,
    ROUND(SUM(mm.total_maintenance_cost) / COUNT(DISTINCT m.machine_id), 2) AS avg_annual_maintenance_per_machine_usd,
    ROUND(AVG(mm.replacement_parts_cost), 2) AS avg_parts_cost_per_job_usd
FROM machines m
JOIN machine_maintenance mm ON m.machine_id = mm.machine_id
WHERE mm.maintenance_status = 'Completed'
GROUP BY 
    CASE 
        WHEN (JULIANDAY('2025-12-31') - JULIANDAY(m.installation_date)) / 365.25 < 4.0 THEN '1. New (0-3 Years)'
        WHEN (JULIANDAY('2025-12-31') - JULIANDAY(m.installation_date)) / 365.25 < 7.0 THEN '2. Mid-Life (4-6 Years)'
        WHEN (JULIANDAY('2025-12-31') - JULIANDAY(m.installation_date)) / 365.25 < 11.0 THEN '3. Mature (7-10 Years)'
        ELSE '4. Aging (> 10 Years)'
    END
ORDER BY machine_age_cohort;

-- ============================================================================
-- QUERY 59: Customer Order Fulfillment Velocity & Lead Time Benchmark
-- ============================================================================

SELECT 
    c.segment,
    COUNT(co.order_id) AS total_orders_fulfilled,
    ROUND(SUM(co.ordered_meters), 2) AS total_meters_dispatched,
    ROUND(AVG(JULIANDAY(co.actual_dispatch_date) - JULIANDAY(co.order_date)), 1) AS avg_fulfillment_cycle_days,
    ROUND(AVG(JULIANDAY(co.promised_delivery_date) - JULIANDAY(co.order_date)), 1) AS avg_promised_lead_time_days,
    ROUND(AVG(JULIANDAY(co.actual_dispatch_date) - JULIANDAY(co.promised_delivery_date)), 1) AS avg_dispatch_variance_days
FROM customers c
JOIN customer_orders co ON c.customer_id = co.customer_id
WHERE co.order_status = 'Fulfilled' AND co.actual_dispatch_date IS NOT NULL
GROUP BY c.segment
ORDER BY avg_fulfillment_cycle_days ASC;

-- ============================================================================
-- QUERY 60: Total Production Loss KPI Master Rollup
-- ============================================================================

WITH PlantWaste AS (
    SELECT pl.plant_id, ROUND(SUM(pw.net_financial_loss), 2) AS waste_loss
    FROM production_lines pl
    JOIN production_runs pr ON pl.line_id = pr.line_id
    JOIN production_waste pw ON pr.run_id = pw.run_id
    GROUP BY pl.plant_id
),
PlantDowntime AS (
    SELECT pl.plant_id, ROUND(SUM(md.financial_downtime_cost), 2) AS downtime_loss
    FROM production_lines pl
    JOIN machines m ON pl.line_id = m.line_id
    JOIN machine_downtime md ON m.machine_id = md.machine_id
    WHERE md.downtime_category = 'Unplanned Breakdown'
    GROUP BY pl.plant_id
),
PlantMaintenance AS (
    SELECT pl.plant_id, ROUND(SUM(mm.total_maintenance_cost), 2) AS maint_cost
    FROM production_lines pl
    JOIN machines m ON pl.line_id = m.line_id
    JOIN machine_maintenance mm ON m.machine_id = mm.machine_id
    WHERE mm.maintenance_type IN ('Corrective', 'Emergency')
    GROUP BY pl.plant_id
),
PlantRework AS (
    SELECT pl.plant_id, ROUND(SUM((rw.technician_hours * e.hourly_labor_rate) + rw.additional_chemical_cost), 2) AS rework_cost
    FROM production_lines pl
    JOIN production_runs pr ON pl.line_id = pr.line_id
    JOIN fabric_rolls fr ON pr.run_id = fr.run_id
    JOIN rework_records rw ON fr.roll_id = rw.roll_id
    JOIN employees e ON rw.operator_id = e.employee_id
    GROUP BY pl.plant_id
)
SELECT 
    p.plant_code,
    p.plant_name,
    COALESCE(pw.waste_loss, 0.0) AS material_waste_loss_usd,
    COALESCE(pd.downtime_loss, 0.0) AS downtime_overhead_loss_usd,
    COALESCE(pm.maint_cost, 0.0) AS reactive_maintenance_usd,
    COALESCE(prw.rework_cost, 0.0) AS secondary_rework_cost_usd,
    ROUND(COALESCE(pw.waste_loss, 0.0) + COALESCE(pd.downtime_loss, 0.0) + COALESCE(pm.maint_cost, 0.0) + COALESCE(prw.rework_cost, 0.0), 2) AS total_production_loss_usd
FROM plants p
LEFT JOIN PlantWaste pw ON p.plant_id = pw.plant_id
LEFT JOIN PlantDowntime pd ON p.plant_id = pd.plant_id
LEFT JOIN PlantMaintenance pm ON p.plant_id = pm.plant_id
LEFT JOIN PlantRework prw ON p.plant_id = prw.plant_id
ORDER BY total_production_loss_usd DESC;

-- ============================================================================
-- QUERY 61: First-Pass Yield (FPY) Trend by Quarter
-- ============================================================================

SELECT 
    SUBSTR(pr.run_date, 1, 4) || '-Q' || ((CAST(SUBSTR(pr.run_date, 6, 2) AS INTEGER) - 1) / 3 + 1) AS production_quarter,
    COUNT(DISTINCT fr.roll_id) AS total_rolls_produced,
    SUM(CASE WHEN fr.roll_grade = 'A' AND rw.rework_id IS NULL THEN 1 ELSE 0 END) AS first_pass_perfect_rolls,
    ROUND((SUM(CASE WHEN fr.roll_grade = 'A' AND rw.rework_id IS NULL THEN 1.0 ELSE 0.0 END) / COUNT(DISTINCT fr.roll_id) * 100.0), 2) AS fpy_percentage
FROM production_runs pr
JOIN fabric_rolls fr ON pr.run_id = fr.run_id
LEFT JOIN rework_records rw ON fr.roll_id = rw.roll_id
GROUP BY SUBSTR(pr.run_date, 1, 4) || '-Q' || ((CAST(SUBSTR(pr.run_date, 6, 2) AS INTEGER) - 1) / 3 + 1)
ORDER BY production_quarter;

-- ============================================================================
-- QUERY 62: Top 5 Machines repeatedly associated with the Same Defect Type
-- ============================================================================

SELECT 
    m.machine_code,
    m.machine_name,
    p.plant_name,
    dt.defect_code,
    dt.defect_name,
    dt.severity_level,
    COUNT(dr.defect_id) AS recurring_defect_count,
    SUM(dr.defect_points) AS cumulative_penalty_points
FROM machines m
JOIN production_lines pl ON m.line_id = pl.line_id
JOIN plants p ON pl.plant_id = p.plant_id
JOIN production_runs pr ON m.machine_id = pr.machine_id
JOIN fabric_rolls fr ON pr.run_id = fr.run_id
JOIN defect_records dr ON fr.roll_id = dr.roll_id
JOIN defect_types dt ON dr.defect_type_id = dt.defect_type_id
GROUP BY m.machine_code, m.machine_name, p.plant_name, dt.defect_code, dt.defect_name, dt.severity_level
HAVING COUNT(dr.defect_id) >= 12
ORDER BY recurring_defect_count DESC
LIMIT 15;

-- ============================================================================
-- QUERY 63: Material Consumption Efficiency: Planned vs Actual Consumption Rate
-- ============================================================================

SELECT 
    prod.product_code,
    prod.product_name,
    prod.fabric_type,
    prod.density_gsm,
    ROUND(SUM(mc.consumed_quantity), 2) AS total_kg_consumed,
    ROUND(SUM(pr.actual_meters), 2) AS total_meters_produced,
    ROUND(SUM(mc.consumed_quantity) / NULLIF(SUM(pr.actual_meters), 0), 4) AS actual_consumption_kg_per_meter,
    ROUND((prod.density_gsm * 1.5) / 1000.0, 4) AS theoretical_bom_kg_per_meter,
    ROUND(((SUM(mc.consumed_quantity) / NULLIF(SUM(pr.actual_meters), 0)) - ((prod.density_gsm * 1.5) / 1000.0)), 4) AS bom_variance_kg_per_meter
FROM products prod
JOIN production_runs pr ON prod.product_id = pr.product_id
JOIN material_consumption mc ON pr.run_id = mc.run_id
GROUP BY prod.product_code, prod.product_name, prod.fabric_type, prod.density_gsm
HAVING SUM(pr.actual_meters) >= 5000.0
ORDER BY bom_variance_kg_per_meter DESC
LIMIT 15;

-- ============================================================================
-- QUERY 64: Machine Downtime Impact on Production Schedule Delays
-- ============================================================================

SELECT 
    po.prod_order_number,
    p.plant_name,
    prod.product_name,
    po.target_end_date,
    po.actual_end_date,
    (JULIANDAY(po.actual_end_date) - JULIANDAY(po.target_end_date)) AS days_delayed,
    COUNT(DISTINCT pr.run_id) AS runs_executed,
    COUNT(md.downtime_id) AS downtime_events,
    ROUND(COALESCE(SUM(md.duration_hours), 0.0), 2) AS total_downtime_hours_lost
FROM production_orders po
JOIN plants p ON po.plant_id = p.plant_id
JOIN products prod ON po.product_id = prod.product_id
JOIN production_runs pr ON po.prod_order_id = pr.prod_order_id
LEFT JOIN machine_downtime md ON pr.run_id = md.run_id AND md.downtime_category = 'Unplanned Breakdown'
WHERE po.actual_end_date > po.target_end_date
GROUP BY po.prod_order_number, p.plant_name, prod.product_name, po.target_end_date, po.actual_end_date
HAVING (JULIANDAY(po.actual_end_date) - JULIANDAY(po.target_end_date)) >= 3
   AND COALESCE(SUM(md.duration_hours), 0.0) >= 4.0
ORDER BY days_delayed DESC, total_downtime_hours_lost DESC
LIMIT 15;

-- ============================================================================
-- QUERY 65: Maintenance Technician Efficiency & Resolution Speed (MTTR)
-- ============================================================================

SELECT 
    e.employee_id,
    e.employee_code,
    e.first_name || ' ' || e.last_name AS technician_name,
    p.plant_name,
    e.skill_level,
    COUNT(mm.maintenance_id) AS total_jobs_completed,
    ROUND(SUM(mm.technician_hours), 2) AS total_hours_worked,
    ROUND(AVG(mm.technician_hours), 2) AS avg_hours_per_job_mttr,
    ROUND(SUM(mm.labor_cost), 2) AS total_labor_cost_usd
FROM employees e
JOIN plants p ON e.plant_id = p.plant_id
JOIN machine_maintenance mm ON e.employee_id = mm.technician_id
WHERE e.role = 'Technician' AND mm.maintenance_status = 'Completed'
GROUP BY e.employee_id, e.employee_code, e.first_name, e.last_name, p.plant_name, e.skill_level
HAVING COUNT(mm.maintenance_id) >= 15
ORDER BY avg_hours_per_job_mttr ASC;

-- ============================================================================
-- QUERY 66: Monthly Defect Rate Trend by Fabric Type (Pivot with CASE)
-- ============================================================================

SELECT 
    SUBSTR(pr.run_date, 1, 4) || '-Q' || ((CAST(SUBSTR(pr.run_date, 6, 2) AS INTEGER) - 1) / 3 + 1) AS production_quarter,
    ROUND(SUM(CASE WHEN prod.fabric_type = 'Cotton' THEN 1 ELSE 0 END) * 1000.0 / NULLIF(SUM(CASE WHEN prod.fabric_type = 'Cotton' THEN pr.actual_meters ELSE 0 END), 0), 2) AS cotton_defects_per_1000m,
    ROUND(SUM(CASE WHEN prod.fabric_type = 'Denim' THEN 1 ELSE 0 END) * 1000.0 / NULLIF(SUM(CASE WHEN prod.fabric_type = 'Denim' THEN pr.actual_meters ELSE 0 END), 0), 2) AS denim_defects_per_1000m,
    ROUND(SUM(CASE WHEN prod.fabric_type = 'Polyester' THEN 1 ELSE 0 END) * 1000.0 / NULLIF(SUM(CASE WHEN prod.fabric_type = 'Polyester' THEN pr.actual_meters ELSE 0 END), 0), 2) AS poly_defects_per_1000m,
    ROUND(SUM(CASE WHEN prod.fabric_type IN ('Cotton Blend', 'Synthetic Fabric') THEN 1 ELSE 0 END) * 1000.0 / NULLIF(SUM(CASE WHEN prod.fabric_type IN ('Cotton Blend', 'Synthetic Fabric') THEN pr.actual_meters ELSE 0 END), 0), 2) AS blends_defects_per_1000m
FROM products prod
JOIN production_runs pr ON prod.product_id = pr.product_id
JOIN fabric_rolls fr ON pr.run_id = fr.run_id
LEFT JOIN defect_records dr ON fr.roll_id = dr.roll_id
GROUP BY SUBSTR(pr.run_date, 1, 4) || '-Q' || ((CAST(SUBSTR(pr.run_date, 6, 2) AS INTEGER) - 1) / 3 + 1)
ORDER BY production_quarter;

-- ============================================================================
-- QUERY 67: Supplier Batch Rejection Root Cause Taxonomy
-- ============================================================================

SELECT 
    mb.batch_rejection_reason,
    s.supplier_name,
    m.material_name,
    COUNT(mb.batch_id) AS rejected_batches_count,
    ROUND(SUM(mb.initial_quantity), 2) AS total_rejected_quantity,
    mb.unit_of_measure
FROM material_batches mb
JOIN suppliers s ON mb.supplier_id = s.supplier_id
JOIN materials m ON mb.material_id = m.material_id
WHERE mb.quality_status = 'Rejected'
GROUP BY mb.batch_rejection_reason, s.supplier_name, m.material_name, mb.unit_of_measure
ORDER BY rejected_batches_count DESC;

-- ============================================================================
-- QUERY 68: Machine Stoppage Severity & Longest Unplanned Breakdown Events
-- ============================================================================

SELECT 
    md.downtime_id,
    p.plant_name,
    m.machine_code,
    m.machine_name,
    md.start_time,
    md.end_time,
    md.duration_hours,
    md.root_cause_category,
    md.reason_description,
    md.financial_downtime_cost AS overhead_loss_usd
FROM machine_downtime md
JOIN machines m ON md.machine_id = m.machine_id
JOIN production_lines pl ON m.line_id = pl.line_id
JOIN plants p ON pl.plant_id = p.plant_id
WHERE md.downtime_category = 'Unplanned Breakdown'
ORDER BY md.duration_hours DESC
LIMIT 15;

-- ============================================================================
-- QUERY 69: Plant Production Capacity Utilization vs Nominal Nameplate Limit
-- ============================================================================

SELECT 
    p.plant_id,
    p.plant_code,
    p.plant_name,
    p.total_capacity_meters_per_day AS nameplate_daily_capacity_meters,
    ROUND(SUM(pr.actual_meters) / 1095.0, 2) AS avg_daily_actual_output_meters,
    ROUND((SUM(pr.actual_meters) / 1095.0) / p.total_capacity_meters_per_day * 100.0, 2) AS nameplate_capacity_utilization_pct,
    ROUND(p.total_capacity_meters_per_day - (SUM(pr.actual_meters) / 1095.0), 2) AS unutilized_daily_headroom_meters
FROM plants p
JOIN production_lines pl ON p.plant_id = pl.plant_id
JOIN production_runs pr ON pl.line_id = pr.line_id
GROUP BY p.plant_id, p.plant_code, p.plant_name, p.total_capacity_meters_per_day
ORDER BY nameplate_capacity_utilization_pct DESC;

-- ============================================================================
-- QUERY 70: Executive Operational Health Matrix & Alert Trigger Scorecard
-- ============================================================================

WITH PlantScrap AS (
    SELECT pl.plant_id, ROUND(COALESCE(SUM(pw.net_financial_loss), 0.0), 2) AS total_scrap_loss_usd
    FROM production_lines pl
    JOIN production_runs pr ON pl.line_id = pr.line_id
    JOIN production_waste pw ON pr.run_id = pw.run_id
    GROUP BY pl.plant_id
),
PlantFPY AS (
    SELECT 
        pl.plant_id,
        ROUND(SUM(CASE WHEN fr.roll_grade = 'A' AND rw.rework_id IS NULL THEN 1.0 ELSE 0.0 END) / COUNT(DISTINCT fr.roll_id) * 100.0, 2) AS fpy_percentage
    FROM production_lines pl
    JOIN production_runs pr ON pl.line_id = pr.line_id
    JOIN fabric_rolls fr ON pr.run_id = fr.run_id
    LEFT JOIN rework_records rw ON fr.roll_id = rw.roll_id
    GROUP BY pl.plant_id
),
PlantDowntime AS (
    SELECT 
        pl.plant_id,
        ROUND(COALESCE(SUM(md.duration_hours), 0.0), 2) AS total_unplanned_downtime_hours
    FROM production_lines pl
    JOIN machines m ON pl.line_id = m.line_id
    JOIN machine_downtime md ON m.machine_id = md.machine_id AND md.downtime_category = 'Unplanned Breakdown'
    GROUP BY pl.plant_id
)
SELECT 
    p.plant_code,
    p.plant_name,
    COALESCE(ps.total_scrap_loss_usd, 0.0) AS total_scrap_loss_usd,
    COALESCE(pf.fpy_percentage, 0.0) AS fpy_percentage,
    COALESCE(pd.total_unplanned_downtime_hours, 0.0) AS total_unplanned_downtime_hours,
    CASE WHEN COALESCE(ps.total_scrap_loss_usd, 0.0) > 300000.0 THEN 'ALERT: High Waste Scrap' ELSE 'NORMAL' END AS waste_alert_status,
    CASE WHEN COALESCE(pf.fpy_percentage, 0.0) < 68.0 THEN 'ALERT: Quality Below Standard' ELSE 'NORMAL' END AS quality_alert_status,
    CASE WHEN COALESCE(pd.total_unplanned_downtime_hours, 0.0) > 800.0 THEN 'ALERT: Chronic Downtime' ELSE 'NORMAL' END AS downtime_alert_status
FROM plants p
LEFT JOIN PlantScrap ps ON p.plant_id = ps.plant_id
LEFT JOIN PlantFPY pf ON p.plant_id = pf.plant_id
LEFT JOIN PlantDowntime pd ON p.plant_id = pd.plant_id
ORDER BY total_scrap_loss_usd DESC;
