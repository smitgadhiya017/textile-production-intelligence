# Textile Production Waste, Defect & Machine Intelligence System
## Business Requirements Document (BRD)

---

### 1. Document Control & Scope

| Attribute | Details |
| :--- | :--- |
| **Project Title** | Textile Production Waste, Defect & Machine Intelligence System |
| **Domain** | Discrete & Continuous Textile Manufacturing Operations Analytics |
| **Core Tech Stack** | PostgreSQL (Relational Engine & Analytical Core) + Power BI (Executive BI) + Python (Synthetic Data Generator Only) |
| **Architecture Model** | Direct Relational Modeling -> Normalized Tables -> Business Views/Functions/Procedures -> Power BI |
| **Architectural Boundaries** | Strictly No ETL / Data Lake / Big Data Frameworks (Airflow, Spark, Kafka, Databricks, SSIS are prohibited). |

---

### 2. Stakeholders & User Personas

| Persona | Role | Key Information Needs & Deliverables |
| :--- | :--- | :--- |
| **Chief Operating Officer (COO)** | Executive Sponsor | Multi-plant financial losses, global capacity utilization, plant-to-plant efficiency comparisons, overall enterprise waste cost. |
| **Plant General Manager** | Plant Operations Lead | Daily shift production vs. targets, production line bottlenecks, unplanned downtime totals, plant scrap metrics. |
| **Quality Assurance Director** | QA / QC Lead | Defect frequency by type/severity, First-Pass Yield (FPY), supplier lot defect correlations, customer return risks. |
| **Maintenance & Reliability Head** | Asset Engineering Lead | Mean Time Between Failures (MTBF), Mean Time To Repair (MTTR), machine risk scores, predictive maintenance schedules. |
| **Procurement & Supply Chain Lead** | Strategic Sourcing | Supplier defect association scores, batch rejection rates, material cost-variance due to excessive processing waste. |
| **Production Line Supervisor / Shift Lead** | Floor Operations | Real-time shift output, operator efficiency, active machine downtime alerts, run scrap percentages. |

---

### 3. End-to-End Textile Manufacturing Process Flow

```
[ Supplier ]
     │ Raw Material Delivery (Yarn, Greige, Dye, Chemicals)
     ▼
[ Purchase Order & Material Batch ]
     │ Receiving Inspection & Lot Segregation
     ▼
[ Production Order ]
     │ Planned Quantity, Product Specification, Target Delivery
     ▼
[ Production Run ]
     │ Machine Allocation + Operator Assignment + Shift Execution
     ▼
[ Material Consumption ]
     │ Batch-to-Run Depletion Tracking (Virgin Material vs. Chemical Additives)
     ├───► [ Production Waste ] (Trimmings, Sizing Loss, Off-Cuts, Dye Residue)
     │
     ▼
[ Fabric Roll Output ]
     │ Gross Length, Weight, Roll Grading
     ▼
[ Quality Inspection ]
     │ 4-Point Inspection System / Visual / Lab Testing
     ├───► [ Defect Records ] (Holes, Snags, Stains, Shade Variation, Selvedge Faults)
     │          │
     │          ├───► [ Rework Records ] (Re-washing, Shearing, Re-dyeing)
     │          └───► [ Rejection / Scrap / Downgrade ]
     │
     ▼
[ Customer Orders & Fulfillment ] (Finished Fabric Rolls Dispatched)
```

---

### 4. Key Performance Indicator (KPI) Master Specifications

All KPIs in this system are strictly derived from relational table columns and computed via standardized SQL formulas:

| KPI ID | KPI Name | Mathematical Formula | Unit | Business Objective |
| :--- | :--- | :--- | :--- | :--- |
| **KPI-01** | **Production Volume** | $\sum \text{actual\_quantity\_meters}$ | Meters ($m$) | Track gross output against commercial demand. |
| **KPI-02** | **Production Efficiency** | $\left( \frac{\sum \text{actual\_quantity}}{\sum \text{planned\_quantity}} \right) \times 100$ | Percentage ($\%$) | Measure output execution fidelity against production planning. |
| **KPI-03** | **Waste Percentage** | $\left( \frac{\sum \text{waste\_quantity\_meters}}{\sum (\text{actual\_quantity\_meters} + \text{waste\_quantity\_meters})} \right) \times 100$ | Percentage ($\%$) | Identify material loss relative to gross throughput. |
| **KPI-04** | **Total Waste Financial Loss** | $\sum (\text{waste\_quantity} \times \text{material\_cost\_per\_unit}) - \text{salvage\_value}$ | Currency ($\$$) | Quantify direct financial loss caused by scrap materials. |
| **KPI-05** | **Defect Rate** | $\left( \frac{\text{Count of Rolls with Defects}}{\text{Total Rolls Inspected}} \right) \times 100$ | Percentage ($\%$) | Baseline quality benchmark across production entities. |
| **KPI-06** | **Defect Severity Points (per $100\text{ m}^2$)** | $\left( \frac{\sum \text{defect\_severity\_points} \times 100}{\text{Total Inspected Area in } m^2} \right)$ | Points / $100\text{ m}^2$ | Standardized ASTM / 4-point fabric grading rating. |
| **KPI-07** | **First-Pass Yield (FPY)** | $\left( \frac{\text{Count of Grade-A Rolls without Rework}}{\text{Total Rolls Produced}} \right) \times 100$ | Percentage ($\%$) | Measure production process capability to get quality right the first time. |
| **KPI-08** | **Rework Rate** | $\left( \frac{\text{Count of Reworked Rolls}}{\text{Total Rolls Produced}} \right) \times 100$ | Percentage ($\%$) | Track secondary labor and utility expenditures. |
| **KPI-09** | **Machine Utilization** | $\left( \frac{\sum \text{operating\_hours}}{\text{Total Available Calendar Hours}} \right) \times 100$ | Percentage ($\%$) | Measure asset productivity and idle capacity. |
| **KPI-10** | **Total Downtime Hours** | $\sum (\text{downtime\_end\_time} - \text{downtime\_start\_time}) \text{ in hours}$ | Hours ($hrs$) | Quantify lost operating time across mechanical, electrical, and setup stoppages. |
| **KPI-11** | **Mean Time Between Failures (MTBF)** | $\frac{\text{Total Operating Hours}}{\text{Count of Unplanned Breakdown Events}}$ | Hours / Breakdown | Evaluate machine asset reliability and engineering resilience. |
| **KPI-12** | **Mean Time To Repair (MTTR)** | $\frac{\text{Total Unplanned Repair Hours}}{\text{Count of Unplanned Breakdown Events}}$ | Hours / Repair | Evaluate maintenance team response and resolution speed. |
| **KPI-13** | **Machine Operational Risk Score** | $\text{Composite Heuristic: } (0.30 \times S_{\text{dt}}) + (0.25 \times S_{\text{freq}}) + (0.20 \times S_{\text{def}}) + (0.15 \times S_{\text{maint}}) + (0.10 \times S_{\text{age}})$ | Index (0–100) | Predict machine failure vulnerability and risk tier. |
| **KPI-14** | **Supplier Quality Index (SQI)** | $100 - \left( 40 \times \text{Rejection Rate} + 35 \times \text{Defect Association} + 25 \times \text{Waste Association} \right)$ | Score (0–100) | Rank and classify suppliers for procurement governance. |
| **KPI-15** | **Total Production Loss (TPL)** | $\text{Waste Cost} + \text{Defect Scrap Cost} + \text{Rework Cost} + \text{Downtime Lost Overhead Cost}$ | Currency ($\$$) | Consolidated financial operational loss across enterprise. |

---

### 5. Detailed Analytical Business Questions (70+ Master Catalog)

#### Section A: Production Performance (14 Questions)
1. What is the total fabric production (in meters) grouped by month and year?
2. What is the production distribution across manufacturing plants?
3. Which production lines yield the highest and lowest gross volume?
4. What is the total volume output achieved by each individual machine?
5. How does production volume distribute across distinct fabric product categories (e.g., Cotton, Denim, Viscose)?
6. Which work shift (Morning, Evening, Night) accounts for the largest share of fabric production?
7. What is the planned vs. actual production output variance across all completed production orders?
8. What is the overall production efficiency percentage by plant and line?
9. Which top 10 machines consistently exceed their planned production targets?
10. Which bottom 10 production lines demonstrate persistent production deficits?
11. What is the month-over-month (MoM) percentage growth in production volume?
12. Which production orders experienced delayed completions relative to target customer delivery dates?
13. What is the enterprise on-time completion percentage for production orders by product line?
14. What is the average production run duration across different product complexity classifications?

