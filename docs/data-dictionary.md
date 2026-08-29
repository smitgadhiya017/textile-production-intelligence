# Textile Production Waste, Defect & Machine Intelligence System
## Master Data Dictionary

---

### Master Tables (12 Entities)

#### 1. `locations`
*Physical and geographical site addresses for plants, suppliers, and customer facilities.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `location_id` | `SERIAL` | **PK** | NO | Surrogate primary key. |
| `location_name` | `VARCHAR(100)` | - | NO | Facility or warehouse title (e.g., "Savannah Textile Yard"). |
| `address_line1` | `VARCHAR(255)` | - | NO | Street address. |
| `city` | `VARCHAR(100)` | - | NO | Municipality / City. |
| `state_province` | `VARCHAR(100)` | - | NO | State or Province. |
| `country` | `VARCHAR(100)` | - | NO | Country name. |
| `postal_code` | `VARCHAR(20)` | - | YES | Postal / ZIP code. |
| `created_at` | `TIMESTAMP` | - | NO | Record creation timestamp (default `CURRENT_TIMESTAMP`). |

---

#### 2. `plants`
*Manufacturing facilities housing multiple production lines.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `plant_id` | `SERIAL` | **PK** | NO | Unique plant identifier. |
| `plant_code` | `VARCHAR(20)` | **UNIQUE** | NO | Enterprise plant code (e.g., "PLANT-GA-01"). |
| `plant_name` | `VARCHAR(100)` | - | NO | Operational facility name. |
| `location_id` | `INTEGER` | **FK** | NO | References `locations(location_id)`. |
| `manager_name` | `VARCHAR(100)` | - | NO | Plant director name. |
| `total_capacity_meters_per_day` | `NUMERIC(12,2)`| - | NO | Daily nominal capacity in meters (`> 0`). |
| `operational_status` | `VARCHAR(20)` | - | NO | Status: `'Active'`, `'Maintenance'`, `'Decommissioned'`. |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 3. `production_lines`
*Operational process lines within a plant (Spinning, Weaving, Knitting, Wet Processing, Finishing).*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `line_id` | `SERIAL` | **PK** | NO | Unique production line ID. |
| `line_code` | `VARCHAR(20)` | **UNIQUE** | NO | Enterprise line code (e.g., "LINE-WVE-04"). |
| `line_name` | `VARCHAR(100)` | - | NO | Descriptive line title. |
| `plant_id` | `INTEGER` | **FK** | NO | References `plants(plant_id)`. |
| `line_type` | `VARCHAR(50)` | - | NO | Process stage: `'Spinning'`, `'Weaving'`, `'Knitting'`, `'Dyeing'`, `'Printing'`, `'Finishing'`. |
| `daily_target_meters` | `NUMERIC(10,2)`| - | NO | Planned daily output in meters (`> 0`). |
| `is_active` | `BOOLEAN` | - | NO | Operational flag (default `TRUE`). |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 4. `machine_types`
*Engineering specification profiles and standard machine categories.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `machine_type_id` | `SERIAL` | **PK** | NO | Machine type identifier. |
| `type_code` | `VARCHAR(20)` | **UNIQUE** | NO | Type code (e.g., "MT-RAPIER-01"). |
| `type_name` | `VARCHAR(100)` | - | NO | Name (e.g., "High-Speed Rapier Loom", "Air-Jet Loom", "Rotary Screen Printer"). |
| `process_stage` | `VARCHAR(50)` | - | NO | Processing stage matching `production_lines.line_type`. |
| `standard_speed_rpm`| `INTEGER` | - | NO | Rated rotational/cycle speed (`> 0`). |
| `power_consumption_kwh`| `NUMERIC(8,2)` | - | NO | Power rating in kWh (`> 0`). |
| `expected_lifespan_years`| `INTEGER` | - | NO | Asset depreciation design life (`> 0`). |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 5. `machines`
*Physical machine assets installed on production lines.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `machine_id` | `SERIAL` | **PK** | NO | Unique machine asset ID. |
| `machine_code` | `VARCHAR(30)` | **UNIQUE** | NO | Machine serial asset tag (e.g., "MCH-PL1-WV03"). |
| `machine_name` | `VARCHAR(100)` | - | NO | Descriptive asset name. |
| `machine_type_id` | `INTEGER` | **FK** | NO | References `machine_types(machine_type_id)`. |
| `line_id` | `INTEGER` | **FK** | NO | References `production_lines(line_id)`. |
| `serial_number` | `VARCHAR(100)` | **UNIQUE** | NO | Manufacturer hardware serial. |
| `model_number` | `VARCHAR(100)` | - | NO | Manufacturer model code. |
| `manufacturer` | `VARCHAR(100)` | - | NO | OEM builder (e.g., Picanol, Rieter, Toyota, Tsudakoma, Zimmer). |
| `installation_date` | `DATE` | - | NO | Commissioning date. |
| `status` | `VARCHAR(20)` | - | NO | Status: `'Operational'`, `'Under Maintenance'`, `'Offline'`. |
| `hourly_overhead_cost`| `NUMERIC(10,2)`| - | NO | Allocated factory overhead cost per run hour (`>= 0.00`). |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 6. `employees`
*Plant personnel including machine operators, QA inspectors, and maintenance technicians.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `employee_id` | `SERIAL` | **PK** | NO | Unique employee ID. |
| `employee_code` | `VARCHAR(20)` | **UNIQUE** | NO | Employee badge ID (e.g., "EMP-2023-042"). |
| `first_name` | `VARCHAR(50)` | - | NO | First name. |
| `last_name` | `VARCHAR(50)` | - | NO | Last name. |
| `plant_id` | `INTEGER` | **FK** | NO | References `plants(plant_id)`. |
| `role` | `VARCHAR(50)` | - | NO | Role: `'Operator'`, `'Technician'`, `'Inspector'`, `'Supervisor'`. |
| `hire_date` | `DATE` | - | NO | Employment start date. |
| `skill_level` | `VARCHAR(20)` | - | NO | Level: `'Junior'`, `'Intermediate'`, `'Senior'`, `'Master'`. |
| `hourly_labor_rate` | `NUMERIC(8,2)` | - | NO | Hourly cost rate (`> 0.00`). |
| `is_active` | `BOOLEAN` | - | NO | Active status flag. |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 7. `shifts`
*Standard factory working shift definitions.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `shift_id` | `SERIAL` | **PK** | NO | Unique shift identifier. |
| `shift_code` | `VARCHAR(10)` | **UNIQUE** | NO | Code: `'SH-MORN'`, `'SH-EVE'`, `'SH-NGHT'`. |
| `shift_name` | `VARCHAR(50)` | - | NO | Name: `'Morning Shift'`, `'Evening Shift'`, `'Night Shift'`. |
| `start_time` | `TIME` | - | NO | Shift start time (e.g., `06:00:00`). |
| `end_time` | `TIME` | - | NO | Shift end time (e.g., `14:00:00`). |
| `duration_hours` | `NUMERIC(4,2)` | - | NO | Duration in hours (`CHECK (duration_hours > 0)`). |
| `is_night_shift` | `BOOLEAN` | - | NO | Night shift flag. |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 8. `products`
*Finished and semi-finished fabric specifications.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `product_id` | `SERIAL` | **PK** | NO | Unique product ID. |
| `product_code` | `VARCHAR(30)` | **UNIQUE** | NO | SKU identifier (e.g., "FAB-DNM-12OZ-01"). |
| `product_name` | `VARCHAR(150)` | - | NO | Commercial name (e.g., "Heavyweight Indigo Denim 12oz"). |
| `fabric_type` | `VARCHAR(50)` | - | NO | Fiber family: `'Cotton'`, `'Denim'`, `'Polyester'`, `'Viscose'`, `'Rayon'`, `'Linen'`, `'Blend'`. |
| `weave_type` | `VARCHAR(50)` | - | NO | Weave/Knit: `'Plain'`, `'Twill'`, `'Satin'`, `'Jacquard'`, `'Single Jersey'`, `'Rib Knit'`. |
| `density_gsm` | `NUMERIC(8,2)` | - | NO | Weight in grams per square meter (`> 0`). |
| `standard_cost_per_meter`| `NUMERIC(10,2)`| - | NO | Standard manufacturing cost per meter (`> 0.00`). |
| `selling_price_per_meter`| `NUMERIC(10,2)`| - | NO | Standard list price per meter (`> standard_cost`). |
| `complexity_tier`| `VARCHAR(20)` | - | NO | Complexity: `'Low'`, `'Medium'`, `'High'`, `'Extreme'`. |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 9. `materials`
*Raw materials and chemical additives catalog.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `material_id` | `SERIAL` | **PK** | NO | Unique material ID. |
| `material_code` | `VARCHAR(30)` | **UNIQUE** | NO | Material code (e.g., "YRN-COT-30S-01"). |
| `material_name` | `VARCHAR(150)` | - | NO | Full name (e.g., "100% Combed Ring-Spun Cotton Yarn 30s"). |
| `category` | `VARCHAR(50)` | - | NO | Category: `'Yarn'`, `'Greige Fabric'`, `'Dye'`, `'Sizing Chemical'`, `'Finishing Agent'`. |
| `subcategory` | `VARCHAR(50)` | - | NO | Subcategory (e.g., "Natural Fiber", "Synthetic", "Reactive Dye"). |
| `unit_of_measure` | `VARCHAR(20)` | - | NO | UOM: `'kg'`, `'meters'`, `'liters'`. |
| `standard_unit_cost`| `NUMERIC(10,2)`| - | NO | Purchase standard cost per unit (`> 0.00`). |
| `density_linear_count`| `VARCHAR(30)` | - | YES | Yarn count / concentration rating (e.g., "30s Ne", "150D/48F"). |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 10. `suppliers`
*Raw material suppliers and chemical manufacturing partners.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `supplier_id` | `SERIAL` | **PK** | NO | Unique supplier ID. |
| `supplier_code` | `VARCHAR(30)` | **UNIQUE** | NO | Supplier code (e.g., "SUP-COT-TEX-001"). |
| `supplier_name` | `VARCHAR(150)` | - | NO | Commercial company name. |
| `location_id` | `INTEGER` | **FK** | NO | References `locations(location_id)`. |
| `contact_email` | `VARCHAR(100)` | - | NO | Email address. |
| `phone` | `VARCHAR(50)` | - | YES | Contact telephone. |
| `payment_terms_days`| `INTEGER` | - | NO | Net terms (e.g., 30, 60, 90). |
| `credit_rating` | `VARCHAR(10)` | - | NO | Rating: `'AAA'`, `'AA'`, `'A'`, `'BBB'`, `'BB'`, `'B'`. |
| `is_preferred` | `BOOLEAN` | - | NO | Preferred vendor flag. |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 11. `customers`
*Wholesale textile buyers, apparel brands, and garment manufacturers.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `customer_id` | `SERIAL` | **PK** | NO | Unique customer ID. |
| `customer_code` | `VARCHAR(30)` | **UNIQUE** | NO | Customer code (e.g., "CUST-DENIM-CORP-01"). |
| `customer_name` | `VARCHAR(150)` | - | NO | Business name. |
| `location_id` | `INTEGER` | **FK** | NO | References `locations(location_id)`. |
| `segment` | `VARCHAR(50)` | - | NO | Tier: `'Fast Fashion'`, `'Luxury'`, `'Industrial'`, `'Wholesale'`. |
| `credit_limit` | `NUMERIC(12,2)`| - | NO | Approved credit limit (`>= 0.00`). |
| `discount_percentage`| `NUMERIC(5,2)` | - | NO | Standard discount (`CHECK (discount_percentage BETWEEN 0 AND 100)`). |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 12. `defect_types`
*Standardized fabric and process defect taxonomy (ASTM D5430 4-Point Standard).*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `defect_type_id` | `SERIAL` | **PK** | NO | Defect type ID. |
| `defect_code` | `VARCHAR(20)` | **UNIQUE** | NO | Defect classification code (e.g., "DEF-WRP-BRK"). |
| `defect_name` | `VARCHAR(100)` | - | NO | Name: `'Warp Break'`, `'Weft Slub'`, `'Oil Stain'`, `'Needle Line'`, `'Hole'`, `'Color Mismatch'`. |
| `category` | `VARCHAR(50)` | - | NO | Category: `'Yarn Defect'`, `'Weaving Defect'`, `'Knitting Defect'`, `'Dyeing Defect'`, `'Finishing Defect'`. |
| `severity_level` | `VARCHAR(20)` | - | NO | Severity: `'Minor'`, `'Major'`, `'Critical'`. |
| `standard_penalty_points`| `INTEGER` | - | NO | 4-point penalty value (`1, 2, 3, or 4`). |
| `standard_scrapping_cost_per_defect`| `NUMERIC(10,2)`| - | NO | Estimated economic loss per defect instance (`>= 0.00`). |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

