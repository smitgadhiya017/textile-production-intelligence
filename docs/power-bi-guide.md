# Power BI Dashboard Implementation Guide
## Textile Production Waste, Defect & Machine Intelligence System

---

## Overview

This guide documents the complete Power BI dashboard implementation for the Textile Production Intelligence System. The dashboard spans **4 interactive pages**, consuming data directly from the 7 SQL Views created in Phase 10.

**Dataset:** 108,518 records | Jan 2023 – Dec 2025 | 8 Plants | 150 Machines | 26 Tables

---

## Data Source Configuration

### Connection Method
```
Connection Type: DirectQuery (PostgreSQL)
Server: localhost
Port: 5432
Database: textile_production_db
Schema: public
```

### Source Views (Power BI Tables)
| Power BI Table Name | Source SQL View | Row Count |
|---|---|---|
| Production Efficiency | vw_production_efficiency | 10,000 |
| Quality Performance | vw_quality_performance | 15,382 |
| Machine Performance | vw_machine_performance | 150 |
| Supplier Performance | vw_supplier_performance | 120 |
| Production Loss | vw_production_loss | 10,000 |
| Machine Risk | vw_machine_risk | 150 |
| Business Alerts | vw_business_alerts | 3,722 |

---

## Data Model — Relationships

```
Production Loss (vw_production_loss)
  ├── [plant_code]       → Machine Performance.plant_code
  ├── [machine_code]     → Machine Risk.machine_code
  └── [run_code]         → Quality Performance.run_code

Quality Performance (vw_quality_performance)
  └── [machine_code]     → Machine Performance.machine_code

Machine Risk (vw_machine_risk)
  └── [plant_code]       → Machine Performance.plant_code

Business Alerts (vw_business_alerts)
  └── [plant_name]       → Production Loss.plant_name
```

---

## DAX Measures

### Page 1: Executive Overview

```dax
// Total Enterprise Production Loss
Total Production Loss USD =
SUM('Production Loss'[total_production_loss_usd])

// First-Pass Yield Rate
FPY Rate % =
DIVIDE(
    SUMX('Quality Performance', 'Quality Performance'[is_first_pass_yield]),
    COUNTROWS('Quality Performance'),
    0
) * 100

// Critical Machine Count
Critical Machine Count =
CALCULATE(
    COUNTROWS('Machine Risk'),
    'Machine Risk'[risk_category] = "CRITICAL"
)

// Total Active Business Alerts
Total Active Alerts =
COUNTROWS('Business Alerts')

// MoM Production Loss Delta
MoM Loss Delta % =
VAR CurrentMonth = MAX('Production Loss'[production_month])
VAR PrevMonth = CurrentMonth - 1
VAR CurrentLoss = CALCULATE([Total Production Loss USD], 'Production Loss'[production_month] = CurrentMonth)
VAR PrevLoss = CALCULATE([Total Production Loss USD], 'Production Loss'[production_month] = PrevMonth)
RETURN
DIVIDE(CurrentLoss - PrevLoss, PrevLoss, 0) * 100
```

### Page 2: Production & Waste

```dax
// Total Meters Produced
Total Meters Produced =
SUM('Production Efficiency'[actual_meters])

// Average Production Efficiency
Avg Efficiency % =
AVERAGE('Production Efficiency'[production_efficiency_pct])

// Total Material Scrap Loss
Total Material Waste Loss =
SUM('Production Loss'[material_waste_loss_usd])

// Waste Rate % of Output
Waste Rate % =
DIVIDE(
    [Total Material Waste Loss],
    [Total Meters Produced] * 2.5,
    0
) * 100

// 3-Month Moving Average Loss
Moving Avg 3M Loss =
AVERAGEX(
    DATESINPERIOD(
        'Production Loss'[run_date],
        LASTDATE('Production Loss'[run_date]),
        -3,
        MONTH
    ),
    [Total Material Waste Loss]
)
```

### Page 3: Quality Intelligence

