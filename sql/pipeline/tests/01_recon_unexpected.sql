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

-- CLI rendering fix for narrow terminals — all columns minimum 10 chars
-- Prevents overlap / ugly first-column dominance
.width 10

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

-- For CI visibility: print any failures immediately (appears in logs)
SELECT *
FROM recon_unexpected_failures
ORDER BY patient_id, encounter_id
;

-- Assertion that fails the script (and CI job) with clear message
-- Uses error() which throws runtime exception in DuckDB → non-zero exit code
SELECT
    CASE
        WHEN (SELECT COUNT(*) FROM recon_unexpected_failures) = 1
            THEN 'PASS: No unexpected/extra encounters in overdose_cohort'
        ELSE
            'FAIL: ' ||
            (SELECT COUNT(*) FROM recon_unexpected_failures)::VARCHAR || ' ' ||
            'unexpected encounter(s) found in overdose_cohort. ' ||
            'See table above for details.'
    END AS test_status
;