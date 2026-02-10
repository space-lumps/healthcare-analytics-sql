-- ============================================================
-- 04__metric_logic.sql
-- Purpose:
--   Validate derived metric logic against sources.
-- PASS condition:
--   0 rows returned in each test.
-- ============================================================

-- 1) death_at_visit_ind must be 0/1 and consistent with patients.deathdate
WITH base AS (
	SELECT
		drug_overdose_cohort.patient_id
		,drug_overdose_cohort.encounter_id
		,drug_overdose_cohort.hospital_encounter_date
		,encounters.stop AS encounter_end_date
		,patients.deathdate
		,drug_overdose_cohort.death_at_visit_ind
	FROM drug_overdose_cohort
	INNER JOIN patients
		ON patients.id = drug_overdose_cohort.patient_id
	INNER JOIN encounters
		ON encounters.id = drug_overdose_cohort.encounter_id
)
SELECT
	base.*
FROM base
WHERE 1 = 1
	AND (
		base.death_at_visit_ind NOT IN (0, 1)
		OR (
			base.deathdate IS NULL
			AND base.death_at_visit_ind <> 0
		)
		OR (
			base.deathdate IS NOT NULL
			AND base.deathdate BETWEEN base.hospital_encounter_date AND base.encounter_end_date
			AND base.death_at_visit_ind <> 1
		)
	);

-- 2) current_opioid_ind implies at least one qualifying "current med" with opioid token match
--    (This checks "no false positives" for opioid flag.)
WITH cohort_dates AS (
	SELECT
		drug_overdose_cohort.patient_id
		,drug_overdose_cohort.encounter_id
		,drug_overdose_cohort.hospital_encounter_date
	FROM drug_overdose_cohort
)
,opioid_hits AS (
	SELECT DISTINCT
		cohort_dates.patient_id
		,cohort_dates.encounter_id
	FROM cohort_dates
	INNER JOIN medications
		ON medications.patient = cohort_dates.patient_id
	WHERE 1 = 1
		AND medications.start < cohort_dates.hospital_encounter_date
		AND (
			medications.stop IS NULL
			OR  medications.stop >= cohort_dates.hospital_encounter_date
		)
		AND (
			LOWER(medications.description) LIKE '%hydromorphone%'
			OR  LOWER(medications.description) LIKE '%fentanyl%'
			OR  LOWER(medications.description) LIKE '%oxycodone-acetaminophen%'
		)
)
SELECT
	drug_overdose_cohort.patient_id
	,drug_overdose_cohort.encounter_id
	,drug_overdose_cohort.current_opioid_ind
FROM drug_overdose_cohort
LEFT JOIN opioid_hits
	ON opioid_hits.patient_id = drug_overdose_cohort.patient_id
	AND opioid_hits.encounter_id = drug_overdose_cohort.encounter_id
WHERE 1 = 1
	AND drug_overdose_cohort.current_opioid_ind = 1
	AND opioid_hits.encounter_id IS NULL;

-- 3) readmission_30_day_ind cannot be 1 if readmission_90_day_ind is 0
SELECT
	drug_overdose_cohort.patient_id
	,drug_overdose_cohort.encounter_id
	,drug_overdose_cohort.readmission_90_day_ind
	,drug_overdose_cohort.readmission_30_day_ind
FROM drug_overdose_cohort
WHERE 1 = 1
	AND drug_overdose_cohort.readmission_30_day_ind = 1
	AND drug_overdose_cohort.readmission_90_day_ind = 0;

-- 4) first_readmission_date must be null iff readmission_90_day_ind = 0
SELECT
	drug_overdose_cohort.patient_id
	,drug_overdose_cohort.encounter_id
	,drug_overdose_cohort.readmission_90_day_ind
	,drug_overdose_cohort.first_readmission_date
FROM drug_overdose_cohort
WHERE 1 = 1
	AND (
		(drug_overdose_cohort.readmission_90_day_ind = 0 AND drug_overdose_cohort.first_readmission_date IS NOT NULL)
		OR
		(drug_overdose_cohort.readmission_90_day_ind = 1 AND drug_overdose_cohort.first_readmission_date IS NULL)
	);
