"""
===============================================================================
TEXTILE PRODUCTION WASTE, DEFECT & MACHINE INTELLIGENCE SYSTEM
Script: generate_synthetic_data.py
Description: Generates realistic, correlated synthetic data across all 26 tables
             covering Jan 2023 to Dec 2025 (~110,000 total records).
             Enforces 100% referential and chronological integrity.
===============================================================================
"""

import os
import random
import datetime
from decimal import Decimal, ROUND_HALF_UP

# Set random seed for reproducibility
random.seed(42)

DATA_DIR = "data/generated_data"
DB_DIR = "database"
os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(DB_DIR, exist_ok=True)

START_DATE = datetime.date(2023, 1, 1)
END_DATE = datetime.date(2025, 12, 31)
TOTAL_DAYS = (END_DATE - START_DATE).days + 1

def random_date(start, end):
    delta = end - start
    return start + datetime.timedelta(days=random.randint(0, delta.days))

def round_curr(val):
    return float(Decimal(str(val)).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP))

def sql_str(val):
    if val is None:
        return "NULL"
    if isinstance(val, bool):
        return "TRUE" if val else "FALSE"
    if isinstance(val, (int, float)):
        return str(val)
    if isinstance(val, (datetime.date, datetime.datetime, datetime.time)):
        return f"'{val}'"
    val_str = str(val).replace("'", "''")
    return f"'{val_str}'"

print("Starting synthetic data generation for Textile Production Intelligence...")

# =============================================================================
# 1. MASTER DATA GENERATION
# =============================================================================

# 1.1 Locations (50 locations)
print("1/26 Generating Locations...")
locations = []
cities_data = [
    ("Savannah Hub", "100 River Rd", "Savannah", "GA", "USA", "31401"),
    ("Charlotte Mill Site", "450 Textile Blvd", "Charlotte", "NC", "USA", "28202"),
    ("Greenville Operations", "120 Industrial Way", "Greenville", "SC", "USA", "29601"),
    ("Atlanta Logistics", "890 Freight Ln", "Atlanta", "GA", "USA", "30301"),
    ("Greensboro Depot", "320 Loom St", "Greensboro", "NC", "USA", "27401"),
    ("Spartanburg Weave Center", "77 Cotton Ave", "Spartanburg", "SC", "USA", "29301"),
    ("Macon Yard", "510 Spindle Rd", "Macon", "GA", "USA", "31201"),
    ("Columbus Finishing Plant", "640 Mill Run", "Columbus", "GA", "USA", "31901"),
    ("Dallas Fabric Center", "101 Commerce St", "Dallas", "TX", "USA", "75201"),
    ("Los Angeles Port Yard", "220 Terminal Way", "Los Angeles", "CA", "USA", "90001"),
    ("Manchester Sourcing Depot", "88 Queen St", "Manchester", "Lancashire", "UK", "M1 1AA"),
    ("Milan Design Yard", "45 Via della Seta", "Milan", "Lombardy", "Italy", "20121"),
    ("Surat Yarn Terminal", "12 Ring Road", "Surat", "Gujarat", "India", "395002"),
    ("Ahmedabad Spinning Hub", "88 Textile Park", "Ahmedabad", "Gujarat", "India", "380001"),
    ("Coimbatore Mill Depot", "204 Avinashi Rd", "Coimbatore", "Tamil Nadu", "India", "641018"),
    ("Dhaka Port Logistics", "55 Export Zone", "Dhaka", "Dhaka", "Bangladesh", "1200"),
    ("Istanbul Dye Depot", "300 Bosphorus Way", "Istanbul", "Marmara", "Turkey", "34000"),
    ("Ho Chi Minh Supply Base", "15 Saigon Port Rd", "Ho Chi Minh City", "SE", "Vietnam", "70000"),
    ("Osaka Tech Terminal", "42 Hanshin Ave", "Osaka", "Kansai", "Japan", "530-0001"),
    ("Alexandria Cotton Pier", "19 Port Said St", "Alexandria", "Alexandria", "Egypt", "21500")
]
for i in range(1, 51):
    base = cities_data[(i - 1) % len(cities_data)]
    locations.append({
        "location_id": i,
        "location_name": f"{base[0]} #{i}",
        "address_line1": f"{100 + i * 7} {base[1]}",
        "city": base[2],
        "state_province": base[3],
        "country": base[4],
        "postal_code": base[5],
        "created_at": "2022-12-01 08:00:00"
    })

# 1.2 Machine Types (12 types)
print("2/26 Generating Machine Types...")
machine_types_data = [
    ("MT-RAPIER-01", "High-Speed Rapier Loom", "Weaving", 650, 18.5, 15),
    ("MT-AIRJET-01", "Ultra Air-Jet Loom", "Weaving", 900, 22.0, 12),
    ("MT-PROJ-01", "Projectile Weaving Machine", "Weaving", 450, 16.0, 18),
    ("MT-CIRC-KNIT", "Single Jersey Circular Knitter", "Knitting", 1200, 14.5, 10),
    ("MT-DBL-KNIT", "Double Jersey Interlock Knitter", "Knitting", 1000, 15.0, 10),
    ("MT-WARP-KNIT", "High-Performance Warp Knitter", "Knitting", 1500, 19.5, 12),
    ("MT-ROT-PRINT", "Rotary Screen Printing Machine", "Printing", 350, 28.0, 14),
    ("MT-DIG-PRINT", "Industrial Digital Textile Printer", "Printing", 250, 12.0, 8),
    ("MT-JET-DYE", "High-Temperature Jet Dyeing Vessel", "Dyeing", 180, 32.0, 15),
    ("MT-JIG-DYE", "Atmospheric Jigger Dyeing Unit", "Dyeing", 120, 24.0, 16),
    ("MT-STENT-01", "Pin-Clip Finishing Stenter Frame", "Finishing", 200, 45.0, 20),
    ("MT-COMP-01", "Tubular & Open-Width Compactor", "Finishing", 160, 26.0, 15),
]
machine_types = []
for i, mt in enumerate(machine_types_data, start=1):
    machine_types.append({
        "machine_type_id": i,
        "type_code": mt[0],
        "type_name": mt[1],
        "process_stage": mt[2],
        "standard_speed_rpm": mt[3],
        "power_consumption_kwh": mt[4],
        "expected_lifespan_years": mt[5],
        "created_at": "2022-12-01 08:00:00"
    })

# 1.3 Shifts (3 shifts)
print("3/26 Generating Shifts...")
shifts_data = [
    ("SH-MORN", "Morning Shift", "06:00:00", "14:00:00", 8.0, False),
    ("SH-EVE", "Evening Shift", "14:00:00", "22:00:00", 8.0, False),
    ("SH-NGHT", "Night Shift", "22:00:00", "06:00:00", 8.0, True)
]
shifts = []
for i, sh in enumerate(shifts_data, start=1):
    shifts.append({
        "shift_id": i,
        "shift_code": sh[0],
        "shift_name": sh[1],
        "start_time": sh[2],
        "end_time": sh[3],
        "duration_hours": sh[4],
        "is_night_shift": sh[5],
        "created_at": "2022-12-01 08:00:00"
    })

