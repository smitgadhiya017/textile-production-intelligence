-- ============================================================================
-- TEXTILE PRODUCTION WASTE, DEFECT & MACHINE INTELLIGENCE SYSTEM
-- Script: 07_basic_analytics.sql
-- Description: 20 Foundational SQL Business Queries using SELECT, WHERE,
--              GROUP BY, HAVING, ORDER BY, CASE statements, multi-table JOINs,
--              and standard aggregations.
-- ============================================================================

-- ============================================================================
-- QUERY 01: Total Production Output by Plant
-- ============================================================================
/*
BUSINESS QUESTION:
What is the total gross fabric production (in meters) and total production runs
completed by each manufacturing plant?

BUSINESS PURPOSE:
Benchmark operational volume throughput across regional manufacturing facilities.

SQL APPROACH:
Join plants, production_lines, and production_runs, aggregating actual meters
and counting completed production runs grouped by plant.
*/
SELECT 
    p.plant_id,
    p.plant_code,
    p.plant_name,
    p.total_capacity_meters_per_day,
    COUNT(pr.run_id) AS total_runs_executed,
    ROUND(SUM(pr.actual_meters), 2) AS total_actual_meters_produced,
    ROUND(AVG(pr.actual_meters), 2) AS avg_meters_per_run
FROM plants p
JOIN production_lines pl ON p.plant_id = pl.plant_id
JOIN production_runs pr ON pl.line_id = pr.line_id
WHERE pr.run_status = 'Completed'
GROUP BY p.plant_id, p.plant_code, p.plant_name, p.total_capacity_meters_per_day
ORDER BY total_actual_meters_produced DESC;


-- ============================================================================
-- QUERY 02: Total Production by Fabric Type
-- ============================================================================
/*
BUSINESS QUESTION:
How does production volume and standard manufacturing value distribute across
different fabric categories (e.g., Denim, Cotton, Viscose, Linen)?

BUSINESS PURPOSE:
Understand product mix distribution to support commercial capacity planning.

SQL APPROACH:
Join products with production_runs, aggregating actual meters produced and
multiplying by standard manufacturing cost per meter.
*/
SELECT 
    prod.fabric_type,
    COUNT(DISTINCT prod.product_id) AS active_product_skus,
    COUNT(pr.run_id) AS total_runs,
    ROUND(SUM(pr.actual_meters), 2) AS total_meters_produced,
    ROUND(SUM(pr.actual_meters * prod.standard_cost_per_meter), 2) AS total_production_cost_usd,
    ROUND(AVG(prod.standard_cost_per_meter), 2) AS avg_unit_cost_per_meter
FROM products prod
JOIN production_runs pr ON prod.product_id = pr.product_id
GROUP BY prod.fabric_type
ORDER BY total_meters_produced DESC;


-- ============================================================================
-- QUERY 03: Shift Production Volume & Target Variance
-- ============================================================================
/*
BUSINESS QUESTION:
What is the total actual vs. planned fabric production across Morning, Evening,
and Night shifts?

BUSINESS PURPOSE:
Evaluate shift productivity and identify if night shifts experience production deficits.

SQL APPROACH:
Join shifts with production_runs, computing planned meters, actual meters,
and variance percentage.
*/
SELECT 
    s.shift_code,
    s.shift_name,
    s.is_night_shift,
    COUNT(pr.run_id) AS total_runs,
    ROUND(SUM(pr.planned_meters), 2) AS total_planned_meters,
    ROUND(SUM(pr.actual_meters), 2) AS total_actual_meters,
    ROUND(SUM(pr.actual_meters) - SUM(pr.planned_meters), 2) AS variance_meters,
    ROUND((SUM(pr.actual_meters) / NULLIF(SUM(pr.planned_meters), 0) * 100.0), 2) AS production_efficiency_pct
FROM shifts s
JOIN production_runs pr ON s.shift_id = pr.shift_id
GROUP BY s.shift_code, s.shift_name, s.is_night_shift, s.shift_id
ORDER BY s.shift_id;


