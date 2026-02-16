-- ============================================================
-- 06__source_reconciliation.sql
-- Purpose:
--   Validate cohort selection correctness vs source data.
-- ============================================================

-- Expected qualifying encounters from raw sources
WITH expected_encounters AS (
    SELECT
        encounters.patient_id
        ,encounters.encounter_id
    FROM encounters
    INNER JOIN patients
        ON patients.patient_id = encounters.patient_id
    WHERE 1 = 1
        AND encounters.encounter_reason = 'Drug overdose'
        AND encounters.encounter_start_timestamp > DATE '1999-07-15'
        AND (        
            EXTRACT(YEAR FROM encounters.encounter_start_timestamp)
            - EXTRACT(YEAR FROM patients.birthdate)
            - CASE
                WHEN
                    EXTRACT(MONTH FROM encounters.encounter_start_timestamp)
                        < EXTRACT(MONTH FROM patients.birthdate)
                    OR (
                        EXTRACT(MONTH FROM encounters.encounter_start_timestamp)
                            = EXTRACT(MONTH FROM patients.birthdate)
                        AND EXTRACT(DAY FROM encounters.encounter_start_timestamp)
                            < EXTRACT(DAY FROM patients.birthdate)
                    )
                THEN 1
                ELSE 0
            END  
        ) BETWEEN 18 AND 35
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
