-- ============================================================
-- 03__cohort_criteria.sql
-- Purpose:
--   Validate cohort criteria are satisfied in the final output.
-- PASS condition:
--   0 rows returned in each test.
-- ============================================================

-- 1) Encounter is actually a Drug overdose encounter in encounters source
SELECT
	overdose_cohort.patient_id
	,overdose_cohort.encounter_id
	,encounters.reasondescription
FROM overdose_cohort
INNER JOIN encounters
	ON encounters.id = overdose_cohort.encounter_id
WHERE 1 = 1
	AND encounters.reasondescription <> 'Drug overdose';

-- 2) Date threshold
SELECT
	overdose_cohort.patient_id
	,overdose_cohort.encounter_id
	,overdose_cohort.hospital_encounter_date
FROM overdose_cohort
WHERE 1 = 1
	AND overdose_cohort.hospital_encounter_date <= DATE '1999-07-15';

-- 3) Age range (18–35 inclusive)
SELECT
	overdose_cohort.patient_id
	,overdose_cohort.encounter_id
	,overdose_cohort.age_at_visit
FROM overdose_cohort
WHERE 1 = 1
	AND overdose_cohort.age_at_visit NOT BETWEEN 18 AND 35;