-- ============================================================================
-- QUERY 04: Top 10 High-Volume Production Machines
-- ============================================================================
/*
BUSINESS QUESTION:
Which top 10 machines have delivered the highest cumulative output in meters?

BUSINESS PURPOSE:
Recognize key production workhorses and plan preventive wear-and-tear inspections.

SQL APPROACH:
Join machines, machine_types, and production_runs, group by machine and order descending.
*/
SELECT 
    m.machine_id,
    m.machine_code,
    m.machine_name,
    mt.type_name,
    m.manufacturer,
    COUNT(pr.run_id) AS completed_runs,
    ROUND(SUM(pr.actual_meters), 2) AS total_meters_produced,
    ROUND(AVG(pr.actual_speed_rpm), 0) AS avg_speed_rpm
FROM machines m
JOIN machine_types mt ON m.machine_type_id = mt.machine_type_id
JOIN production_runs pr ON m.machine_id = pr.machine_id
GROUP BY m.machine_id, m.machine_code, m.machine_name, mt.type_name, m.manufacturer
ORDER BY total_meters_produced DESC
LIMIT 10;


-- ============================================================================
-- QUERY 05: Production Order Status Distribution & Completion Rates
-- ============================================================================
/*
BUSINESS QUESTION:
How many production work orders are in Scheduled, In Progress, Completed, or Aborted states,
and what is their volume breakdown?

BUSINESS PURPOSE:
Monitor open work-in-progress (WIP) and factory order backlog.

SQL APPROACH:
Group production_orders by order_status and compute planned vs completed quantities.
*/
SELECT 
    order_status,
    COUNT(prod_order_id) AS total_orders,
    ROUND(SUM(planned_quantity_meters), 2) AS total_planned_meters,
    ROUND(SUM(completed_quantity_meters), 2) AS total_completed_meters,
    ROUND(AVG(planned_quantity_meters), 2) AS avg_order_size_meters
FROM production_orders
GROUP BY order_status
ORDER BY total_orders DESC;


-- ============================================================================
-- QUERY 06: Quality Inspection Outcomes & Roll Pass Rates
-- ============================================================================
/*
BUSINESS QUESTION:
What is the distribution of inspection results (Pass, Conditional Pass, Fail)
and the average quality score for each result tier?

BUSINESS PURPOSE:
Establish first-line baseline quality compliance across all inspected fabric rolls.

SQL APPROACH:
Group quality_inspections by inspection_result, calculating counts, percentages,
and average quality score.
*/
SELECT 
    inspection_result,
    COUNT(inspection_id) AS total_inspections,
    ROUND(COUNT(inspection_id) * 100.0 / (SELECT COUNT(*) FROM quality_inspections), 2) AS percentage_of_total,
    ROUND(AVG(quality_score), 2) AS avg_quality_score,
    ROUND(AVG(total_defect_points), 2) AS avg_defect_points,
    ROUND(AVG(points_per_100_sqm), 2) AS avg_points_per_100_sqm
FROM quality_inspections
GROUP BY inspection_result
ORDER BY total_inspections DESC;


-- ============================================================================
-- QUERY 07: Fabric Roll Quality Grade Breakdown
-- ============================================================================
/*
BUSINESS QUESTION:
What percentage of produced fabric rolls achieve Grade A, Grade B, Grade C, or Scrap?

BUSINESS PURPOSE:
Directly evaluate First-Pass Yield (Grade A) and identify scrap downgrades.

SQL APPROACH:
Group fabric_rolls by roll_grade, aggregate roll counts, total length in meters,
and total weight in kilograms.
*/
SELECT 
    roll_grade,
    COUNT(roll_id) AS total_rolls,
    ROUND(COUNT(roll_id) * 100.0 / (SELECT COUNT(*) FROM fabric_rolls), 2) AS grade_percentage,
    ROUND(SUM(roll_length_meters), 2) AS total_meters,
    ROUND(SUM(roll_weight_kg), 2) AS total_weight_kg,
    ROUND(AVG(roll_length_meters), 2) AS avg_roll_length_meters
