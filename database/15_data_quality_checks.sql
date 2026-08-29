-- ============================================================================
-- TEXTILE PRODUCTION WASTE, DEFECT & MACHINE INTELLIGENCE SYSTEM
-- Script: 15_data_quality_checks.sql
-- Description: Automated Enterprise Data Quality Audit Suite returning
--              CHECK_ID, CHECK_NAME, CATEGORY, EXPECTED, ACTUAL, and STATUS (PASS/FAIL).
-- ============================================================================

-- ============================================================================
-- 10-POINT COMPREHENSIVE DATA QUALITY AUDIT MATRIX
-- ============================================================================

WITH QualityCheckResults AS (

    -- CHECK 01: Referential Integrity (Orphaned Foreign Key Records)
    SELECT 
        1 AS check_id,
        'Referential Integrity: Orphaned Transaction Records' AS check_name,
        'Referential Integrity' AS check_category,
        '0 Orphan Records' AS expected_value,
        CAST((
            (SELECT COUNT(*) FROM purchase_order_items poi LEFT JOIN purchase_orders po ON poi.po_id = po.po_id WHERE po.po_id IS NULL) +
            (SELECT COUNT(*) FROM material_batches mb LEFT JOIN suppliers s ON mb.supplier_id = s.supplier_id WHERE s.supplier_id IS NULL) +
            (SELECT COUNT(*) FROM production_runs pr LEFT JOIN production_orders po ON pr.prod_order_id = po.prod_order_id WHERE po.prod_order_id IS NULL) +
            (SELECT COUNT(*) FROM material_consumption mc LEFT JOIN production_runs pr ON mc.run_id = pr.run_id WHERE pr.run_id IS NULL) +
            (SELECT COUNT(*) FROM fabric_rolls fr LEFT JOIN production_runs pr ON fr.run_id = pr.run_id WHERE pr.run_id IS NULL) +
            (SELECT COUNT(*) FROM quality_inspections qi LEFT JOIN fabric_rolls fr ON qi.roll_id = fr.roll_id WHERE fr.roll_id IS NULL) +
            (SELECT COUNT(*) FROM defect_records dr LEFT JOIN quality_inspections qi ON dr.inspection_id = qi.inspection_id WHERE qi.inspection_id IS NULL) +
            (SELECT COUNT(*) FROM rework_records rw LEFT JOIN fabric_rolls fr ON rw.roll_id = fr.roll_id WHERE fr.roll_id IS NULL) +
            (SELECT COUNT(*) FROM machine_downtime md LEFT JOIN machines m ON md.machine_id = m.machine_id WHERE m.machine_id IS NULL) +
            (SELECT COUNT(*) FROM production_waste pw LEFT JOIN production_runs pr ON pw.run_id = pr.run_id WHERE pr.run_id IS NULL)
        ) AS TEXT) || ' Orphan Records' AS actual_value,
        CASE WHEN (
            (SELECT COUNT(*) FROM purchase_order_items poi LEFT JOIN purchase_orders po ON poi.po_id = po.po_id WHERE po.po_id IS NULL) +
            (SELECT COUNT(*) FROM material_batches mb LEFT JOIN suppliers s ON mb.supplier_id = s.supplier_id WHERE s.supplier_id IS NULL) +
            (SELECT COUNT(*) FROM production_runs pr LEFT JOIN production_orders po ON pr.prod_order_id = po.prod_order_id WHERE po.prod_order_id IS NULL) +
            (SELECT COUNT(*) FROM material_consumption mc LEFT JOIN production_runs pr ON mc.run_id = pr.run_id WHERE pr.run_id IS NULL) +
            (SELECT COUNT(*) FROM fabric_rolls fr LEFT JOIN production_runs pr ON fr.run_id = pr.run_id WHERE pr.run_id IS NULL) +
            (SELECT COUNT(*) FROM quality_inspections qi LEFT JOIN fabric_rolls fr ON qi.roll_id = fr.roll_id WHERE fr.roll_id IS NULL) +
            (SELECT COUNT(*) FROM defect_records dr LEFT JOIN quality_inspections qi ON dr.inspection_id = qi.inspection_id WHERE qi.inspection_id IS NULL) +
            (SELECT COUNT(*) FROM rework_records rw LEFT JOIN fabric_rolls fr ON rw.roll_id = fr.roll_id WHERE fr.roll_id IS NULL) +
            (SELECT COUNT(*) FROM machine_downtime md LEFT JOIN machines m ON md.machine_id = m.machine_id WHERE m.machine_id IS NULL) +
            (SELECT COUNT(*) FROM production_waste pw LEFT JOIN production_runs pr ON pw.run_id = pr.run_id WHERE pr.run_id IS NULL)
        ) = 0 THEN 'PASS' ELSE 'FAIL' END AS status

    UNION ALL

    -- CHECK 02: Temporal Chronology (Start Time < End Time)
    SELECT 
        2 AS check_id,
        'Temporal Chronology: Start vs. End Timestamps' AS check_name,
        'Temporal Logic' AS check_category,
        '0 Chronology Inversions' AS expected_value,
        CAST((
            (SELECT COUNT(*) FROM production_runs WHERE end_time <= start_time) +
            (SELECT COUNT(*) FROM machine_downtime WHERE end_time <= start_time) +
            (SELECT COUNT(*) FROM customer_orders WHERE actual_dispatch_date IS NOT NULL AND actual_dispatch_date < order_date) +
            (SELECT COUNT(*) FROM production_orders WHERE actual_end_date IS NOT NULL AND actual_start_date IS NOT NULL AND actual_end_date < actual_start_date)
        ) AS TEXT) || ' Inversions' AS actual_value,
        CASE WHEN (
            (SELECT COUNT(*) FROM production_runs WHERE end_time <= start_time) +
            (SELECT COUNT(*) FROM machine_downtime WHERE end_time <= start_time) +
            (SELECT COUNT(*) FROM customer_orders WHERE actual_dispatch_date IS NOT NULL AND actual_dispatch_date < order_date) +
            (SELECT COUNT(*) FROM production_orders WHERE actual_end_date IS NOT NULL AND actual_start_date IS NOT NULL AND actual_end_date < actual_start_date)
        ) = 0 THEN 'PASS' ELSE 'FAIL' END AS status

    UNION ALL

    -- CHECK 03: Domain Boundary: Positive Quantitative Metrics
    SELECT 
        3 AS check_id,
        'Domain Boundary: Non-Negative & Positive Metrics' AS check_name,
        'Domain Range' AS check_category,
        '0 Boundary Violations' AS expected_value,
        CAST((
            (SELECT COUNT(*) FROM production_runs WHERE planned_meters <= 0 OR actual_meters < 0 OR planned_speed_rpm <= 0 OR actual_speed_rpm < 0) +
            (SELECT COUNT(*) FROM fabric_rolls WHERE roll_length_meters <= 0 OR roll_weight_kg <= 0) +
            (SELECT COUNT(*) FROM machine_downtime WHERE duration_hours <= 0 OR financial_downtime_cost < 0) +
            (SELECT COUNT(*) FROM production_waste WHERE waste_quantity <= 0 OR unit_cost <= 0 OR total_waste_cost < 0)
        ) AS TEXT) || ' Violations' AS actual_value,
        CASE WHEN (
            (SELECT COUNT(*) FROM production_runs WHERE planned_meters <= 0 OR actual_meters < 0 OR planned_speed_rpm <= 0 OR actual_speed_rpm < 0) +
            (SELECT COUNT(*) FROM fabric_rolls WHERE roll_length_meters <= 0 OR roll_weight_kg <= 0) +
            (SELECT COUNT(*) FROM machine_downtime WHERE duration_hours <= 0 OR financial_downtime_cost < 0) +
            (SELECT COUNT(*) FROM production_waste WHERE waste_quantity <= 0 OR unit_cost <= 0 OR total_waste_cost < 0)
        ) = 0 THEN 'PASS' ELSE 'FAIL' END AS status

    UNION ALL

    -- CHECK 04: Quality Inspection Boundaries (Quality Score 0-100 & ASTM Points 1-4)
    SELECT 
        4 AS check_id,
        'Quality Boundary: ASTM 4-Point & Score (0-100)' AS check_name,
        'Quality Standard' AS check_category,
        '0 Score Anomalies' AS expected_value,
        CAST((
            (SELECT COUNT(*) FROM quality_inspections WHERE quality_score < 0.0 OR quality_score > 100.0 OR total_defect_points < 0) +
            (SELECT COUNT(*) FROM defect_records WHERE defect_points NOT IN (1, 2, 3, 4) OR position_meters < 0.0)
        ) AS TEXT) || ' Anomalies' AS actual_value,
        CASE WHEN (
            (SELECT COUNT(*) FROM quality_inspections WHERE quality_score < 0.0 OR quality_score > 100.0 OR total_defect_points < 0) +
            (SELECT COUNT(*) FROM defect_records WHERE defect_points NOT IN (1, 2, 3, 4) OR position_meters < 0.0)
        ) = 0 THEN 'PASS' ELSE 'FAIL' END AS status

    UNION ALL

    -- CHECK 05: Financial Loss Arithmetic Reconciliation
    SELECT 
        5 AS check_id,
        'Financial Reconciliation: Scrap Net Loss Consistency' AS check_name,
        'Financial Accuracy' AS check_category,
        '0 Math Discrepancies' AS expected_value,
        CAST((
            SELECT COUNT(*) FROM production_waste 
            WHERE ABS(net_financial_loss - ROUND(total_waste_cost - salvage_recovery_value, 2)) > 0.02
        ) AS TEXT) || ' Discrepancies' AS actual_value,
        CASE WHEN (
            SELECT COUNT(*) FROM production_waste 
            WHERE ABS(net_financial_loss - ROUND(total_waste_cost - salvage_recovery_value, 2)) > 0.02
        ) = 0 THEN 'PASS' ELSE 'FAIL' END AS status

    UNION ALL

    -- CHECK 06: Maintenance Schedule Chronology
    SELECT 
        6 AS check_id,
        'Maintenance Schedule Chronology' AS check_name,
        'Temporal Logic' AS check_category,
        '0 Chronology Faults' AS expected_value,
        CAST((
            SELECT COUNT(*) FROM machine_maintenance
            WHERE completion_date IS NOT NULL AND completion_date < scheduled_date
        ) AS TEXT) || ' Faults' AS actual_value,
        CASE WHEN (
            SELECT COUNT(*) FROM machine_maintenance
            WHERE completion_date IS NOT NULL AND completion_date < scheduled_date
        ) = 0 THEN 'PASS' ELSE 'FAIL' END AS status

    UNION ALL

    -- CHECK 07: Uniqueness of Business Keys and Serial Barcodes
    SELECT 
        7 AS check_id,
        'Uniqueness: Natural Keys & Barcodes' AS check_name,
        'Uniqueness' AS check_category,
        '0 Duplicate Keys' AS expected_value,
        CAST((
            (SELECT COUNT(*) - COUNT(DISTINCT roll_barcode) FROM fabric_rolls) +
            (SELECT COUNT(*) - COUNT(DISTINCT run_code) FROM production_runs) +
            (SELECT COUNT(*) - COUNT(DISTINCT plant_code) FROM plants) +
            (SELECT COUNT(*) - COUNT(DISTINCT machine_code) FROM machines) +
            (SELECT COUNT(*) - COUNT(DISTINCT product_code) FROM products) +
            (SELECT COUNT(*) - COUNT(DISTINCT material_code) FROM materials) +
            (SELECT COUNT(*) - COUNT(DISTINCT supplier_code) FROM suppliers)
        ) AS TEXT) || ' Duplicates' AS actual_value,
        CASE WHEN (
            (SELECT COUNT(*) - COUNT(DISTINCT roll_barcode) FROM fabric_rolls) +
            (SELECT COUNT(*) - COUNT(DISTINCT run_code) FROM production_runs) +
            (SELECT COUNT(*) - COUNT(DISTINCT plant_code) FROM plants) +
            (SELECT COUNT(*) - COUNT(DISTINCT machine_code) FROM machines) +
            (SELECT COUNT(*) - COUNT(DISTINCT product_code) FROM products) +
            (SELECT COUNT(*) - COUNT(DISTINCT material_code) FROM materials) +
            (SELECT COUNT(*) - COUNT(DISTINCT supplier_code) FROM suppliers)
        ) = 0 THEN 'PASS' ELSE 'FAIL' END AS status

    UNION ALL

    -- CHECK 08: Missing Mandatory Attributes (NOT NULL Audit)
    SELECT 
        8 AS check_id,
        'Data Completeness: Mandatory Column Audit' AS check_name,
        'Completeness' AS check_category,
        '0 NULL Violations' AS expected_value,
        CAST((
            (SELECT COUNT(*) FROM production_runs WHERE run_code IS NULL OR machine_id IS NULL OR product_id IS NULL OR planned_meters IS NULL) +
            (SELECT COUNT(*) FROM fabric_rolls WHERE roll_barcode IS NULL OR run_id IS NULL OR product_id IS NULL OR roll_grade IS NULL) +
            (SELECT COUNT(*) FROM quality_inspections WHERE inspection_code IS NULL OR roll_id IS NULL OR inspector_id IS NULL) +
            (SELECT COUNT(*) FROM machine_maintenance WHERE maintenance_code IS NULL OR machine_id IS NULL OR technician_id IS NULL) +
            (SELECT COUNT(*) FROM production_waste WHERE run_id IS NULL OR material_id IS NULL OR waste_quantity IS NULL)
        ) AS TEXT) || ' NULL Violations' AS actual_value,
        CASE WHEN (
            (SELECT COUNT(*) FROM production_runs WHERE run_code IS NULL OR machine_id IS NULL OR product_id IS NULL OR planned_meters IS NULL) +
            (SELECT COUNT(*) FROM fabric_rolls WHERE roll_barcode IS NULL OR run_id IS NULL OR product_id IS NULL OR roll_grade IS NULL) +
            (SELECT COUNT(*) FROM quality_inspections WHERE inspection_code IS NULL OR roll_id IS NULL OR inspector_id IS NULL) +
            (SELECT COUNT(*) FROM machine_maintenance WHERE maintenance_code IS NULL OR machine_id IS NULL OR technician_id IS NULL) +
            (SELECT COUNT(*) FROM production_waste WHERE run_id IS NULL OR material_id IS NULL OR waste_quantity IS NULL)
        ) = 0 THEN 'PASS' ELSE 'FAIL' END AS status

    UNION ALL

    -- CHECK 09: Material Consumption Traceability
    SELECT 
        9 AS check_id,
        'Material Traceability: Batches Consumed' AS check_name,
        'Traceability' AS check_category,
        '0 Untraceable Batches' AS expected_value,
        CAST((
            SELECT COUNT(*) FROM material_consumption mc
            LEFT JOIN material_batches mb ON mc.batch_id = mb.batch_id
            WHERE mb.batch_id IS NULL
        ) AS TEXT) || ' Untraceable' AS actual_value,
        CASE WHEN (
            SELECT COUNT(*) FROM material_consumption mc
            LEFT JOIN material_batches mb ON mc.batch_id = mb.batch_id
            WHERE mb.batch_id IS NULL
        ) = 0 THEN 'PASS' ELSE 'FAIL' END AS status

    UNION ALL

    -- CHECK 10: Rework Quality Transition Integrity
    SELECT 
        10 AS check_id,
        'Quality State Transition: Rework Grades' AS check_name,
        'Domain Range' AS check_category,
        '0 Invalid Transitions' AS expected_value,
        CAST((
            SELECT COUNT(*) FROM rework_records
            WHERE pre_rework_grade NOT IN ('B', 'C', 'Scrap') OR post_rework_grade NOT IN ('A', 'B', 'C', 'Scrap')
        ) AS TEXT) || ' Invalid Transitions' AS actual_value,
        CASE WHEN (
            SELECT COUNT(*) FROM rework_records
            WHERE pre_rework_grade NOT IN ('B', 'C', 'Scrap') OR post_rework_grade NOT IN ('A', 'B', 'C', 'Scrap')
        ) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
)
SELECT 
    check_id,
    check_name,
    check_category,
    expected_value,
    actual_value,
    status
FROM QualityCheckResults
ORDER BY check_id;
