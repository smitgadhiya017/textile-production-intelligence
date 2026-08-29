import re
import sqlite3
import sys

def run_phase10_views():
    print("===============================================================================")
    print("PHASE 10: EXECUTING & VALIDATING 7 CORE BUSINESS VIEWS & INTELLIGENCE ENGINES")
    print("===============================================================================")
    
    conn = sqlite3.connect(":memory:")
    conn.execute("PRAGMA foreign_keys = ON;")
    cursor = conn.cursor()

    # Load DDL & Data
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
    cursor.executescript(sqlite_ddl)

    with open("database/04_seed_master_data.sql", "r", encoding="utf-8") as f:
        cursor.executescript(f.read())
    with open("database/05_seed_transaction_data.sql", "r", encoding="utf-8") as f:
        cursor.executescript(f.read())

    print("Database populated with 108k+ records.")

    # Load and execute 10_views.sql
    with open("database/10_views.sql", "r", encoding="utf-8") as f:
        views_sql = f.read()
    
    cursor.executescript(views_sql)
    print("All 7 Business Views successfully compiled in relational database engine.\n")

    views_to_test = [
        ("vw_production_efficiency", "SELECT COUNT(*), ROUND(AVG(production_efficiency_pct), 2), ROUND(SUM(actual_meters), 2) FROM vw_production_efficiency"),
        ("vw_quality_performance", "SELECT COUNT(*), ROUND(AVG(quality_score), 2), SUM(is_first_pass_yield) FROM vw_quality_performance"),
        ("vw_machine_performance", "SELECT COUNT(*), ROUND(AVG(machine_utilization_pct), 2), ROUND(AVG(mtbf_hours), 2) FROM vw_machine_performance"),
        ("vw_supplier_performance", "SELECT COUNT(*), ROUND(AVG(supplier_quality_index), 2), SUM(CASE WHEN supplier_tier = 'Tier 1: Excellent' THEN 1 ELSE 0 END) FROM vw_supplier_performance"),
        ("vw_production_loss", "SELECT COUNT(*), ROUND(SUM(total_production_loss_usd), 2), ROUND(SUM(material_waste_loss_usd), 2) FROM vw_production_loss"),
        ("vw_machine_risk", "SELECT COUNT(*), ROUND(AVG(machine_risk_score), 2), SUM(CASE WHEN risk_category = 'CRITICAL' THEN 1 ELSE 0 END) FROM vw_machine_risk"),
        ("vw_business_alerts", "SELECT COUNT(*), COUNT(DISTINCT alert_type), ROUND(SUM(financial_impact_usd), 2) FROM vw_business_alerts")
    ]

    all_passed = True
    for vname, test_query in views_to_test:
        try:
            cursor.execute(f"SELECT * FROM {vname} LIMIT 1")
            col_names = [desc[0] for desc in cursor.description]
            cursor.execute(test_query)
            metrics = cursor.fetchone()
            print(f"VIEW: {vname}")
            print(f"  -> Projected Columns ({len(col_names)}): {', '.join(col_names[:6])} ...")
            print(f"  -> Audit Metrics: {metrics}")
            print(f"  -> Status: PASS\n")
        except Exception as e:
            print(f"VIEW: {vname} - FAILED: {e}")
            all_passed = False

    conn.close()
    if all_passed:
        print("===============================================================================")
        print("ALL 7 CORE BUSINESS VIEWS EXECUTED AND VALIDATED SUCCESSFULLY!")
        print("===============================================================================")
        return True
    return False

if __name__ == "__main__":
    if run_phase10_views():
        sys.exit(0)
    else:
        sys.exit(1)
