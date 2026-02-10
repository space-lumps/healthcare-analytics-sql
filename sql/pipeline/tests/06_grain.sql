-- ============================================================
-- 02__grain_and_uniqueness.sql
-- Purpose:
--   Enforce cohort grain + key integrity.
-- PASS condition:
--   0 rows returned in each test.
-- ============================================================

-- 1) Null keys
SELECT
	drug_overdose_cohort.*
FROM drug_overdose_cohort
WHERE 1 = 1
	AND drug_overdose_cohort.patient_id IS NULL
	OR  drug_overdose_cohort.encounter_id IS NULL;

-- 2) Duplicate patient_id + encounter_id
WITH dupes AS (
	SELECT
		drug_overdose_cohort.patient_id
		,drug_overdose_cohort.encounter_id
		,COUNT(*) AS row_count
	FROM drug_overdose_cohort
	GROUP BY
		drug_overdose_cohort.patient_id
		,drug_overdose_cohort.encounter_id
	HAVING COUNT(*) > 1
)
SELECT
	dupes.*
FROM dupes;
