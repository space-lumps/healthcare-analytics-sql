-- ============================================================
-- 31_nulls_and_ranges.sql
-- Purpose:
--   Data quality checks for derived columns in overdose_cohort:
--     1. Indicator flags (death_at_visit_ind, current_opioid_ind, etc.) must be 0 or 1
--     2. count_current_meds must be non-negative integer (not NULL)
--     3. first_readmission_timestamp cannot be before encounter_start_timestamp
--
--   Catches invalid values, negative counts, or illogical timestamps.
-- ============================================================

-- CLI rendering fix for narrow terminals — minimum column width
-- Prevents overlap / ugly first-column dominance
.width 10

-- Violation code lookup (full descriptions in one place)
CREATE OR REPLACE TEMP VIEW violation_lookup AS
    SELECT 'ind_not_01'        AS code, 'Indicator flag not in (0, 1)'                              AS description UNION ALL
    SELECT 'count_neg_or_null' AS code, 'count_current_meds is NULL or negative'                    AS description UNION ALL
    SELECT 'read_date_before'  AS code, 'first_readmission_timestamp before encounter_start_timestamp' AS description
;

-- 1) Indicator flags must be 0 or 1
CREATE OR REPLACE TEMP VIEW ind_not_01_violations AS
    SELECT
        patient_id
        ,encounter_id
        ,'ind_not_01' AS violation_code
    FROM overdose_cohort
    WHERE death_at_visit_ind NOT IN (0, 1)
       OR current_opioid_ind NOT IN (0, 1)
       OR readmission_90_day_ind NOT IN (0, 1)
       OR readmission_30_day_ind NOT IN (0, 1)
;

-- 2) count_current_meds must be non-negative and not NULL
CREATE OR REPLACE TEMP VIEW count_neg_or_null_violations AS
    SELECT
        patient_id
        ,encounter_id
        ,'count_neg_or_null' AS violation_code
    FROM overdose_cohort
    WHERE count_current_meds IS NULL
       OR count_current_meds < 0
;

-- 3) first_readmission_timestamp cannot be before encounter date
CREATE OR REPLACE TEMP VIEW read_date_before_violations AS
    SELECT
        patient_id
        ,encounter_id
        ,'read_date_before' AS violation_code
    FROM overdose_cohort
    WHERE first_readmission_timestamp IS NOT NULL
      AND first_readmission_timestamp < encounter_start_timestamp
;

-- Combine violations – only short code for compact main table
CREATE OR REPLACE TEMP VIEW range_violations AS
    SELECT patient_id, encounter_id, violation_code FROM ind_not_01_violations
    UNION ALL
    SELECT patient_id, encounter_id, violation_code FROM count_neg_or_null_violations
    UNION ALL
    SELECT patient_id, encounter_id, violation_code FROM read_date_before_violations
;

-- Diagnostic output: violations if any (empty on success) – short codes only
SELECT
    patient_id
    ,encounter_id
    ,violation_code
FROM range_violations
ORDER BY violation_code, patient_id, encounter_id
;

-- Description table: full descriptions for each violation type found in this run
-- (empty if no violations; provides context without cluttering main table)
SELECT DISTINCT
    vl.code AS violation_code
    ,vl.description
FROM range_violations rv
INNER JOIN violation_lookup vl ON vl.code = rv.violation_code
ORDER BY vl.code
;

-- Final result: short PASS/FAIL message
SELECT
    CASE
        WHEN (SELECT COUNT(*) FROM range_violations) = 0 THEN
            'PASS: All range and null checks passed'
        ELSE
            'FAIL: Range/null violations found (' ||
            (SELECT COUNT(*)::VARCHAR FROM range_violations) ||
            ' rows). See tables above.'
    END AS test_status
;