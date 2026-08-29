# Textile Production Waste, Defect & Machine Intelligence System
## Master Business Rules & Data Integrity Specifications

---

### 1. Overview & Purpose

This document establishes the authoritative operational and business rules governing the **Textile Production Waste, Defect & Machine Intelligence System**. These rules dictate both database-level constraints (CHECK constraints, FOREIGN KEYS, NOT NULL constraints, Triggers) and analytical logic across SQL queries and Power BI measures.

---

### 2. Entity & Relational Integrity Rules

1. **Mandatory Primary Keys:** Every table in the schema must possess an explicit, non-null Primary Key (typically an auto-incrementing `BIGSERIAL` / `SERIAL` or standard integer identifier).
2. **Foreign Key Enforcement:** Every transactional entity must strictly reference valid master or upstream transactional records. Cascading deletes are strictly disallowed on critical operational logs; `ON DELETE RESTRICT` or soft status markers must be utilized.
3. **Natural Key Uniqueness:** Unique business keys (e.g., `batch_code`, `order_number`, `serial_number`, `roll_barcode`) must have explicit `UNIQUE` constraints to prevent duplicate entries.
4. **Normalized Storage:** Redundant text descriptions of masters (such as supplier names, plant names, machine types) must not be duplicated into transactional tables.

---

### 3. Chronological & Temporal Integrity Rules

All operational events follow a strict, non-reversible lifecycle chronology:

$$\text{Purchase Order Date} \le \text{Batch Delivery Date} \le \text{Production Run Start} < \text{Production Run End} \le \text{Roll Output} \le \text{Inspection Date} \le \text{Rework / Defect Resolution}$$

1. **Material Batch Delivery:** A material batch `received_date` cannot precede its associated `purchase_orders.order_date`.
2. **Production Order Scheduling:** A `production_orders.target_start_date` must be on or before `target_end_date`.
3. **Production Run Execution:**
   - `production_runs.start_time` must be strictly earlier than `production_runs.end_time`.
   - `production_runs.start_time` cannot occur before the parent `production_orders.order_date`.
4. **Material Consumption:** The `consumed_at` timestamp for a batch must fall within the `[start_time, end_time]` window of the corresponding production run.
5. **Fabric Roll Production:** A `fabric_rolls.produced_at` timestamp must fall within the duration of the parent production run.
6. **Quality Inspection:** `quality_inspections.inspection_date` must be greater than or equal to `fabric_rolls.produced_at`.
7. **Defect Records:** Any defect timestamp `defect_records.detected_at` must match the parent `quality_inspections.inspection_date`.
8. **Machine Downtime:**
   - `machine_downtime.start_time` must be strictly less than `machine_downtime.end_time`.
   - Downtime cannot be recorded in the future.
9. **Machine Maintenance:**
   - `machine_maintenance.completion_date` (when status is 'Completed') must be greater than or equal to `machine_maintenance.scheduled_date`.

---

### 4. Quantitative, Value & Domain Rules

| Entity / Field | Rule Definition | Constraint Type |
| :--- | :--- | :--- |
| **Quantities** | All production meters, planned quantities, consumed kilograms, roll lengths, and waste quantities must be strictly $> 0$. | `CHECK (quantity > 0)` |
| **Costs & Prices** | Unit costs, scrap salvage values, hourly labor rates, and maintenance costs must be $\ge 0.00$. Financial currency fields must use `NUMERIC(12, 2)` or `NUMERIC(14, 2)`. | `CHECK (cost >= 0.00)` |
| **Quality Scores** | Inspection scores must be bound between $0.00$ and $100.00$. | `CHECK (quality_score BETWEEN 0.00 AND 100.00)` |
| **Defect Points** | 4-Point system penalty points per defect must be restricted to integers $\{1, 2, 3, 4\}$. | `CHECK (defect_points IN (1, 2, 3, 4))` |
| **Roll Quality Grades** | Fabric roll grades are strictly categorized as `'A'`, `'B'`, `'C'`, or `'Scrap'`. | `CHECK (roll_grade IN ('A', 'B', 'C', 'Scrap'))` |
| **Waste Quantities** | Total waste generated on a run cannot exceed $100\%$ of input material equivalent. | Business Validation |
| **Inspection Roll Validity** | Defected meters on a roll cannot exceed the physical length of the roll. | Business Validation |

---

### 5. Operational Business Rules

#### A. Production & Material Consumption
- Every production run is assigned to exactly **one** primary machine, **one** lead operator, and executed across **one** specific shift.
- A production run may consume material from multiple material batches (e.g., warp yarn from Batch A, weft yarn from Batch B, dye chemicals from Batch C).
- Material consumption must be recorded with exact quantities and units of measure matching the material specification (`kg`, `liters`, `meters`).

#### B. Quality Assurance & Defect Classification
- Every fabric roll generated must undergo mandatory 1st-stage quality inspection.
- When an inspection yields a `quality_score < 75.0`, the roll must be marked as `'B'`, `'C'`, or `'Scrap'` and have at least one associated `defect_records` entry.
- When rework is performed, a corresponding `rework_records` entry must log the corrective action (e.g., `'Re-Washing'`, `'Mending'`, `'Re-Dyeing'`), rework labor hours, additional chemical cost, and the resulting post-rework quality grade.

