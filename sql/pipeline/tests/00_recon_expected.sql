-- ============================================================================
-- 00_recon_expected.sql
-- Purpose:
--   Smoke / reconciliation test: Verify that EVERY encounter meeting
--   the core cohort business rules exists in the final overdose_cohort.
--
--   Business rules (independent source-of-truth check):
--     - encounter_reason         = 'Drug overdose'
--     - encounter_start_timestamp >= '1999-07-16 00:00:00'
--     - age at encounter         BETWEEN 18 AND 35 (inclusive)
--
--   Returns: 0 rows on success
--   Fails CI job if any expected encounter is missing
-- ============================================================================

-- Expected qualifying encounter keys derived directly from raw sources
-- (mirrors exact inclusion criteria — no dependency on pipeline views)
CREATE OR REPLACE TEMP VIEW recon_expected_qualifying_keys AS
    SELECT DISTINCT
        encounters.patient_id
        ,encounters.encounter_id
    FROM encounters
    INNER JOIN patients
        ON patients.patient_id = encounters.patient_id
    WHERE 1 = 1
        AND encounters.encounter_reason = 'Drug overdose'
        AND encounters.encounter_start_timestamp >= TIMESTAMP '1999-07-16 00:00:00'
        AND (
            EXTRACT(YEAR FROM encounters.encounter_start_timestamp)
            - EXTRACT(YEAR FROM patients.birthdate)
            - CASE
                WHEN EXTRACT(MONTH FROM encounters.encounter_start_timestamp) < EXTRACT(MONTH FROM patients.birthdate)
                  OR (EXTRACT(MONTH FROM encounters.encounter_start_timestamp) = EXTRACT(MONTH FROM patients.birthdate)
                      AND EXTRACT(DAY FROM encounters.encounter_start_timestamp) < EXTRACT(DAY FROM patients.birthdate))
                THEN 1
                ELSE 0
              END
        ) BETWEEN 18 AND 35
;

-- Final failures view: expected keys that are NOT present in overdose_cohort
CREATE OR REPLACE TEMP VIEW recon_expected_failures AS
    SELECT
        expected.patient_id
        ,expected.encounter_id
        ,'Missing from final overdose_cohort' AS failure_reason
    FROM recon_expected_qualifying_keys expected
    LEFT JOIN overdose_cohort actual
        ON actual.patient_id  = expected.patient_id
        AND actual.encounter_id = expected.encounter_id
    WHERE actual.encounter_id IS NULL
;

-- ----------------------------------------------------------------------------
-- Visual log separator + blank line for clean separation in CI artifacts
-- ----------------------------------------------------------------------------
.mode list
.separator ''
.headers off
SELECT REPEAT('=', 28) || ' START OF TEST FILE: tests/00_recon_expected.sql ' || REPEAT('=', 28);
SELECT ' ';
-- ----------------------------------------------------------------------------
-- For CI visibility: print any failures immediately as table (appears in logs)
-- ----------------------------------------------------------------------------
.mode table
.headers on
SELECT
*
FROM recon_expected_failures
ORDER BY patient_id, encounter_id
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
        WHEN (SELECT COUNT(*) FROM recon_expected_failures) = 0
            THEN '✅ PASS: All expected overdose encounters are present in overdose_cohort'
        ELSE
            '❌ FAIL: ' ||
            (SELECT COUNT(*) FROM recon_expected_failures)::VARCHAR || ' ' ||
            'expected overdose encounter(s) missing from final cohort. ' ||
            'See table above for details.'
    END AS test_status
;
-- ----------------------------------------------------------------------------
-- File end marker plus extra blanklines between this and next test
-- ----------------------------------------------------------------------------
SELECT ' ';
SELECT REPEAT('=', 29) || ' END OF TEST FILE: tests/00_recon_expected.sql ' || REPEAT('=', 29);
SELECT ' ';
SELECT ' ';
-- End of test — next test output follows after blank lines