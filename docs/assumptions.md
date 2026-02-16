# Assumptions

## Purpose
Assumptions and tested constraints used to build the drug overdose encounter cohort and derived metrics in `20_build_cohort.sql`.

---

## Data and Environment Assumptions

### Source Normalization
- `10_normalize_sources.sql` is executed before `20_build_cohort.sql` and produces TEMP VIEWs:
  - `encounters`
  - `patients`
  - `medications`

- Raw CSV timestamp fields (START, STOP) in encounters.csv are stored as UTC timestamps and normalized to:
  - `encounter_start_timestamp`
  - `encounter_stop_timestamp`

- Raw medication date fields are normalized to:
  - `medication_start_date`
  - `medication_stop_date`

- Timestamp fields are intentionally preserved as `TIMESTAMP` to avoid loss of granularity.

- All downstream logic references normalized column names only, not raw CSV field names.

---

### Output Grain
- Final result is one row per `patient_id + encounter_id`.
- This grain is explicitly validated in `11_grain.sql`.

---

## Cohort Definition Assumptions

### Drug Overdose Labeling
- Cohort inclusion is based on:
  - `encounters.encounter_reason` = 'Drug overdose'
  - This matches the exercise definition and is not expanded beyond explicitly labeled overdose rows.

**Data Quality Note**
- `encounters.encounter_reason` contains `NA` for many encounters.
- Encounter `code/description` values observed under `reasondescription = 'NA'` are predominantly generic encounter-type concepts (e.g., “Encounter for check up”, “Emergency room admission”) and do not provide a reliable basis to infer overdose.
- Cohort logic is therefore not expanded beyond the labeled overdose rows.

---

### Date Threshold
- Encounters must start after July 15, 1999:
  - `encounters.encounter_start_timestamp >= TIMESTAMP '1999-07-16 00:00:00'`
- “After” is interpreted as exclusive of July 15.

---

### Age Eligibility (Birthday-accurate)
- Age at encounter is calculated using a birthday-accurate method (year difference adjusted by month/day comparison).
- `DATE_DIFF('year', ...)` is not used due to lack of day-level precision.
- Cohort filter: age between 18 and 35 inclusive.
- Readmission logic evaluates all patients age ≥ 18 to ensure:
  - Readmissions after turning 36 are not incorrectly excluded.

---

## Metric Derivation Assumptions

### Active medications at encounter start
A medication is considered “current” at encounter start if:
- `medications_start_date < encounter_start_timestamp`
- AND (`medication_stop_date IS NULL` OR `medication_stop_date >= encounter_start_timestamp`)

---

### Opioid Identification
- Opioids are identified via token match on `medication_description` using the prompt’s list:
  - `hydromorphone`
  - `fentanyl`
  - `oxycodone-acetaminophen`
- This is a minimal rule, not a comprehensive medication ontology mapping.

### Readmissions
- Readmission window is evaluated from `encounter_end_timestamp`.
- Readmission is defined as:
  - The next qualifying overdose encounter
  - Ocurring within 90 days (with a 30-day subset flag).
- Readmission logic is evaluated against all qualifying overdose encounters (not age-restricted to 18–35 on the readmit side).

---

## Validations (tested, not assumed)
These statements were validated during profiling/QA and are documented as tested constraints rather than assumptions:

- `encounter_id` is unique in the normalized encounters view.
- `encounter_stop_timestamp` contains no null values in the current datasets.
- Medication deduplication was required and handled during normalization.
- Expanding readmission logic beyond the age-restricted cohort produced identical results in current datasets.
- No literal 'NA' values persist after normalization.