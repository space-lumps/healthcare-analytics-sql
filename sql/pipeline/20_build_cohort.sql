-- ============================================================
-- 20_build_cohort.sql
-- Purpose:
--   Build an analysis-ready cohort of drug overdose hospital encounters.
--
-- Cohort criteria:
--   - encounters.reasondescription = 'Drug overdose'
--   - encounter start date > 1999-07-15
--   - age at encounter between 18 and 35 (inclusive)
--
-- Metrics produced (one row per patient_id + encounter_id):
--   - death_at_visit_ind
--   - count_current_meds
--   - current_opioid_ind
--   - readmission_90_day_ind
--   - readmission_30_day_ind
--   - first_readmission_date
--
-- Output:
--   Final SELECT returning the cohort at patient_id + encounter_id grain
--
-- Notes:
--   - Requires 10_normalize_sources.sql to be executed first
--     (encounters, medications, patients TEMP VIEWs must exist)
-- ============================================================

-- Define qualifying_encounters
--   - filter encounters to drug overdose + date threshold
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

-- Define cohort
--   - join patients
--   - compute age_at_visit
--   - apply age filter
,cohort AS (
    SELECT
        qualifying_encounters.patient_id
        ,qualifying_encounters.encounter_id
        ,qualifying_encounters.hospital_encounter_date
        ,qualifying_encounters.encounter_end_date
        ,DATE_DIFF(
            'year'
            , patients.birthdate
            ,qualifying_encounters.hospital_encounter_date
            ) 
            AS age_at_visit
        ,patients.birthdate
        ,patients.deathdate

    FROM qualifying_encounters
    INNER JOIN patients
        ON patients.id = qualifying_encounters.patient_id
    WHERE 1 = 1
        AND DATE_DIFF('year', patients.birthdate, qualifying_encounters.hospital_encounter_date) BETWEEN 18 AND 35
)

-- Define current_meds
--   - medications active at encounter start
,current_meds AS (
    SELECT
        cohort.patient_id
        ,cohort.encounter_id
        ,cohort.hospital_encounter_date
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

select count(*) from cohort;
-- Define opioids_list
--   - keyword/token list for opioid identification

-- Define current_opioids
--   - subset of current_meds matching opioid tokens

-- Define readmissions
--   - first overdose readmission within 90 days

-- Final SELECT
--   - aggregate to one row per patient_id + encounter_id
--   - compute indicator and count columns
