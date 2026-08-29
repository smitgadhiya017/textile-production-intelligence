import re
import sqlite3
import sys

def run_phase15_quality_checks():
    print("===============================================================================")
    print("PHASE 15: EXECUTING & VALIDATING 10-POINT ENTERPRISE DATA QUALITY AUDIT")
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

    print("Database populated with 108k+ records.\n")

    # Read and execute 15_data_quality_checks.sql
    with open("database/15_data_quality_checks.sql", "r", encoding="utf-8") as f:
        checks_sql = f.read()

    cursor.execute(checks_sql)
    rows = cursor.fetchall()
    
    print(f"{'ID':<4} | {'CHECK NAME':<48} | {'CATEGORY':<22} | {'EXPECTED':<22} | {'ACTUAL':<22} | {'STATUS'}")
    print("-" * 140)

    all_passed = True
    for r in rows:
        cid, cname, ccat, exp, act, status = r
        print(f"{cid:<4} | {cname:<48} | {ccat:<22} | {exp:<22} | {act:<22} | {status}")
        if status != 'PASS':
            all_passed = False

    conn.close()
    if all_passed and len(rows) == 10:
        print("\n===============================================================================")
        print("ALL 10 DATA QUALITY AUDIT CHECKS PASSED PERFECTLY (100% PASS RATE)!")
        print("===============================================================================")
        return True
    return False

if __name__ == "__main__":
    if run_phase15_quality_checks():
        sys.exit(0)
    else:
        sys.exit(1)
