-- ============================================================
-- 05__nulls_and_ranges.sql
-- Purpose:
--   Data quality checks: allowed ranges, non-negativity, enums.
-- PASS condition:
--   0 rows returned in each test.
-- ============================================================

-- 1) Indicator columns must be 0/1
SELECT
	drug_overdose_cohort.*
FROM drug_overdose_cohort
WHERE 1 = 1
	AND (
		drug_overdose_cohort.death_at_visit_ind NOT IN (0, 1)
		OR  drug_overdose_cohort.current_opioid_ind NOT IN (0, 1)
		OR  drug_overdose_cohort.readmission_90_day_ind NOT IN (0, 1)
		OR  drug_overdose_cohort.readmission_30_day_ind NOT IN (0, 1)
	);

-- 2) count_current_meds should be >= 0 (and not null)
SELECT
	drug_overdose_cohort.patient_id
	,drug_overdose_cohort.encounter_id
	,drug_overdose_cohort.count_current_meds
FROM drug_overdose_cohort
WHERE 1 = 1
	AND (
		drug_overdose_cohort.count_current_meds IS NULL
		OR  drug_overdose_cohort.count_current_meds < 0
	);

-- 3) first_readmission_date cannot be before the encounter date
SELECT
	drug_overdose_cohort.patient_id
	,drug_overdose_cohort.encounter_id
	,drug_overdose_cohort.hospital_encounter_date
	,drug_overdose_cohort.first_readmission_date
FROM drug_overdose_cohort
WHERE 1 = 1
	AND drug_overdose_cohort.first_readmission_date IS NOT NULL
	AND drug_overdose_cohort.first_readmission_date < drug_overdose_cohort.hospital_encounter_date;
