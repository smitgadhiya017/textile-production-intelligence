import re
import sqlite3
import sys

def validate_indexes():
    print("Validating Phase 4 Indexes...")
    
    with open("database/02_create_tables.sql", "r", encoding="utf-8") as f:
        ddl_sql = f.read()
        
    with open("database/03_indexes.sql", "r", encoding="utf-8") as f:
        idx_sql = f.read()

    # Extract tables and their columns from DDL
    tables = {}
    table_blocks = re.findall(r"CREATE\s+TABLE\s+([a-zA-Z_0-9]+)\s*\((.*?)\);", ddl_sql, re.DOTALL | re.IGNORECASE)
    for tname, block in table_blocks:
        cols = set()
        for line in block.split("\n"):
            line = line.strip()
            if not line or line.startswith("--") or line.startswith("CONSTRAINT") or line.startswith("PRIMARY KEY") or line.startswith("FOREIGN KEY"):
                continue
            col_match = re.match(r"^([a-zA-Z_0-9]+)", line)
            if col_match:
                cols.add(col_match.group(1).lower())
        tables[tname.lower()] = cols

    print(f"Extracted schema for {len(tables)} tables.")

    # Parse index statements
    index_matches = re.findall(r"CREATE\s+INDEX\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z_0-9]+)\s+ON\s+([a-zA-Z_0-9]+)\s*\((.*?)\)(?:\s*WHERE\s*(.*?))?;", idx_sql, re.DOTALL | re.IGNORECASE)
    print(f"Found {len(index_matches)} index definitions in database/03_indexes.sql.")

    fk_idx_count = 0
    composite_idx_count = 0
    partial_idx_count = 0

    for idx_name, tname, cols_str, where_clause in index_matches:
        tname_clean = tname.lower().strip()
        if tname_clean not in tables:
            print(f"ERROR: Index '{idx_name}' targets non-existent table '{tname}'")
            return False
            
        cols = [c.strip().split()[0].lower() for c in cols_str.split(",")]
        for col in cols:
            if col not in tables[tname_clean]:
                print(f"ERROR: Index '{idx_name}' references non-existent column '{col}' on table '{tname}'")
                return False
                
        if where_clause:
            partial_idx_count += 1
        elif len(cols) > 1:
            composite_idx_count += 1
        else:
            fk_idx_count += 1

    print(f"\nIndex Breakdown:")
    print(f"- FK / Single-Column B-Tree Join Indexes: {fk_idx_count}")
    print(f"- Composite Analytical & Time-Series Indexes: {composite_idx_count}")
    print(f"- Filtered Partial Indexes: {partial_idx_count}")
    print(f"- Total Validated Indexes: {len(index_matches)}")

    # Execute inside in-memory engine to verify syntactic validity
    sqlite_ddl = ddl_sql
    sqlite_ddl = re.sub(r'BIGSERIAL PRIMARY KEY', 'INTEGER PRIMARY KEY AUTOINCREMENT', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'SERIAL PRIMARY KEY', 'INTEGER PRIMARY KEY AUTOINCREMENT', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'NUMERIC\(\d+,\s*\d+\)', 'NUMERIC', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'BOOLEAN DEFAULT FALSE', 'INTEGER DEFAULT 0', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'BOOLEAN DEFAULT TRUE', 'INTEGER DEFAULT 1', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'BOOLEAN', 'INTEGER', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'TIMESTAMP DEFAULT CURRENT_TIMESTAMP', 'DATETIME DEFAULT CURRENT_TIMESTAMP', sqlite_ddl, flags=re.IGNORECASE)
    sqlite_ddl = re.sub(r'DROP TABLE IF EXISTS \w+ CASCADE;', '', sqlite_ddl, flags=re.IGNORECASE)

    conn = sqlite3.connect(":memory:")
    cursor = conn.cursor()
    cursor.executescript(sqlite_ddl)
    cursor.executescript(idx_sql)
    print("All index statements successfully executed and verified against active database schema.")
    conn.close()
    return True

if __name__ == "__main__":
    if validate_indexes():
        print("\nALL PHASE 4 INDEX VALIDATIONS PASSED.")
        sys.exit(0)
    else:
        print("\nPHASE 4 INDEX VALIDATIONS FAILED.")
        sys.exit(1)