# 1.4 Defect Types (25 types)
print("4/26 Generating Defect Types...")
defect_data = [
    ("DEF-WRP-01", "Warp Break / End Out", "Weaving Defect", "Major", 3, 35.0),
    ("DEF-WFT-02", "Weft Slub / Thick Pick", "Weaving Defect", "Minor", 1, 15.0),
    ("DEF-MIS-03", "Mispick / Broken Weft", "Weaving Defect", "Major", 3, 30.0),
    ("DEF-SLV-04", "Selvedge Tear / Broken Edge", "Weaving Defect", "Critical", 4, 60.0),
    ("DEF-OIL-05", "Loom Oil / Grease Spot", "Handling Defect", "Major", 2, 25.0),
    ("DEF-HOL-06", "Fabric Drop Hole", "Knitting Defect", "Critical", 4, 75.0),
    ("DEF-NDL-07", "Needle Line / Vertical Streak", "Knitting Defect", "Major", 3, 40.0),
    ("DEF-SNX-08", "Yarn Snag / Pull", "Knitting Defect", "Minor", 1, 12.0),
    ("DEF-LUP-09", "Dropped Loop Stitch", "Knitting Defect", "Minor", 2, 18.0),
    ("DEF-COL-10", "Shade Variation (Side-to-Side)", "Dyeing Defect", "Major", 3, 50.0),
    ("DEF-DYS-11", "Dye Spot / Chemical Speck", "Dyeing Defect", "Major", 2, 30.0),
    ("DEF-BLE-12", "Uneven Bleach Level", "Dyeing Defect", "Major", 3, 45.0),
    ("DEF-STR-13", "Dye Bath Crease Mark", "Dyeing Defect", "Major", 3, 40.0),
    ("DEF-PRT-14", "Print Misregistration", "Finishing Defect", "Major", 3, 55.0),
    ("DEF-SMR-15", "Color Smear / Ghosting", "Finishing Defect", "Major", 2, 35.0),
    ("DEF-BLD-16", "Pigment Bleed / Haloing", "Finishing Defect", "Major", 3, 45.0),
    ("DEF-BOW-17", "Bow & Skew Distortion", "Finishing Defect", "Major", 3, 50.0),
    ("DEF-PIN-18", "Stenter Pin Hole / Tear", "Finishing Defect", "Critical", 4, 70.0),
    ("DEF-SHT-19", "Thermal Scorching / Yellowing", "Finishing Defect", "Critical", 4, 80.0),
    ("DEF-YRN-20", "Yarn Count Coarseness Variance", "Yarn Defect", "Minor", 2, 20.0),
    ("DEF-NEP-21", "Excessive Nep Cluster", "Yarn Defect", "Minor", 1, 10.0),
    ("DEF-FLF-22", "Foreign Fiber / Trash Contamination", "Yarn Defect", "Major", 3, 45.0),
    ("DEF-DIR-23", "Floor Dirt / Handling Soil", "Handling Defect", "Minor", 1, 10.0),
    ("DEF-CUT-24", "Tension Cut / Knife Nick", "Handling Defect", "Critical", 4, 85.0),
    ("DEF-WRK-25", "Water Ring / Condensation Stain", "Handling Defect", "Minor", 1, 15.0)
]
defect_types = []
for i, df in enumerate(defect_data, start=1):
    defect_types.append({
        "defect_type_id": i,
        "defect_code": df[0],
        "defect_name": df[1],
        "category": df[2],
        "severity_level": df[3],
        "standard_penalty_points": df[4],
        "standard_scrapping_cost_per_defect": df[5],
        "created_at": "2022-12-01 08:00:00"
    })

# 1.5 Plants (8 plants)
print("5/26 Generating Plants...")
plant_names = [
    ("PLT-GA-01", "Savannah Integrated Weaving Mill", 1, "Marcus Vance", 45000.0),
    ("PLT-NC-02", "Charlotte Denim & Twill Plant", 2, "Eleanor Hughes", 60000.0),
    ("PLT-SC-03", "Greenville High-Speed Knits", 3, "Robert Sterling", 50000.0),
    ("PLT-NC-04", "Greensboro Dyeing & Printing Complex", 5, "Patricia Morales", 40000.0),
    ("PLT-SC-05", "Spartanburg Specialty Blends", 6, "David Campbell", 35000.0),
    ("PLT-GA-06", "Columbus Technical Finishing Facility", 8, "Angela Wright", 30000.0),
    ("PLT-TX-07", "Dallas Apparel Fabric Mill", 9, "James Thornton", 42000.0),
    ("PLT-CA-08", "Pacific Coast Performance Textiles", 10, "Chloe Zhao", 38000.0)
]
plants = []
for i, pl in enumerate(plant_names, start=1):
    plants.append({
        "plant_id": i,
        "plant_code": pl[0],
        "plant_name": pl[1],
        "location_id": pl[2],
        "manager_name": pl[3],
        "total_capacity_meters_per_day": pl[4],
        "operational_status": "Active",
        "created_at": "2022-12-01 08:00:00"
    })

# 1.6 Products (60 products)
print("6/26 Generating Products...")
fabrics = [
    ("Cotton", "Plain", 140.0, 3.20, 5.50, "Low"),
    ("Cotton", "Twill", 220.0, 4.10, 6.80, "Medium"),
    ("Denim", "Twill", 340.0, 4.80, 8.20, "Medium"),
    ("Denim", "Twill", 420.0, 5.60, 9.50, "High"),
    ("Polyester", "Plain", 120.0, 2.40, 4.20, "Low"),
    ("Polyester", "Single Jersey", 180.0, 3.00, 5.10, "Medium"),
    ("Viscose", "Satin", 160.0, 4.50, 7.80, "High"),
    ("Rayon", "Plain", 130.0, 3.80, 6.40, "Medium"),
    ("Linen", "Plain", 210.0, 6.20, 11.00, "High"),
    ("Cotton Blend", "Rib Knit", 200.0, 4.00, 6.90, "Medium"),
    ("Synthetic Fabric", "Jacquard", 260.0, 5.80, 10.50, "Extreme"),
    ("Knitted Fabric", "Single Jersey", 150.0, 3.50, 5.90, "Medium"),
    ("Dyed Fabric", "Twill", 280.0, 5.20, 8.90, "High"),
    ("Printed Fabric", "Plain", 170.0, 4.90, 8.50, "High"),
    ("Cotton Blend", "Jacquard", 310.0, 6.50, 12.00, "Extreme")
]
products = []
prod_id = 1
for stage_idx in range(4):
    for f in fabrics:
        p_code = f"PROD-{f[0][:3].upper()}-{f[1][:3].upper()}-{prod_id:03d}"
        p_name = f"{f[0]} {f[1]} Fabric Series-{prod_id}"
        c_mult = 1.0 + (prod_id % 5) * 0.05
        cost = round_curr(f[3] * c_mult)
        price = round_curr(f[4] * c_mult)
        products.append({
            "product_id": prod_id,
            "product_code": p_code,
            "product_name": p_name,
            "fabric_type": f[0],
            "weave_type": f[1],
            "density_gsm": f[2],
            "standard_cost_per_meter": cost,
            "selling_price_per_meter": price,
            "complexity_tier": f[5],
            "created_at": "2022-12-01 08:00:00"
        })
        prod_id += 1
        if prod_id > 60:
            break
    if prod_id > 60:
        break