FROM fabric_rolls
GROUP BY roll_grade
ORDER BY CASE roll_grade WHEN 'A' THEN 1 WHEN 'B' THEN 2 WHEN 'C' THEN 3 ELSE 4 END;


-- ============================================================================
-- QUERY 08: Top 10 Most Frequent Fabric Defect Types
-- ============================================================================
/*
BUSINESS QUESTION:
Which 10 defect types occur most frequently during fabric inspections?

BUSINESS PURPOSE:
Identify the primary defect drivers to prioritize root-cause containment actions.

SQL APPROACH:
Join defect_records with defect_types, count defect occurrences, and calculate
total penalty points accrued.
*/
SELECT 
    dt.defect_code,
    dt.defect_name,
    dt.category,
    dt.severity_level,
    COUNT(dr.defect_id) AS total_occurrences,
    SUM(dr.defect_points) AS total_penalty_points,
    ROUND(AVG(dr.defect_length_meters), 2) AS avg_defect_length_meters,
    ROUND(SUM(dt.standard_scrapping_cost_per_defect), 2) AS estimated_scrap_cost_usd
FROM defect_records dr
JOIN defect_types dt ON dr.defect_type_id = dt.defect_type_id
GROUP BY dt.defect_code, dt.defect_name, dt.category, dt.severity_level
ORDER BY total_occurrences DESC
LIMIT 10;


-- ============================================================================
-- QUERY 09: Defect Severity Distribution by Machine Process Stage
-- ============================================================================
/*
BUSINESS QUESTION:
How do Minor, Major, and Critical defects distribute across Weaving, Knitting,
Dyeing, Printing, and Finishing process stages?

BUSINESS PURPOSE:
Pinpoint which manufacturing process introduces high-severity fabric flaws.

SQL APPROACH:
Join defect_records, quality_inspections, fabric_rolls, production_runs, machines,
and machine_types, grouping by process_stage and severity.
*/
SELECT 
    mt.process_stage,
    dr.severity,
    COUNT(dr.defect_id) AS defect_count,
    SUM(dr.defect_points) AS total_points,
    ROUND(AVG(dr.defect_points), 2) AS avg_points_per_defect
FROM defect_records dr
JOIN fabric_rolls fr ON dr.roll_id = fr.roll_id
JOIN production_runs pr ON fr.run_id = pr.run_id
JOIN machines m ON pr.machine_id = m.machine_id
JOIN machine_types mt ON m.machine_type_id = mt.machine_type_id
GROUP BY mt.process_stage, dr.severity
ORDER BY mt.process_stage, CASE dr.severity WHEN 'Critical' THEN 1 WHEN 'Major' THEN 2 ELSE 3 END;


-- ============================================================================
-- QUERY 10: Corrective Rework Success Rates by Rework Type
-- ============================================================================
/*
BUSINESS QUESTION:
What is the success rate and average labor duration for each rework method
(e.g., Re-Washing, Mending, Re-Dyeing)?

BUSINESS PURPOSE:
Determine which rework interventions are economically viable vs. ineffective.

SQL APPROACH:
Group rework_records by rework_type, computing total rework jobs, average technician
hours, chemical costs, and successful outcome percentage.
*/
SELECT 
    rework_type,
    COUNT(rework_id) AS total_rework_jobs,
    SUM(CASE WHEN rework_result = 'Successful' THEN 1 ELSE 0 END) AS successful_jobs,
    ROUND(SUM(CASE WHEN rework_result = 'Successful' THEN 1.0 ELSE 0.0 END) / COUNT(rework_id) * 100.0, 2) AS success_rate_pct,
    ROUND(AVG(technician_hours), 2) AS avg_labor_hours,
    ROUND(SUM(additional_chemical_cost), 2) AS total_chemical_spend_usd
FROM rework_records
GROUP BY rework_type
ORDER BY total_rework_jobs DESC;


