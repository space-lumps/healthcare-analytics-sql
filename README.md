# Healthcare Analytics SQL

### Overview

This repository implements a **reproducible analytics-engineering workflow** for healthcare encounter data using SQL. The project focuses on constructing a clinically meaningful cohort, deriving encounter-level metrics, and validating results with explicit QA tests.

The end result is an **analysis-ready cohort table** at a clear grain (`patient_id + encounter_id`) that can be safely used downstream for reporting, modeling, or further analysis.

---

### Objective

* Define a drug overdose hospital encounter cohort using explicit clinical and demographic criteria
* Engineer encounter-level features commonly used in healthcare analytics
* Validate complex logic (e.g., readmissions) with standalone test queries
* Demonstrate production-style SQL organization and quality checks

---

### Cohort Definition

The cohort includes hospital encounters that meet all of the following:

* `encounters.reasondescription = 'Drug overdose'`
* Encounter start date after **1999-07-15**
* Patient age at encounter between **18 and 35** (inclusive)

The cohort is built as a **TEMP VIEW** to support iterative analysis and testing.

---

### Metrics & Features Produced

Each row represents **one patient encounter** and includes:

* `death_at_visit_ind`
  Indicator for death occurring during the encounter window
* `count_current_meds`
  Count of medications active at encounter start
* `current_opioid_ind`
  Indicator for active opioid medications at encounter start
* `readmission_90_day_ind`
  Indicator for overdose readmission within 90 days
* `readmission_30_day_ind`
  Indicator for overdose readmission within 30 days
* `first_readmission_date`
  Date of first qualifying readmission, if any

All metrics are derived explicitly in SQL with documented assumptions.

---

### Validation & QA

The repo includes **dedicated validation queries** to verify correctness of key logic, including:

* Recalculation of readmission indicators independent of the main pipeline
* Checks for duplicate grain violations (`patient_id + encounter_id`)
* Distribution checks (e.g., encounters per patient)
* Sanity checks on row counts and null behavior

Validation logic lives alongside the pipeline and can be run independently.

---

### Repository Structure

```
sql/
├─ pipeline/
│  ├─ 10_normalize_sources.sql
│  ├─ 20_build_cohort.sql
│  └─ tests/
│     ├─ 21_test_readmissions_validation.sql
│     └─ additional QA tests
├─ explore/
│  └─ ad-hoc analysis and sanity checks
/docs
│  ├─ assumptions.md
│  ├─ data_dictionary.md
│  └─ validation_notes.md
/output
│  └─ local exports (gitignored)
```

---

### How to Run

* SQL engine: **DuckDB**
* Scripts are numbered and intended to be run in order
* Source normalization must be executed before cohort construction
* Tests can be run after the cohort TEMP VIEW is created

Exact commands and environment setup are documented in `/docs`.

---

### Data

* Source data consists of healthcare encounter, patient, and medication tables
* Raw data files are **not committed** to the repository
* Schema assumptions and field definitions are documented separately

---

### Notes

This project is intentionally SQL-first and mirrors patterns used in analytics engineering and healthcare data work: clear grain definition, explicit business logic, and testable transformations.