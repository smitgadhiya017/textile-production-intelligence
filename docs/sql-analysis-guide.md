# SQL Analysis Guide
## Textile Production Intelligence System

This guide explains every SQL analytics script in the project — what each query answers, the SQL techniques used, and how to run them.

---

## How to Execute Queries

### Using psql (CLI)
```bash
psql -h localhost -U postgres -d textile_production_db -f database/07_basic_analytics.sql
```

### Using pgAdmin 4
1. Open Query Tool (Alt+Shift+Q)
2. File → Open → select any `database/*.sql` file
3. Press F5 to execute all, or F9 for selected block

### Query Output
All analytics queries include `-- ===` section headers and `\echo` markers to identify outputs in CLI.

---

## Script Reference

---

### `database/07_basic_analytics.sql` — Basic Analytics

**15 foundational queries. All single or dual-table. GROUP BY aggregations.**

| # | Query Title | Tables Used | SQL Technique |
|---|------------|-------------|---------------|
| Q1 | Total production output by plant per month | `production_runs`, `plants` | GROUP BY, SUM, JOIN |
| Q2 | Monthly defect count trend | `defect_records` | DATE_TRUNC, COUNT |
| Q3 | Top 10 waste types by financial loss | `waste_records`, `waste_types` | GROUP BY, ORDER BY DESC |
| Q4 | Machine downtime hours by plant | `machine_downtime`, `machines`, `plants` | SUM, JOIN, GROUP BY |
| Q5 | Operator efficiency ranking | `production_runs`, `operators` | AVG, ORDER BY |
| Q6 | Average quality score by fabric type | `quality_inspections`, `products`, `fabric_types` | AVG, 3-table JOIN |
| Q7 | Supplier defect contribution rate | `defect_records`, `material_purchases`, `suppliers` | COUNT, DIVIDE |
| Q8 | Machine utilization rate by machine type | `production_runs`, `machines`, `machine_types` | AVG, GROUP BY |
| Q9 | Monthly production loss trend | `waste_records`, `machine_downtime` | UNION ALL, DATE_TRUNC |
| Q10 | Top 10 defect types by frequency | `defect_records`, `defect_types` | COUNT, LIMIT |
| Q11 | Maintenance frequency by machine type | `machine_maintenance`, `machines`, `machine_types` | COUNT, GROUP BY |
| Q12 | Shift performance comparison (Day/Night/Eve) | `production_runs`, `shift_schedules` | AVG, CASE WHEN |
| Q13 | Material cost variance vs actual usage cost | `material_purchases`, `material_usage` | SUM, variance calc |
| Q14 | Business alert distribution by severity | `production_alerts` | COUNT, GROUP BY severity |
| Q15 | First-Pass Yield rate by plant | `quality_inspections`, `plants` | COUNT FILTER, DIVIDE |

**Example — Q15 FPY by Plant:**
```sql
SELECT
    p.plant_name,
    COUNT(*) AS total_inspections,
    COUNT(*) FILTER (WHERE qi.is_first_pass_yield = TRUE) AS fpy_count,
    ROUND(
        COUNT(*) FILTER (WHERE qi.is_first_pass_yield = TRUE)::NUMERIC
        / COUNT(*) * 100, 2
    ) AS fpy_rate_pct
FROM quality_inspections qi
JOIN production_runs pr ON qi.run_id = pr.run_id
JOIN machines m ON pr.machine_id = m.machine_id
JOIN plants p ON m.plant_id = p.plant_id
GROUP BY p.plant_name
ORDER BY fpy_rate_pct DESC;
```

---

### `database/08_intermediate_analytics.sql` — Intermediate Analytics

**20 multi-table analytics. Subqueries, ROLLUP, HAVING, complex JOINs.**