```dax
// FPY Rolls (Grade A, no rework)
FPY Roll Count =
CALCULATE(
    COUNTROWS('Quality Performance'),
    'Quality Performance'[is_first_pass_yield] = 1
)

// Average ASTM Quality Score
Avg Quality Score =
AVERAGE('Quality Performance'[quality_score])

// Critical Defects Count
Critical Defect Count =
SUM('Quality Performance'[critical_defects_count])

// Rework Rate %
Rework Rate % =
DIVIDE(
    CALCULATE(COUNTROWS('Quality Performance'), 'Quality Performance'[is_reworked] = 1),
    COUNTROWS('Quality Performance'),
    0
) * 100

// Defects per 1000m
Defect Rate per 1000m =
DIVIDE(
    SUM('Quality Performance'[total_defects_count]) * 1000,
    SUM('Quality Performance'[roll_length_meters]),
    0
)
```

### Page 4: Machine Intelligence

```dax
// Average Machine Risk Score
Avg Machine Risk Score =
AVERAGE('Machine Risk'[machine_risk_score])

// Fleet Average MTBF (hours)
Fleet Avg MTBF =
AVERAGEX(
    FILTER('Machine Risk', 'Machine Risk'[mtbf_hours] > 0),
    'Machine Risk'[mtbf_hours]
)

// Fleet Average Utilization
Fleet Avg Utilization % =
AVERAGEX(
    FILTER('Machine Performance', 'Machine Performance'[machine_utilization_pct] > 0),
    'Machine Performance'[machine_utilization_pct]
)

// Total Downtime Financial Loss
Total Downtime Loss =
SUM('Machine Performance'[total_downtime_overhead_usd])

// Risk Score Color Conditional
Risk Color =
SWITCH(
    TRUE(),
    SELECTEDVALUE('Machine Risk'[risk_category]) = "CRITICAL", "#DC2626",
    SELECTEDVALUE('Machine Risk'[risk_category]) = "HIGH", "#F97316",
    SELECTEDVALUE('Machine Risk'[risk_category]) = "MEDIUM", "#EAB308",
    "#22C55E"
)
```

---

## Dashboard Pages

### Page 1: Executive Overview

![Executive Overview Dashboard](screenshots/dashboard_page1_executive_overview.jpg)

**Visuals:**
| Visual | Type | Fields | Purpose |
|---|---|---|---|
| Total Production Loss | KPI Card | `[Total Production Loss USD]` | Enterprise P&L |
| Total Records | KPI Card | `COUNTROWS(Production Efficiency)` | Dataset scale |
| FPY Rate | KPI Card | `[FPY Rate %]` | Quality headline |
| Critical Machines | KPI Card | `[Critical Machine Count]` | Asset risk |
| Total Alerts | KPI Card | `[Total Active Alerts]` | Exception count |
| Monthly Loss Trend | Clustered Bar | run_date[month], Total Production Loss USD | MoM tracking |
| Loss Breakdown | Donut Chart | loss_category (calculated), sum(usd) | Category split |
| Top Plants by Loss | Table | plant_name, Total Loss USD, rank | Ranked losses |

**Slicers:** Year, Plant, Date Range

---

### Page 2: Production & Waste Intelligence

![Production & Waste Dashboard](screenshots/dashboard_page2_production_waste.jpg)

**Visuals:**
| Visual | Type | Fields | Purpose |
|---|---|---|---|
| Total Meters | KPI Card | `[Total Meters Produced]` | Output volume |
| Avg Efficiency | KPI Card | `[Avg Efficiency %]` | Run efficiency |
| Total Scrap Loss | KPI Card | `[Total Material Waste Loss]` | Financial scrap |
| Waste Rate | KPI Card | `[Waste Rate %]` | Scrap intensity |
| Monthly Waste by Type | Stacked Area | run_date, material_waste_loss_usd, waste_type | Trend decomposition |
| Top Materials Scrap | Bar Chart | material_name, sum(net_financial_loss) | Pareto scrap view |
| Operator Efficiency vs Defect | Scatter | avg_efficiency_pct, defect_rate, operator_name | Correlation |
| Waste by Plant × Month | Matrix | plant_name (rows), month (cols), waste_rate% | Heatmap |

