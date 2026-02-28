-- ==============================================================================
-- 04_recon_no_na.sql
-- Purpose:
--   Ensure no literal 'NA' strings leaked into key columns after ingestion,
--   normalization, and type casting.
--
--   This is a data quality smoke test — should return ZERO rows if clean.
--   Any row returned indicates a problem in upstream data cleaning / casting.
--
--   Covers main source tables + final overdose_cohort.
-- ==============================================================================

CREATE OR REPLACE TEMP VIEW na_violations AS

    -- encounters checks
    SELECT 'encounters' AS table_name, 'patient_id' AS column_name, COUNT(*) AS na_row_count
    FROM encounters
    WHERE LOWER(TRIM(CAST(patient_id AS VARCHAR))) = 'na'

    UNION ALL SELECT 'encounters', 'encounter_id', COUNT(*)
    FROM encounters WHERE LOWER(TRIM(CAST(encounter_id AS VARCHAR))) = 'na'

    UNION ALL SELECT 'encounters', 'encounter_code', COUNT(*)
    FROM encounters WHERE encounter_code IS NOT NULL
        AND LOWER(TRIM(CAST(encounter_code AS VARCHAR))) = 'na'

    UNION ALL SELECT 'encounters', 'encounter_description', COUNT(*)
    FROM encounters WHERE encounter_description IS NOT NULL
        AND LOWER(TRIM(CAST(encounter_description AS VARCHAR))) = 'na'

    UNION ALL SELECT 'encounters', 'encounter_start_timestamp', COUNT(*)
    FROM encounters WHERE encounter_start_timestamp IS NOT NULL
        AND LOWER(TRIM(CAST(encounter_start_timestamp AS VARCHAR))) = 'na'

    UNION ALL SELECT 'encounters', 'encounter_stop_timestamp', COUNT(*)
    FROM encounters WHERE encounter_stop_timestamp IS NOT NULL
        AND LOWER(TRIM(CAST(encounter_stop_timestamp AS VARCHAR))) = 'na'

    UNION ALL SELECT 'encounters', 'encounter_reason', COUNT(*)
    FROM encounters WHERE encounter_reason IS NOT NULL
        AND LOWER(TRIM(CAST(encounter_reason AS VARCHAR))) = 'na'

    -- medications checks
    UNION ALL SELECT 'medications', 'patient_id', COUNT(*)
    FROM medications WHERE LOWER(TRIM(CAST(patient_id AS VARCHAR))) = 'na'

    UNION ALL SELECT 'medications', 'encounter_id', COUNT(*)
    FROM medications WHERE LOWER(TRIM(CAST(encounter_id AS VARCHAR))) = 'na'

    UNION ALL SELECT 'medications', 'medication_code', COUNT(*)
    FROM medications WHERE medication_code IS NOT NULL
        AND LOWER(TRIM(CAST(medication_code AS VARCHAR))) = 'na'

    UNION ALL SELECT 'medications', 'medication_description', COUNT(*)
    FROM medications WHERE medication_description IS NOT NULL
        AND LOWER(TRIM(CAST(medication_description AS VARCHAR))) = 'na'

    UNION ALL SELECT 'medications', 'medication_start_date', COUNT(*)
    FROM medications WHERE medication_start_date IS NOT NULL
        AND LOWER(TRIM(CAST(medication_start_date AS VARCHAR))) = 'na'

    UNION ALL SELECT 'medications', 'medication_stop_date', COUNT(*)
    FROM medications WHERE medication_stop_date IS NOT NULL
        AND LOWER(TRIM(CAST(medication_stop_date AS VARCHAR))) = 'na'

    -- patients checks
    UNION ALL SELECT 'patients', 'patient_id', COUNT(*)
    FROM patients WHERE LOWER(TRIM(CAST(patient_id AS VARCHAR))) = 'na'

    UNION ALL SELECT 'patients', 'birthdate', COUNT(*)
    FROM patients WHERE LOWER(TRIM(CAST(birthdate AS VARCHAR))) = 'na'

    UNION ALL SELECT 'patients', 'deathdate', COUNT(*)
    FROM patients WHERE LOWER(TRIM(CAST(deathdate AS VARCHAR))) = 'na'

    -- final cohort checks (if the view exists in session)
    UNION ALL SELECT 'overdose_cohort', 'patient_id', COUNT(*)
    FROM overdose_cohort WHERE LOWER(TRIM(CAST(patient_id AS VARCHAR))) = 'na'

    UNION ALL SELECT 'overdose_cohort', 'encounter_id', COUNT(*)
    FROM overdose_cohort WHERE LOWER(TRIM(CAST(encounter_id AS VARCHAR))) = 'na'

;

CREATE OR REPLACE TEMP VIEW final_output AS
    SELECT
        table_name
        ,column_name
        ,na_row_count
    FROM na_violations
    WHERE na_row_count > 0
    ORDER BY na_row_count DESC, table_name, column_name
;

-- ----------------------------------------------------------------------------
-- Visual log separator + blank line for clean separation in CI artifacts
-- ----------------------------------------------------------------------------
.mode list
.separator ''
.headers off
SELECT REPEAT('=', 30) || ' START OF TEST FILE: tests/04_recon_no_na.sql ' || REPEAT('=', 29);
SELECT ' ';
-- ----------------------------------------------------------------------------
-- For CI visibility: print any failures immediately as table (appears in logs)
-- ----------------------------------------------------------------------------
.mode table
.headers on
SELECT * FROM final_output;
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
        WHEN (SELECT COUNT(*) FROM final_output) = 0 THEN
            '✅ PASS: No "NA" string leaks detected in key columns across all tables'
        ELSE
            '❌ FAIL: "NA" string leaks detected in ' ||
            (SELECT COUNT(*)::VARCHAR FROM final_output) ||
            ' column(s). Total violation rows: ' ||
            (SELECT COALESCE(SUM(na_row_count), 0)::VARCHAR FROM final_output) ||
            '. See table above for details.'
    END AS test_status
;
-- ----------------------------------------------------------------------------
-- File end marker plus extra blanklines between this and next test
-- ----------------------------------------------------------------------------
SELECT ' ';
SELECT REPEAT('=', 31) || ' END OF TEST FILE: tests/04_recon_no_na.sql ' || REPEAT('=', 30);
SELECT ' ';
SELECT ' ';
-- End of test — next test output follows after blank lines