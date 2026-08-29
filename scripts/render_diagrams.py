import os
import shutil
from PIL import Image, ImageDraw, ImageFont

def create_er_diagram():
    width, height = 2400, 1600
    img = Image.new("RGB", (width, height), color="#0F172A")
    draw = ImageDraw.Draw(img)
    
    # Try default font
    try:
        title_font = ImageFont.truetype("arial.ttf", 36)
        header_font = ImageFont.truetype("arialbd.ttf", 20)
        table_header_font = ImageFont.truetype("arialbd.ttf", 16)
        text_font = ImageFont.truetype("arial.ttf", 13)
        small_font = ImageFont.truetype("arial.ttf", 11)
    except:
        title_font = ImageFont.load_default()
        header_font = ImageFont.load_default()
        table_header_font = ImageFont.load_default()
        text_font = ImageFont.load_default()
        small_font = ImageFont.load_default()

    # Title Banner
    draw.rectangle([(0, 0), (width, 80)], fill="#1E293B")
    draw.text((40, 22), "TEXTILE PRODUCTION WASTE, DEFECT & MACHINE INTELLIGENCE SYSTEM", fill="#38BDF8", font=title_font)
    draw.text((1800, 28), "RELATIONAL ER SCHEMA (3NF)", fill="#94A3B8", font=header_font)

    # Define table blocks (x, y, w, h, title, [columns], color_theme)
    tables = [
        # Master Data (Blue-ish)
        (50, 110, 240, 170, "locations", ["PK location_id", "   location_name", "   city, state", "   country", "   created_at"], "#0284C7"),
        (330, 110, 250, 200, "plants", ["PK plant_id", "UK plant_code", "   plant_name", "FK location_id", "   capacity_per_day", "   operational_status"], "#0284C7"),
        (620, 110, 260, 200, "production_lines", ["PK line_id", "UK line_code", "   line_name", "FK plant_id", "   line_type", "   daily_target_meters", "   is_active"], "#0284C7"),
        (920, 110, 260, 200, "machine_types", ["PK machine_type_id", "UK type_code", "   type_name", "   process_stage", "   standard_speed_rpm", "   power_kwh", "   lifespan_years"], "#0284C7"),
        (1220, 110, 270, 230, "machines", ["PK machine_id", "UK machine_code", "   machine_name", "FK machine_type_id", "FK line_id", "UK serial_number", "   installation_date", "   hourly_overhead_cost"], "#0284C7"),
        (1530, 110, 250, 220, "employees", ["PK employee_id", "UK employee_code", "   first_name, last_name", "FK plant_id", "   role", "   skill_level", "   hourly_labor_rate", "   is_active"], "#0284C7"),
        (1820, 110, 240, 180, "shifts", ["PK shift_id", "UK shift_code", "   shift_name", "   start_time, end_time", "   duration_hours", "   is_night_shift"], "#0284C7"),
        (2100, 110, 250, 220, "defect_types", ["PK defect_type_id", "UK defect_code", "   defect_name", "   category", "   severity_level", "   standard_points", "   scrapping_cost"], "#0284C7"),
        
        # Sourcing & Materials (Teal/Emerald)
        (50, 390, 240, 210, "suppliers", ["PK supplier_id", "UK supplier_code", "   supplier_name", "FK location_id", "   credit_rating", "   payment_terms", "   is_preferred"], "#0D9488"),
        (330, 390, 250, 210, "materials", ["PK material_id", "UK material_code", "   material_name", "   category", "   unit_of_measure", "   standard_unit_cost", "   density_count"], "#0D9488"),
        (620, 390, 260, 220, "purchase_orders", ["PK po_id", "UK po_number", "FK supplier_id", "FK plant_id", "   order_date", "   expected_delivery", "   total_po_amount"], "#0D9488"),
        (920, 390, 260, 220, "purchase_order_items", ["PK po_item_id", "FK po_id", "FK material_id", "   ordered_quantity", "   received_quantity", "   unit_price", "   line_total"], "#0D9488"),
        (1220, 390, 270, 230, "material_batches", ["PK batch_id", "UK batch_code", "FK po_item_id", "FK material_id", "FK supplier_id", "   received_date", "   initial_quantity", "   quality_status"], "#0D9488"),
        
        # Commercial & Production Planning (Amber/Orange)
        (1530, 390, 250, 200, "customers", ["PK customer_id", "UK customer_code", "   customer_name", "FK location_id", "   segment", "   credit_limit", "   discount_pct"], "#D97706"),
        (1820, 390, 240, 220, "products", ["PK product_id", "UK product_code", "   product_name", "   fabric_type", "   weave_type", "   standard_cost", "   selling_price"], "#D97706"),
        (2100, 390, 250, 220, "customer_orders", ["PK order_id", "UK order_number", "FK customer_id", "FK product_id", "   order_date", "   promised_delivery", "   ordered_meters"], "#D97706"),
        (1820, 680, 250, 240, "production_orders", ["PK prod_order_id", "UK prod_order_number", "FK customer_order_id", "FK product_id", "FK plant_id", "   target_start_date", "   planned_quantity", "   order_status"], "#D97706"),
        
        # Production Execution Core (Purple/Indigo)
        (1150, 710, 320, 270, "production_runs", ["PK run_id", "UK run_code", "FK prod_order_id", "FK machine_id", "FK line_id", "FK product_id", "FK operator_id", "FK shift_id", "   run_date, start_time, end_time", "   planned_meters, actual_meters", "   run_status"], "#7C3AED"),
        
        # Operations, Quality & Reliability (Rose/Red/Slate)
        (150, 1070, 270, 210, "material_consumption", ["PK consumption_id", "FK run_id", "FK batch_id", "FK material_id", "   consumed_quantity", "   unit_of_measure", "   consumed_at"], "#6366F1"),
        (460, 1070, 280, 220, "production_waste", ["PK waste_id", "FK run_id", "FK material_id", "   waste_type", "   waste_quantity", "   total_waste_cost", "   salvage_value", "   net_financial_loss"], "#E11D48"),
        (780, 1070, 280, 240, "machine_downtime", ["PK downtime_id", "FK machine_id", "FK run_id", "FK shift_id", "   start_time, end_time", "   duration_hours", "   downtime_category", "   root_cause_category", "   financial_downtime_cost"], "#DC2626"),
        (1100, 1070, 280, 240, "machine_maintenance", ["PK maintenance_id", "UK maintenance_code", "FK machine_id", "FK technician_id", "   maintenance_type", "   scheduled_date", "   technician_hours", "   total_maintenance_cost", "   maintenance_status"], "#DC2626"),
        (1420, 1070, 270, 220, "fabric_rolls", ["PK roll_id", "UK roll_barcode", "FK run_id", "FK product_id", "   roll_length_meters", "   roll_weight_kg", "   roll_grade", "   roll_status"], "#2563EB"),
        (1730, 1070, 290, 240, "quality_inspections", ["PK inspection_id", "UK inspection_code", "FK roll_id", "FK inspector_id", "   inspection_date", "   inspected_length, width", "   total_defect_points", "   quality_score", "   inspection_result"], "#059669"),
        (2060, 1070, 280, 240, "defect_records", ["PK defect_id", "FK inspection_id", "FK roll_id", "FK defect_type_id", "   position_meters", "   defect_length_meters", "   defect_points", "   detected_at", "   severity"], "#EA580C"),
        (1730, 1370, 310, 200, "rework_records", ["PK rework_id", "FK roll_id", "FK defect_id", "FK operator_id", "   rework_date, rework_type", "   technician_hours", "   additional_chem_cost", "   pre/post_rework_grade", "   rework_result"], "#D97706")
    ]

    # Draw Table Cards
    for x, y, w, h, name, cols, col_bg in tables:
        # Table Header Box
        draw.rounded_rectangle([(x, y), (x + w, y + h)], radius=6, fill="#1E293B", outline="#334155", width=2)
        draw.rounded_rectangle([(x, y), (x + w, y + 32)], radius=6, fill=col_bg)
        draw.text((x + 12, y + 7), name, fill="#FFFFFF", font=table_header_font)
        
        # Columns List
        cy = y + 42
        for col in cols:
            prefix = col[:2]
            if prefix == "PK":
                cfill = "#F59E0B"
            elif prefix == "FK":
                cfill = "#38BDF8"
            elif prefix == "UK":
                cfill = "#A78BFA"
            else:
                cfill = "#E2E8F0"
            draw.text((x + 10, cy), col, fill=cfill, font=text_font)
            cy += 20

    # Save to docs and screenshots
    os.makedirs("docs", exist_ok=True)
    os.makedirs("screenshots", exist_ok=True)
    img.save("docs/er-diagram.png", "PNG")
    img.save("screenshots/er-diagram.png", "PNG")
    img.save("screenshots/database-schema.png", "PNG")
    print("ER Diagram rendered successfully.")

