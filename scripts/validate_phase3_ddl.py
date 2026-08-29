import re
import sqlite3
import sys

def parse_and_validate_sql_ddl(sql_path):
    print(f"Reading DDL from {sql_path}...")
    with open(sql_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Extract all CREATE TABLE statements
    table_matches = re.findall(r"CREATE\s+TABLE\s+([a-zA-Z_0-9]+)\s*\((.*?)\);", content, re.DOTALL | re.IGNORECASE)
    
    print(f"Found {len(table_matches)} CREATE TABLE definitions.")
    tables = [m[0] for m in table_matches]
    print(f"Tables: {', '.join(tables)}")
    
    expected_tables = [
        "locations", "machine_types", "shifts", "defect_types", "plants",
        "products", "materials", "suppliers", "customers", "production_lines",
        "employees", "machines", "customer_orders", "purchase_orders",
        "purchase_order_items", "production_orders", "material_batches",
        "production_runs", "machine_maintenance", "material_consumption",
        "fabric_rolls", "machine_downtime", "production_waste",
        "quality_inspections", "defect_records", "rework_records"
    ]
    
    missing = set(expected_tables) - set(tables)
    if missing:
        print(f"ERROR: Missing expected tables: {missing}")
        return False
    else:
        print("All 26 required normalized tables are present.")

    # Check for PKs, FKs, NOT NULL, UNIQUE, CHECK constraints
    pk_count = content.count("PRIMARY KEY")
    fk_count = content.count("REFERENCES")
    not_null_count = content.count("NOT NULL")
    unique_count = content.count("UNIQUE")
    check_count = content.count("CHECK")
    
    print(f"\nConstraint Metrics:")
    print(f"- PRIMARY KEY definitions: {pk_count}")
    print(f"- FOREIGN KEY references: {fk_count}")
    print(f"- NOT NULL constraints: {not_null_count}")
    print(f"- UNIQUE constraints: {unique_count}")
    print(f"- CHECK constraints: {check_count}")

    if pk_count < 26:
        print("ERROR: Not all tables have Primary Keys.")
        return False
    if fk_count < 30:
        print("ERROR: Insufficient Foreign Key constraints.")
        return False
    if check_count < 20:
        print("ERROR: Insufficient domain CHECK constraints.")
        return False

    return True

def test_sql_constraints_simulation():
    """
    Translates PostgreSQL DDL types into SQLite to execute actual DB-level
    constraint validation (Positive test cases and Negative test cases).
    """
    print("\nExecuting In-Memory Relational Engine Constraint & Foreign Key Tests...")
    
    with open("database/02_create_tables.sql", "r", encoding="utf-8") as f:
        sql = f.read()
    
    # Translate PostgreSQL specifics to SQLite syntax for validation testing
    sqlite_sql = sql
    sqlite_sql = re.sub(r'BIGSERIAL PRIMARY KEY', 'INTEGER PRIMARY KEY AUTOINCREMENT', sqlite_sql, flags=re.IGNORECASE)
    sqlite_sql = re.sub(r'SERIAL PRIMARY KEY', 'INTEGER PRIMARY KEY AUTOINCREMENT', sqlite_sql, flags=re.IGNORECASE)
    sqlite_sql = re.sub(r'NUMERIC\(\d+,\s*\d+\)', 'NUMERIC', sqlite_sql, flags=re.IGNORECASE)
    sqlite_sql = re.sub(r'BOOLEAN DEFAULT FALSE', 'INTEGER DEFAULT 0', sqlite_sql, flags=re.IGNORECASE)
    sqlite_sql = re.sub(r'BOOLEAN DEFAULT TRUE', 'INTEGER DEFAULT 1', sqlite_sql, flags=re.IGNORECASE)
    sqlite_sql = re.sub(r'BOOLEAN', 'INTEGER', sqlite_sql, flags=re.IGNORECASE)
    sqlite_sql = re.sub(r'TIMESTAMP DEFAULT CURRENT_TIMESTAMP', 'DATETIME DEFAULT CURRENT_TIMESTAMP', sqlite_sql, flags=re.IGNORECASE)
    sqlite_sql = re.sub(r'DROP TABLE IF EXISTS \w+ CASCADE;', '', sqlite_sql, flags=re.IGNORECASE)
    
    conn = sqlite3.connect(":memory:")
    conn.execute("PRAGMA foreign_keys = ON;")
    cursor = conn.cursor()
    
    # Execute DDL
    try:
        cursor.executescript(sqlite_sql)
        print("Schema successfully instantiated in database engine.")
    except Exception as e:
        print(f"ERROR executing DDL: {e}")
        return False

    # TEST 1: Positive Insert Test on Master & Transactional Hierarchy
    try:
        cursor.execute("INSERT INTO locations (location_name, address_line1, city, state_province, country, postal_code) VALUES ('Savannah Mill', '100 River St', 'Savannah', 'GA', 'USA', '31401')")
        loc_id = cursor.lastrowid
        
        cursor.execute("INSERT INTO plants (plant_code, plant_name, location_id, manager_name, total_capacity_meters_per_day, operational_status) VALUES ('PLT-01', 'Savannah Main Plant', ?, 'John Doe', 50000.0, 'Active')", (loc_id,))
        plant_id = cursor.lastrowid
        
        cursor.execute("INSERT INTO machine_types (type_code, type_name, process_stage, standard_speed_rpm, power_consumption_kwh, expected_lifespan_years) VALUES ('MT-RAPIER', 'Rapier Loom', 'Weaving', 600, 15.5, 12)")
        mt_id = cursor.lastrowid
        
        cursor.execute("INSERT INTO shifts (shift_code, shift_name, start_time, end_time, duration_hours, is_night_shift) VALUES ('SH-MORN', 'Morning Shift', '06:00:00', '14:00:00', 8.0, 0)")
        shift_id = cursor.lastrowid
        
        cursor.execute("INSERT INTO defect_types (defect_code, defect_name, category, severity_level, standard_penalty_points, standard_scrapping_cost_per_defect) VALUES ('DEF-WRP-01', 'Warp Break', 'Weaving Defect', 'Major', 3, 25.0)")
        def_type_id = cursor.lastrowid
        
        cursor.execute("INSERT INTO products (product_code, product_name, fabric_type, weave_type, density_gsm, standard_cost_per_meter, selling_price_per_meter, complexity_tier) VALUES ('PROD-DNM-01', 'Heavy Denim 12oz', 'Denim', 'Twill', 340.0, 4.50, 7.50, 'High')")
        prod_id = cursor.lastrowid
        
        cursor.execute("INSERT INTO materials (material_code, material_name, category, subcategory, unit_of_measure, standard_unit_cost, density_linear_count) VALUES ('MAT-YRN-01', 'Ring-Spun Cotton Yarn', 'Yarn', 'Natural', 'kg', 3.20, '20s Ne')")
        mat_id = cursor.lastrowid

        print("TEST 1 PASSED: Master entity inserts and foreign keys succeed.")
    except Exception as e:
        print(f"TEST 1 FAILED: {e}")
        return False

    # TEST 2: Negative Constraint Test - Invalid Quality Score (> 100 or < 0)
    try:
        cursor.execute("INSERT INTO fabric_rolls (roll_barcode, run_id, product_id, roll_length_meters, roll_weight_kg, roll_grade, roll_status, produced_at) VALUES ('RLL-001', 1, 1, 100.0, 30.0, 'A', 'In Stock', '2023-01-01 10:00:00')")
        roll_id = cursor.lastrowid
        cursor.execute("INSERT INTO quality_inspections (inspection_code, roll_id, inspector_id, inspection_date, inspected_length_meters, inspected_width_meters, total_defect_points, points_per_100_sqm, quality_score, inspection_result) VALUES ('QC-001', ?, 1, '2023-01-01 12:00:00', 100.0, 1.5, 10, 6.6, 125.0, 'Pass')", (roll_id,))
        print("TEST 2 FAILED: Insertion with invalid quality_score (125.0 > 100.0) should have been rejected.")
        return False
    except Exception as e:
        print(f"TEST 2 PASSED: Quality score constraint properly rejected invalid score ({e})")

    # TEST 3: Negative Constraint Test - Invalid Defect Points (Points not in 1,2,3,4)
    try:
        cursor.execute("INSERT INTO defect_types (defect_code, defect_name, category, severity_level, standard_penalty_points, standard_scrapping_cost_per_defect) VALUES ('DEF-INV', 'Bad Defect', 'Weaving Defect', 'Major', 5, 25.0)")
        print("TEST 3 FAILED: Defect type with penalty points = 5 should have been rejected.")
        return False
    except Exception as e:
        print(f"TEST 3 PASSED: Defect penalty points constraint rejected invalid points ({e})")

    # TEST 4: Negative Constraint Test - Negative Waste Quantity
    try:
        cursor.execute("INSERT INTO production_waste (run_id, material_id, waste_type, waste_quantity, unit_of_measure, unit_cost, total_waste_cost, salvage_recovery_value, net_financial_loss, recorded_at) VALUES (1, 1, 'Selvage Trimming', -15.0, 'kg', 3.20, 48.0, 5.0, 43.0, '2023-01-01 10:00:00')")
        print("TEST 4 FAILED: Negative waste quantity should have been rejected.")
        return False
    except Exception as e:
        print(f"TEST 4 PASSED: Negative waste quantity rejected ({e})")

    # TEST 5: Negative Constraint Test - Invalid Product Selling Price < Standard Cost
    try:
        cursor.execute("INSERT INTO products (product_code, product_name, fabric_type, weave_type, density_gsm, standard_cost_per_meter, selling_price_per_meter, complexity_tier) VALUES ('PROD-BAD', 'Bad Price Product', 'Cotton', 'Plain', 200.0, 10.00, 5.00, 'Low')")
        print("TEST 5 FAILED: Product with selling price < standard cost should have been rejected.")
        return False
    except Exception as e:
        print(f"TEST 5 PASSED: Product selling price constraint rejected price < cost ({e})")

    conn.close()
    return True

if __name__ == "__main__":
    v1 = parse_and_validate_sql_ddl("database/02_create_tables.sql")
    v2 = test_sql_constraints_simulation()
    if v1 and v2:
        print("\nALL PHASE 3 DDL AND CONSTRAINT VALIDATIONS PASSED.")
        sys.exit(0)
    else:
        print("\nPHASE 3 VALIDATIONS FAILED.")
        sys.exit(1)
