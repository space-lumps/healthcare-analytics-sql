-- ============================================================
-- 07__join_explosion_reconciliation.sql
-- Purpose:
--   Detect join fan-out that gets hidden by the final GROUP BY.
-- PASS:
--   0 rows returned.
-- ============================================================

WITH qualifying_encounters AS (
	SELECT
		encounters.patient AS patient_id
		,encounters.id AS encounter_id
		,encounters.start AS hospital_encounter_date
		,encounters.stop AS encounter_end_date
	FROM encounters
	WHERE 1 = 1
		AND encounters.reasondescription = 'Drug overdose'
		AND encounters.start > DATE '1999-07-15'
)
,cohort AS (
	SELECT
		qualifying_encounters.patient_id
		,qualifying_encounters.encounter_id
		,qualifying_encounters.hospital_encounter_date
		,qualifying_encounters.encounter_end_date
	FROM qualifying_encounters
	INNER JOIN patients
		ON patients.id = qualifying_encounters.patient_id
	WHERE 1 = 1
		AND DATE_DIFF('year', patients.birthdate, qualifying_encounters.hospital_encounter_date) BETWEEN 18 AND 35
)
,current_meds AS (
	SELECT
		cohort.patient_id
		,cohort.encounter_id
		,medications.code AS medication_code
		,medications.description AS medication_description
		,medications.start AS medication_start_date
		,medications.stop AS medication_stop_date
	FROM medications
	INNER JOIN cohort
		ON medications.patient = cohort.patient_id
	WHERE 1 = 1
		AND medications.start < cohort.hospital_encounter_date
		AND (
			medications.stop IS NULL
			OR  medications.stop >= cohort.hospital_encounter_date
		)
)
,opioids_list AS (
	SELECT *
	FROM (VALUES
		('hydromorphone')
		,('fentanyl')
		,('oxycodone-acetaminophen')
	) AS opioids(opioid_token)
)
,current_opioids AS (
	SELECT DISTINCT
		current_meds.patient_id
		,current_meds.encounter_id
		,current_meds.medication_code AS opioid_code
	FROM current_meds
	INNER JOIN opioids_list
		ON LOWER(current_meds.medication_description)
			LIKE '%' || opioids_list.opioid_token || '%'
)
,readmissions AS (
	SELECT
		first_encounter.patient_id
		,first_encounter.encounter_id AS first_encounter_id
		,MIN(readmit.hospital_encounter_date) AS first_readmission_date
	FROM cohort first_encounter
	INNER JOIN cohort readmit
		ON first_encounter.patient_id = readmit.patient_id
		AND readmit.hospital_encounter_date > first_encounter.encounter_end_date
		AND readmit.hospital_encounter_date
			<= CAST(first_encounter.encounter_end_date + INTERVAL '90 days' AS DATE)
	GROUP BY
		first_encounter.patient_id
		,first_encounter.encounter_id
)

-- This is the critical check:
-- compare the rowcount BEFORE GROUP BY to the expected "base" encounter count.
,pre_group_joined AS (
	SELECT
		cohort.patient_id
		,cohort.encounter_id
	FROM cohort
	LEFT JOIN current_meds
		ON cohort.encounter_id = current_meds.encounter_id
	LEFT JOIN current_opioids
		ON cohort.encounter_id = current_opioids.encounter_id
	LEFT JOIN readmissions
		ON cohort.patient_id = readmissions.patient_id
		AND cohort.encounter_id = readmissions.first_encounter_id
)

,counts AS (
	SELECT
		(SELECT COUNT(*) FROM cohort) AS base_encounter_rows
		,(SELECT COUNT(*) FROM pre_group_joined) AS pre_group_rows
		,(SELECT COUNT(*) FROM overdose_cohort) AS final_rows
)
SELECT
	counts.*
FROM counts
WHERE 1 = 1
	AND counts.final_rows <> counts.base_encounter_rows
	OR  counts.pre_group_rows < counts.base_encounter_rows
	OR  counts.pre_group_rows > counts.base_encounter_rows * 100;