#### Section B: Quality & Defect Intelligence (16 Questions)
15. What is the enterprise-wide overall fabric defect rate?
16. How does the defect rate vary across different manufacturing plants?
17. Which specific machines exhibit the highest roll defect rates?
18. What is the defect rate breakdown across different machine types (e.g., Rapier Loom, Air-Jet Loom, Circular Knit)?
19. Which products have the highest defect probability per 1,000 meters produced?
20. What is the defect rate associated with each individual machine operator?
21. Does the defect rate differ significantly between Morning, Evening, and Night shifts?
22. Which raw material suppliers have the highest defect association rate in finished fabric?
23. What are the top 5 most frequently occurring defect types across all fabric categories?
24. Which defect types result in the highest monetary scrap and degradation losses?
25. What is the defect severity distribution (Critical, Major, Minor) enterprise-wide?
26. What is the average quality inspection score by product and plant?
27. What is the First-Pass Yield (FPY) trend across the 3-year historical timeline?
28. What percentage of total production volume requires secondary rework?
29. Which fabric product blends exhibit persistent structural defect rates above the 10% threshold?
30. Which machines are repeatedly associated with the exact same defect type over consecutive quarters?

#### Section C: Material Waste & Scrap Analytics (14 Questions)
31. What is the total material waste generated across all plants in meters and kilograms?
32. What is the overall material waste percentage relative to total input material?
33. What is the total cumulative financial cost of material waste across the business?
34. How does waste cost break down across individual manufacturing plants?
35. Which individual machines generate the highest total waste volume?
36. Which fabric products incur the highest waste percentage during processing?
37. Which raw material categories (e.g., combed yarn, synthetic filament) suffer the highest scrap rate?
38. What is the waste volume associated with specific raw material suppliers?
39. Which operational shift generates the highest average waste per production run?
40. What is the monthly trend of waste cost and waste percentage over the 36-month timeline?
41. Which specific production runs generated waste exceeding $+2$ standard deviations from the product average?
42. Who are the top 10 waste-producing machines across all plants?
43. Which top 5 products represent over 50% of the total scrap cost?
44. What are the most expensive waste categories (e.g., Selvage Trimming, Off-Shade Dye Dumping, Sizing Loss)?

#### Section D: Machine Downtime & Asset Reliability (15 Questions)
45. What is the total cumulative machine downtime hours recorded enterprise-wide?
46. What is the downtime hours breakdown for each individual machine?
47. How does unplanned downtime distribute across manufacturing plants?
48. Which machine types experience the highest downtime hours per 1,000 operating hours?
49. What is the breakdown of downtime frequency across breakdown categories (Mechanical, Electrical, Setup, Operator Error)?
50. What is the average repair duration (MTTR) across machine types and maintenance priority levels?
51. What is the average machine utilization rate by plant and production line?
52. What is the total maintenance expenditure (parts + technician labor) across all machines?
53. What is the breakdown between preventive maintenance cost vs. corrective breakdown repair cost?
54. Which machines exhibit a continuous quarter-over-quarter increase in unplanned downtime?
55. Which machines suffered 3 or more critical breakdown events within a rolling 30-day window?
56. Which 10 machines are responsible for the largest production volume loss due to downtime?
57. What is the Mean Time Between Failures (MTBF) for each machine model?
58. What is the Mean Time To Repair (MTTR) across each maintenance technician crew?
59. Which machines currently have a high failure probability and urgently require preventive maintenance?

#### Section E: Supplier Quality & Sourcing Intelligence (7 Questions)
60. What is the comprehensive supplier quality ranking based on incoming rejection rates?
61. What is the percentage of raw material batches rejected at receiving inspection by supplier?
62. Which suppliers supply raw materials that correlate with high downstream fabric defects?
63. Which suppliers are associated with higher-than-average production run scrap waste?
64. What is the total purchase spend vs. total defect cost associated with each raw material supplier?
65. What is the composite Supplier Quality Index (SQI) score for every active vendor?
66. Which bottom-tier suppliers fail the quality threshold and should be targeted for contract audit/renegotiation?

#### Section F: Operator & Shift Workforce Intelligence (4 Questions)
67. What is the production efficiency rating of each operator relative to standard engineering run hours?
68. What is the defect rate associated with each machine operator?
69. What is the rework rate associated with each machine operator?
70. How does each operator's defect and efficiency performance compare to their peer group shift average?

---

### 6. System Architecture & Constraints

1. **Relational Model First:** The system relies entirely on normalized PostgreSQL tables with strict primary, foreign key, and domain check constraints.
2. **Deterministic SQL Logic:** All KPIs and metrics must be calculated via standardized views, CTEs, and SQL functions, guaranteeing identical numbers across SQL queries and Power BI visuals.
3. **No External Transformations:** No Python scripts, ETL pipelines, or intermediate staging data warehouses are used for transformations. Python is restricted to initial synthetic seed data generation.
4. **Data Chronology:** All event timestamps (PO $\to$ Batch $\to$ Production Order $\to$ Production Run $\to$ Fabric Roll $\to$ Quality Inspection $\to$ Defect $\to$ Maintenance) must strictly observe chronological causality.
