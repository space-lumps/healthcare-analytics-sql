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
CREATE OR REPLACE TEMP VIEW cohort_output AS


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

-- select count(*) from cohort;


-- Define opioids_list
--   - keyword/token list for opioid identification
,opioids_list AS (
    SELECT *
    FROM (VALUES
        ('hydromorphone')
        ,('fentanyl')
        ,('oxycodone-acetaminophen')
    ) AS opioids(opioid_token)
)

-- Define current_opioids
--   - subset of current_meds matching opioid tokens
,current_opioids AS (
    SELECT DISTINCT
        current_meds.patient_id
        ,current_meds.encounter_id
        ,current_meds.medication_code AS opioid_code
        ,current_meds.medication_description
        ,current_meds.medication_start_date
        ,current_meds.medication_stop_date
    FROM current_meds
    INNER JOIN opioids_list
        ON LOWER(current_meds.medication_description)
            LIKE '%' || opioids_list.opioid_token || '%'
)
-- select * from current_opioids limit 10;


-- Define readmissions
--   - first overdose readmission within 90 days
,readmissions AS (
    SELECT
        first_encounter.patient_id
        ,first_encounter.encounter_id AS first_encounter_id
        ,first_encounter.hospital_encounter_date AS first_encounter_date
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
        ,first_encounter.hospital_encounter_date
)
-- select count(*), count(distinct first_encounter_id) from readmissions;


-- Final SELECT
--   - aggregate to one row per patient_id + encounter_id
--   - compute indicator and count columns
,drug_overdose_cohort AS (
    
    SELECT
        cohort.patient_id
        ,cohort.encounter_id
        ,cohort.hospital_encounter_date
        ,cohort.age_at_visit
        
        ,CASE
            WHEN cohort.deathdate IS NULL THEN 0
            WHEN cohort.deathdate BETWEEN cohort.hospital_encounter_date AND cohort.encounter_end_date THEN 1
            ELSE 0
        END AS death_at_visit_ind

        ,COUNT(
                DISTINCT CAST(current_meds.medication_code AS VARCHAR) 
                || '|' || CAST(current_meds.medication_start_date AS VARCHAR)

        ) AS count_current_meds
        
        ,CASE
            WHEN current_opioids.opioid_code IS NOT NULL THEN 1
            ELSE 0
        END AS current_opioid_ind

        ,CASE
            WHEN readmissions.first_readmission_date IS NULL THEN 0
            ELSE 1
        END AS readmission_90_day_ind

        ,CASE
            WHEN readmissions.first_readmission_date IS NULL THEN 0
            WHEN readmissions.first_readmission_date
                <= CAST(cohort.encounter_end_date + INTERVAL '30 days' AS DATE)
            THEN 1
            ELSE 0
        END AS readmission_30_day_ind

        ,CASE
            WHEN readmissions.first_readmission_date IS NULL THEN NULL
            ELSE readmissions.first_readmission_date
        END AS first_readmission_date

    FROM
        cohort
    LEFT JOIN
        current_meds ON cohort.encounter_id = current_meds.encounter_id
    LEFT JOIN
        current_opioids ON cohort.encounter_id = current_opioids.encounter_id
    LEFT JOIN
        readmissions
            ON cohort.patient_id = readmissions.patient_id
            AND cohort.encounter_id = readmissions.first_encounter_id

    GROUP BY 
        cohort.patient_id
        ,cohort.encounter_id
        ,cohort.hospital_encounter_date
        ,cohort.age_at_visit
        ,cohort.deathdate
        ,cohort.encounter_end_date
        ,current_opioids.opioid_code
        ,readmissions.first_readmission_date
    )

SELECT * FROM drug_overdose_cohort


;



-- select count(*) over() partition by(patient_id) ;