-- ============================================================================
-- QUERY 11: Total Material Waste & Net Financial Loss by Waste Type
-- ============================================================================
/*
BUSINESS QUESTION:
What are the gross cost, salvage value recovered, and net financial loss for each
waste category (e.g., Selvage Trimming, Off-Shade Dye Dumping, Sizing Loss)?

BUSINESS PURPOSE:
Quantify the dollarized impact of scrap generation across waste streams.

SQL APPROACH:
Group production_waste by waste_type, summing waste quantities, gross cost,
salvage recovery, and net loss.
*/
SELECT 
    waste_type,
    COUNT(waste_id) AS waste_events,
    ROUND(SUM(waste_quantity), 2) AS total_quantity_scrapped,
    unit_of_measure,
    ROUND(SUM(total_waste_cost), 2) AS gross_waste_cost_usd,
    ROUND(SUM(salvage_recovery_value), 2) AS total_salvage_recovered_usd,
    ROUND(SUM(net_financial_loss), 2) AS net_financial_loss_usd,
    ROUND((SUM(salvage_recovery_value) / NULLIF(SUM(total_waste_cost), 0) * 100.0), 2) AS salvage_recovery_pct
FROM production_waste
GROUP BY waste_type, unit_of_measure
ORDER BY net_financial_loss_usd DESC;


-- ============================================================================
-- QUERY 12: Production Waste Generation by Manufacturing Plant
-- ============================================================================
/*
BUSINESS QUESTION:
How much financial loss is caused by material waste at each plant?

BUSINESS PURPOSE:
Compare plant waste management performance and target high-loss facilities.

SQL APPROACH:
Join plants, production_lines, production_runs, and production_waste,
aggregating waste events and net loss by plant.
*/
SELECT 
    p.plant_id,
    p.plant_code,
    p.plant_name,
    COUNT(pw.waste_id) AS total_waste_records,
    ROUND(SUM(pw.waste_quantity), 2) AS total_waste_units,
    ROUND(SUM(pw.total_waste_cost), 2) AS gross_waste_cost_usd,
    ROUND(SUM(pw.net_financial_loss), 2) AS net_waste_loss_usd,
    ROUND(AVG(pw.net_financial_loss), 2) AS avg_loss_per_event_usd
FROM plants p
JOIN production_lines pl ON p.plant_id = pl.plant_id
JOIN production_runs pr ON pl.line_id = pr.line_id
JOIN production_waste pw ON pr.run_id = pw.run_id
GROUP BY p.plant_id, p.plant_code, p.plant_name
ORDER BY net_waste_loss_usd DESC;


-- ============================================================================
-- QUERY 13: Machine Downtime Hours & Loss by Category
-- ============================================================================
/*
BUSINESS QUESTION:
What is the total duration (in hours) and financial burden of machine downtime
grouped by downtime category?

BUSINESS PURPOSE:
Isolate whether mechanical failures, setup changes, or material jams cause the bulk of downtime.

SQL APPROACH:
Group machine_downtime by downtime_category, summing duration hours and financial cost.
*/
SELECT 
    downtime_category,
    COUNT(downtime_id) AS stoppage_incidents,
    ROUND(SUM(duration_hours), 2) AS total_downtime_hours,
    ROUND(AVG(duration_hours), 2) AS avg_hours_per_stoppage,
    ROUND(SUM(financial_downtime_cost), 2) AS total_downtime_cost_usd,
    ROUND(AVG(financial_downtime_cost), 2) AS avg_cost_per_stoppage_usd
FROM machine_downtime
GROUP BY downtime_category
ORDER BY total_downtime_hours DESC;


-- ============================================================================
-- QUERY 14: Top 10 Machines with the Highest Unplanned Downtime
-- ============================================================================
/*
BUSINESS QUESTION:
Which 10 machines have recorded the highest cumulative unplanned breakdown hours?

BUSINESS PURPOSE:
Target chronic breakdown machines for engineering review and overhauls.

SQL APPROACH:
Filter machine_downtime for 'Unplanned Breakdown', join machines and plants,
group by machine and sort descending.
*/
SELECT 
    m.machine_id,
    m.machine_code,
    m.machine_name,
    p.plant_name,
    m.manufacturer,
    m.installation_date,
    COUNT(md.downtime_id) AS breakdown_count,
    ROUND(SUM(md.duration_hours), 2) AS total_breakdown_hours,
    ROUND(SUM(md.financial_downtime_cost), 2) AS total_overhead_loss_usd
