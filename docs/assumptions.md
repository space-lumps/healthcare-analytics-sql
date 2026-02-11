# Assumptions

## Purpose
Assumptions and tested constraints used to build the drug overdose encounter cohort and derived metrics in `20_build_cohort.sql`.

---

## Data and environment assumptions

### Source normalization
- `10_normalize_sources.sql` is executed before `20_build_cohort.sql` and produces TEMP VIEWs:
  - `encounters`
  - `patients`
  - `medications`
- Raw `encounters.start` / `encounters.stop` are UTC timestamps. During normalization, these are converted to dates for downstream comparisons and joins.
  - Note: the raw timestamps contain time-of-day values (not midnight), so converting to DATE intentionally drops time-of-day granularity.

### Output grain
- Final result is one row per `patient_id + encounter_id`.

---

## Cohort definition assumptions

### Drug overdose labeling
- Cohort inclusion is based on:
  - `encounters.reasondescription = 'Drug overdose'`
  - This matches the exercise definition.

**Data quality note**
- `encounters.reasondescription` contains `NA` for many encounters.
- At least one generic encounter code (`50849002`) appears under both `reasondescription = 'NA'` and `reasondescription = 'Drug overdose'`.
- Encounter `code/description` values observed under `reasondescription = 'NA'` are predominantly generic encounter-type concepts (e.g., “Encounter for check up”, “Emergency room admission”) and do not provide a reliable basis to infer overdose.
- Cohort logic is therefore not expanded beyond the labeled overdose rows.

### Date threshold
- Encounters must start after July 15, 1999:
  - `encounters.start > DATE '1999-07-15'`
- Interprets “after” as exclusive of `1999-07-15`.

### Age eligibility (implemented as birthday-accurate age)
- Age at encounter is calculated using a birthday-accurate year difference (not `DATE_DIFF('year', ...)`) and filtered to 18–35 inclusive.
- This aligns with: “Patient is considered to be 35 until turning 36.”

---

## Metric derivation assumptions

### Active medications at encounter start
A medication is considered “current” at encounter start if:
- `medications.start < hospital_encounter_date`
- AND (`medications.stop IS NULL` OR `medications.stop >= hospital_encounter_date`)

### Opioid identification
- Opioids are identified via token match on `medications.description` using the prompt’s list:
  - `hydromorphone`
  - `fentanyl`
  - `oxycodone-acetaminophen`
- This is a minimal rule, not a comprehensive medication ontology mapping.

### Readmissions
- Readmission window is evaluated from `encounter_end_date` (stop).
- Readmission is defined as the next qualifying overdose encounter within 90 days (and a 30-day subset).
- Tested result: expanding readmission search to all overdose encounters (removing the age filter on the readmit side) produced the same readmission counts in this dataset (`missed_by_age_filter = 0`).

---

## Validations (tested, not assumed)
These statements were validated during profiling/QA and are documented as tested constraints rather than assumptions:

- `encounters.stop` has no null values in this dataset, so “during encounter” logic and readmission windows always have an encounter end date available.
- `encounters.id` is unique (validated during source profiling); encounter-level deduplication was not required.
- Medication deduplication was performed in the source normalization step where needed.