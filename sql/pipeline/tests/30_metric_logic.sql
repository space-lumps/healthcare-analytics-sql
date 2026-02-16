-- ============================================================
-- 30_metric_logic.sql
-- Purpose:
--   Validate derived metric logic against sources.
-- PASS condition:
--   0 rows returned in each test.
-- ============================================================

-- 1) death_at_visit_ind must be 0/1 and consistent with patients.deathdate
WITH base AS (
    SELECT
        overdose_cohort.patient_id
        ,overdose_cohort.encounter_id
        ,overdose_cohort.encounter_start_timestamp
        ,encounters.encounter_stop_timestamp
        ,patients.deathdate
        ,overdose_cohort.death_at_visit_ind
    FROM overdose_cohort
    INNER JOIN patients
        ON patients.patient_id = overdose_cohort.patient_id
    INNER JOIN encounters
        ON encounters.encounter_id = overdose_cohort.encounter_id
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
            AND base.deathdate BETWEEN CAST(base.encounter_start_timestamp AS DATE) AND CAST(base.encounter_stop_timestamp AS DATE)
            AND base.death_at_visit_ind <> 1
        )
    );

-- 2) current_opioid_ind implies at least one qualifying "current med" with opioid token match
--    (This checks "no false positives" for opioid flag.)
WITH cohort_dates AS (
    SELECT
        overdose_cohort.patient_id
        ,overdose_cohort.encounter_id
        ,overdose_cohort.encounter_start_timestamp
    FROM overdose_cohort
)
,opioid_hits AS (
    SELECT DISTINCT
        cohort_dates.patient_id
        ,cohort_dates.encounter_id
    FROM cohort_dates
    INNER JOIN medications
        ON medications.patient_id = cohort_dates.patient_id
    WHERE 1 = 1
        AND medications.medication_start_date < CAST(cohort_dates.encounter_start_timestamp AS DATE)
        AND (
            medications.medication_stop_date IS NULL
            OR  medications.medication_stop_date >= CAST(cohort_dates.encounter_start_timestamp AS DATE)
        )
        AND (
            LOWER(medications.medication_description) LIKE '%hydromorphone%'
            OR  LOWER(medications.medication_description) LIKE '%fentanyl%'
            OR  LOWER(medications.medication_description) LIKE '%oxycodone-acetaminophen%'
        )
)
SELECT
    overdose_cohort.patient_id
    ,overdose_cohort.encounter_id
    ,overdose_cohort.current_opioid_ind
FROM overdose_cohort
LEFT JOIN opioid_hits
    ON opioid_hits.patient_id = overdose_cohort.patient_id
    AND opioid_hits.encounter_id = overdose_cohort.encounter_id
WHERE 1 = 1
    AND overdose_cohort.current_opioid_ind = 1
    AND opioid_hits.encounter_id IS NULL;

-- 3) readmission_30_day_ind cannot be 1 if readmission_90_day_ind is 0
SELECT
    overdose_cohort.patient_id
    ,overdose_cohort.encounter_id
    ,overdose_cohort.readmission_90_day_ind
    ,overdose_cohort.readmission_30_day_ind
FROM overdose_cohort
WHERE 1 = 1
    AND overdose_cohort.readmission_30_day_ind = 1
    AND overdose_cohort.readmission_90_day_ind = 0;

-- 4) first_readmission_date must be null iff readmission_90_day_ind = 0
SELECT
    overdose_cohort.patient_id
    ,overdose_cohort.encounter_id
    ,overdose_cohort.readmission_90_day_ind
    ,overdose_cohort.first_readmission_timestamp
FROM overdose_cohort
WHERE 1 = 1
    AND (
        (overdose_cohort.readmission_90_day_ind = 0 AND overdose_cohort.first_readmission_timestamp IS NOT NULL)
        OR
        (overdose_cohort.readmission_90_day_ind = 1 AND overdose_cohort.first_readmission_timestamp IS NULL)
    );
