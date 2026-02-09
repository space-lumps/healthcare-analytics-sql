-- ============================================================
-- 21_test_readmissions_validation.sql
-- Purpose:
--   Recalculate readmissions for drug overdose encounters and
--   compare to the outputs produced by 20_build_cohort.sql.
--
-- Assumptions:
--   - 10_normalize_sources.sql has been executed
--     (TEMP VIEWs: encounters, patients exist)
--   - 20_build_cohort.sql has been executed and its final output 
--     (drug_overdose_cohort) is available as a TEMP VIEW 
--     or table you can join to.
-- ============================================================

WITH overdose_encounters AS (
	SELECT
		encounters.patient													AS patient_id
		,encounters.id														AS encounter_id
		,encounters.start													AS hospital_encounter_date
		,encounters.stop													AS encounter_end_date
	FROM encounters
	WHERE 1 = 1
		AND encounters.reasondescription = 'Drug overdose'
		AND encounters.start > DATE '1999-07-15'
)
,overdose_encounters_with_age AS (
	SELECT
		overdose_encounters.patient_id
		,overdose_encounters.encounter_id
		,overdose_encounters.hospital_encounter_date
		,overdose_encounters.encounter_end_date
		,DATE_DIFF('year', patients.birthdate, overdose_encounters.hospital_encounter_date)	AS age_at_visit
	FROM overdose_encounters
	INNER JOIN patients
		ON patients.id = overdose_encounters.patient_id
	WHERE 1 = 1
		AND DATE_DIFF('year', patients.birthdate, overdose_encounters.hospital_encounter_date) BETWEEN 18 AND 35
)
,recalc_readmissions AS (
	SELECT
		overdose_encounters_with_age.patient_id
		,overdose_encounters_with_age.encounter_id

		,MIN(
			CASE
				WHEN overdose_encounters_with_age_readmit.hospital_encounter_date
					<= CAST(overdose_encounters_with_age.encounter_end_date + INTERVAL '30 days' AS DATE)
				THEN overdose_encounters_with_age_readmit.hospital_encounter_date
				ELSE NULL
			END
		)																	AS first_readmission_date_30

		,MIN(overdose_encounters_with_age_readmit.hospital_encounter_date)	AS first_readmission_date_90

		,CASE
			WHEN MIN(
				CASE
					WHEN overdose_encounters_with_age_readmit.hospital_encounter_date
						<= CAST(overdose_encounters_with_age.encounter_end_date + INTERVAL '30 days' AS DATE)
					THEN 1
					ELSE NULL
				END
			) = 1
			THEN 1
			ELSE 0
		END																	AS readmission_30_day_ind_recalc

		,CASE
			WHEN MIN(overdose_encounters_with_age_readmit.hospital_encounter_date) IS NOT NULL
			THEN 1
			ELSE 0
		END																	AS readmission_90_day_ind_recalc

	FROM overdose_encounters_with_age
	LEFT JOIN overdose_encounters_with_age AS overdose_encounters_with_age_readmit
		ON overdose_encounters_with_age_readmit.patient_id = overdose_encounters_with_age.patient_id
		AND overdose_encounters_with_age_readmit.hospital_encounter_date > overdose_encounters_with_age.encounter_end_date
		AND overdose_encounters_with_age_readmit.hospital_encounter_date
			<= CAST(overdose_encounters_with_age.encounter_end_date + INTERVAL '90 days' AS DATE)

	GROUP BY
		overdose_encounters_with_age.patient_id
		,overdose_encounters_with_age.encounter_id
)
,comparison AS (
	SELECT
		drug_overdose_cohort.patient_id
		,drug_overdose_cohort.encounter_id

		,drug_overdose_cohort.readmission_30_day_ind								AS readmission_30_day_ind_model
		,recalc_readmissions.readmission_30_day_ind_recalc					AS readmission_30_day_ind_recalc

		,drug_overdose_cohort.readmission_90_day_ind								AS readmission_90_day_ind_model
		,recalc_readmissions.readmission_90_day_ind_recalc					AS readmission_90_day_ind_recalc

		,drug_overdose_cohort.first_readmission_date								AS first_readmission_date_model
		,recalc_readmissions.first_readmission_date_90						AS first_readmission_date_recalc

		,CASE
			WHEN drug_overdose_cohort.readmission_30_day_ind IS DISTINCT FROM recalc_readmissions.readmission_30_day_ind_recalc
			THEN 1 ELSE 0
		END																	AS mismatch_30_ind

		,CASE
			WHEN drug_overdose_cohort.readmission_90_day_ind IS DISTINCT FROM recalc_readmissions.readmission_90_day_ind_recalc
			THEN 1 ELSE 0
		END																	AS mismatch_90_ind

		,CASE
			WHEN drug_overdose_cohort.first_readmission_date IS DISTINCT FROM recalc_readmissions.first_readmission_date_90
			THEN 1 ELSE 0
		END																	AS mismatch_first_date

	FROM drug_overdose_cohort
	LEFT JOIN recalc_readmissions
		ON recalc_readmissions.patient_id = drug_overdose_cohort.patient_id
		AND recalc_readmissions.encounter_id = drug_overdose_cohort.encounter_id
)

-- Summary counts (should be all zeros for mismatches)
SELECT
	COUNT(*)											AS cohort_rows
	,SUM(mismatch_30_ind)								AS mismatch_30_ind_rows
	,SUM(mismatch_90_ind)								AS mismatch_90_ind_rows
	,SUM(mismatch_first_date)							AS mismatch_first_readmission_date_rows
FROM comparison
;

-- Uncomment to inspect mismatches (sample)
-- SELECT *
-- FROM comparison
-- WHERE 1 = 1
-- 	AND (mismatch_30_ind = 1 OR mismatch_90_ind = 1 OR mismatch_first_date = 1)
-- ORDER BY
-- 	patient_id
-- 	,encounter_id
-- LIMIT 50
;
