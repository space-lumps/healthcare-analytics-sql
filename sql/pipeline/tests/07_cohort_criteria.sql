-- ============================================================
-- 03__cohort_criteria.sql
-- Purpose:
--   Validate cohort criteria are satisfied in the final output.
-- PASS condition:
--   0 rows returned in each test.
-- ============================================================

-- 1) Encounter is actually a Drug overdose encounter in encounters source
SELECT
	drug_overdose_cohort.patient_id
	,drug_overdose_cohort.encounter_id
	,encounters.reasondescription
FROM drug_overdose_cohort
INNER JOIN encounters
	ON encounters.id = drug_overdose_cohort.encounter_id
WHERE 1 = 1
	AND encounters.reasondescription <> 'Drug overdose';

-- 2) Date threshold
SELECT
	drug_overdose_cohort.patient_id
	,drug_overdose_cohort.encounter_id
	,drug_overdose_cohort.hospital_encounter_date
FROM drug_overdose_cohort
WHERE 1 = 1
	AND drug_overdose_cohort.hospital_encounter_date <= DATE '1999-07-15';

-- 3) Age range (18–35 inclusive)
SELECT
	drug_overdose_cohort.patient_id
	,drug_overdose_cohort.encounter_id
	,drug_overdose_cohort.age_at_visit
FROM drug_overdose_cohort
WHERE 1 = 1
	AND drug_overdose_cohort.age_at_visit NOT BETWEEN 18 AND 35;