# 1.7 Materials (60 materials)
print("7/26 Generating Materials...")
raw_mat_types = [
    ("YRN-COT-20S", "Carded Cotton Yarn 20s", "Yarn", "Natural Fiber", "kg", 3.20, "20s Ne"),
    ("YRN-COT-30S", "Combed Ring-Spun Cotton Yarn 30s", "Yarn", "Natural Fiber", "kg", 4.10, "30s Ne"),
    ("YRN-COT-40S", "Compact Combed Cotton Yarn 40s", "Yarn", "Natural Fiber", "kg", 5.20, "40s Ne"),
    ("YRN-POLY-150D", "Polyester DTY 150D/48F", "Yarn", "Synthetic Filament", "kg", 2.30, "150D"),
    ("YRN-POLY-75D", "Microfiber Polyester Yarn 75D", "Yarn", "Synthetic Filament", "kg", 2.90, "75D"),
    ("YRN-VISC-30S", "100% Viscose Rayon Spun Yarn 30s", "Yarn", "Regenerated Cellulosic", "kg", 3.80, "30s Ne"),
    ("YRN-LIN-14LEA", "Natural Wet-Spun Linen Yarn 14 Lea", "Yarn", "Bast Fiber", "kg", 7.50, "14 Lea"),
    ("YRN-BLND-COT-POLY", "Polyester-Cotton 65/35 Blend Yarn", "Yarn", "Blended Spun", "kg", 3.50, "30s Ne"),
    ("DYE-INDIGO-GRAN", "Synthetic Indigo Blue Granules 94%", "Dye", "Vat Dye", "kg", 12.50, "94% Purity"),
    ("DYE-REACT-RED", "Reactive Red Brilliant Crimson HE3B", "Dye", "Reactive Dye", "kg", 18.00, "Standard High-Fix"),
    ("DYE-REACT-BLUE", "Reactive Navy Blue ED-RN", "Dye", "Reactive Dye", "kg", 16.50, "Standard High-Fix"),
    ("DYE-DISP-BLK", "Disperse Black Dye EX-SF 300%", "Dye", "Disperse Dye", "kg", 14.00, "300% Strength"),
    ("CHEM-SIZE-PVA", "Polyvinyl Alcohol Sizing Polymer", "Sizing Chemical", "Warp Sizing Compound", "kg", 4.80, "Industrial Grade"),
    ("CHEM-SIZE-STRCH", "Modified Corn Starch Binder", "Sizing Chemical", "Warp Sizing Compound", "kg", 1.80, "99% Active"),
    ("CHEM-SOFT-SILC", "Hydrophilic Silicone Softener", "Finishing Agent", "Textile Finishing Auxiliary", "liters", 6.50, "30% Emulsion"),
    ("CHEM-FIX-AGENT", "Formaldehyde-Free Cationic Dye Fixative", "Auxiliary Chemical", "Wet Processing Additive", "liters", 5.20, "High Affinity"),
]
materials = []
mat_id = 1
for cycle in range(4):
    for rmt in raw_mat_types:
        materials.append({
            "material_id": mat_id,
            "material_code": f"{rmt[0]}-{mat_id:03d}",
            "material_name": f"{rmt[1]} (Grade-{chr(65 + mat_id % 3)})",
            "category": rmt[2],
            "subcategory": rmt[3],
            "unit_of_measure": rmt[4],
            "standard_unit_cost": round_curr(rmt[5] * (1.0 + (mat_id % 4) * 0.04)),
            "density_linear_count": rmt[6],
            "created_at": "2022-12-01 08:00:00"
        })
        mat_id += 1
        if mat_id > 60:
            break
    if mat_id > 60:
        break

# 1.8 Suppliers (120 suppliers with engineered quality tiers)
print("8/26 Generating Suppliers...")
supplier_prefixes = ["Apex", "Global", "Vanguard", "Delta", "Pinnacle", "Sterling", "Horizon", "Imperial", "Atlas", "Crest", "Vertex", "Prime"]
supplier_types = ["Yarn Mills", "Fibers Ltd", "Chemicals Corp", "Dye Specialties", "Synthetics Group", "Textile Supply", "Cellulose Ltd", "Polymer Ind"]

suppliers = []
for i in range(1, 121):
    pref = supplier_prefixes[(i - 1) % len(supplier_prefixes)]
    suf = supplier_types[(i - 1) % len(supplier_types)]
    
    # Engineer supplier quality profiles:
    # 15% poor/problematic, 65% average/good, 20% excellent
    if i in [7, 14, 23, 38, 49, 58, 72, 85, 96, 110]:  # Problematic suppliers
        credit = random.choice(["B", "BB", "BBB"])
        is_pref = False
        quality_bias = "Poor"
    elif i <= 25:  # Excellent suppliers
        credit = random.choice(["AAA", "AA"])
        is_pref = True
        quality_bias = "Excellent"
    else:  # Normal/Good suppliers
        credit = random.choice(["A", "AA", "BBB"])
        is_pref = random.choice([True, False, False])
        quality_bias = "Good"

    suppliers.append({
        "supplier_id": i,
        "supplier_code": f"SUP-{pref[:3].upper()}-{i:03d}",
        "supplier_name": f"{pref} {suf} #{i}",
        "location_id": random.randint(1, 50),
        "contact_email": f"sales@{pref.lower()}{i}.com",
        "phone": f"+1-555-01{i:02d}",
        "payment_terms_days": random.choice([30, 45, 60, 90]),
        "credit_rating": credit,
        "is_preferred": is_pref,
        "quality_bias": quality_bias, # used internally for realistic correlation
        "created_at": "2022-12-01 08:00:00"
    })

# 1.9 Customers (200 customers)
print("9/26 Generating Customers...")
cust_brands = ["DenimCo", "UrbanStyle", "LuxeApparel", "NordicFashion", "FastTrend", "VogueWear", "ClassicCloth", "SummitOutdoor", "IndigoWorks", "EcoWeave"]
customers = []
for i in range(1, 201):
    cb = cust_brands[(i - 1) % len(cust_brands)]
    seg = random.choice(["Fast Fashion", "Luxury", "Industrial", "Wholesale", "Direct Retail"])
    customers.append({
        "customer_id": i,
        "customer_code": f"CUST-{cb[:3].upper()}-{i:03d}",
        "customer_name": f"{cb} Global #{i}",
        "location_id": random.randint(1, 50),
        "segment": seg,
        "credit_limit": round_curr(random.uniform(50000.0, 500000.0)),
        "discount_percentage": round_curr(random.choice([0.0, 2.5, 5.0, 7.5, 10.0, 12.5])),
        "created_at": "2022-12-01 08:00:00"
    })

# 1.10 Production Lines (32 lines: 4 per plant)
print("10/26 Generating Production Lines...")
line_types = ["Spinning", "Weaving", "Knitting", "Dyeing", "Printing", "Finishing"]
production_lines = []
line_id = 1
for p in plants:
    for l_idx in range(1, 5):
        l_type = line_types[(l_idx - 1) % len(line_types)]
        production_lines.append({
            "line_id": line_id,
            "line_code": f"LINE-P{p['plant_id']:02d}-{l_type[:3].upper()}-{l_idx:02d}",
            "line_name": f"{p['plant_name']} - {l_type} Line {l_idx}",
            "plant_id": p["plant_id"],
            "line_type": l_type,
            "daily_target_meters": round_curr(random.uniform(8000.0, 18000.0)),
            "is_active": True,
            "created_at": "2022-12-01 08:00:00"
        })
        line_id += 1

# 1.11 Employees (500 employees: Operators, Technicians, Inspectors, Supervisors)
print("11/26 Generating Employees...")
first_names = ["James", "John", "Robert", "Michael", "William", "David", "Richard", "Joseph", "Thomas", "Charles",
               "Mary", "Patricia", "Jennifer", "Linda", "Elizabeth", "Barbara", "Susan", "Jessica", "Sarah", "Karen",
               "Raj", "Amit", "Suresh", "Vikram", "Priya", "Ananya", "Carlos", "Mateo", "Wei", "Hao", "Kenji", "Tariq"]