### Transactional Tables (14 Entities)

#### 13. `purchase_orders`
*Raw material purchase orders placed with suppliers.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `po_id` | `BIGSERIAL` | **PK** | NO | Unique PO ID. |
| `po_number` | `VARCHAR(30)` | **UNIQUE** | NO | PO document number (e.g., "PO-2023-00891"). |
| `supplier_id` | `INTEGER` | **FK** | NO | References `suppliers(supplier_id)`. |
| `plant_id` | `INTEGER` | **FK** | NO | References `plants(plant_id)`. |
| `order_date` | `DATE` | - | NO | Issue date. |
| `expected_delivery_date`| `DATE` | - | NO | Promised delivery (`>= order_date`). |
| `actual_delivery_date`| `DATE` | - | YES | Fulfillment delivery date (`>= order_date`). |
| `status` | `VARCHAR(20)` | - | NO | Status: `'Draft'`, `'Approved'`, `'Received'`, `'Closed'`, `'Cancelled'`. |
| `total_po_amount` | `NUMERIC(14,2)`| - | NO | Total monetary value (`>= 0.00`). |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 14. `purchase_order_items`
*Line item details of raw materials purchased.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `po_item_id` | `BIGSERIAL` | **PK** | NO | Line item primary key. |
| `po_id` | `BIGINT` | **FK** | NO | References `purchase_orders(po_id)`. |
| `material_id` | `INTEGER` | **FK** | NO | References `materials(material_id)`. |
| `ordered_quantity` | `NUMERIC(12,2)`| - | NO | Quantity ordered (`> 0`). |
| `received_quantity`| `NUMERIC(12,2)`| - | NO | Quantity received (`>= 0`). |
| `unit_price` | `NUMERIC(10,2)`| - | NO | Price per unit (`> 0.00`). |
| `line_total` | `NUMERIC(12,2)`| - | NO | `ordered_quantity * unit_price`. |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 15. `material_batches`
*Received physical inventory lots tested for initial quality.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `batch_id` | `BIGSERIAL` | **PK** | NO | Unique batch lot ID. |
| `batch_code` | `VARCHAR(50)` | **UNIQUE** | NO | Lot code (e.g., "BAT-202305-COT031"). |
| `po_item_id` | `BIGINT` | **FK** | NO | References `purchase_order_items(po_item_id)`. |
| `material_id` | `INTEGER` | **FK** | NO | References `materials(material_id)`. |
| `supplier_id` | `INTEGER` | **FK** | NO | References `suppliers(supplier_id)`. |
| `received_date` | `DATE` | - | NO | Date lot was received. |
| `initial_quantity` | `NUMERIC(12,2)`| - | NO | Total delivered quantity (`> 0`). |
| `remaining_quantity`| `NUMERIC(12,2)`| - | NO | Current inventory balance (`>= 0`). |
| `unit_of_measure` | `VARCHAR(20)` | - | NO | UOM matching material definition. |
| `quality_status` | `VARCHAR(20)` | - | NO | Status: `'Accepted'`, `'Quarantined'`, `'Rejected'`. |
| `batch_rejection_reason`| `TEXT` | - | YES | Rejection narrative if rejected. |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 16. `customer_orders`
*Commercial sales orders placed by customers.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `order_id` | `BIGSERIAL` | **PK** | NO | Unique sales order ID. |
| `order_number` | `VARCHAR(30)` | **UNIQUE** | NO | Order number (e.g., "SO-2023-1002"). |
| `customer_id` | `INTEGER` | **FK** | NO | References `customers(customer_id)`. |
| `product_id` | `INTEGER` | **FK** | NO | References `products(product_id)`. |
| `order_date` | `DATE` | - | NO | Order placement date. |
| `promised_delivery_date`| `DATE`| - | NO | Promised dispatch date (`>= order_date`). |
| `actual_dispatch_date`| `DATE` | - | YES | Actual delivery date (`>= order_date`). |
| `ordered_meters` | `NUMERIC(12,2)`| - | NO | Ordered length in meters (`> 0`). |
| `unit_selling_price`| `NUMERIC(10,2)`| - | NO | Agreed price per meter (`> 0.00`). |
| `order_status` | `VARCHAR(20)` | - | NO | Status: `'Pending'`, `'In Production'`, `'Fulfilled'`, `'Delayed'`, `'Cancelled'`. |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 17. `production_orders`
*Factory work authorizations scheduled against customer demand or inventory replenishment.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `prod_order_id` | `BIGSERIAL` | **PK** | NO | Production order ID. |
| `prod_order_number`| `VARCHAR(30)` | **UNIQUE** | NO | Order number (e.g., "WO-2023-4055"). |
| `customer_order_id`| `BIGINT` | **FK** | YES | References `customer_orders(order_id)`. |
| `product_id` | `INTEGER` | **FK** | NO | References `products(product_id)`. |
| `plant_id` | `INTEGER` | **FK** | NO | References `plants(plant_id)`. |
| `order_date` | `DATE` | - | NO | Work order issue date. |
| `target_start_date`| `DATE` | - | NO | Scheduled start (`>= order_date`). |
| `target_end_date` | `DATE` | - | NO | Scheduled completion (`>= target_start_date`). |
| `actual_start_date`| `DATE` | - | YES | Actual manufacturing start. |
| `actual_end_date` | `DATE` | - | YES | Actual manufacturing completion (`>= actual_start_date`). |
| `planned_quantity_meters`| `NUMERIC(12,2)`| - | NO | Target output length (`> 0`). |
| `completed_quantity_meters`| `NUMERIC(12,2)`| - | NO | Actual output completed (`>= 0.00`). |
| `order_status` | `VARCHAR(20)` | - | NO | Status: `'Scheduled'`, `'In Progress'`, `'Completed'`, `'Aborted'`. |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 18. `production_runs`
*Discrete manufacturing runs executed by a specific machine, operator, and shift.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `run_id` | `BIGSERIAL` | **PK** | NO | Unique production run ID. |
| `run_code` | `VARCHAR(50)` | **UNIQUE** | NO | Run identifier (e.g., "RUN-20230501-PL1-M03-01"). |
| `prod_order_id` | `BIGINT` | **FK** | NO | References `production_orders(prod_order_id)`. |
| `machine_id` | `INTEGER` | **FK** | NO | References `machines(machine_id)`. |
| `line_id` | `INTEGER` | **FK** | NO | References `production_lines(line_id)`. |
| `product_id` | `INTEGER` | **FK** | NO | References `products(product_id)`. |
| `operator_id` | `INTEGER` | **FK** | NO | References `employees(employee_id)`. |
| `shift_id` | `INTEGER` | **FK** | NO | References `shifts(shift_id)`. |
| `run_date` | `DATE` | - | NO | Date of execution. |
| `start_time` | `TIMESTAMP` | - | NO | Run start timestamp. |
| `end_time` | `TIMESTAMP` | - | NO | Run completion (`CHECK (end_time > start_time)`). |
| `planned_speed_rpm`| `INTEGER` | - | NO | Target machine speed (`> 0`). |
| `actual_speed_rpm` | `INTEGER` | - | NO | Average operating speed (`> 0`). |
| `planned_meters` | `NUMERIC(10,2)`| - | NO | Target meters scheduled (`> 0`). |
| `actual_meters` | `NUMERIC(10,2)`| - | NO | Actual gross meters produced (`>= 0`). |
| `run_status` | `VARCHAR(20)` | - | NO | Status: `'Completed'`, `'Interrupted'`, `'Terminated'`. |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 19. `material_consumption`
*Detailed raw material batch quantities consumed during a production run.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `consumption_id` | `BIGSERIAL` | **PK** | NO | Consumption record ID. |
| `run_id` | `BIGINT` | **FK** | NO | References `production_runs(run_id)`. |
| `batch_id` | `BIGINT` | **FK** | NO | References `material_batches(batch_id)`. |
| `material_id` | `INTEGER` | **FK** | NO | References `materials(material_id)`. |
| `consumed_quantity`| `NUMERIC(12,2)`| - | NO | Quantity consumed (`> 0`). |
| `unit_of_measure` | `VARCHAR(20)` | - | NO | UOM (`kg`, `liters`, `meters`). |
| `consumed_at` | `TIMESTAMP` | - | NO | Consumption timestamp during the run. |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 20. `fabric_rolls`
*Individual physical fabric rolls output from a production run.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `roll_id` | `BIGSERIAL` | **PK** | NO | Unique roll ID. |
| `roll_barcode` | `VARCHAR(50)` | **UNIQUE** | NO | Barcode identifier (e.g., "RLL-20230501-84920"). |
| `run_id` | `BIGINT` | **FK** | NO | References `production_runs(run_id)`. |
| `product_id` | `INTEGER` | **FK** | NO | References `products(product_id)`. |
| `roll_length_meters`| `NUMERIC(10,2)`| - | NO | Physical length (`> 0`). |
| `roll_weight_kg` | `NUMERIC(10,2)`| - | NO | Measured weight (`> 0`). |
| `roll_grade` | `VARCHAR(10)` | - | NO | Grade: `'A'`, `'B'`, `'C'`, `'Scrap'`. |
| `roll_status` | `VARCHAR(20)` | - | NO | Status: `'In Stock'`, `'Dispatched'`, `'Rework'`, `'Scrapped'`. |
| `produced_at` | `TIMESTAMP` | - | NO | Timestamp of doffing/production. |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 21. `quality_inspections`
*Formal quality inspection records based on ASTM D5430 4-point rating.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `inspection_id` | `BIGSERIAL` | **PK** | NO | Unique inspection ID. |
| `inspection_code` | `VARCHAR(50)` | **UNIQUE** | NO | Inspection code (e.g., "QC-2023-9081"). |
| `roll_id` | `BIGINT` | **FK** | NO | References `fabric_rolls(roll_id)`. |
| `inspector_id` | `INTEGER` | **FK** | NO | References `employees(employee_id)`. |
| `inspection_date` | `TIMESTAMP` | - | NO | Date and time of inspection. |
| `inspected_length_meters`| `NUMERIC(10,2)`| - | NO | Inspected roll length (`> 0`). |
| `inspected_width_meters`| `NUMERIC(6,2)` | - | NO | Width in meters (`> 0`). |
| `total_defect_points`| `INTEGER` | - | NO | Cumulative 4-point penalty score (`>= 0`). |
| `points_per_100_sqm`| `NUMERIC(8,2)` | - | NO | Normalized score: $\frac{\text{points} \times 100}{\text{length} \times \text{width}}$. |
| `quality_score` | `NUMERIC(5,2)` | - | NO | Composite quality percentage (`0.00 to 100.00`). |
| `inspection_result`| `VARCHAR(20)` | - | NO | Result: `'Pass'`, `'Conditional Pass'`, `'Fail'`. |
| `notes` | `TEXT` | - | YES | Inspector comments. |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 22. `defect_records`
*Individual defect instances identified during quality inspection.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `defect_id` | `BIGSERIAL` | **PK** | NO | Defect instance ID. |
| `inspection_id` | `BIGINT` | **FK** | NO | References `quality_inspections(inspection_id)`. |
| `roll_id` | `BIGINT` | **FK** | NO | References `fabric_rolls(roll_id)`. |
| `defect_type_id` | `INTEGER` | **FK** | NO | References `defect_types(defect_type_id)`. |
| `position_meters` | `NUMERIC(10,2)`| - | NO | Linear distance along roll (`>= 0`). |
| `defect_length_meters`| `NUMERIC(6,2)`| - | NO | Physical defect dimension (`> 0`). |
| `defect_points` | `INTEGER` | - | NO | ASTM 4-point penalty (`1, 2, 3, or 4`). |
| `detected_at` | `TIMESTAMP` | - | NO | Timestamp of defect detection. |
| `severity` | `VARCHAR(20)` | - | NO | Severity: `'Minor'`, `'Major'`, `'Critical'`. |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 23. `rework_records`
*Corrective re-processing jobs applied to defective rolls.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `rework_id` | `BIGSERIAL` | **PK** | NO | Rework job ID. |
| `roll_id` | `BIGINT` | **FK** | NO | References `fabric_rolls(roll_id)`. |
| `defect_id` | `BIGINT` | **FK** | YES | References `defect_records(defect_id)`. |
| `rework_date` | `DATE` | - | NO | Date rework was conducted. |
| `rework_type` | `VARCHAR(50)` | - | NO | Type: `'Re-Washing'`, `'Mending/Darning'`, `'Re-Dyeing'`, `'Re-Finishing'`, `'Shearing'`. |
| `operator_id` | `INTEGER` | **FK** | NO | References `employees(employee_id)`. |
| `technician_hours`| `NUMERIC(6,2)` | - | NO | Rework labor duration (`> 0`). |
| `additional_chemical_cost`| `NUMERIC(10,2)`| - | NO | Cost of additional chemicals/dyes (`>= 0.00`). |
| `pre_rework_grade` | `VARCHAR(10)` | - | NO | Grade prior to rework (`'B'`, `'C'`, `'Scrap'`). |
| `post_rework_grade`| `VARCHAR(10)` | - | NO | Grade post rework (`'A'`, `'B'`, `'C'`, `'Scrap'`). |
| `rework_result` | `VARCHAR(20)` | - | NO | Result: `'Successful'`, `'Partial Improvement'`, `'Failed'`. |
| `notes` | `TEXT` | - | YES | Technician narrative. |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 24. `machine_downtime`
*Unplanned and planned machine stoppage logs.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `downtime_id` | `BIGSERIAL` | **PK** | NO | Downtime event ID. |
| `machine_id` | `INTEGER` | **FK** | NO | References `machines(machine_id)`. |
| `run_id` | `BIGINT` | **FK** | YES | References `production_runs(run_id)`. |
| `shift_id` | `INTEGER` | **FK** | NO | References `shifts(shift_id)`. |
| `start_time` | `TIMESTAMP` | - | NO | Stoppage start timestamp. |
| `end_time` | `TIMESTAMP` | - | NO | Stoppage end (`CHECK (end_time > start_time)`). |
| `duration_hours` | `NUMERIC(8,2)` | - | NO | Calculated duration in hours (`> 0`). |
| `downtime_category`| `VARCHAR(50)` | - | NO | Category: `'Unplanned Breakdown'`, `'Setup & Changeover'`, `'Operator Delay'`, `'Preventive Stoppage'`. |
| `reason_description`| `TEXT` | - | NO | Specific root cause narrative. |
| `root_cause_category`| `VARCHAR(50)` | - | NO | Classification: `'Mechanical'`, `'Electrical'`, `'Sensor/Pneumatic'`, `'Raw Material Jam'`, `'Operational'`. |
| `financial_downtime_cost`| `NUMERIC(12,2)`| - | NO | Lost overhead cost: `duration_hours * hourly_overhead_cost`. |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 25. `machine_maintenance`
*Preventive, corrective, and predictive maintenance servicing jobs.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `maintenance_id` | `BIGSERIAL` | **PK** | NO | Maintenance job ID. |
| `maintenance_code`| `VARCHAR(50)` | **UNIQUE** | NO | Job order code (e.g., "MNT-2023-0491"). |
| `machine_id` | `INTEGER` | **FK** | NO | References `machines(machine_id)`. |
| `maintenance_type`| `VARCHAR(50)` | - | NO | Type: `'Preventive'`, `'Corrective'`, `'Predictive'`, `'Emergency'`. |
| `scheduled_date` | `DATE` | - | NO | Scheduled intervention date. |
| `completion_date` | `DATE` | - | YES | Actual completion (`>= scheduled_date`). |
| `technician_id` | `INTEGER` | **FK** | NO | References `employees(employee_id)`. |
| `technician_hours`| `NUMERIC(6,2)` | - | NO | Labor hours spent (`>= 0`). |
| `labor_cost` | `NUMERIC(10,2)`| - | NO | `technician_hours * hourly_labor_rate`. |
| `replacement_parts_cost`| `NUMERIC(10,2)`| - | NO | Spare parts cost (`>= 0.00`). |
| `total_maintenance_cost`| `NUMERIC(12,2)`| - | NO | `labor_cost + replacement_parts_cost`. |
| `maintenance_status`| `VARCHAR(20)` | - | NO | Status: `'Scheduled'`, `'In Progress'`, `'Completed'`, `'Cancelled'`. |
| `notes` | `TEXT` | - | YES | Technician maintenance log. |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |

---

#### 26. `production_waste`
*Operational scrap, off-cut, selvedge trimming, and chemical waste events per run.*

| Column | Data Type | PK/FK | Nullable | Description & Domain Rules |
| :--- | :--- | :--- | :--- | :--- |
| `waste_id` | `BIGSERIAL` | **PK** | NO | Unique waste record ID. |
| `run_id` | `BIGINT` | **FK** | NO | References `production_runs(run_id)`. |
| `material_id` | `INTEGER` | **FK** | NO | References `materials(material_id)`. |
| `waste_type` | `VARCHAR(50)` | - | NO | Type: `'Selvage Trimming'`, `'Sizing Loss'`, `'Off-Shade Dye Dumping'`, `'Yarn Bobbin Scrap'`, `'Fabric Off-Cut'`. |
| `waste_quantity` | `NUMERIC(10,2)`| - | NO | Physical quantity scrapped (`> 0`). |
| `unit_of_measure` | `VARCHAR(20)` | - | NO | UOM (`kg`, `meters`, `liters`). |
| `unit_cost` | `NUMERIC(10,2)`| - | NO | Material cost per unit (`> 0.00`). |
| `total_waste_cost`| `NUMERIC(12,2)`| - | NO | `waste_quantity * unit_cost`. |
| `salvage_recovery_value`| `NUMERIC(10,2)`| - | NO | Scrap resale recovery value (`>= 0.00`). |
| `net_financial_loss`| `NUMERIC(12,2)`| - | NO | `total_waste_cost - salvage_recovery_value`. |
| `recorded_at` | `TIMESTAMP` | - | NO | Timestamp of waste generation. |
| `created_at` | `TIMESTAMP` | - | NO | Audit timestamp. |