FROM machines m
JOIN production_lines pl ON m.line_id = pl.line_id
JOIN plants p ON pl.plant_id = p.plant_id
JOIN machine_downtime md ON m.machine_id = md.machine_id
WHERE md.downtime_category = 'Unplanned Breakdown'
GROUP BY m.machine_id, m.machine_code, m.machine_name, p.plant_name, m.manufacturer, m.installation_date
ORDER BY total_breakdown_hours DESC
LIMIT 10;


-- ============================================================================
-- QUERY 15: Machine Maintenance Spend & Hours by Maintenance Type
-- ============================================================================
/*
BUSINESS QUESTION:
What is the enterprise expenditure on Preventive, Corrective, Predictive,
and Emergency machine maintenance?

BUSINESS PURPOSE:
Assess if the plant is overly reliant on expensive reactive/emergency servicing.

SQL APPROACH:
Group machine_maintenance by maintenance_type, aggregating technician hours,
labor cost, parts cost, and total spend.
*/
SELECT 
    maintenance_type,
    COUNT(maintenance_id) AS total_jobs,
    ROUND(SUM(technician_hours), 2) AS total_technician_hours,
    ROUND(SUM(labor_cost), 2) AS total_labor_cost_usd,
    ROUND(SUM(replacement_parts_cost), 2) AS total_parts_cost_usd,
    ROUND(SUM(total_maintenance_cost), 2) AS total_maintenance_spend_usd,
    ROUND(AVG(total_maintenance_cost), 2) AS avg_cost_per_job_usd
FROM machine_maintenance
WHERE maintenance_status = 'Completed'
GROUP BY maintenance_type
ORDER BY total_maintenance_spend_usd DESC;


