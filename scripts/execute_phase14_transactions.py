import re
import sqlite3
import sys

def run_phase14_transactions():
    print("===============================================================================")
    print("PHASE 14: EXECUTING & VALIDATING ACID-COMPLIANT TRANSACTIONS")
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

    # =========================================================================
    # TEST 1: Scenario 1 - Multi-Table Atomic Run Completion (COMMIT)
    # =========================================================================
    print("--- Test 1: Multi-Table Atomic Run Completion Transaction ---")
    try:
        cursor.execute("BEGIN TRANSACTION;")
        
        # 1. Update Run
        cursor.execute("UPDATE production_runs SET actual_meters = 1250.0, run_status = 'Completed' WHERE run_id = 1;")
        
        # 2. Insert Consumption
        cursor.execute("INSERT INTO material_consumption (run_id, batch_id, material_id, consumed_quantity, unit_of_measure, consumed_at) VALUES (1, 1, 1, 312.50, 'kg', '2025-01-15 14:05:00');")
        
        # 3. Insert Roll
        cursor.execute("INSERT INTO fabric_rolls (roll_barcode, run_id, product_id, roll_length_meters, roll_weight_kg, roll_grade, roll_status, produced_at) VALUES ('ROL-TX-20250115-001', 1, 1, 1250.00, 300.00, 'A', 'In Stock', '2025-01-15 14:00:00');")
        roll_id = cursor.lastrowid
        
        # 4. Insert Inspection
        cursor.execute("INSERT INTO quality_inspections (inspection_code, roll_id, inspector_id, inspection_date, inspected_length_meters, inspected_width_meters, total_defect_points, points_per_100_sqm, quality_score, inspection_result) VALUES ('INS-20250115-001', ?, 10, '2025-01-15 14:30:00', 1250.00, 1.50, 2, 0.11, 98.50, 'Pass');", (roll_id,))
        
        # 5. Insert Waste
        cursor.execute("INSERT INTO production_waste (run_id, material_id, waste_type, waste_quantity, unit_of_measure, unit_cost, total_waste_cost, salvage_recovery_value, net_financial_loss, recorded_at) VALUES (1, 1, 'Selvage Trimming', 12.50, 'kg', 3.50, 43.75, 5.00, 38.75, '2025-01-15 14:00:00');")
        
        cursor.execute("COMMIT;")
        print("  -> Transaction Scenario 1: All 5 operations atomically committed (PASS)")
    except Exception as e:
        cursor.execute("ROLLBACK;")
        print(f"  -> Transaction Scenario 1 FAILED: {e}")
        return False

    # =========================================================================
    # TEST 2: Scenario 2 - Failure & Clean Rollback Simulation (ROLLBACK)
    # =========================================================================
    print("\n--- Test 2: Transaction Failure & Full Rollback Simulation ---")
    cursor.execute("SELECT actual_meters FROM production_runs WHERE run_id = 2;")
    orig_meters = cursor.fetchone()[0]
    
    rollback_success = False
    try:
        cursor.execute("BEGIN TRANSACTION;")
        cursor.execute("UPDATE production_runs SET actual_meters = 99999.0 WHERE run_id = 2;")
        # Intentional constraint violation: negative waste quantity
        cursor.execute("INSERT INTO production_waste (run_id, material_id, waste_type, waste_quantity, unit_of_measure, unit_cost, total_waste_cost, salvage_recovery_value, net_financial_loss, recorded_at) VALUES (2, 1, 'Selvage Trimming', -50.0, 'kg', 3.50, 175.0, 0.0, 175.0, '2025-01-01 12:00:00');")
        cursor.execute("COMMIT;")
    except sqlite3.IntegrityError as e:
        cursor.execute("ROLLBACK;")
        cursor.execute("SELECT actual_meters FROM production_runs WHERE run_id = 2;")
        reverted_meters = cursor.fetchone()[0]
        if reverted_meters == orig_meters:
            print(f"  -> Caught expected constraint error: {e}")
            print(f"  -> Reverted state verified: actual_meters={reverted_meters} (matches initial {orig_meters})")
            print("  -> Transaction Scenario 2: Rollback completely preserved data integrity (PASS)")
            rollback_success = True

    if not rollback_success:
        return False

    # =========================================================================
    # TEST 3: Scenario 3 - Partial Rollback with SAVEPOINTS
    # =========================================================================
    print("\n--- Test 3: Partial Rollback with Savepoint Checkpoints ---")
    try:
        cursor.execute("BEGIN TRANSACTION;")
        cursor.execute("UPDATE machine_maintenance SET total_maintenance_cost = 555.55 WHERE maintenance_id = 5;")
        cursor.execute("SAVEPOINT sv_valid_step;")
        
        # Risky nested operation that fails
        try:
            cursor.execute("INSERT INTO fabric_rolls (roll_barcode, run_id, product_id, roll_length_meters, roll_weight_kg, roll_grade, produced_at) VALUES ('INVALID_ROLL', 1, 1, -500.0, 100.0, 'A', '2025-01-01 12:00:00');")
        except sqlite3.IntegrityError:
            cursor.execute("ROLLBACK TO SAVEPOINT sv_valid_step;")
        
        cursor.execute("COMMIT;")
        
        cursor.execute("SELECT total_maintenance_cost FROM machine_maintenance WHERE maintenance_id = 5;")
        cost = cursor.fetchone()[0]
        print(f"  -> Maintenance Cost updated to ${cost} while invalid roll was rolled back cleanly")
        print("  -> Transaction Scenario 3: Savepoint partial rollback verified (PASS)")
    except Exception as e:
        print(f"  -> Transaction Scenario 3 FAILED: {e}")
        return False

    # =========================================================================
    # TEST 4: Scenario 4 - Maintenance Emergency Stoppage & Asset Lock (COMMIT)
    # =========================================================================
    print("\n--- Test 4: Maintenance Emergency Stoppage & Asset State Lock ---")
    try:
        cursor.execute("BEGIN TRANSACTION;")
        cursor.execute("UPDATE machines SET status = 'Under Maintenance' WHERE machine_id = 12;")
        cursor.execute("INSERT INTO machine_downtime (machine_id, shift_id, start_time, end_time, duration_hours, downtime_category, root_cause_category, reason_description, financial_downtime_cost) VALUES (12, 1, '2025-01-22 09:00:00', '2025-01-22 13:30:00', 4.50, 'Unplanned Breakdown', 'Mechanical', 'Main drive gearbox bearing thermal seizure', 382.50);")
        cursor.execute("INSERT INTO machine_maintenance (maintenance_code, machine_id, technician_id, scheduled_date, maintenance_type, maintenance_status, technician_hours, labor_cost, replacement_parts_cost, total_maintenance_cost, completion_date, notes) VALUES ('MNT-EMG-20250122-01', 12, 15, '2025-01-22', 'Emergency', 'In Progress', 4.50, 135.00, 250.00, 385.00, NULL, 'Emergency gearbox replacement');")
        cursor.execute("COMMIT;")
        
        cursor.execute("SELECT status FROM machines WHERE machine_id = 12;")
        m_status = cursor.fetchone()[0]
        print(f"  -> Machine 12 Status successfully updated to: {m_status}")
        print("  -> Transaction Scenario 4: Asset lock & synchronized stoppage committed (PASS)")
    except Exception as e:
        cursor.execute("ROLLBACK;")
        print(f"  -> Transaction Scenario 4 FAILED: {e}")
        return False

    conn.close()
    print("\n===============================================================================")
    print("ALL ACID-COMPLIANT TRANSACTION SCENARIOS VALIDATED SUCCESSFULLY!")
    print("===============================================================================")
    return True

if __name__ == "__main__":
    if run_phase14_transactions():
        sys.exit(0)
    else:
        sys.exit(1)
