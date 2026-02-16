-- ============================================================
-- 02_recon_counts.sql
-- Purpose:
--   Compares final counts from overdose_cohort to expected counts 
--     from source files
-- PASS:
--   0 rows returned.
-- ============================================================

WITH expected AS (
    SELECT COUNT(*) AS expected_count
    FROM encounters
    INNER JOIN patients
        ON patients.patient_id = encounters.patient_id
    WHERE 1 = 1
        AND encounters.encounter_reason = 'Drug overdose'
        AND encounters.encounter_start_timestamp >= TIMESTAMP '1999-07-16 00:00:00' -- AFTER 7/15
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
,actual AS (
    SELECT COUNT(*) AS actual_count
    FROM overdose_cohort
)
SELECT
    expected.expected_count
    ,actual.actual_count
FROM expected
CROSS JOIN actual
WHERE expected.expected_count <> actual.actual_count;