-- ============================================================================
-- QUERY 16: Supplier Raw Material Batch Acceptance & Rejection Rates
-- ============================================================================
/*
BUSINESS QUESTION:
What are the incoming quality acceptance vs rejection rates for each raw material supplier?

BUSINESS PURPOSE:
Track vendor quality compliance at goods receiving inspection.

SQL APPROACH:
Join suppliers and material_batches, counting accepted, quarantined, and rejected batches.
*/
SELECT 
    s.supplier_id,
    s.supplier_code,
    s.supplier_name,
    s.credit_rating,
    s.is_preferred,
    COUNT(mb.batch_id) AS total_delivered_batches,
    SUM(CASE WHEN mb.quality_status = 'Accepted' THEN 1 ELSE 0 END) AS accepted_batches,
    SUM(CASE WHEN mb.quality_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_batches,
    ROUND(SUM(CASE WHEN mb.quality_status = 'Rejected' THEN 1.0 ELSE 0.0 END) / COUNT(mb.batch_id) * 100.0, 2) AS rejection_rate_pct
FROM suppliers s
JOIN material_batches mb ON s.supplier_id = mb.supplier_id
GROUP BY s.supplier_id, s.supplier_code, s.supplier_name, s.credit_rating, s.is_preferred
HAVING COUNT(mb.batch_id) >= 5
ORDER BY rejection_rate_pct DESC, total_delivered_batches DESC;


-- ============================================================================
-- QUERY 17: Raw Material Purchase Spend by Material Category
-- ============================================================================
/*
BUSINESS QUESTION:
What is the total procurement spend across raw material categories (Yarn, Dyes, Sizing, Chemicals)?

BUSINESS PURPOSE:
Understand direct material cost drivers for inventory budget management.

SQL APPROACH:
Join materials with purchase_order_items, aggregating ordered quantity and line totals.
*/
SELECT 
    m.category,
    COUNT(DISTINCT m.material_id) AS distinct_materials_count,
    COUNT(poi.po_item_id) AS total_po_line_items,
    ROUND(SUM(poi.ordered_quantity), 2) AS total_ordered_quantity,
    ROUND(SUM(poi.line_total), 2) AS total_spend_usd,
    ROUND(AVG(poi.unit_price), 2) AS avg_unit_price_usd
FROM materials m
JOIN purchase_order_items poi ON m.material_id = poi.material_id
GROUP BY m.category
ORDER BY total_spend_usd DESC;


-- ============================================================================
-- QUERY 18: Operator Productivity & Skill Level Benchmarking
-- ============================================================================
/*
BUSINESS QUESTION:
What is the average output volume and run speed achieved by operators grouped
by skill level (Junior, Intermediate, Senior, Master)?

BUSINESS PURPOSE:
Evaluate the relationship between workforce experience and production velocity.

SQL APPROACH:
Join employees with production_runs, grouping by skill_level and calculating
run averages.
*/
SELECT 
    e.skill_level,
    COUNT(DISTINCT e.employee_id) AS operator_count,
    COUNT(pr.run_id) AS total_runs_completed,
    ROUND(SUM(pr.actual_meters), 2) AS total_meters_produced,
    ROUND(AVG(pr.actual_meters), 2) AS avg_meters_per_run,
    ROUND(AVG(pr.actual_speed_rpm), 0) AS avg_speed_rpm,
    ROUND(AVG(pr.actual_meters / NULLIF(pr.planned_meters, 0) * 100.0), 2) AS avg_efficiency_pct
FROM employees e
JOIN production_runs pr ON e.employee_id = pr.operator_id
WHERE e.role = 'Operator'
GROUP BY e.skill_level
ORDER BY avg_efficiency_pct DESC;


-- ============================================================================
-- QUERY 19: Customer Order Fulfillment Status & On-Time Performance
-- ============================================================================
/*
BUSINESS QUESTION:
How many sales orders are fulfilled, in production, delayed, or cancelled,
and what is the total commercial revenue associated with each state?

BUSINESS PURPOSE:
Monitor on-time in-full (OTIF) customer delivery health and sales pipeline status.

SQL APPROACH:
Group customer_orders by order_status, computing order counts, total meters ordered,
and gross sales value.
*/
SELECT 
    order_status,
    COUNT(order_id) AS total_orders,
    ROUND(COUNT(order_id) * 100.0 / (SELECT COUNT(*) FROM customer_orders), 2) AS pct_of_total_orders,
    ROUND(SUM(ordered_meters), 2) AS total_ordered_meters,
    ROUND(SUM(ordered_meters * unit_selling_price), 2) AS total_sales_value_usd,
    ROUND(AVG(ordered_meters * unit_selling_price), 2) AS avg_order_value_usd
FROM customer_orders
GROUP BY order_status
ORDER BY total_sales_value_usd DESC;


-- ============================================================================
-- QUERY 20: Monthly Production Trend & Operating Run Velocity
-- ============================================================================
/*
BUSINESS QUESTION:
What is the monthly fabric production volume and average operating speed
across the historical timeline (2023–2025)?

BUSINESS PURPOSE:
Identify macro production volume seasonality and output trends over time.

SQL APPROACH:
Extract year and month from run_date, aggregating completed runs, meters produced,
and operating RPM.
*/
SELECT 
    SUBSTR(run_date, 1, 4) AS production_year,
    SUBSTR(run_date, 6, 2) AS production_month,
    COUNT(run_id) AS runs_completed,
    ROUND(SUM(actual_meters), 2) AS total_meters_produced,
    ROUND(SUM(planned_meters), 2) AS total_planned_meters,
    ROUND((SUM(actual_meters) / NULLIF(SUM(planned_meters), 0) * 100.0), 2) AS monthly_efficiency_pct,
    ROUND(AVG(actual_speed_rpm), 0) AS avg_operating_speed_rpm
FROM production_runs
WHERE run_status = 'Completed'
GROUP BY SUBSTR(run_date, 1, 4), SUBSTR(run_date, 6, 2)
ORDER BY production_year, production_month;
