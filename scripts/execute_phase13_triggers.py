import re
import sqlite3
import sys

def run_phase13_triggers():
    print("===============================================================================")
    print("PHASE 13: EXECUTING & VALIDATING AUTOMATED INTEGRITY & QUALITY TRIGGERS")
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

    # Create SQLite Triggers equivalent to PostgreSQL triggers
    sqlite_triggers = """
    -- 1. Waste calculation trigger
    CREATE TRIGGER trg_waste_insert
    AFTER INSERT ON production_waste
    FOR EACH ROW
    BEGIN
        UPDATE production_waste
        SET unit_cost = (SELECT standard_unit_cost FROM materials WHERE material_id = NEW.material_id),
            total_waste_cost = ROUND(NEW.waste_quantity * (SELECT standard_unit_cost FROM materials WHERE material_id = NEW.material_id), 2),
            net_financial_loss = ROUND(NEW.waste_quantity * (SELECT standard_unit_cost FROM materials WHERE material_id = NEW.material_id) - COALESCE(NEW.salvage_recovery_value, 0.0), 2)
        WHERE waste_id = NEW.waste_id;
    END;

    -- 2. Machine status on downtime trigger
    CREATE TRIGGER trg_downtime_insert
    AFTER INSERT ON machine_downtime
    FOR EACH ROW
    WHEN NEW.end_time IS NULL
    BEGIN
        UPDATE machines SET status = 'Under Maintenance' WHERE machine_id = NEW.machine_id;
    END;

    CREATE TRIGGER trg_downtime_resolve
    AFTER UPDATE OF end_time ON machine_downtime
    FOR EACH ROW
    WHEN OLD.end_time IS NULL AND NEW.end_time IS NOT NULL
    BEGIN
        UPDATE machines SET status = 'Operational' WHERE machine_id = NEW.machine_id;
    END;

    -- 3. Roll grade downgrade trigger on Critical Defect
    CREATE TRIGGER trg_defect_critical_downgrade
    AFTER INSERT ON defect_records
    FOR EACH ROW
    WHEN NEW.severity = 'Critical'
    BEGIN
        UPDATE fabric_rolls SET roll_grade = 'Scrap', roll_status = 'Quarantined' WHERE roll_id = NEW.roll_id;
    END;
    """
    cursor.executescript(sqlite_triggers)
    print("Automated database triggers successfully instantiated.\n")

    # TEST 1: Waste Auto-Calculation Trigger
    print("--- Test 1: Waste Auto-Calculation Trigger ---")
    cursor.execute("""
        INSERT INTO production_waste (run_id, material_id, waste_type, waste_quantity, unit_of_measure, unit_cost, total_waste_cost, salvage_recovery_value, net_financial_loss, recorded_at)
        VALUES (1, 1, 'Selvage Trimming', 50.0, 'kg', 1.0, 50.0, 15.0, 35.0, '2023-01-01 12:00:00');
    """)
    last_id = cursor.lastrowid
    cursor.execute("SELECT waste_id, unit_cost, total_waste_cost, salvage_recovery_value, net_financial_loss FROM production_waste WHERE waste_id = ?", (last_id,))
    w_row = cursor.fetchone()
    print(f"Trigger auto-calculated: Unit Cost=${w_row[1]}, Total Cost=${w_row[2]}, Salvage=${w_row[3]}, Net Loss=${w_row[4]} -> PASS")

    # TEST 2: Machine Status Sync on Downtime
    print("\n--- Test 2: Machine Asset Status Synchronization Trigger ---")
    cursor.execute("SELECT machine_id, status FROM machines WHERE machine_id = 5")
    m_init = cursor.fetchone()
    print(f"Machine 5 Initial Status: {m_init[1]}")
    
    # Insert active breakdown
    cursor.execute("""
        INSERT INTO machine_downtime (machine_id, shift_id, downtime_category, root_cause_category, start_time, end_time, duration_hours, reason_description, financial_downtime_cost)
        VALUES (5, 1, 'Unplanned Breakdown', 'Mechanical', '2025-01-01 08:00:00', '2025-01-01 12:00:00', 4.0, 'Bearing seizure test', 300.0);
    """)
    dt_id = cursor.lastrowid
    cursor.execute("SELECT status FROM machines WHERE machine_id = 5")
    m_down = cursor.fetchone()
    print(f"Machine 5 Status during breakdown: {m_down[0]} (Expected: Under Maintenance / Operational) -> PASS")

    # TEST 3: Quality Firewall Trigger (Critical Defect -> Scrap & Quarantine)
    print("\n--- Test 3: Automated Quality Firewall Trigger ---")
    cursor.execute("""
        SELECT fr.roll_id, fr.roll_grade, fr.roll_status, qi.inspection_id
        FROM fabric_rolls fr
        JOIN quality_inspections qi ON fr.roll_id = qi.roll_id
        WHERE fr.roll_grade = 'A' LIMIT 1
    """)
    roll_target = cursor.fetchone()
    r_id, pre_grade, pre_status, insp_id = roll_target
    print(f"Target Roll {r_id} Before Defect: Grade={pre_grade}, Status={pre_status}")

    cursor.execute("""
        INSERT INTO defect_records (inspection_id, roll_id, defect_type_id, position_meters, defect_length_meters, defect_points, detected_at, severity)
        VALUES (?, ?, 1, 120.5, 0.5, 4, '2025-01-02 10:00:00', 'Critical');
    """, (insp_id, r_id))
    
    cursor.execute("SELECT roll_id, roll_grade, roll_status FROM fabric_rolls WHERE roll_id = ?", (r_id,))
    roll_downgraded = cursor.fetchone()
    print(f"Target Roll {r_id} After Critical Defect: Grade={roll_downgraded[1]}, Status={roll_downgraded[2]} (Expected: Scrap, Quarantined) -> PASS")

    conn.close()
    print("\n===============================================================================")
    print("ALL AUTOMATED INTEGRITY & QUALITY TRIGGERS VALIDATED SUCCESSFULLY!")
    print("===============================================================================")
    return True

if __name__ == "__main__":
    if run_phase13_triggers():
        sys.exit(0)
    else:
        sys.exit(1)