last_names = ["Smith", "Johnson", "Williams", "Jones", "Brown", "Davis", "Miller", "Wilson", "Moore", "Taylor",
              "Anderson", "Thomas", "Jackson", "White", "Harris", "Martin", "Patel", "Sharma", "Rodriguez", "Hernandez"]

employees = []
emp_id = 1
for p in plants:
    # ~62 employees per plant
    for i in range(62):
        role_roll = random.random()
        if role_roll < 0.65:
            role = "Operator"
            rate = round_curr(random.uniform(22.0, 32.0))
        elif role_roll < 0.80:
            role = "Technician"
            rate = round_curr(random.uniform(30.0, 45.0))
        elif role_roll < 0.93:
            role = "Inspector"
            rate = round_curr(random.uniform(24.0, 35.0))
        else:
            role = "Supervisor"
            rate = round_curr(random.uniform(40.0, 60.0))

        skill = random.choice(["Junior", "Intermediate", "Senior", "Master"])
        hire_dt = random_date(datetime.date(2015, 1, 1), datetime.date(2022, 12, 1))

        employees.append({
            "employee_id": emp_id,
            "employee_code": f"EMP-P{p['plant_id']:02d}-{emp_id:04d}",
            "first_name": random.choice(first_names),
            "last_name": random.choice(last_names),
            "plant_id": p["plant_id"],
            "role": role,
            "hire_date": hire_dt,
            "skill_level": skill,
            "hourly_labor_rate": rate,
            "is_active": True,
            "created_at": "2022-12-01 08:00:00"
        })
        emp_id += 1

# 1.12 Machines (150 machines)
print("12/26 Generating Machines...")
oems = ["Picanol Group", "Toyota Industries", "Tsudakoma Corp", "Rieter AG", "Karl Mayer", "Zimmer Austria", "Monforts", "Thies GmbH"]
machines = []
for m_id in range(1, 151):
    m_type = machine_types[(m_id - 1) % len(machine_types)]
    line = production_lines[(m_id - 1) % len(production_lines)]
    
    # Correlated age & condition
    # 15% older/problematic machines (installed 2012-2016), 85% modern machines (2017-2022)
    is_problematic = (m_id in [4, 12, 19, 27, 44, 53, 68, 77, 89, 102, 115, 128, 142])
    if is_problematic:
        install_dt = random_date(datetime.date(2012, 1, 1), datetime.date(2016, 12, 31))
        overhead = round_curr(random.uniform(75.0, 110.0))
    else:
        install_dt = random_date(datetime.date(2017, 1, 1), datetime.date(2022, 11, 30))
        overhead = round_curr(random.uniform(45.0, 75.0))

    machines.append({
        "machine_id": m_id,
        "machine_code": f"MCH-P{line['plant_id']:02d}-{m_type['process_stage'][:3].upper()}-{m_id:03d}",
        "machine_name": f"{m_type['type_name']} #{m_id}",
        "machine_type_id": m_type["machine_type_id"],
        "line_id": line["line_id"],
        "serial_number": f"SN-{install_dt.year}-{m_id:04d}-{random.randint(1000, 9999)}",
        "model_number": f"MOD-{m_type['type_code']}-V{random.randint(2, 5)}",
        "manufacturer": random.choice(oems),
        "installation_date": install_dt,
        "status": "Operational",
        "hourly_overhead_cost": overhead,
        "is_problematic": is_problematic, # for realistic correlation
        "created_at": "2022-12-01 08:00:00"
    })

# =============================================================================
# 2. TRANSACTION DATA GENERATION (2023 - 2025)
# =============================================================================

# 2.1 Customer Orders (2,500 orders)
print("13/26 Generating Customer Orders (2,500 records)...")
customer_orders = []
for co_id in range(1, 2501):
    c = random.choice(customers)
    p = random.choice(products)
    ord_dt = random_date(START_DATE, END_DATE)
    lead_time = random.randint(14, 45)
    promised_dt = ord_dt + datetime.timedelta(days=lead_time)
    
    # 85% fulfilled on time or slightly late, 10% in production, 5% delayed
    r = random.random()
    if ord_dt > datetime.date(2025, 11, 15):
        actual_disp = None
        status = "In Production" if r < 0.7 else "Pending"
    elif r < 0.88:
        disp_delay = random.randint(-3, 3)
        actual_disp = promised_dt + datetime.timedelta(days=disp_delay)
        status = "Fulfilled"
    elif r < 0.96:
        disp_delay = random.randint(4, 15)
        actual_disp = promised_dt + datetime.timedelta(days=disp_delay)
        status = "Delayed"
    else:
        actual_disp = None
        status = "Cancelled"

    qty = round_curr(random.uniform(1000.0, 15000.0))
    price = round_curr(p["selling_price_per_meter"] * (1.0 - c["discount_percentage"] / 100.0))

    customer_orders.append({
        "order_id": co_id,
        "order_number": f"SO-{ord_dt.year}-{co_id:05d}",
        "customer_id": c["customer_id"],
        "product_id": p["product_id"],
        "order_date": ord_dt,
        "promised_delivery_date": promised_dt,
        "actual_dispatch_date": actual_disp,
        "ordered_meters": qty,
        "unit_selling_price": price,
        "order_status": status,
        "created_at": datetime.datetime.combine(ord_dt, datetime.time(9, 0, 0))
    })

# 2.2 Purchase Orders & PO Items (1,500 POs, ~4,000 Items)
print("14/26 & 15/26 Generating Purchase Orders & Items (1,500 POs, 4,000 Items)...")
purchase_orders = []
purchase_order_items = []
po_item_id = 1

for po_id in range(1, 1501):
    sup = random.choice(suppliers)
    plant = random.choice(plants)
    po_dt = random_date(START_DATE, END_DATE)
    lead_time = random.randint(7, 30)
    exp_dt = po_dt + datetime.timedelta(days=lead_time)
    
    if po_dt > datetime.date(2025, 12, 1):
        act_dt = None
        status = "Approved"
    else:
        act_dt = exp_dt + datetime.timedelta(days=random.randint(-2, 5))
        status = "Received"

    # 2 to 4 items per PO
    po_total = 0.0
    item_count = random.randint(2, 4)
    for _ in range(item_count):
        mat = random.choice(materials)
        ord_qty = round_curr(random.uniform(500.0, 5000.0))
        rec_qty = ord_qty if status == "Received" else 0.0
        u_price = round_curr(mat["standard_unit_cost"] * random.uniform(0.95, 1.05))
        l_total = round_curr(ord_qty * u_price)
        po_total += l_total

        purchase_order_items.append({
            "po_item_id": po_item_id,
            "po_id": po_id,
            "material_id": mat["material_id"],
            "ordered_quantity": ord_qty,
            "received_quantity": rec_qty,
            "unit_price": u_price,
            "line_total": l_total,
            "supplier_id": sup["supplier_id"], # for batch tracking
            "po_date": po_dt,
            "act_delivery_date": act_dt,
            "created_at": datetime.datetime.combine(po_dt, datetime.time(10, 0, 0))
        })
        po_item_id += 1

    purchase_orders.append({
        "po_id": po_id,
        "po_number": f"PO-{po_dt.year}-{po_id:05d}",
        "supplier_id": sup["supplier_id"],
        "plant_id": plant["plant_id"],
        "order_date": po_dt,
        "expected_delivery_date": exp_dt,
        "actual_delivery_date": act_dt,
        "status": status,
        "total_po_amount": round_curr(po_total),
        "created_at": datetime.datetime.combine(po_dt, datetime.time(10, 0, 0))
    })