| # | Query Title | Key Technique |
|---|------------|---------------|
| Q1 | Plant × Fabric Cross-Tab Production Loss | CROSS JOIN, CUBE |
| Q2 | Supplier Quality vs Defect Rate Correlation | Correlated subquery |
| Q3 | Machine Age vs MTBF Analysis (age cohorts) | CASE WHEN bucketing |
| Q4 | Operator Skill Level vs Defect Rate | Multi-level GROUP BY |
| Q5 | Monthly Production KPI Dashboard Query | CTE, multiple aggregates |
| Q6 | Top 5 Loss-Causing Machines per Plant | Subquery with RANK() |
| Q7 | Material Rejection Rate by Supplier Country | JOIN chain, ratio calc |
| Q8 | Alert Resolution Time Analysis | DATEDIFF, HAVING |
| Q9 | Quarterly Quality Score Distribution | NTILE, percentile |
| Q10 | Waste Recovery Rate by Waste Type | FILTER, conditional SUM |
| Q11 | Machine Downtime Cascade Analysis | Self-JOIN on time overlap |
| Q12 | Operator Fatigue Index (late shift defects) | TIME extraction, CASE |
| Q13 | Product Margin Impact from Defects | Multi-table cost calc |
| Q14 | Supplier Lead Time vs Quality Rating | Rank correlation |
| Q15 | Seasonal Production Efficiency Patterns | EXTRACT(MONTH), GROUP BY |
| Q16 | Critical Alert Escalation Timeline | LAG, time-to-escalate |
| Q17 | Plant Capacity Utilization Report | Planned vs actual ratio |
| Q18 | Material Batch Traceability Query | Join chain 5 tables |
| Q19 | Defect Density Map by Plant × Defect Type | Pivot-style CASE |
| Q20 | Inspector Workload vs Accuracy Analysis | COUNT, AVG, HAVING |

**Example — Q3 Machine Age vs MTBF:**
```sql
SELECT
    CASE
        WHEN EXTRACT(YEAR FROM AGE(NOW(), m.installation_date)) BETWEEN 0 AND 3 THEN '0-3 years'
        WHEN EXTRACT(YEAR FROM AGE(NOW(), m.installation_date)) BETWEEN 4 AND 7 THEN '4-7 years'
        WHEN EXTRACT(YEAR FROM AGE(NOW(), m.installation_date)) BETWEEN 8 AND 11 THEN '8-11 years'
        ELSE '12+ years'
    END AS age_cohort,
    COUNT(DISTINCT m.machine_id) AS machine_count,
    ROUND(AVG(md_stats.mtbf_hours), 2) AS avg_mtbf_hours,
    ROUND(AVG(md_stats.total_downtime_hours), 2) AS avg_downtime_hours
FROM machines m
LEFT JOIN (
    SELECT machine_id,
           SUM(downtime_hours) AS total_downtime_hours,
           AVG(hours_since_last_failure) AS mtbf_hours
    FROM machine_downtime
    GROUP BY machine_id
) md_stats ON m.machine_id = md_stats.machine_id
GROUP BY age_cohort
ORDER BY age_cohort;
```

---

### `database/09_advanced_analytics.sql` — Advanced Analytics

**25 advanced queries. Window functions, CTEs, recursive queries, composite scoring.**

#### Window Function Patterns

| Query | Function | Purpose |
|-------|----------|---------|
| Machine Risk Rank per Plant | `DENSE_RANK() OVER (PARTITION BY plant_id ORDER BY risk_score DESC)` | Intra-plant ranking |
| MoM Defect Rate Delta | `LAG(defect_count) OVER (ORDER BY month)` | Period-over-period delta |
| Cumulative Production Loss | `SUM(loss_usd) OVER (ORDER BY run_date ROWS UNBOUNDED PRECEDING)` | Running total |
| Operator Performance Quartile | `NTILE(4) OVER (ORDER BY efficiency_pct DESC)` | Quartile segmentation |
| 3-Month Moving Average Loss | `AVG(loss_usd) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)` | Smoothed trend |

#### CTE Pipeline — Machine Risk Score (Flagship Query)

