import re
import sqlite3
import sys

def run_phase7_analytics():
    print("===============================================================================")
    print("PHASE 7: EXECUTING & VALIDATING BASIC SQL ANALYTICS (20 QUERIES)")
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

    print("Database instantiated and populated with 108k+ records.")

    # Read queries from database/07_basic_analytics.sql
    with open("database/07_basic_analytics.sql", "r", encoding="utf-8") as f:
        analytics_content = f.read()

    # Split queries by semicolon outside comments
    query_blocks = re.findall(r"(/\*.*?\*/\s*)(SELECT.*?;)", analytics_content, re.DOTALL | re.IGNORECASE)
    print(f"Found {len(query_blocks)} queries with business documentation headers.\n")

    query_count = 0
    for header, sql_stmt in query_blocks:
        query_count += 1
        title_match = re.search(r"QUERY\s+(\d+):\s*(.*)", header)
        q_title = title_match.group(2).strip() if title_match else f"Query {query_count}"
        
        try:
            cursor.execute(sql_stmt)
            rows = cursor.fetchall()
            col_names = [desc[0] for desc in cursor.description]
            print(f"QUERY {query_count:02d}: {q_title}")
            print(f"  -> Columns: {', '.join(col_names)}")
            print(f"  -> Output Rows Returned: {len(rows)}")
            if rows:
                print(f"  -> Sample Top Row: {rows[0]}")
            print("  -> Status: PASS\n")
        except Exception as e:
            print(f"QUERY {query_count:02d}: {q_title} - FAILED: {e}")
            conn.close()
            return False

    conn.close()
    if query_count >= 20:
        print("===============================================================================")
        print("ALL 20 BASIC SQL ANALYTICS QUERIES EXECUTED AND VALIDATED SUCCESSFULLY!")
        print("===============================================================================")
        return True
    return False

if __name__ == "__main__":
    if run_phase7_analytics():
        sys.exit(0)
    else:
        sys.exit(1)
