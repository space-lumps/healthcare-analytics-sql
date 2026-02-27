-- ============================================================
-- 10_schema.sql
-- Purpose:
--   Schema sanity test: Verify that all expected columns in overdose_cohort
--   exist, are selectable, and can be queried without runtime errors.
--
--   This is a critical gate test — if it fails, downstream analysis is invalid.
-- ============================================================

-- PASS condition:
--   - SELECT executes successfully (no BinderError, CatalogError, etc.)
--   - Final PASS message prints at end of output

-- FAIL condition:
--   - DuckDB throws runtime error (e.g. Binder Error: Column "xyz" not found)
--   - Execution stops immediately — no PASS message appears
--   - In CI/logs: error message + file name signals failure
--   - CRITICAL: This is the ONLY test that intentionally hard-fails the CI job on error.
--     Schema breakage makes downstream tests meaningless → pipeline stops early.
--   - All other tests use string 'PASS:' / 'FAIL:' output to allow full serial reporting.
-- ============================================================

-- CLI rendering fix for narrow terminals — all columns minimum 10 chars
-- Prevents overlap / ugly first-column dominance
.width 10

-- Attempt to select every expected column from overdose_cohort
-- If any column is missing or the view doesn't exist, DuckDB throws here
CREATE OR REPLACE TEMP VIEW schema_smoke_test AS
    SELECT
        patient_id
        ,encounter_id
        ,encounter_start_timestamp AS enc_start
        ,encounter_stop_timestamp AS enc_stop
        ,age_at_visit
        ,death_at_visit_ind
        ,count_current_meds
        ,current_opioid_ind
        ,readmission_90_day_ind AS read_90_day
        ,readmission_30_day_ind AS read_30_day
        ,first_readmission_timestamp AS first_readmission
    FROM overdose_cohort
    LIMIT 1
;

-- Trigger the check with a zero-row select (we only care about execution)
SELECT * FROM schema_smoke_test LIMIT 1;
-- If execution reaches this point → all columns are present and selectable
SELECT 'PASS: All expected columns present and selectable in overdose_cohort' AS test_status;