```sql
-- Full machine risk score computation (vw_machine_risk source)
WITH machine_age AS (
    SELECT machine_id, machine_code,
           EXTRACT(YEAR FROM AGE(NOW(), installation_date)) AS age_years
    FROM machines
),
downtime_stats AS (
    SELECT machine_id,
           SUM(downtime_hours) AS total_downtime_hours,
           COUNT(*) AS failure_count
    FROM machine_downtime
    WHERE created_at >= NOW() - INTERVAL '12 months'
    GROUP BY machine_id
),
defect_stats AS (
    SELECT pr.machine_id,
           COUNT(dr.defect_id) AS total_defects,
           SUM(CASE WHEN dt.severity = 'CRITICAL' THEN 1 ELSE 0 END) AS critical_defects
    FROM defect_records dr
    JOIN production_runs pr ON dr.run_id = pr.run_id
    JOIN defect_types dt ON dr.defect_type_id = dt.defect_type_id
    WHERE pr.run_date >= NOW() - INTERVAL '12 months'
    GROUP BY pr.machine_id
),
utilization_stats AS (
    SELECT machine_id,
           AVG(production_efficiency_pct) AS avg_utilization_pct
    FROM production_runs
    WHERE run_date >= NOW() - INTERVAL '12 months'
    GROUP BY machine_id
),
risk_raw AS (
    SELECT
        m.machine_id, m.machine_code, ma.age_years,
        COALESCE(ds.total_downtime_hours, 0) AS downtime_hours,
        COALESCE(def.total_defects, 0) AS total_defects,
        COALESCE(us.avg_utilization_pct, 0) AS utilization_pct,
        -- Normalize each factor 0–1 then weight
        (ma.age_years / NULLIF(MAX(ma.age_years) OVER (), 0)) * 30 +
        (COALESCE(ds.total_downtime_hours, 0) / NULLIF(MAX(COALESCE(ds.total_downtime_hours, 0)) OVER (), 0)) * 25 +
        (COALESCE(def.total_defects, 0) / NULLIF(MAX(COALESCE(def.total_defects, 0)) OVER (), 0)) * 25 +
        (1 - COALESCE(us.avg_utilization_pct, 0) / 100.0) * 20 AS risk_score_raw
    FROM machines m
    JOIN machine_age ma ON m.machine_id = ma.machine_id
    LEFT JOIN downtime_stats ds ON m.machine_id = ds.machine_id
    LEFT JOIN defect_stats def ON m.machine_id = def.machine_id
    LEFT JOIN utilization_stats us ON m.machine_id = us.machine_id
)
SELECT
    machine_id, machine_code, age_years, downtime_hours, total_defects, utilization_pct,
    ROUND(LEAST(risk_score_raw, 100), 2) AS machine_risk_score,
    CASE
        WHEN risk_score_raw >= 75 THEN 'CRITICAL'
        WHEN risk_score_raw >= 50 THEN 'HIGH'
        WHEN risk_score_raw >= 25 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS risk_category
FROM risk_raw
ORDER BY machine_risk_score DESC;
```

---

### `database/10_views.sql` — Semantic Business Views

All 7 views are designed as the **sole data source** for Power BI reports. Views are not materialized — they execute dynamically against the base tables on each BI refresh.

```sql
-- Quick reference: query any view
SELECT * FROM vw_production_efficiency   LIMIT 10;
SELECT * FROM vw_quality_performance     LIMIT 10;
SELECT * FROM vw_machine_performance     LIMIT 10;
SELECT * FROM vw_supplier_performance    LIMIT 10;
SELECT * FROM vw_production_loss         LIMIT 10;
SELECT * FROM vw_machine_risk            ORDER BY machine_risk_score DESC LIMIT 10;
SELECT * FROM vw_business_alerts         WHERE alert_severity = 'CRITICAL';
```

---

### `database/11_functions.sql` — Stored Functions

```sql
-- Usage examples for all 5 functions

-- 1. Get production loss for a specific run
SELECT fn_calculate_production_loss('run-uuid-here'::UUID);

-- 2. Get machine risk score on-demand
SELECT fn_get_machine_risk_score('machine-uuid-here'::UUID);

-- 3. FPY rate for a plant over a period
SELECT fn_calculate_fpy_rate('plant-uuid-here'::UUID, '2024-Q1');

-- 4. Composite supplier quality rating
SELECT fn_get_supplier_quality_rating('supplier-uuid-here'::UUID);

-- 5. Efficiency grade for a production run
SELECT fn_production_efficiency_grade(94.7);  -- Returns 'A'
```

