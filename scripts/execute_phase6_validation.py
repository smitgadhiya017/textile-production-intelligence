import re
import sqlite3
import sys
import time

def run_phase6_validation():
    print("===============================================================================")
    print("PHASE 6: DATA LOADING & FULL RELATIONAL VALIDATION")
    print("===============================================================================")
    
    conn = sqlite3.connect(":memory:")
    conn.execute("PRAGMA foreign_keys = ON;")
    cursor = conn.cursor()

    # 1. Load DDL
    print("\n1. Instantiating 26-Table Database Schema...")
    with open("database/02_create_tables.sql", "r", encoding="utf-8") as f:
        ddl_sql = f.read()
    
    # Translate PostgreSQL types to SQLite for in-memory testing
    sqlite_ddl = ddl_sql
    sqlite_ddl = re.sub(r'BIGSERIAL PRIMARY KEY', 'INTEGER PRIMARY KEY AUTOINCREMENT', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'SERIAL PRIMARY KEY', 'INTEGER PRIMARY KEY AUTOINCREMENT', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'NUMERIC\(\d+,\s*\d+\)', 'NUMERIC', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'BOOLEAN DEFAULT FALSE', 'INTEGER DEFAULT 0', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'BOOLEAN DEFAULT TRUE', 'INTEGER DEFAULT 1', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'BOOLEAN', 'INTEGER', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'TIMESTAMP DEFAULT CURRENT_TIMESTAMP', 'DATETIME DEFAULT CURRENT_TIMESTAMP', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'DROP TABLE IF EXISTS \w+ CASCADE;', '', sqlite_ddl, flags=re.IGNORECASE)

    cursor.executescript(sqlite_ddl)
    print("DDL Schema Created.")

    # 2. Load Master Seed Data
    print("2. Loading Master Seed Data (database/04_seed_master_data.sql)...")
    t0 = time.time()
    with open("database/04_seed_master_data.sql", "r", encoding="utf-8") as f:
        master_sql = f.read()
    cursor.executescript(master_sql)
    print(f"Master Data Loaded in {time.time() - t0:.2f}s.")

    # 3. Load Transaction Seed Data
    print("3. Loading Transaction Seed Data (database/05_seed_transaction_data.sql)...")
    t0 = time.time()
    with open("database/05_seed_transaction_data.sql", "r", encoding="utf-8") as f:
        tx_sql = f.read()
    cursor.executescript(tx_sql)
    print(f"Transaction Data (107k+ rows) Loaded in {time.time() - t0:.2f}s.")

    # 4. Execute Row Count Audits
    print("\n===============================================================================")
    print("AUDIT 1: ROW COUNTS ACROSS ALL 26 TABLES")
    print("===============================================================================")
    tables = [
        "locations", "machine_types", "shifts", "defect_types", "plants",
        "products", "materials", "suppliers", "customers", "production_lines",
        "employees", "machines", "customer_orders", "purchase_orders",
        "purchase_order_items", "material_batches", "production_orders",
        "production_runs", "material_consumption", "fabric_rolls",
        "quality_inspections", "defect_records", "rework_records",
        "machine_downtime", "machine_maintenance", "production_waste"
    ]
    
    total_db_rows = 0
    all_counts_pass = True
    print(f"{'Table Name':<26} {'Record Count':<16} {'Status'}")
    print("-" * 55)
    for t in tables:
        cursor.execute(f"SELECT COUNT(*) FROM {t}")
        cnt = cursor.fetchone()[0]
        total_db_rows += cnt
        status = "PASS" if cnt > 0 else "FAIL"
        if status != "PASS": all_counts_pass = False
        print(f"{t:<26} {cnt:<16,} {status}")
    print("-" * 55)
    print(f"{'TOTAL DATABASE RECORDS':<26} {total_db_rows:<16,} {'PASS' if all_counts_pass else 'FAIL'}")

    # 5. Execute Foreign Key Integrity Check
    print("\n===============================================================================")
    print("AUDIT 2: FOREIGN KEY INTEGRITY & ZERO ORPHAN RECORDS")
    print("===============================================================================")
    fk_queries = [
        ("production_runs -> machines", "SELECT COUNT(*) FROM production_runs pr LEFT JOIN machines m ON pr.machine_id = m.machine_id WHERE m.machine_id IS NULL"),
        ("production_runs -> employees (operators)", "SELECT COUNT(*) FROM production_runs pr LEFT JOIN employees e ON pr.operator_id = e.employee_id WHERE e.employee_id IS NULL"),
        ("material_consumption -> batches", "SELECT COUNT(*) FROM material_consumption mc LEFT JOIN material_batches mb ON mc.batch_id = mb.batch_id WHERE mb.batch_id IS NULL"),
        ("fabric_rolls -> production_runs", "SELECT COUNT(*) FROM fabric_rolls fr LEFT JOIN production_runs pr ON fr.run_id = pr.run_id WHERE pr.run_id IS NULL"),
        ("quality_inspections -> fabric_rolls", "SELECT COUNT(*) FROM quality_inspections qi LEFT JOIN fabric_rolls fr ON qi.roll_id = fr.roll_id WHERE fr.roll_id IS NULL"),
        ("defect_records -> defect_types", "SELECT COUNT(*) FROM defect_records dr LEFT JOIN defect_types dt ON dr.defect_type_id = dt.defect_type_id WHERE dt.defect_type_id IS NULL"),
        ("rework_records -> fabric_rolls", "SELECT COUNT(*) FROM rework_records rr LEFT JOIN fabric_rolls fr ON rr.roll_id = fr.roll_id WHERE fr.roll_id IS NULL"),
        ("machine_downtime -> machines", "SELECT COUNT(*) FROM machine_downtime md LEFT JOIN machines m ON md.machine_id = m.machine_id WHERE m.machine_id IS NULL"),
        ("machine_maintenance -> machines", "SELECT COUNT(*) FROM machine_maintenance mm LEFT JOIN machines m ON mm.machine_id = m.machine_id WHERE m.machine_id IS NULL"),
        ("production_waste -> materials", "SELECT COUNT(*) FROM production_waste pw LEFT JOIN materials m ON pw.material_id = m.material_id WHERE m.material_id IS NULL")
    ]
    
    fk_pass = True
    for name, query in fk_queries:
        cursor.execute(query)
        orphans = cursor.fetchone()[0]
        status = "PASS" if orphans == 0 else "FAIL"
        if status != "PASS": fk_pass = False
        print(f"FK Check [{name}]: {orphans} orphans -> {status}")

    # 6. Execute Chronological & Domain Audits
    print("\n===============================================================================")
    print("AUDIT 3: CHRONOLOGICAL & DOMAIN CONSTRAINT AUDITS")
    print("===============================================================================")
    domain_queries = [
        ("Temporal: PO Expected >= Order Date", "SELECT COUNT(*) FROM purchase_orders WHERE expected_delivery_date < order_date"),
        ("Temporal: Production Run End > Start Time", "SELECT COUNT(*) FROM production_runs WHERE end_time <= start_time"),
        ("Temporal: Downtime End > Start Time", "SELECT COUNT(*) FROM machine_downtime WHERE end_time <= start_time"),
        ("Temporal: Inspection Date >= Roll Produced Time", "SELECT COUNT(*) FROM quality_inspections qi JOIN fabric_rolls fr ON qi.roll_id = fr.roll_id WHERE qi.inspection_date < fr.produced_at"),
        ("Domain: Quality Score 0 to 100", "SELECT COUNT(*) FROM quality_inspections WHERE quality_score < 0.00 OR quality_score > 100.00"),
        ("Domain: Defect Points in (1,2,3,4)", "SELECT COUNT(*) FROM defect_records WHERE defect_points NOT IN (1, 2, 3, 4)"),
        ("Domain: Waste Quantity > 0", "SELECT COUNT(*) FROM production_waste WHERE waste_quantity <= 0.00"),
        ("Financial: Waste Net Loss Consistency", "SELECT COUNT(*) FROM production_waste WHERE ABS(net_financial_loss - (total_waste_cost - salvage_recovery_value)) > 0.02"),
        ("Financial: Product Selling Price >= Cost", "SELECT COUNT(*) FROM products WHERE selling_price_per_meter < standard_cost_per_meter")
    ]
    
    domain_pass = True
    for name, query in domain_queries:
        cursor.execute(query)
        violations = cursor.fetchone()[0]
        status = "PASS" if violations == 0 else "FAIL"
        if status != "PASS": domain_pass = False
        print(f"Domain Audit [{name}]: {violations} violations -> {status}")

    conn.close()
    
    if all_counts_pass and fk_pass and domain_pass:
        print("\n===============================================================================")
        print("ALL DATA QUALITY & INTEGRITY AUDITS PASSED (100% DATASET VALIDATION)")
        print("===============================================================================")
        return True
    else:
        print("\nDATA VALIDATION FAILED.")
        return False

if __name__ == "__main__":
    if run_phase6_validation():
        sys.exit(0)
    else:
        sys.exit(1)