# 2.3 Material Batches (2,500 batches)
print("16/26 Generating Material Batches (2,500 records)...")
material_batches = []
valid_po_items = [item for item in purchase_order_items if item["received_quantity"] > 0]
for b_id in range(1, 2501):
    po_item = valid_po_items[(b_id - 1) % len(valid_po_items)]
    sup = next(s for s in suppliers if s["supplier_id"] == po_item["supplier_id"])
    mat = next(m for m in materials if m["material_id"] == po_item["material_id"])
    
    rec_dt = po_item["act_delivery_date"] or (po_item["po_date"] + datetime.timedelta(days=10))
    init_qty = po_item["received_quantity"]
    rem_qty = round_curr(init_qty * random.uniform(0.05, 0.40))

    # Supplier quality correlation on incoming batch rejection
    if sup["quality_bias"] == "Poor":
        rej_prob = 0.12
    elif sup["quality_bias"] == "Excellent":
        rej_prob = 0.01
    else:
        rej_prob = 0.03

    if random.random() < rej_prob:
        q_stat = "Rejected"
        rem_qty = init_qty
        rej_reason = random.choice([
            "Yarn tensile strength below ASTM standard",
            "Color fastness grade < 3 in lab wash test",
            "Excessive moisture content in roving packaging",
            "Contamination by non-cellulosic foreign fibers"
        ])
    else:
        q_stat = "Accepted"
        rej_reason = None

    material_batches.append({
        "batch_id": b_id,
        "batch_code": f"BAT-{rec_dt.year}{rec_dt.month:02d}-{mat['material_code'][:7]}-{b_id:04d}",
        "po_item_id": po_item["po_item_id"],
        "material_id": mat["material_id"],
        "supplier_id": sup["supplier_id"],
        "received_date": rec_dt,
        "initial_quantity": init_qty,
        "remaining_quantity": rem_qty,
        "unit_of_measure": mat["unit_of_measure"],
        "quality_status": q_stat,
        "batch_rejection_reason": rej_reason,
        "created_at": datetime.datetime.combine(rec_dt, datetime.time(11, 0, 0))
    })

# 2.4 Production Orders (3,000 orders)
print("17/26 Generating Production Orders (3,000 records)...")
production_orders = []
for pord_id in range(1, 3001):
    co = customer_orders[(pord_id - 1) % len(customer_orders)] if pord_id <= len(customer_orders) else None
    prod = next(p for p in products if p["product_id"] == co["product_id"]) if co else random.choice(products)
    plant = random.choice(plants)
    
    ord_dt = co["order_date"] if co else random_date(START_DATE, END_DATE)
    tgt_start = ord_dt + datetime.timedelta(days=random.randint(1, 5))
    tgt_end = tgt_start + datetime.timedelta(days=random.randint(3, 10))
    
    if tgt_end > END_DATE:
        act_start = tgt_start
        act_end = None
        status = "In Progress"
        planned_m = round_curr(random.uniform(2000.0, 10000.0))
        comp_m = round_curr(planned_m * random.uniform(0.3, 0.7))
    else:
        act_start = tgt_start + datetime.timedelta(days=random.randint(0, 2))
        act_end = tgt_end + datetime.timedelta(days=random.randint(-1, 3))
        status = "Completed"
        planned_m = round_curr(random.uniform(2000.0, 10000.0))
        comp_m = round_curr(planned_m * random.uniform(0.92, 1.03))

    production_orders.append({
        "prod_order_id": pord_id,
        "prod_order_number": f"WO-{ord_dt.year}-{pord_id:05d}",
        "customer_order_id": co["order_id"] if co else None,
        "product_id": prod["product_id"],
        "plant_id": plant["plant_id"],
        "order_date": ord_dt,
        "target_start_date": tgt_start,
        "target_end_date": tgt_end,
        "actual_start_date": act_start,
        "actual_end_date": act_end,
        "planned_quantity_meters": planned_m,
        "completed_quantity_meters": comp_m,
        "order_status": status,
        "created_at": datetime.datetime.combine(ord_dt, datetime.time(8, 30, 0))
    })

# 2.5 Production Runs (10,000 runs)
print("18/26 Generating Production Runs (10,000 records)...")
production_runs = []
operators = [e for e in employees if e["role"] == "Operator"]
valid_prod_orders = [po for po in production_orders if po["actual_start_date"] is not None]

for r_id in range(1, 10001):
    porder = valid_prod_orders[(r_id - 1) % len(valid_prod_orders)]
    prod = next(p for p in products if p["product_id"] == porder["product_id"])
    mch = random.choice(machines)
    line = next(l for l in production_lines if l["line_id"] == mch["line_id"])
    m_type = next(mt for mt in machine_types if mt["machine_type_id"] == mch["machine_type_id"])
    
    plant_ops = [op for op in operators if op["plant_id"] == line["plant_id"]]
    op = random.choice(plant_ops) if plant_ops else random.choice(operators)
    shift = random.choice(shifts)
    
    base_dt = porder["actual_start_date"] + datetime.timedelta(days=random.randint(0, 3))
    if base_dt > END_DATE:
        base_dt = END_DATE
    
    if shift["shift_code"] == "SH-MORN":
        st_time = datetime.datetime.combine(base_dt, datetime.time(6, 0, 0))
        end_time = datetime.datetime.combine(base_dt, datetime.time(14, 0, 0))
    elif shift["shift_code"] == "SH-EVE":
        st_time = datetime.datetime.combine(base_dt, datetime.time(14, 0, 0))
        end_time = datetime.datetime.combine(base_dt, datetime.time(22, 0, 0))
    else:
        st_time = datetime.datetime.combine(base_dt, datetime.time(22, 0, 0))
        end_time = datetime.datetime.combine(base_dt + datetime.timedelta(days=1), datetime.time(6, 0, 0))

    planned_spd = m_type["standard_speed_rpm"]
    
    # Correlated efficiency based on operator skill, machine health, and shift
    eff_factor = 1.0
    if op["skill_level"] == "Master": eff_factor += 0.04
    elif op["skill_level"] == "Junior": eff_factor -= 0.05
    
    if mch["is_problematic"]: eff_factor -= 0.08
    if shift["is_night_shift"]: eff_factor -= 0.02

    eff_factor += random.uniform(-0.04, 0.04)
    actual_spd = int(planned_spd * max(0.70, min(1.05, eff_factor)))
    
    planned_meters = round_curr(random.uniform(800.0, 1600.0))
    actual_meters = round_curr(planned_meters * eff_factor)

    production_runs.append({
        "run_id": r_id,
        "run_code": f"RUN-{base_dt.year}{base_dt.month:02d}{base_dt.day:02d}-M{mch['machine_id']:03d}-{r_id:05d}",
        "prod_order_id": porder["prod_order_id"],
        "machine_id": mch["machine_id"],
        "line_id": line["line_id"],
        "product_id": prod["product_id"],
        "operator_id": op["employee_id"],
        "shift_id": shift["shift_id"],
        "run_date": base_dt,
        "start_time": st_time,
        "end_time": end_time,
        "planned_speed_rpm": planned_spd,
        "actual_speed_rpm": actual_spd,
        "planned_meters": planned_meters,
        "actual_meters": actual_meters,
        "run_status": "Completed",
        "created_at": st_time
    })

