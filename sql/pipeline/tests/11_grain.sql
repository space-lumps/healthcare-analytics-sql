-- ============================================================
-- 11_grain.sql
-- Purpose:
--   Enforce the correct grain and key integrity of overdose_cohort:
--     - No NULLs in primary keys (patient_id, encounter_id)
--     - Exactly one row per patient_id + encounter_id (no duplicates)
--
--   Protects against upstream join fan-out, aggregation mistakes,
--   or data loading issues that could silently duplicate or corrupt keys.
-- ============================================================

-- PASS condition:
--   - Both violation checks return 0 rows
--   - Final message shows PASS

-- FAIL condition:
--   - One or both checks return >0 rows
--   - Final message shows FAIL with violation count
--   - No runtime exceptions → test suite continues
-- ============================================================

-- 1) Check for NULL primary keys
CREATE OR REPLACE TEMP VIEW null_keys AS
    SELECT
        patient_id
        ,encounter_id
        ,'NULL primary key detected' AS violation_type
    FROM overdose_cohort
    WHERE patient_id IS NULL
       OR encounter_id IS NULL
;

-- 2) Check for duplicate keys (patient_id + encounter_id)
CREATE OR REPLACE TEMP VIEW duplicates AS
    SELECT
        patient_id
        ,encounter_id
        ,COUNT(*) AS row_count
        ,'Duplicate key' AS violation_type
    FROM overdose_cohort
    GROUP BY patient_id, encounter_id
    HAVING COUNT(*) > 1
;

-- Combine violations (now both have 4 columns)
CREATE OR REPLACE TEMP VIEW grain_violations AS
    SELECT
        patient_id
        ,encounter_id
        ,NULL::BIGINT AS row_count           -- NULL for NULL-key violations
        ,violation_type
    FROM null_keys

    UNION ALL

    SELECT
        patient_id
        ,encounter_id
        ,row_count
        ,violation_type
    FROM duplicates
;

-- ----------------------------------------------------------------------------
-- Visual log separator + blank line for clean separation in CI artifacts
-- ----------------------------------------------------------------------------
.mode list
.separator ''
.headers off
SELECT REPEAT('=', 33) || ' START OF TEST FILE: tests/11_grain.sql ' || REPEAT('=', 32);
SELECT ' ';
-- ----------------------------------------------------------------------------
-- For CI visibility: print any failures immediately as table (appears in logs)
-- ----------------------------------------------------------------------------
.mode table
.headers on
SELECT 
        patient_id
        ,encounter_id
        ,row_count
        ,violation_type
FROM grain_violations
ORDER BY violation_type, patient_id, encounter_id
;
-- ----------------------------------------------------------------------------
-- Final verdict line — outputs ✅ PASS or ❌ FAIL for easy log scanning
-- Uses plain text (no runtime error on FAIL) so all tests execute serially
-- CI workflow greps for 'FAIL:' to detect issues after the full run
-- ----------------------------------------------------------------------------
.mode list
.separator ''
.headers off
SELECT
    CASE
        WHEN (SELECT COUNT(*) FROM grain_violations) = 0 THEN
            '✅ PASS: overdose_cohort grain intact (no NULL keys, no duplicates).'
        ELSE
            '❌ FAIL: Grain violations in overdose_cohort (' ||
            (SELECT COUNT(*)::VARCHAR FROM grain_violations) ||
            ' rows). See table above.'
    END AS test_status
;
-- ----------------------------------------------------------------------------
-- File end marker plus extra blanklines between this and next test
-- ----------------------------------------------------------------------------
SELECT ' ';
SELECT REPEAT('=', 34) || ' END OF TEST FILE: tests/11_grain.sql ' || REPEAT('=', 33);
SELECT ' ';
SELECT ' ';
-- End of test — next test output follows after blank lines