def create_architecture_diagram():
    width, height = 1800, 1000
    img = Image.new("RGB", (width, height), color="#0B1329")
    draw = ImageDraw.Draw(img)
    
    try:
        title_font = ImageFont.truetype("arial.ttf", 32)
        header_font = ImageFont.truetype("arialbd.ttf", 22)
        box_title_font = ImageFont.truetype("arialbd.ttf", 18)
        text_font = ImageFont.truetype("arial.ttf", 14)
    except:
        title_font = ImageFont.load_default()
        header_font = ImageFont.load_default()
        box_title_font = ImageFont.load_default()
        text_font = ImageFont.load_default()

    # Title
    draw.rectangle([(0, 0), (width, 80)], fill="#111C44")
    draw.text((50, 24), "SYSTEM ARCHITECTURE & OPERATIONAL INTELLIGENCE FLOW", fill="#00F2FE", font=title_font)
    draw.text((1400, 30), "STRICT NO-ETL TOPOLOGY", fill="#4FACFE", font=header_font)

    # 4 Architecture Columns / Layers
    layers = [
        (60, 120, 380, 800, "1. RELATIONAL CORE (PostgreSQL 14+)", "#0F2B5C", [
            ("Master Entities (12 Tables)", "Plants, Lines, Machine Types, Machines, Employees, Shifts, Products, Materials, Suppliers, Customers, Defects"),
            ("Transactional Entities (14 Tables)", "POs, Material Batches, Production Orders, Runs, Material Consumption, Rolls, Inspections, Downtime, Maintenance, Waste"),
            ("Data Integrity & Constraints", "3NF Normalization, PK/FK referential integrity, NOT NULL, CHECK bounds, Domain rules, Cascade Restrict")
        ]),
        (480, 120, 380, 800, "2. PROCEDURAL & TRIGGER LAYER", "#133E68", [
            ("PL/pgSQL Business Functions", "calculate_production_efficiency(), calculate_waste_percentage(), calculate_defect_rate(), calculate_machine_risk_score()"),
            ("Automated Stored Procedures", "complete_production_run(), record_production_waste(), complete_machine_maintenance()"),
            ("Data Quality & Integrity Triggers", "trg_prevent_invalid_production(), trg_flag_abnormal_waste(), trg_audit_machine_status()")
        ]),
        (900, 120, 380, 800, "3. BUSINESS VIEWS & INTELLIGENCE", "#1B4F72", [
            ("Production & Loss Views", "vw_production_efficiency, vw_quality_performance, vw_production_loss (Waste + Defect + Rework + Downtime Loss)"),
            ("Machine Intelligence Engine", "vw_machine_risk (Composite heuristic: Downtime 30%, Failure 25%, Defect 20%, Cost 15%, Age 10%)"),
            ("Supplier Quality Engine", "vw_supplier_performance (SQI Index & Rejection/Defect/Waste tracking)"),
            ("Executive Operational Alerts", "vw_business_alerts (High Waste, High Defect, High Downtime, Critical Machine alerts)")
        ]),
        (1320, 120, 420, 800, "4. POWER BI EXECUTIVE ANALYTICS", "#0E6251", [
            ("Page 1: Executive Overview", "Consolidated KPIs (Volume, Efficiency, Defect %, Waste %, Loss $, FPY), Enterprise Plant benchmarking"),
            ("Page 2: Production & Waste", "Planned vs Actual, Waste by material & machine, scrap cost decomposition, abnormal runs"),
            ("Page 3: Quality Intelligence", "4-Point defect Pareto, Defect severity distribution, FPY trends, Supplier quality correlation"),
            ("Page 4: Machine Intelligence", "MTBF, MTTR, Machine Risk Score heatmaps, Downtime root cause, Maintenance spend")
        ])
    ]

    for x, y, w, h, title, header_col, items in layers:
        draw.rounded_rectangle([(x, y), (x + w, y + h)], radius=10, fill="#131B34", outline="#203A63", width=2)
        draw.rounded_rectangle([(x, y), (x + w, y + 45)], radius=10, fill=header_col)
        draw.text((x + 15, y + 12), title, fill="#38BDF8", font=box_title_font)
        
        iy = y + 65
        for item_title, item_desc in items:
            draw.rounded_rectangle([(x + 15, iy), (x + w - 15, iy + 210)], radius=6, fill="#1A2744", outline="#2A3B5C")
            draw.text((x + 25, iy + 12), item_title, fill="#FBBF24", font=box_title_font)
            
            # Simple text wrap
            words = item_desc.split(" ")
            line = ""
            ty = iy + 45
            for word in words:
                test_line = line + word + " "
                if len(test_line) > 36:
                    draw.text((x + 25, ty), line, fill="#CBD5E1", font=text_font)
                    line = word + " "
                    ty += 22
                else:
                    line = test_line
            if line:
                draw.text((x + 25, ty), line, fill="#CBD5E1", font=text_font)
            
            iy += 235

    img.save("docs/architecture.png", "PNG")
    print("Architecture diagram rendered successfully.")

if __name__ == "__main__":
    create_er_diagram()
    create_architecture_diagram()