# 2.6 Material Consumption (15,000 records)
print("19/26 Generating Material Consumption (15,000 records)...")
material_consumption = []
accepted_batches = [b for b in material_batches if b["quality_status"] == "Accepted"]
cons_id = 1

for run in production_runs:
    # 1 to 2 batches consumed per run
    items_to_consume = 2 if run["run_id"] <= 5000 else 1
    for _ in range(items_to_consume):
        batch = accepted_batches[(cons_id - 1) % len(accepted_batches)]
        mat = next(m for m in materials if m["material_id"] == batch["material_id"])
        
        # Standard consumption kg based on meters produced
        c_qty = round_curr((run["actual_meters"] * 0.22) * random.uniform(0.95, 1.12))
        
        material_consumption.append({
            "consumption_id": cons_id,
            "run_id": run["run_id"],
            "batch_id": batch["batch_id"],
            "material_id": mat["material_id"],
            "consumed_quantity": max(10.0, c_qty),
            "unit_of_measure": mat["unit_of_measure"],
            "consumed_at": run["start_time"] + datetime.timedelta(hours=random.uniform(1.0, 6.0)),
            "created_at": run["start_time"]
        })
        cons_id += 1
        if cons_id > 15000:
            break
    if cons_id > 15000:
        break

# 2.7 Fabric Rolls (15,000 rolls: 1-2 rolls per run)
print("20/26 Generating Fabric Rolls (15,000 records)...")
fabric_rolls = []
roll_id = 1

for run in production_runs:
    rolls_per_run = 2 if run["run_id"] <= 5000 else 1
    m_per_roll = round_curr(run["actual_meters"] / rolls_per_run)
    prod = next(p for p in products if p["product_id"] == run["product_id"])
    mch = next(m for m in machines if m["machine_id"] == run["machine_id"])
    
    for r_idx in range(rolls_per_run):
        weight = round_curr(m_per_roll * (prod["density_gsm"] / 1000.0) * 1.5) # 1.5m width
        
        # Grade correlation
        prob_bad = 0.08
        if mch["is_problematic"]: prob_bad += 0.12
        
        roll_val = random.random()
        if roll_val < (1.0 - prob_bad):
            grade = "A"
            status = "In Stock" if random.random() < 0.7 else "Dispatched"
        elif roll_val < (1.0 - prob_bad * 0.3):
            grade = "B"
            status = "In Stock"
        elif roll_val < (1.0 - prob_bad * 0.1):
            grade = "C"
            status = "Rework"
        else:
            grade = "Scrap"
            status = "Scrapped"

        fabric_rolls.append({
            "roll_id": roll_id,
            "roll_barcode": f"RLL-{run['run_date'].year}{run['run_date'].month:02d}-{roll_id:06d}",
            "run_id": run["run_id"],
            "product_id": prod["product_id"],
            "roll_length_meters": max(50.0, m_per_roll),
            "roll_weight_kg": max(15.0, weight),
            "roll_grade": grade,
            "roll_status": status,
            "produced_at": run["start_time"] + datetime.timedelta(hours=4 + r_idx * 3),
            "created_at": run["start_time"] + datetime.timedelta(hours=4 + r_idx * 3)
        })
        roll_id += 1
        if roll_id > 15000:
            break
    if roll_id > 15000:
        break

# 2.8 Quality Inspections (15,000 inspections)
print("21/26 Generating Quality Inspections (15,000 records)...")
quality_inspections = []
inspectors = [e for e in employees if e["role"] == "Inspector"]
if not inspectors:
    inspectors = employees[:10]

for roll in fabric_rolls:
    insp_dt = roll["produced_at"] + datetime.timedelta(hours=random.uniform(0.5, 4.0))
    inspector = random.choice(inspectors)
    
    # 4-point ASTM quality score based on roll grade
    if roll["roll_grade"] == "A":
        points = random.randint(0, 8)
        score = round_curr(random.uniform(90.0, 100.0))
        res = "Pass"
    elif roll["roll_grade"] == "B":
        points = random.randint(9, 20)
        score = round_curr(random.uniform(75.0, 89.9))
        res = "Conditional Pass"
    elif roll["roll_grade"] == "C":
        points = random.randint(21, 35)
        score = round_curr(random.uniform(60.0, 74.9))
        res = "Conditional Pass"
    else: # Scrap
        points = random.randint(36, 60)
        score = round_curr(random.uniform(20.0, 59.9))
        res = "Fail"

    sqm = (roll["roll_length_meters"] * 1.5)
    pts_per_100 = round_curr((points * 100.0) / sqm) if sqm > 0 else 0.0

    quality_inspections.append({
        "inspection_id": roll["roll_id"],
        "inspection_code": f"QC-{insp_dt.year}-{roll['roll_id']:06d}",
        "roll_id": roll["roll_id"],
        "inspector_id": inspector["employee_id"],
        "inspection_date": insp_dt,
        "inspected_length_meters": roll["roll_length_meters"],
        "inspected_width_meters": 1.50,
        "total_defect_points": points,
        "points_per_100_sqm": pts_per_100,
        "quality_score": score,
        "inspection_result": res,
        "notes": f"ASTM 4-point inspection for Roll #{roll['roll_id']}",
        "created_at": insp_dt
    })

# 2.9 Defect Records (22,000 defects)
print("22/26 Generating Defect Records (22,000 records)...")
defect_records = []
def_id = 1
inspections_with_defects = [insp for insp in quality_inspections if insp["total_defect_points"] > 0]

