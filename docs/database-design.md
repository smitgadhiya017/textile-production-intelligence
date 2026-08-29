# Textile Production Waste, Defect & Machine Intelligence System
## Database Architecture & Design Specification

---

### 1. Architecture Overview & Relational Strategy

The database is architected as a highly normalized, enterprise-grade relational database within **PostgreSQL 14+**. The design balances strict **Third Normal Form (3NF)** relational normalization with high-performance operational analytics.

```
+----------------------------------------------------------------------------------------------------+
|                                    MASTER TOPOLOGY & DATA TIERS                                     |
+----------------------------------------------------------------------------------------------------+
|                                                                                                    |
|  [ LOCATIONS ] ───► [ PLANTS ] ───► [ PRODUCTION LINES ] ───► [ MACHINES ] ◄─── [ MACHINE TYPES ]  |
|         │                  │                                       ▲                               |
|         ▼                  ▼                                       │                               |
|  [ SUPPLIERS ]       [ EMPLOYEES ]                                 │                               |
|         │                  │ (Operators / Technicians)             │                               |
|         ▼                  ▼                                       │                               |
|  [ MATERIALS ]       [ SHIFTS ]                                    │                               |
|         │                  │                                       │                               |
|         ▼                  ▼                                       │                               |
|  [ PO ITEMS ] ──────► [ BATCHES ]                                  │                               |
|                            │                                       │                               |
|                            ▼                                       │                               |
|  [ CUSTOMER ORDERS ] ──► [ PROD ORDERS ] ──► [ PROD RUNS ] ────────┘                               |
|                                                     │                                              |
|            ┌────────────────────────┬───────────────┴───────────────┬──────────────────────┐       |
|            ▼                        ▼                               ▼                      ▼       |
|  [ MATERIAL CONSUMPTION ]  [ PRODUCTION WASTE ]              [ FABRIC ROLLS ]    [ MACHINE DOWNTIME ]
|            │                                                        │                      │       |
|            └────────────────────────────────────────┐               ▼                      ▼       |
|                                                     │    [ QUALITY INSPECTIONS ] [ MACHINE MAINT ] |
|                                                     │               │                              |
|                                                     │               ▼                              |
|                                                     │       [ DEFECT RECORDS ] ◄── [ DEFECT TYPES ]|
|                                                     │               │                              |
|                                                     │               ▼                              |
|                                                     └──────► [ REWORK RECORDS ]                    |
|                                                                                                    |
+----------------------------------------------------------------------------------------------------+
```

---

### 2. Normalization Assessment (Third Normal Form - 3NF)

| Entity Tier | Normalization Compliance | Rationale & Design Decision |
| :--- | :--- | :--- |
| **Master Tables** | **Full 3NF** | All non-key attributes are strictly dependent on the primary key alone. Addresses and geographical identifiers are isolated in `locations`. Machine operational specifications are segmented into `machine_types`. |
| **Procurement & Inventory** | **Full 3NF** | `purchase_orders` contains header metadata; line items in `purchase_order_items`; specific vendor shipments in `material_batches`. Eliminates transitive supplier-material redundancy. |
| **Production Hierarchy** | **Full 3NF** | Clear parent-child hierarchy: `customer_orders` $\to$ `production_orders` $\to$ `production_runs`. Single runs link to single machines, operators, shifts, and production lines. |
| **Quality & Defect Chain** | **Full 3NF** | Quality evaluations are split: `quality_inspections` handles roll-level inspection scores; `defect_records` handles localized defect instances; `rework_records` captures post-defect remediation. Defect metadata resides in `defect_types`. |
| **Asset Reliability & Maintenance** | **Full 3NF** | Unplanned stoppage logs are isolated in `machine_downtime`, whereas scheduled, corrective, and predictive maintenance jobs reside in `machine_maintenance`. |

---

### 3. Entity Classification & Table Registry (26 Tables)