#### C. Machine Downtime & Maintenance
- Machine downtime is categorized into `'Unplanned Breakdown'`, `'Setup & Changeover'`, `'Operator Delay'`, or `'Preventive Stoppage'`.
- Only downtime tagged as `'Unplanned Breakdown'` is included in MTBF calculations.
- Machine maintenance must log the maintenance type (`'Preventive'`, `'Corrective'`, `'Predictive'`, `'Emergency'`), technician hours, replacement parts cost, and downtime duration.

---

### 6. Heuristic Machine Intelligence & Scoring Rules

#### Machine Operational Risk Score (0 to 100 Scale)
The operational risk score is computed through a standardized weighted normalization model:

$$\text{Risk Score} = 0.30 \cdot S_{\text{downtime}} + 0.25 \cdot S_{\text{failure\_freq}} + 0.20 \cdot S_{\text{defect\_rate}} + 0.15 \cdot S_{\text{maint\_cost}} + 0.10 \cdot S_{\text{machine\_age}}$$

Where each sub-score $S_i$ is normalized against factory-wide min-max bounds ($0 \text{ to } 100$):

$$S_i = \text{LEAST}\left(100.0, \; \text{GREATEST}\left(0.0, \; \frac{X_i - \min(X)}{\max(X) - \min(X)} \times 100\right)\right)$$

**Risk Classification Tiers:**
- **$0 \le \text{Score} \le 30$:** `LOW` — Healthy machine operating within standard parameters.
- **$31 \le \text{Score} \le 60$:** `MEDIUM` — Average operational degradation; standard preventive maintenance cycle.
- **$61 \le \text{Score} \le 80$:** `HIGH` — Elevated failure frequency or defect rate; schedule inspection within 7 days.
- **$81 \le \text{Score} \le 100$:** `CRITICAL` — Severe operational hazard or impending breakdown; trigger immediate maintenance intervention.

---

### 7. Supplier Performance Intelligence Rules

#### Supplier Quality Index (SQI)
Suppliers are evaluated across three empirical dimensions:

$$\text{SQI} = 100 - \left( 0.40 \times \text{Rejection Rate \%} + 0.35 \times \text{Defect Association Rate \%} + 0.25 \times \text{Waste Excess \%} \right)$$

**Supplier Classification Tiers:**
- **$\text{SQI} \ge 90.0$:** `Tier 1: Excellent` — Preferred vendor status; eligible for long-term contract extensions.
- **$80.0 \le \text{SQI} < 90.0$:** `Tier 2: Good` — Stable vendor meeting standard operational tolerance.
- **$70.0 \le \text{SQI} < 80.0$:** `Tier 3: Average` — Moderate quality variance; periodic sampling audits.
- **$60.0 \le \text{SQI} < 70.0$:** `Tier 4: Poor` — Quality degradation; mandatory supplier warning and corrective action plan.
- **$\text{SQI} < 60.0$:** `Tier 5: Critical` — Severe quality failure; freeze new purchase orders and execute commercial audit.

---

### 8. Total Financial Production Loss Rules

The enterprise Total Production Loss ($TPL$) is mathematically defined as:

$$TPL = C_{\text{waste}} + C_{\text{defect\_scrap}} + C_{\text{rework}} + C_{\text{downtime\_overhead}}$$

1. **Waste Loss ($C_{\text{waste}}$):**
   $$\sum (\text{waste\_quantity} \times \text{unit\_cost}) - \text{salvage\_recovery\_value}$$
2. **Defect Scrap Loss ($C_{\text{defect\_scrap}}$):**
   $$\sum (\text{scrapped\_roll\_meters} \times \text{product\_unit\_cost}) + \sum (\text{downgraded\_roll\_meters} \times (\text{full\_price} - \text{discount\_price}))$$
3. **Rework Cost ($C_{\text{rework}}$):**
   $$\sum (\text{rework\_hours} \times \text{technician\_hourly\_rate}) + \sum \text{rework\_chemicals\_cost}$$
4. **Downtime Overhead Cost ($C_{\text{downtime\_overhead}}$):**
   $$\sum (\text{downtime\_hours} \times \text{unabsorbed\_overhead\_rate\_per\_hour})$$

---

### 9. Statistical Sample-Size & Causality Rules

#### A. Minimum Activity Thresholds for Analytical Rankings
To prevent statistical distortion from low sample sizes:
- **Operator Rankings:** Must have completed at least **15 production runs** before being ranked in efficiency or quality scorecards.
- **Machine Rankings:** Must have at least **100 total operating hours** recorded.
- **Supplier Evaluation:** Must have delivered at least **5 distinct material batches** before receiving an official SQI tier.
- **Product Defect Profiling:** Must have at least **5,000 meters produced** across the evaluated window.

#### B. Causality Terminology Rule
All SQL views, analytical documentation, and Power BI dashboards must strictly respect non-deterministic association:
- **Prohibited:** Stating "Supplier X caused defects" or "Night shift caused high downtime."
- **Mandatory:** Phrased as "Supplier X is associated with an elevated defect rate of $Y\%$ ($+Z\%$ above factory baseline)" or "Night shift is correlated with higher mechanical downtime."
