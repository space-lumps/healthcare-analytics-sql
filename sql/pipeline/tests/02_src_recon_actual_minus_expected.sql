-- ============================================================
-- 06__source_reconciliation.sql
-- Purpose:
--   Validate cohort selection correctness vs source data.
-- ============================================================

-- Expected qualifying encounters from raw sources
WITH expected_encounters AS (
	SELECT
		encounters.patient AS patient_id
		,encounters.id AS encounter_id
	FROM encounters
	INNER JOIN patients
		ON patients.id = encounters.patient
	WHERE 1 = 1
		AND encounters.reasondescription = 'Drug overdose'
		AND encounters.start > DATE '1999-07-15'
		AND DATE_DIFF('year', patients.birthdate, encounters.start) BETWEEN 18 AND 35
)

-- Actual cohort keys
,actual_cohort AS (
	SELECT
		patient_id
		,encounter_id
	FROM overdose_cohort
)

-- Only main SELECT statement differs from 06_src_recon_test_01
-- Fail if cohort includes anything not in expected set
SELECT
	actual_cohort.*
FROM actual_cohort
LEFT JOIN expected_encounters
	ON expected_encounters.patient_id = actual_cohort.patient_id
	AND expected_encounters.encounter_id = actual_cohort.encounter_id
WHERE expected_encounters.encounter_id IS NULL;