#### Master Tables (12 Entities)
1. `locations`: Global physical and geographical sites (Plants, Suppliers, Customers).
2. `plants`: Manufacturing facilities and high-level capacity boundaries.
3. `production_lines`: Distinct departmental production workflows within plants (Spinning, Weaving, Knitting, Dyeing, Printing, Finishing).
4. `machine_types`: Engineering classifications, standard RPM speeds, power ratings, and lifespans.
5. `machines`: Physical asset registry with serial numbers, installation dates, and overhead rates.
6. `employees`: Production workforce, operators, QA inspectors, and maintenance technicians.
7. `shifts`: Operational work windows (Morning, Evening, Night) with duration and hour boundaries.
8. `products`: Fabric catalog specifying weave, fiber blend, density (GSM), and pricing tiers.
9. `materials`: Raw material catalog (Cotton Yarns, Synthetic Filaments, Dyes, Sizing Agents, Finishing Chemicals).
10. `suppliers`: Raw material vendor profiles, credit ratings, and payment terms.
11. `customers`: Commercial fabric buyers, wholesale converters, and garment manufacturers.
12. `defect_types`: Standardized defect taxonomy (ASTM D5430 4-point classifications and severity).

#### Transactional Tables (14 Entities)
13. `purchase_orders`: Vendor procurement headers.
14. `purchase_order_items`: Specific material quantities and negotiated purchase prices.
15. `material_batches`: Physical inventory lot receipts with QA acceptance status.
16. `customer_orders`: Client commercial demand and delivery commitments.
17. `production_orders`: Plant manufacturing work authorizations.
18. `production_runs`: Discrete operational manufacturing runs on a specific machine, operator, and shift.
19. `material_consumption`: Batch-level material depletion tied to specific production runs.
20. `fabric_rolls`: Physical rolls produced with gross length, weight, and grade.
21. `quality_inspections`: Formal roll inspection records with 4-point penalty calculations.
22. `defect_records`: Specific defect events mapped to roll length coordinates.
23. `rework_records`: Corrective actions taken on defective rolls.
24. `machine_downtime`: Granular machine stoppage and breakdown logs.
25. `machine_maintenance`: Preventive, corrective, and predictive servicing logs.
26. `production_waste`: Operational scrap, off-cut, and chemical waste events per run.

---

### 4. Cardinality & Relationship Matrix