**Slicers:** Plant, Fabric Type, Waste Type, Year-Month range

---

### Page 3: Quality Intelligence

![Quality Intelligence Dashboard](screenshots/dashboard_page3_quality_intelligence.jpg)

**Visuals:**
| Visual | Type | Fields | Purpose |
|---|---|---|---|
| FPY Rate | KPI Card | `[FPY Rate %]` vs 88% target | Quality gate |
| Rolls Inspected | KPI Card | `COUNTROWS(Quality Performance)` | Inspection volume |
| Critical Defects | KPI Card | `[Critical Defect Count]` | Risk flag |
| Avg Quality Score | KPI Card | `[Avg Quality Score]` | ASTM benchmark |
| Quarterly FPY Trend | Line Chart | production_quarter, FPY Rate % | FPY trajectory |
| Defect Type Treemap | Treemap | defect_name, total_defects_count | Distribution |
| Defects by Severity / Fabric | Stacked Bar | fabric_type, critical/major/minor defects | Severity split |
| Inspector Performance | Matrix Table | inspector_name, rolls_inspected, avg_score, pass_rate | Staff leaderboard |

**Slicers:** Fabric Type, Severity Level, Plant, Quarter

---

### Page 4: Machine Intelligence

![Machine Intelligence Dashboard](screenshots/dashboard_page4_machine_intelligence.jpg)

**Visuals:**
| Visual | Type | Fields | Purpose |
|---|---|---|---|
| Critical Machines | KPI Card | `[Critical Machine Count]` | Asset risk count |
| Avg Risk Score | KPI Card | `[Avg Machine Risk Score]` | Fleet risk pulse |
| Avg MTBF | KPI Card | `[Fleet Avg MTBF]` | Reliability |
| Total Downtime Loss | KPI Card | `[Total Downtime Loss]` | Financial exposure |
| Risk Score Matrix | Bubble Scatter | machine_age_years (X), total_downtime_hours (Y), total_defects_count (size), risk_category (color) | Quadrant risk view |
| Top 10 Risk Machines | Horizontal Bar | machine_code, machine_risk_score | Ranked risk |
| MTBF by Age Cohort | Multi-Line | age_cohort, mtbf_hours, year | Reliability trend |
| Fleet Utilization | Gauge | `[Fleet Avg Utilization %]` | OEE snapshot |

**Slicers:** Plant, Machine Type, Risk Category, Installation Year

---

## Conditional Formatting Rules

| Visual | Column | Rule | Format |
|---|---|---|---|
| Machine Risk Table | risk_category = CRITICAL | Background | Red #DC2626 |
| Machine Risk Table | risk_category = HIGH | Background | Orange #F97316 |
| Machine Risk Table | risk_category = MEDIUM | Background | Yellow #EAB308 |
| Machine Risk Table | risk_category = LOW | Background | Green #22C55E |
| Business Alerts | alert_severity = CRITICAL | Font Color | Red #DC2626 |
| Business Alerts | alert_severity = HIGH | Font Color | Orange #F97316 |
| Quality Table | quality_score < 80 | Background | Red gradient |
| Quality Table | quality_score >= 90 | Background | Green gradient |

---

## Theme Configuration

```json
{
  "name": "Textile Intelligence Dark",
  "dataColors": ["#00D4FF", "#F97316", "#A855F7", "#22C55E", "#EAB308", "#DC2626", "#EC4899", "#06B6D4"],
  "background": "#0F1B2D",
  "foreground": "#1E3A5F",
  "tableAccent": "#00D4FF",
  "visualStyles": {
    "card": { "*": { "background": [{"color": {"solid": {"color": "#1E3A5F"}}}] } }
  }
}
```

> **Apply theme:** Power BI Desktop → View → Themes → Browse for themes → Select `textile_intelligence_dark.json`
