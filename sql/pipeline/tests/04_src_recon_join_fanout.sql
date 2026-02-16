-- ============================================================
-- 07_src_recon_join_fanout.sql
-- Purpose:
--   Detect join fan-out that gets hidden by the final GROUP BY.
-- PASS:
--   0 rows returned.
-- ============================================================

WITH qualifying_encounters AS (
    SELECT
        encounters.patient_id
        ,encounters.encounter_id
        ,encounters.encounter_start_timestamp
        ,encounters.encounter_stop_timestamp
    FROM encounters
    WHERE 1 = 1
        AND encounters.encounter_reason = 'Drug overdose'
        AND encounters.encounter_start_timestamp >= TIMESTAMP '1999-07-16 00:00:00' -- AFTER 7/15

)
,cohort AS (
    SELECT
        qualifying_encounters.patient_id
        ,qualifying_encounters.encounter_id
        ,qualifying_encounters.encounter_start_timestamp
        ,qualifying_encounters.encounter_stop_timestamp
    FROM qualifying_encounters
    INNER JOIN patients
        ON patients.patient_id = qualifying_encounters.patient_id
    WHERE 1 = 1
        AND (        
            EXTRACT(YEAR FROM qualifying_encounters.encounter_start_timestamp)
            - EXTRACT(YEAR FROM patients.birthdate)
            - CASE
                WHEN
                    EXTRACT(MONTH FROM qualifying_encounters.encounter_start_timestamp)
                        < EXTRACT(MONTH FROM patients.birthdate)
                    OR (
                        EXTRACT(MONTH FROM qualifying_encounters.encounter_start_timestamp)
                            = EXTRACT(MONTH FROM patients.birthdate)
                        AND EXTRACT(DAY FROM qualifying_encounters.encounter_start_timestamp)
                            < EXTRACT(DAY FROM patients.birthdate)
                    )
                THEN 1
                ELSE 0
            END  
        ) BETWEEN 18 AND 35
)
,current_meds AS (
    SELECT
        cohort.patient_id
        ,cohort.encounter_id
        ,medications.medication_code
        ,medications.medication_description
        ,medications.medication_start_date
        ,medications.medication_stop_date
    FROM medications
    INNER JOIN cohort
        ON medications.patient_id = cohort.patient_id
    WHERE 1 = 1
        AND medications.medication_start_date < cohort.encounter_start_timestamp
        AND (
            medications.medication_stop_date IS NULL
            OR  medications.medication_stop_date >= cohort.encounter_start_timestamp
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
        ,MIN(readmit.encounter_start_timestamp) AS first_readmission_timestamp
    FROM cohort first_encounter
    INNER JOIN cohort readmit
        ON first_encounter.patient_id = readmit.patient_id
        AND readmit.encounter_start_timestamp > first_encounter.encounter_stop_timestamp
        AND readmit.encounter_start_timestamp
            <= CAST(first_encounter.encounter_stop_timestamp + INTERVAL '90 days' AS TIMESTAMP)
    GROUP BY
        first_encounter.patient_id
        ,first_encounter_id
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
