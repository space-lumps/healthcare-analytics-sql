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

-- Fail if anything expected is missing
SELECT
	expected_encounters.*
FROM expected_encounters
LEFT JOIN actual_cohort
	ON actual_cohort.patient_id = expected_encounters.patient_id
	AND actual_cohort.encounter_id = expected_encounters.encounter_id
WHERE actual_cohort.encounter_id IS NULL;
