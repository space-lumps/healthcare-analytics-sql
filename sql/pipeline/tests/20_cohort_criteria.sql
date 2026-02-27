-- ============================================================
-- 20_cohort_criteria.sql
-- Purpose:
--   Validate that every row in overdose_cohort satisfies the core inclusion criteria:
--     1. encounter_reason = 'Drug overdose' in source
--     2. encounter_start_timestamp > 1999-07-15
--     3. age_at_visit BETWEEN 18 AND 35 (inclusive)
--
--   These checks protect against silent filtering failures or incorrect derivations.
-- ============================================================

-- CLI rendering fix for narrow terminals — minimum column width
-- Prevents overlap / ugly first-column dominance
.width 10

-- 1) Encounter reason must be 'Drug overdose' in source
CREATE OR REPLACE TEMP VIEW invalid_reason AS
    SELECT
        oc.patient_id
        ,oc.encounter_id
        ,e.encounter_reason
        ,'Wrong encounter reason' AS violation_type
    FROM overdose_cohort oc
    INNER JOIN encounters e
        ON e.encounter_id = oc.encounter_id
    WHERE e.encounter_reason <> 'Drug overdose'
;

-- 2) Start timestamp must be after 1999-07-15
CREATE OR REPLACE TEMP VIEW invalid_date AS
    SELECT
        patient_id
        ,encounter_id
        ,encounter_start_timestamp
        ,'Start date too early' AS violation_type
    FROM overdose_cohort
    WHERE encounter_start_timestamp <= TIMESTAMP '1999-07-16 00:00:00'
;

-- 3) Age must be 18–35 inclusive
CREATE OR REPLACE TEMP VIEW invalid_age AS
    SELECT
        patient_id
        ,encounter_id
        ,age_at_visit
        ,'Age outside 18-35 range' AS violation_type
    FROM overdose_cohort
    WHERE age_at_visit NOT BETWEEN 18 AND 35
;

-- Combine all violations for reporting
CREATE OR REPLACE TEMP VIEW cohort_criteria_violations AS
    SELECT * FROM invalid_reason
    UNION ALL SELECT * FROM invalid_date
    UNION ALL SELECT * FROM invalid_age
;

-- Diagnostic output: show violating rows if any (empty table on success)
SELECT 
    patient_id
    ,encounter_id
    ,violation_type
FROM cohort_criteria_violations
ORDER BY violation_type, patient_id, encounter_id
;

-- Final result: short PASS/FAIL message
SELECT
    CASE
        WHEN (SELECT COUNT(*) FROM cohort_criteria_violations) = 0 THEN
            'PASS: All rows meet cohort criteria (reason, date, age)'
        ELSE
            'FAIL: Cohort criteria violations found (' ||
            (SELECT COUNT(*)::VARCHAR FROM cohort_criteria_violations) ||
            ' rows). See table above.'
    END AS test_status
;