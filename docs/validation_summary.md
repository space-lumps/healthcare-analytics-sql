# Validation Summary (QA Sign-off)

This document summarizes the validation performed for the cohort pipeline and serves as QA sign-off for the current implementation.

## Scope

Validated scripts:

- `sql/pipeline/10_normalize_sources.sql`
- `sql/pipeline/20_build_cohort.sql`
- `sql/pipeline/30_output_csv.sql`
- `sql/pipeline/tests/*`

Validated datasets:

- `datasets/sample/` (committed)
- `datasets/prod/` (local-only; not committed)

All validation queries are **read-only** and do not modify source files or outputs.

---

## Pass Criteria

The pipeline is considered **passing** if:

1. Source reconciliation tests return **0 rows** (no unexpected extras / missing keys).
2. Grain tests return **0 rows** (no duplicate `patient_id + encounter_id` keys).
3. Cohort criteria tests return **0 rows** (no out-of-scope encounters included).
4. Metric validation tests return **0 rows** (no mismatches vs independent recomputation).
5. Null and range tests return **0 rows** (no literal `'NA'` leakage, no invalid required fields, sane timestamp ranges).

---

## 1. Source Data Reconciliation (Ingest Accuracy)

**Goal:** confirm ingestion and normalization do not drop or distort qualifying records.

Covered by:
- `00_recon_expected.sql` — defines the expected keyset from sources
- `01_recon_unexpected.sql` — fails if cohort contains keys not in expected set
- `02_recon_counts.sql` — validates row counts and distinct key counts at key stages
- `03_recon_fanout.sql` — detects join fanout / unexpected duplication
- `04_recon_no_na.sql` — confirms no literal placeholder strings (e.g., `NA`) remain after normalization

---

## 2. Schema & Type Checks

**Goal:** ensure expected columns exist and are correctly typed.

Covered by:
- `10_schema.sql`

Confirmed:
- TIMESTAMP vs DATE typing preserved as intended.
- Indicator fields are numeric.
- No unintended implicit type drift during casting.

---

## 3. Grain Validation

**Goal:** confirm the final cohort is **one row per `patient_id + encounter_id`**.

Covered by:
- `11_grain.sql`

Outputs:
- Duplicate-key detection returns 0 rows.

---

## 4. Cohort Criteria Validation

**Goal:** validate independently:
- `encounter_reason` = 'Drug overdose'
- `encounter_start_timestamp` ≥ 1999-07-16
- Age at encounter between **18–35 inclusive**

Covered by:
- `20_cohort_criteria.sql`

Result:
- No out-of-scope records included.
- Age calculation verified down to day-level precision.

---

## 5. Metric Logic Validation

**Goal:** verify derived fields are correct using independent recomputation.

Covered by:
- `30_metric_logic.sql`

Validated:
- `count_current_meds`: independently recomputed from medications active at encounter start.
- `current_opioid_ind`: independently recomputed using the opioid token list applied to active meds.
- `readmission_90_day_ind`, `readmission_30_day_ind`, `first_readmission_timestamp`:
  - validated using an alternative implementation (e.g., window/row-number vs `ARG_MIN`) and compared for identical outputs.

Notes:

- Readmissions are evaluated against the full qualifying overdose encounter universe (not age-restricted to 18–35).
- Readmissions after age 35 are allowed by design.

Observed:

- Age-36 readmissions are possible in principle within a 90-day window
- None are present in the current sample or production datasets.

---

## 6. Nulls, Ranges, and Final Sanity Checks

**Goal:** ensure required fields are populated, values are in expected bounds, and high-level aggregates look reasonable.

Covered by:

- `31_nulls_ranges.sql` — required fields, null policy, plausible timestamp ranges
- `40_final_sanity.sql` — high-level counts and indicator totals for quick regression checks

Confirmed:
- No unintended null leakage.
- Timestamps within realistic clinical bounds.
- Indicator aggregates stable across sample and production datasets.

---

## Export Notes (30_output_csv.sql)

The export script writes `output/overdose_cohort.csv` for convenience.

Notes:

- Export preserves typed NULLs (no presentation-layer substitution).
- Export formatting does not affect internal validation logic.

---

## Test Location

All tests live here:

`sql/pipeline/tests/`

They are intended to be executed after building TEMP VIEWs:

1. `.read 10_normalize_sources.sql`
2. `.read 20_build_cohort.sql`
3. `.read tests/<test_file>.sql`
