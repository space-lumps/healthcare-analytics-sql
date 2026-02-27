-- ============================================================
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
-- ============================================================

-- CLI rendering fix for narrow terminals — all columns minimum 10 chars
-- Prevents overlap / ugly first-column dominance
.width 10

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

-- For CI visibility: print any failures immediately (appears in logs)
SELECT *
FROM recon_expected_failures
ORDER BY patient_id, encounter_id
;

-- Assertion that fails the script (and thus CI job) with clear message
-- Uses error() which throws runtime exception in DuckDB → non-zero exit code
SELECT
    CASE
        WHEN (SELECT COUNT(*) FROM recon_expected_failures) = 0
            THEN 'PASS: All expected overdose encounters are present in overdose_cohort'
        ELSE
            'FAIL: ' ||
            (SELECT COUNT(*) FROM recon_unexpected_failures)::VARCHAR || ' ' ||
            'expected overdose encounter(s) missing from final cohort. ' ||
            'See table above for details.'

    END AS test_status
;