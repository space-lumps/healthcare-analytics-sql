-- ============================================================
-- 01__schema_and_types.sql
-- Purpose:
--   Sanity-check expected columns exist and are selectable.
--   (DuckDB doesn't have an information_schema as rich as warehouses,
--    so keep this simple + pragmatic.)
-- PASS condition:
--   Queries run without error and return 0 failing rows.
-- ============================================================

-- 1) Column existence smoke test (will error if missing)
WITH _smoke AS (
	SELECT
		drug_overdose_cohort.patient_id
		,drug_overdose_cohort.encounter_id
		,drug_overdose_cohort.hospital_encounter_date
		,drug_overdose_cohort.age_at_visit
		,drug_overdose_cohort.death_at_visit_ind
		,drug_overdose_cohort.count_current_meds
		,drug_overdose_cohort.current_opioid_ind
		,drug_overdose_cohort.readmission_90_day_ind
		,drug_overdose_cohort.readmission_30_day_ind
		,drug_overdose_cohort.first_readmission_date
	FROM drug_overdose_cohort
	LIMIT 1
)
SELECT
	*
FROM _smoke
WHERE 1 = 0;