---

### `database/12_procedures.sql` — Stored Procedures

```sql
-- Execute stored procedures
CALL sp_generate_production_alerts();        -- Scan thresholds, create alerts
CALL sp_calculate_monthly_kpis('2024-01');   -- Snapshot KPIs for a period
CALL sp_update_machine_risk_scores();        -- Refresh all risk scores
CALL sp_archive_resolved_alerts(30);         -- Archive alerts resolved >30 days ago
```

---

### `database/13_triggers.sql` — Triggers

```sql
-- Triggers fire automatically. Verify audit entries after production run insert:
INSERT INTO production_runs (...) VALUES (...);
SELECT * FROM audit_log ORDER BY created_at DESC LIMIT 5;

-- Verify critical alert auto-creation after defect insert:
INSERT INTO defect_records (..., severity = 'CRITICAL') VALUES (...);
SELECT * FROM production_alerts ORDER BY created_at DESC LIMIT 3;
```

---

### `database/14_transactions.sql` — ACID Transactions

**5 transaction scenarios demonstrating full ACID compliance:**

| Transaction | Scenario | ACID Property Demonstrated |
|-------------|----------|---------------------------|
| T1 | Complete production run with quality and waste records | Atomicity |
| T2 | Bulk defect insert with rollback on constraint violation | Atomicity + Isolation |
| T3 | Concurrent machine status update with row-level lock | Isolation |
| T4 | Monthly KPI snapshot with audit trail | Consistency |
| T5 | Alert status transition (OPEN → ACKNOWLEDGED → RESOLVED) | Consistency + Durability |

---

### `database/15_data_quality_checks.sql` — Quality Assertions

**20 assertions. All must return 0 rows (no violations) for PASS.**

```sql
-- Sample assertions
-- 1. No orphan defect records (no run_id match)
SELECT COUNT(*) FROM defect_records WHERE run_id NOT IN (SELECT run_id FROM production_runs);
-- Expected: 0

-- 2. No quality score outside valid range
SELECT COUNT(*) FROM quality_inspections WHERE quality_score < 0 OR quality_score > 100;
-- Expected: 0

-- 3. No negative waste quantity
SELECT COUNT(*) FROM waste_records WHERE waste_quantity_kg < 0;
-- Expected: 0

-- 4. No future-dated production runs
SELECT COUNT(*) FROM production_runs WHERE run_date > CURRENT_DATE;
-- Expected: 0

-- 5. No machine downtime exceeding 168 hours (1 week) per event
SELECT COUNT(*) FROM machine_downtime WHERE downtime_hours > 168;
-- Expected: 0
```

---

### `database/16_performance_testing.sql` — Benchmark Workloads

**5 workloads designed to stress-test index coverage:**

```sql
-- Run EXPLAIN ANALYZE on each to verify index usage
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT ... FROM quality_inspections qi
JOIN production_runs pr ON qi.run_id = pr.run_id
JOIN defect_records dr ON dr.run_id = pr.run_id
JOIN machines m ON pr.machine_id = m.machine_id
WHERE pr.run_date BETWEEN '2024-01-01' AND '2024-12-31';

-- Expected: Index Scan using idx_quality_run_code (not Seq Scan)
-- Speedup achieved: 2.48×
```

---

## Query Optimization Notes

### Index Strategy Applied

```
B-Tree indexes on all:
  - Foreign key columns (all 26 FK relationships)
  - Date/timestamp columns used in WHERE / ORDER BY
  - Status/severity/category enum columns used in filtering
  - Composite indexes for the 3 highest-frequency join patterns
```

### Query Best Practices Used

1. **CTEs over nested subqueries** — CTEs improve readability and allow optimizer to materialize intermediate results.
2. **`FILTER` clause over `CASE WHEN`** — More efficient for conditional aggregation.
3. **`COALESCE` for null safety** — Applied on all LEFT JOIN numeric columns.
4. **`NULLIF` in divisions** — Prevents division-by-zero in ratio calculations.
5. **`EXPLAIN ANALYZE`** — Used during Phase 16 to validate all index choices.
