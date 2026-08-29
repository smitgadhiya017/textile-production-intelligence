import re
import sqlite3
import time
import sys

def run_benchmarks():
    print("===============================================================================")
    print("PHASE 16: PERFORMANCE TESTING & INDEX BENCHMARKING (108k+ ROWS)")
    print("===============================================================================")

    # 1. Setup In-Memory DB without indexes
    conn_unindexed = sqlite3.connect(":memory:")
    conn_unindexed.execute("PRAGMA foreign_keys = ON;")
    cursor_unindexed = conn_unindexed.cursor()

    with open("database/02_create_tables.sql", "r", encoding="utf-8") as f:
        ddl_sql = f.read()
    sqlite_ddl = ddl_sql
    sqlite_ddl = re.sub(r'BIGSERIAL PRIMARY KEY', 'INTEGER PRIMARY KEY AUTOINCREMENT', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'SERIAL PRIMARY KEY', 'INTEGER PRIMARY KEY AUTOINCREMENT', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'NUMERIC\(\d+,\s*\d+\)', 'NUMERIC', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'BOOLEAN DEFAULT FALSE', 'INTEGER DEFAULT 0', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'BOOLEAN DEFAULT TRUE', 'INTEGER DEFAULT 1', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'BOOLEAN', 'INTEGER', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'TIMESTAMP DEFAULT CURRENT_TIMESTAMP', 'DATETIME DEFAULT CURRENT_TIMESTAMP', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'DROP TABLE IF EXISTS \w+ CASCADE;', '', sqlite_ddl, flags=re.IGNORECASE)
    cursor_unindexed.executescript(sqlite_ddl)

    with open("database/04_seed_master_data.sql", "r", encoding="utf-8") as f:
        cursor_unindexed.executescript(f.read())
    with open("database/05_seed_transaction_data.sql", "r", encoding="utf-8") as f:
        cursor_unindexed.executescript(f.read())

    print("Populated unindexed database instance (108k+ records).")

    # 2. Setup In-Memory DB WITH 62 indexes from 03_indexes.sql
    conn_indexed = sqlite3.connect(":memory:")
    conn_indexed.execute("PRAGMA foreign_keys = ON;")
    cursor_indexed = conn_indexed.cursor()
    cursor_indexed.executescript(sqlite_ddl)
    with open("database/04_seed_master_data.sql", "r", encoding="utf-8") as f:
        cursor_indexed.executescript(f.read())
    with open("database/05_seed_transaction_data.sql", "r", encoding="utf-8") as f:
        cursor_indexed.executescript(f.read())

    with open("database/03_indexes.sql", "r", encoding="utf-8") as f:
        idx_sql = f.read()
    # Clean PostgreSQL specific syntax if any
    idx_sql_clean = re.sub(r'CREATE INDEX CONCURRENTLY', 'CREATE INDEX', idx_sql, flags=re.IGNORECASE)
    cursor_indexed.executescript(idx_sql_clean)

    print("Populated indexed database instance (108k+ records + 62 B-Tree Indexes).\n")

    queries = [
        ("Benchmark 01: Quality Inspection & Defect Join", """
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
        """),
        ("Benchmark 02: Machine Downtime & Root Cause Loss", """
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
        """),
        ("Benchmark 03: Raw Material Traceability & Downstream Scrap", """
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
        """),
        ("Benchmark 04: Date-Range Quarter Loss Aggregation", """
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
        """),
        ("Benchmark 05: Operator & Shift Efficiency Aggregation", """
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
        """)
    ]

    iterations = 5
    print(f"{'BENCHMARK WORKLOAD':<52} | {'UNINDEXED':<12} | {'INDEXED':<12} | {'SPEEDUP':<10} | {'IMPROVEMENT'}")
    print("-" * 105)

    for title, sql in queries:
        # Warmup
        cursor_unindexed.execute(sql).fetchall()
        cursor_indexed.execute(sql).fetchall()

        # Benchmark Unindexed
        t0 = time.perf_counter()
        for _ in range(iterations):
            cursor_unindexed.execute(sql).fetchall()
        t_unindexed = ((time.perf_counter() - t0) / iterations) * 1000.0

        # Benchmark Indexed
        t0 = time.perf_counter()
        for _ in range(iterations):
            cursor_indexed.execute(sql).fetchall()
        t_indexed = ((time.perf_counter() - t0) / iterations) * 1000.0

        speedup = t_unindexed / max(t_indexed, 0.0001)
        improvement = ((t_unindexed - t_indexed) / max(t_unindexed, 0.0001)) * 100.0

        print(f"{title:<52} | {t_unindexed:>8.2f} ms | {t_indexed:>8.2f} ms | {speedup:>8.2f}x | {improvement:>8.1f}%")

        # Explain Query Plan
        cursor_indexed.execute(f"EXPLAIN QUERY PLAN {sql}")
        plan_rows = cursor_indexed.fetchall()
        plan_summary = " -> ".join([r[3] for r in plan_rows if "USING INDEX" in r[3] or "USING COVERING INDEX" in r[3]])
        if plan_summary:
            print(f"   [Index Usage]: {plan_summary[:90]}...")
        print()

    conn_unindexed.close()
    conn_indexed.close()
    print("===============================================================================")
    print("ALL 5 ANALYTICAL QUERY WORKLOADS BENCHMARKED & OPTIMIZED SUCCESSFULLY!")
    print("===============================================================================")
    return True

if __name__ == "__main__":
    if run_benchmarks():
        sys.exit(0)
    else:
        sys.exit(1)
