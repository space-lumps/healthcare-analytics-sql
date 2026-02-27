-- ============================================================
-- 30_metric_logic.sql
-- Purpose:
--   Validate core derived metrics in overdose_cohort against source logic:
--     1. death_at_visit_ind consistent with deathdate and encounter dates
--     2. current_opioid_ind = 1 only when at least one active opioid match exists
--     3. readmission_30_day_ind cannot be 1 if readmission_90_day_ind = 0
--     4. first_readmission_timestamp null iff readmission_90_day_ind = 0
--
--   These checks catch logic bugs in metric derivation.
-- ============================================================

-- CLI rendering fix for narrow terminals — minimum column width
-- Prevents overlap / ugly first-column dominance
.width 10
-- Violation code lookup (full descriptions in one place)
CREATE OR REPLACE TEMP VIEW violation_lookup AS
    SELECT 'death_ind_inc'    AS code, 'death_at_visit_ind inconsistent with deathdate or encounter dates' AS description UNION ALL
    SELECT 'opioid_false_pos' AS code, 'current_opioid_ind = 1 but no active opioid match found in medications' AS description UNION ALL
    SELECT 'read30_no90'      AS code, 'readmission_30_day_ind = 1 but readmission_90_day_ind = 0' AS description UNION ALL
    SELECT 'read_date_null'   AS code, 'first_readmission_timestamp nullity inconsistent with readmission_90_day_ind' AS description
;
-- 1) death_at_visit_ind logic violations
CREATE OR REPLACE TEMP VIEW death_ind_violations AS
    SELECT
        oc.patient_id
        ,oc.encounter_id
        ,oc.death_at_visit_ind
        ,p.deathdate
        ,'death_ind_inc' as violation_code
    FROM overdose_cohort oc
    INNER JOIN patients p ON p.patient_id = oc.patient_id
    INNER JOIN encounters e ON e.encounter_id = oc.encounter_id
    WHERE oc.death_at_visit_ind NOT IN (0, 1)
       OR (p.deathdate IS NULL AND oc.death_at_visit_ind <> 0)
       OR (p.deathdate IS NOT NULL
           AND p.deathdate BETWEEN CAST(oc.encounter_start_timestamp AS DATE)
                               AND CAST(e.encounter_stop_timestamp AS DATE)
           AND oc.death_at_visit_ind <> 1)
;

-- 2) current_opioid_ind = 1 but no matching active opioid found
CREATE OR REPLACE TEMP VIEW opioid_ind_violations AS
    SELECT
        oc.patient_id
        ,oc.encounter_id
        ,oc.current_opioid_ind
        ,'opioid_false_pos' as violation_code
    FROM overdose_cohort oc
    LEFT JOIN (
        SELECT DISTINCT m.patient_id, oc2.encounter_id
        FROM medications m
        INNER JOIN overdose_cohort oc2 ON oc2.patient_id = m.patient_id
        WHERE m.medication_start_date < CAST(oc2.encounter_start_timestamp AS DATE)
          AND (m.medication_stop_date IS NULL
               OR m.medication_stop_date >= CAST(oc2.encounter_start_timestamp AS DATE))
          AND (LOWER(m.medication_description) LIKE '%hydromorphone%'
               OR LOWER(m.medication_description) LIKE '%fentanyl%'
               OR LOWER(m.medication_description) LIKE '%oxycodone-acetaminophen%')
    ) opioid_hits ON opioid_hits.patient_id = oc.patient_id
                 AND opioid_hits.encounter_id = oc.encounter_id
    WHERE oc.current_opioid_ind = 1
      AND opioid_hits.encounter_id IS NULL -- LEFT JOIN + IS NULL anti-join pattern to detect missing matches
;

-- 3) readmission_30_day_ind = 1 but readmission_90_day_ind = 0
CREATE OR REPLACE TEMP VIEW readmission_30_violations AS
    SELECT
        patient_id
        ,encounter_id
        ,readmission_90_day_ind
        ,readmission_30_day_ind
        ,'read30_no90' AS violation_code
    FROM overdose_cohort
    WHERE readmission_30_day_ind = 1
      AND readmission_90_day_ind = 0
;

-- 4) first_readmission_timestamp nullity inconsistent with readmission_90_day_ind
CREATE OR REPLACE TEMP VIEW readmission_date_violations AS
    SELECT
        patient_id
        ,encounter_id
        ,readmission_90_day_ind
        ,first_readmission_timestamp
        ,'read_date_null' AS violation_code
    FROM overdose_cohort
    WHERE (readmission_90_day_ind = 0 AND first_readmission_timestamp IS NOT NULL)
       OR (readmission_90_day_ind = 1 AND first_readmission_timestamp IS NULL)
;

-- Combine violations – only short code for compact main table
CREATE OR REPLACE TEMP VIEW metric_violations AS
    SELECT patient_id, encounter_id, violation_code FROM death_ind_violations
    UNION ALL 
    SELECT patient_id, encounter_id, violation_code FROM opioid_ind_violations
    UNION ALL 
    SELECT patient_id, encounter_id, violation_code FROM readmission_30_violations
    UNION ALL 
    SELECT patient_id, encounter_id, violation_code FROM readmission_date_violations
;

-- Diagnostic output: violations if any (empty on success) – short codes for narrow columns
SELECT
    patient_id
    ,encounter_id
    ,violation_code
FROM metric_violations
ORDER BY violation_code, patient_id, encounter_id
;

-- Description table: full descriptions for each violation type found in this run
-- (empty if no violations; helps logs/reviewers without cluttering main table)
SELECT DISTINCT
    vl.code AS violation_code
    ,vl.description
FROM metric_violations mv
INNER JOIN violation_lookup vl ON vl.code = mv.violation_code
ORDER BY vl.code
;

-- Final result: short PASS/FAIL message
SELECT
    CASE
        WHEN (SELECT COUNT(*) FROM metric_violations) = 0 THEN
            'PASS: All derived metrics consistent with source logic'
        ELSE
            'FAIL: Metric logic violations (' ||
            (SELECT COUNT(*)::VARCHAR FROM metric_violations) ||
            ' rows). See tables above.'
    END AS test_status
;