| Parent Table | Child Table | Cardinality | Foreign Key Column | Business Relationship |
| :--- | :--- | :--- | :--- | :--- |
| `locations` | `plants` | 1 : N | `plants.location_id` | A plant is situated at a single geographic location. |
| `locations` | `suppliers` | 1 : N | `suppliers.location_id` | A supplier operates from a verified location. |
| `locations` | `customers` | 1 : N | `customers.location_id` | A customer is registered at a location. |
| `plants` | `production_lines` | 1 : N | `production_lines.plant_id` | A plant contains multiple production lines. |
| `plants` | `employees` | 1 : N | `employees.plant_id` | An employee is stationed at a primary plant. |
| `production_lines` | `machines` | 1 : N | `machines.line_id` | A line houses multiple physical machines. |
| `machine_types` | `machines` | 1 : N | `machines.machine_type_id` | A machine belongs to an engineering classification. |
| `suppliers` | `purchase_orders` | 1 : N | `purchase_orders.supplier_id` | A supplier receives multiple purchase orders. |
| `plants` | `purchase_orders` | 1 : N | `purchase_orders.plant_id` | A PO is destined for delivery at a plant. |
| `purchase_orders` | `purchase_order_items` | 1 : N | `purchase_order_items.po_id` | A PO contains multiple line items. |
| `materials` | `purchase_order_items` | 1 : N | `purchase_order_items.material_id` | A PO line specifies a raw material. |
| `purchase_order_items`| `material_batches` | 1 : N | `material_batches.po_item_id` | A PO line item is delivered in one or more batches. |
| `suppliers` | `material_batches` | 1 : N | `material_batches.supplier_id` | Direct link for supplier quality tracking. |
| `materials` | `material_batches` | 1 : N | `material_batches.material_id` | Direct link to material specification. |
| `customers` | `customer_orders` | 1 : N | `customer_orders.customer_id` | A customer places multiple sales orders. |
| `products` | `customer_orders` | 1 : N | `customer_orders.product_id` | An order specifies a fabric product. |
| `customer_orders` | `production_orders` | 1 : N | `production_orders.customer_order_id`| A customer order triggers production orders. |
| `products` | `production_orders` | 1 : N | `production_orders.product_id` | A production order targets a specific product. |
| `plants` | `production_orders` | 1 : N | `production_orders.plant_id` | A production order is scheduled at a plant. |
| `production_orders` | `production_runs` | 1 : N | `production_runs.prod_order_id` | An order is executed across multiple runs. |
| `machines` | `production_runs` | 1 : N | `production_runs.machine_id` | A run is executed on a machine. |
| `production_lines` | `production_runs` | 1 : N | `production_runs.line_id` | A run belongs to a production line. |
| `products` | `production_runs` | 1 : N | `production_runs.product_id` | A run produces a specific product. |
| `employees` | `production_runs` | 1 : N | `production_runs.operator_id` | An operator executes the run. |
| `shifts` | `production_runs` | 1 : N | `production_runs.shift_id` | A run is performed during a shift. |
| `production_runs` | `material_consumption`| 1 : N | `material_consumption.run_id` | A run consumes raw materials. |
| `material_batches` | `material_consumption`| 1 : N | `material_consumption.batch_id` | Material is drawn from a specific batch. |
| `production_runs` | `fabric_rolls` | 1 : N | `fabric_rolls.run_id` | A run yields multiple fabric rolls. |
| `fabric_rolls` | `quality_inspections` | 1 : 1 | `quality_inspections.roll_id` | Each roll has a primary inspection record. |
| `employees` | `quality_inspections` | 1 : N | `quality_inspections.inspector_id` | An inspector evaluates the roll. |
| `quality_inspections` | `defect_records` | 1 : N | `defect_records.inspection_id` | An inspection detects zero or more defects. |
| `fabric_rolls` | `defect_records` | 1 : N | `defect_records.roll_id` | Direct link to roll for rapid querying. |
| `defect_types` | `defect_records` | 1 : N | `defect_records.defect_type_id` | A defect is categorized by defect type. |
| `fabric_rolls` | `rework_records` | 1 : N | `rework_records.roll_id` | A defective roll undergoes rework. |
| `defect_records` | `rework_records` | 1 : N | `rework_records.defect_id` | Rework is linked to the triggering defect. |
| `employees` | `rework_records` | 1 : N | `rework_records.operator_id` | An operator executes the rework. |
| `machines` | `machine_downtime` | 1 : N | `machine_downtime.machine_id` | A machine experiences stoppage events. |
| `production_runs` | `machine_downtime` | 1 : N | `machine_downtime.run_id` | Downtime may link to an active run. |
| `shifts` | `machine_downtime` | 1 : N | `machine_downtime.shift_id` | Downtime occurs during a shift. |
| `machines` | `machine_maintenance` | 1 : N | `machine_maintenance.machine_id` | A machine undergoes maintenance jobs. |
| `employees` | `machine_maintenance` | 1 : N | `machine_maintenance.technician_id` | A technician completes maintenance. |
| `production_runs` | `production_waste` | 1 : N | `production_waste.run_id` | A run generates material waste. |
| `materials` | `production_waste` | 1 : N | `production_waste.material_id` | Waste is classified by raw material. |

---

### 5. Referential Integrity & Dependency Ordering

To prevent circular dependency locks during table creation and data loading, all SQL operations must follow this strict hierarchical order:

1. Level 0 (Zero Foreign Keys): `locations`, `machine_types`, `shifts`, `defect_types`
2. Level 1 (Depends on L0): `plants`, `suppliers`, `customers`, `materials`
3. Level 2 (Depends on L1): `production_lines`, `employees`
4. Level 3 (Depends on L2): `machines`, `purchase_orders`, `customer_orders`
5. Level 4 (Depends on L3): `purchase_order_items`, `production_orders`
6. Level 5 (Depends on L4): `material_batches`
7. Level 6 (Depends on L5): `production_runs`, `machine_maintenance`
8. Level 7 (Depends on L6): `material_consumption`, `fabric_rolls`, `machine_downtime`, `production_waste`
9. Level 8 (Depends on L7): `quality_inspections`
10. Level 9 (Depends on L8): `defect_records`
11. Level 10 (Depends on L9): `rework_records`