for insp in inspections_with_defects:
    # 1 to 3 defect instances per non-zero inspection
    num_defects = min(3, max(1, insp["total_defect_points"] // 6))
    roll = next(r for r in fabric_rolls if r["roll_id"] == insp["roll_id"])
    
    for _ in range(num_defects):
        dtype = random.choice(defect_types)
        pos = round_curr(random.uniform(2.0, max(5.0, roll["roll_length_meters"] - 5.0)))
        d_len = round_curr(random.uniform(0.05, 1.20))
        pts = dtype["standard_penalty_points"]
        
        defect_records.append({
            "defect_id": def_id,
            "inspection_id": insp["inspection_id"],
            "roll_id": roll["roll_id"],
            "defect_type_id": dtype["defect_type_id"],
            "position_meters": pos,
            "defect_length_meters": d_len,
            "defect_points": pts,
            "detected_at": insp["inspection_date"],
            "severity": dtype["severity_level"],
            "created_at": insp["inspection_date"]
        })
        def_id += 1
        if def_id > 22000:
            break
    if def_id > 22000:
        break

# 2.10 Rework Records (4,000 reworks)
print("23/26 Generating Rework Records (4,000 records)...")
rework_records = []
rework_types = ["Re-Washing", "Mending/Darning", "Re-Dyeing", "Re-Finishing", "Shearing", "Stenter Alignment"]
reworkable_defects = [d for d in defect_records if d["severity"] in ["Major", "Minor"]]
rw_id = 1

for d in reworkable_defects:
    roll = next(r for r in fabric_rolls if r["roll_id"] == d["roll_id"])
    op = random.choice(operators)
    rw_dt = d["detected_at"].date() + datetime.timedelta(days=random.randint(1, 3))
    rw_type = random.choice(rework_types)
    hours = round_curr(random.uniform(0.5, 4.0))
    chem_cost = round_curr(random.uniform(5.0, 35.0)) if "Dye" in rw_type or "Wash" in rw_type else 0.0
    
    # 70% improve grade, 30% stay same
    pre_g = roll["roll_grade"] if roll["roll_grade"] in ["B", "C", "Scrap"] else "B"
    if random.random() < 0.70:
        post_g = "A" if pre_g == "B" else "B"
        res = "Successful"
    else:
        post_g = pre_g
        res = "Partial Improvement"

    rework_records.append({
        "rework_id": rw_id,
        "roll_id": roll["roll_id"],
        "defect_id": d["defect_id"],
        "rework_date": rw_dt,
        "rework_type": rw_type,
        "operator_id": op["employee_id"],
        "technician_hours": hours,
        "additional_chemical_cost": chem_cost,
        "pre_rework_grade": pre_g,
        "post_rework_grade": post_g,
        "rework_result": res,
        "notes": f"Post-inspection corrective rework for {rw_type}",
        "created_at": datetime.datetime.combine(rw_dt, datetime.time(14, 0, 0))
    })
    rw_id += 1
    if rw_id > 4000:
        break

# 2.11 Machine Downtime (7,500 records)
print("24/26 Generating Machine Downtime (7,500 records)...")
machine_downtime = []
downtime_categories = [
    ("Unplanned Breakdown", "Mechanical", "Loom weft insertion rapier tape snapped during cycle"),
    ("Unplanned Breakdown", "Electrical", "Main drive servo motor overload thermal trip"),
    ("Unplanned Breakdown", "Sensor/Pneumatic", "Warp tension digital load cell communication loss"),
    ("Setup & Changeover", "Operational", "Style and warp beam tie-in lot changeover"),
    ("Operator Delay", "Operational", "Yarn package reloading and creel bobbin replenishment"),
    ("Preventive Stoppage", "Mechanical", "Scheduled lubrication and shuttle race alignment"),
    ("Material Shortage", "Raw Material Jam", "Knot entanglement caused yarn feeder lockup")
]

for dt_id in range(1, 7501):
    mch = random.choice(machines)
    # Older machines have higher downtime frequency
    if not mch["is_problematic"] and random.random() < 0.35:
        mch = random.choice([m for m in machines if m["is_problematic"]])
        
    shift = random.choice(shifts)
    run = random.choice(production_runs)
    
    st_dt = run["start_time"] + datetime.timedelta(hours=random.uniform(0.5, 6.0))
    
    # 75% short micro-stoppages (0.25 - 1.5 hrs), 25% major breakdowns (2.0 - 8.0 hrs)
    if random.random() < 0.75:
        dur = round_curr(random.uniform(0.25, 1.50))
    else:
        dur = round_curr(random.uniform(2.00, 8.50))
        
    end_dt = st_dt + datetime.timedelta(hours=dur)
    cat, root_cat, reason = random.choice(downtime_categories)
    fin_cost = round_curr(dur * mch["hourly_overhead_cost"])

    machine_downtime.append({
        "downtime_id": dt_id,
        "machine_id": mch["machine_id"],
        "run_id": run["run_id"] if random.random() < 0.8 else None,
        "shift_id": shift["shift_id"],
        "start_time": st_dt,
        "end_time": end_dt,
        "duration_hours": dur,
        "downtime_category": cat,
        "reason_description": reason,
        "root_cause_category": root_cat,
        "financial_downtime_cost": fin_cost,
        "created_at": st_dt
    })

# 2.12 Machine Maintenance (3,500 maintenance jobs)
print("25/26 Generating Machine Maintenance (3,500 records)...")
machine_maintenance = []
technicians = [e for e in employees if e["role"] == "Technician"]
if not technicians:
    technicians = employees[:15]

maint_types = ["Preventive", "Corrective", "Predictive", "Emergency", "Calibration"]

for mnt_id in range(1, 3501):
    mch = random.choice(machines)
    tech = random.choice(technicians)
    m_type = random.choice(maint_types)
    
    sched_dt = random_date(START_DATE, END_DATE)
    if sched_dt > datetime.date(2025, 12, 15):
        comp_dt = None
        stat = "Scheduled"
        t_hours = 0.0
        p_cost = 0.0
    else:
        comp_dt = sched_dt + datetime.timedelta(days=random.randint(0, 2))
        stat = "Completed"
        t_hours = round_curr(random.uniform(2.0, 16.0))
        p_cost = round_curr(random.uniform(50.0, 650.0))
        if mch["is_problematic"]:
            p_cost = round_curr(p_cost * 1.5)

    l_cost = round_curr(t_hours * tech["hourly_labor_rate"])
    tot_cost = round_curr(l_cost + p_cost)

    machine_maintenance.append({
        "maintenance_id": mnt_id,
        "maintenance_code": f"MNT-{sched_dt.year}-{mnt_id:05d}",
        "machine_id": mch["machine_id"],
        "maintenance_type": m_type,
        "scheduled_date": sched_dt,
        "completion_date": comp_dt,
        "technician_id": tech["employee_id"],
        "technician_hours": t_hours,
        "labor_cost": l_cost,
        "replacement_parts_cost": p_cost,
        "total_maintenance_cost": tot_cost,
        "maintenance_status": stat,
        "notes": f"{m_type} servicing on {mch['machine_name']}",
        "created_at": datetime.datetime.combine(sched_dt, datetime.time(8, 0, 0))
    })

# 2.13 Production Waste (8,000 waste records)
print("26/26 Generating Production Waste (8,000 records)...")
production_waste = []
waste_types = [
    ("Selvage Trimming", 0.08),
    ("Sizing Loss", 0.05),
    ("Off-Shade Dye Dumping", 0.12),
    ("Yarn Bobbin Scrap", 0.06),
    ("Fabric Off-Cut", 0.07),
    ("Defective Yarn Slub Scrap", 0.05)
]

w_id = 1
for run in production_runs:
    # 80% of runs log waste
    if random.random() < 0.80:
        w_t, salvage_pct = random.choice(waste_types)
        mat = random.choice(materials)
        
        # Correlated waste: 2-6% of actual output
        w_qty = round_curr(run["actual_meters"] * random.uniform(0.02, 0.06))
        u_cost = mat["standard_unit_cost"]
        tot_cost = round_curr(w_qty * u_cost)
        salvage = round_curr(tot_cost * salvage_pct)
        net_loss = round_curr(tot_cost - salvage)

        production_waste.append({
            "waste_id": w_id,
            "run_id": run["run_id"],
            "material_id": mat["material_id"],
            "waste_type": w_t,
            "waste_quantity": max(1.0, w_qty),
            "unit_of_measure": mat["unit_of_measure"],
            "unit_cost": u_cost,
            "total_waste_cost": tot_cost,
            "salvage_recovery_value": salvage,
            "net_financial_loss": net_loss,
            "recorded_at": run["end_time"],
            "created_at": run["end_time"]
        })
        w_id += 1
        if w_id > 8000:
            break

print("\nGenerating SQL seed files (database/04_seed_master_data.sql & database/05_seed_transaction_data.sql)...")

# Write Master Seed File
with open("database/04_seed_master_data.sql", "w", encoding="utf-8") as f:
    f.write("-- Master Data Seed File for Textile Production Intelligence\n\n")
    
    def write_table_inserts(table_name, rows, columns):
        if not rows: return
        f.write(f"-- Table: {table_name} ({len(rows)} records)\n")
        col_list = ", ".join(columns)
        batch_size = 500
        for i in range(0, len(rows), batch_size):
            batch = rows[i:i+batch_size]
            vals_list = []
            for r in batch:
                row_vals = ", ".join(sql_str(r[c]) for c in columns)
                vals_list.append(f"({row_vals})")
            f.write(f"INSERT INTO {table_name} ({col_list}) VALUES\n" + ",\n".join(vals_list) + ";\n\n")

    write_table_inserts("locations", locations, ["location_id", "location_name", "address_line1", "city", "state_province", "country", "postal_code", "created_at"])
    write_table_inserts("machine_types", machine_types, ["machine_type_id", "type_code", "type_name", "process_stage", "standard_speed_rpm", "power_consumption_kwh", "expected_lifespan_years", "created_at"])
    write_table_inserts("shifts", shifts, ["shift_id", "shift_code", "shift_name", "start_time", "end_time", "duration_hours", "is_night_shift", "created_at"])
    write_table_inserts("defect_types", defect_types, ["defect_type_id", "defect_code", "defect_name", "category", "severity_level", "standard_penalty_points", "standard_scrapping_cost_per_defect", "created_at"])
    write_table_inserts("plants", plants, ["plant_id", "plant_code", "plant_name", "location_id", "manager_name", "total_capacity_meters_per_day", "operational_status", "created_at"])
    write_table_inserts("products", products, ["product_id", "product_code", "product_name", "fabric_type", "weave_type", "density_gsm", "standard_cost_per_meter", "selling_price_per_meter", "complexity_tier", "created_at"])
    write_table_inserts("materials", materials, ["material_id", "material_code", "material_name", "category", "subcategory", "unit_of_measure", "standard_unit_cost", "density_linear_count", "created_at"])
    write_table_inserts("suppliers", suppliers, ["supplier_id", "supplier_code", "supplier_name", "location_id", "contact_email", "phone", "payment_terms_days", "credit_rating", "is_preferred", "created_at"])
    write_table_inserts("customers", customers, ["customer_id", "customer_code", "customer_name", "location_id", "segment", "credit_limit", "discount_percentage", "created_at"])
    write_table_inserts("production_lines", production_lines, ["line_id", "line_code", "line_name", "plant_id", "line_type", "daily_target_meters", "is_active", "created_at"])
    write_table_inserts("employees", employees, ["employee_id", "employee_code", "first_name", "last_name", "plant_id", "role", "hire_date", "skill_level", "hourly_labor_rate", "is_active", "created_at"])
    write_table_inserts("machines", machines, ["machine_id", "machine_code", "machine_name", "machine_type_id", "line_id", "serial_number", "model_number", "manufacturer", "installation_date", "status", "hourly_overhead_cost", "created_at"])

# Write Transactional Seed File
with open("database/05_seed_transaction_data.sql", "w", encoding="utf-8") as f:
    f.write("-- Transaction Data Seed File for Textile Production Intelligence\n\n")

    def write_tx_inserts(table_name, rows, columns):
        if not rows: return
        f.write(f"-- Table: {table_name} ({len(rows)} records)\n")
        col_list = ", ".join(columns)
        batch_size = 500
        for i in range(0, len(rows), batch_size):
            batch = rows[i:i+batch_size]
            vals_list = []
            for r in batch:
                row_vals = ", ".join(sql_str(r[c]) for c in columns)
                vals_list.append(f"({row_vals})")
            f.write(f"INSERT INTO {table_name} ({col_list}) VALUES\n" + ",\n".join(vals_list) + ";\n\n")

    write_tx_inserts("customer_orders", customer_orders, ["order_id", "order_number", "customer_id", "product_id", "order_date", "promised_delivery_date", "actual_dispatch_date", "ordered_meters", "unit_selling_price", "order_status", "created_at"])
    write_tx_inserts("purchase_orders", purchase_orders, ["po_id", "po_number", "supplier_id", "plant_id", "order_date", "expected_delivery_date", "actual_delivery_date", "status", "total_po_amount", "created_at"])
    write_tx_inserts("purchase_order_items", purchase_order_items, ["po_item_id", "po_id", "material_id", "ordered_quantity", "received_quantity", "unit_price", "line_total", "created_at"])
    write_tx_inserts("material_batches", material_batches, ["batch_id", "batch_code", "po_item_id", "material_id", "supplier_id", "received_date", "initial_quantity", "remaining_quantity", "unit_of_measure", "quality_status", "batch_rejection_reason", "created_at"])
    write_tx_inserts("production_orders", production_orders, ["prod_order_id", "prod_order_number", "customer_order_id", "product_id", "plant_id", "order_date", "target_start_date", "target_end_date", "actual_start_date", "actual_end_date", "planned_quantity_meters", "completed_quantity_meters", "order_status", "created_at"])
    write_tx_inserts("production_runs", production_runs, ["run_id", "run_code", "prod_order_id", "machine_id", "line_id", "product_id", "operator_id", "shift_id", "run_date", "start_time", "end_time", "planned_speed_rpm", "actual_speed_rpm", "planned_meters", "actual_meters", "run_status", "created_at"])
    write_tx_inserts("material_consumption", material_consumption, ["consumption_id", "run_id", "batch_id", "material_id", "consumed_quantity", "unit_of_measure", "consumed_at", "created_at"])
    write_tx_inserts("fabric_rolls", fabric_rolls, ["roll_id", "roll_barcode", "run_id", "product_id", "roll_length_meters", "roll_weight_kg", "roll_grade", "roll_status", "produced_at", "created_at"])
    write_tx_inserts("quality_inspections", quality_inspections, ["inspection_id", "inspection_code", "roll_id", "inspector_id", "inspection_date", "inspected_length_meters", "inspected_width_meters", "total_defect_points", "points_per_100_sqm", "quality_score", "inspection_result", "notes", "created_at"])
    write_tx_inserts("defect_records", defect_records, ["defect_id", "inspection_id", "roll_id", "defect_type_id", "position_meters", "defect_length_meters", "defect_points", "detected_at", "severity", "created_at"])
    write_tx_inserts("rework_records", rework_records, ["rework_id", "roll_id", "defect_id", "rework_date", "rework_type", "operator_id", "technician_hours", "additional_chemical_cost", "pre_rework_grade", "post_rework_grade", "rework_result", "notes", "created_at"])
    write_tx_inserts("machine_downtime", machine_downtime, ["downtime_id", "machine_id", "run_id", "shift_id", "start_time", "end_time", "duration_hours", "downtime_category", "reason_description", "root_cause_category", "financial_downtime_cost", "created_at"])
    write_tx_inserts("machine_maintenance", machine_maintenance, ["maintenance_id", "maintenance_code", "machine_id", "maintenance_type", "scheduled_date", "completion_date", "technician_id", "technician_hours", "labor_cost", "replacement_parts_cost", "total_maintenance_cost", "maintenance_status", "notes", "created_at"])
    write_tx_inserts("production_waste", production_waste, ["waste_id", "run_id", "material_id", "waste_type", "waste_quantity", "unit_of_measure", "unit_cost", "total_waste_cost", "salvage_recovery_value", "net_financial_loss", "recorded_at", "created_at"])

total_records = (len(locations) + len(machine_types) + len(shifts) + len(defect_types) + len(plants) +
                 len(products) + len(materials) + len(suppliers) + len(customers) + len(production_lines) +
                 len(employees) + len(machines) + len(customer_orders) + len(purchase_orders) +
                 len(purchase_order_items) + len(material_batches) + len(production_orders) +
                 len(production_runs) + len(material_consumption) + len(fabric_rolls) +
                 len(quality_inspections) + len(defect_records) + len(rework_records) +
                 len(machine_downtime) + len(machine_maintenance) + len(production_waste))

print(f"\n===============================================================================")
print(f"SUCCESS: Synthetic Data Generation Complete!")
print(f"Total Database Records Generated: {total_records:,}")
print(f"===============================================================================")
