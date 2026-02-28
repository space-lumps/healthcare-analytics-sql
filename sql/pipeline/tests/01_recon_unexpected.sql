-- ============================================================
-- 01_recon_unexpected.sql
-- Purpose:
--   Reconciliation test: Ensure overdose_cohort contains ONLY encounters
--   that meet the inclusion criteria — no unexpected/extra rows.
--
--   Business rules (source-of-truth check):
--     - encounter_reason         = 'Drug overdose'
--     - encounter_start_timestamp >= '1999-07-16 00:00:00'
--     - age at encounter         BETWEEN 18 AND 35 (inclusive)
--
--   Returns: 0 rows on success
--   Fails CI job if any unexpected encounter is present
-- ============================================================

-- Expected qualifying encounter keys derived directly from raw sources
-- (exact same logic as in 00_recon_expected.sql for consistency)
CREATE OR REPLACE TEMP VIEW recon_expected_qualifying_keys AS
    SELECT DISTINCT
        encounters.patient_id,
        encounters.encounter_id
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

-- Final failures view: rows in overdose_cohort that do NOT match any expected key
CREATE OR REPLACE TEMP VIEW recon_unexpected_failures AS
    SELECT
        actual.patient_id,
        actual.encounter_id,
        'Unexpected row in overdose_cohort' AS failure_reason
    FROM overdose_cohort actual
    LEFT JOIN recon_expected_qualifying_keys expected
        ON expected.patient_id  = actual.patient_id
        AND expected.encounter_id = actual.encounter_id
    WHERE expected.encounter_id IS NULL
;

-- ----------------------------------------------------------------------------
-- Visual log separator + blank line for clean separation in CI artifacts
-- ----------------------------------------------------------------------------
.mode list
.separator ''
.headers off
SELECT REPEAT('=', 27) || ' START OF TEST FILE: tests/01_recon_unexpected.sql ' || REPEAT('=', 27);
SELECT ' ';
-- ----------------------------------------------------------------------------
-- For CI visibility: print any failures immediately as table (appears in logs)
-- ----------------------------------------------------------------------------
.mode table
.headers on
SELECT *
FROM recon_unexpected_failures
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
        WHEN (SELECT COUNT(*) FROM recon_unexpected_failures) = 0
            THEN '✅ PASS: No unexpected/extra encounters in overdose_cohort'
        ELSE
            '❌ FAIL: ' ||
            (SELECT COUNT(*) FROM recon_unexpected_failures)::VARCHAR || ' ' ||
            'unexpected encounter(s) found in overdose_cohort. ' ||
            'See table above for details.'
    END AS test_status
;
-- ----------------------------------------------------------------------------
-- File end marker plus extra blanklines between this and next test
-- ----------------------------------------------------------------------------
SELECT ' ';
SELECT REPEAT('=', 28) || ' END OF TEST FILE: tests/01_recon_unexpected.sql ' || REPEAT('=', 28);
SELECT ' ';
SELECT ' ';
-- End of test — next test output follows after blank lines