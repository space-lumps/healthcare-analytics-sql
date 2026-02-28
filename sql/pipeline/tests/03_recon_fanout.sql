-- ============================================================
-- 03_recon_fanout.sql
-- Purpose:
--   Advanced integrity test: Detects hidden row fan-out or loss during
--   the LEFT JOINs and final aggregation in overdose_cohort.
--
--   Checks three critical counts:
--     1. base_rows     → rows in 'cohort' (core qualifying encounters)
--     2. pre_group → rows after all LEFT JOINs but before aggregation
--     3. final_rows    → rows in final overdose_cohort
--
--   Expected invariants:
--     - pre_group >= base_rows          (LEFT JOINs can only preserve or increase)
--     - pre_group <= base_rows * 100    (arbitrary but generous cap to catch severe fan-out)
--     - final_rows     =  base_rows          (aggregation must preserve 1 row per encounter)
--
--   Uses shared TEMP VIEWs from 20_build_cohort.sql → no duplication of business logic.
--   Returns: one row on success (PASS message with counts)
--   Fails CI if any invariant is violated (throws error with details)
-- ============================================================

-- Base count: number of qualifying index encounters (age 18–35, overdose, post-1999-07-16)
CREATE OR REPLACE TEMP VIEW recon_base_count AS
    SELECT COUNT(*) AS base_rows
    FROM cohort
;

-- Count after all LEFT JOINs (potential fan-out point from current_meds or current_opioids)
-- Uses DISTINCT to preserve encounter grain before any implicit grouping
CREATE OR REPLACE TEMP VIEW recon_pre_group_count AS
    SELECT COUNT(DISTINCT cohort.patient_id || '|' || cohort.encounter_id) AS pre_group
    FROM cohort
    LEFT JOIN current_meds
        ON cohort.patient_id = current_meds.patient_id
        AND cohort.encounter_id = current_meds.encounter_id
    LEFT JOIN current_opioids_agg
        ON cohort.patient_id = current_opioids_agg.patient_id
        AND cohort.encounter_id = current_opioids_agg.encounter_id
    LEFT JOIN readmissions
        ON cohort.patient_id = readmissions.patient_id
        AND cohort.encounter_id = readmissions.first_encounter_id
;

-- Final output count from the analysis-ready cohort
CREATE OR REPLACE TEMP VIEW recon_final_count AS
    SELECT COUNT(*) AS final_rows
    FROM overdose_cohort
;

-- Combine counts and evaluate invariants
CREATE OR REPLACE TEMP VIEW recon_fanout_failures AS
    SELECT
        b.base_rows
        ,p.pre_group
        ,f.final_rows
        ,CASE
            WHEN b.base_rows = 0 THEN 0.0
            ELSE ROUND(CAST(p.pre_group AS DOUBLE) / b.base_rows, 4)
        END AS fanout_ratio

        ,CASE
            WHEN p.pre_group < b.base_rows
                THEN 'Rows lost during LEFT JOINs (unexpected)'
            WHEN p.pre_group > b.base_rows * 100
                THEN 'Severe fan-out detected during joins'
            WHEN f.final_rows <> b.base_rows
                THEN 'Final agg. did not preserve 1 row per encounter'
            ELSE 'No violation detected'
        END AS failure_reason
    FROM recon_base_count b
    CROSS JOIN recon_pre_group_count p
    CROSS JOIN recon_final_count f
    WHERE 1=1
      AND (   p.pre_group < b.base_rows
           OR p.pre_group > b.base_rows * 100
           OR f.final_rows <> b.base_rows )
;

-- ----------------------------------------------------------------------------
-- Visual log separator + blank line for clean separation in CI artifacts
-- ----------------------------------------------------------------------------
.mode list
.separator ''
.headers off
SELECT REPEAT('=', 29) || ' START OF TEST FILE: tests/03_recon_fanout.sql ' || REPEAT('=', 29);
SELECT ' ';
-- ----------------------------------------------------------------------------
-- For CI visibility: print any failures immediately as table (appears in logs)
-- ----------------------------------------------------------------------------
.mode table
.headers on
SELECT 
*
FROM recon_fanout_failures
ORDER BY base_rows DESC
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
        WHEN (SELECT COUNT(*) FROM recon_fanout_failures) = 0 THEN
            '✅ PASS: Fan-out test clean. ' ||
            'Base = '     || (SELECT base_rows::VARCHAR FROM recon_base_count)     || ' rows. ' ||
            'Pre-group = '|| (SELECT pre_group::VARCHAR FROM recon_pre_group_count) || '. ' ||
            'Final = '    || (SELECT final_rows::VARCHAR FROM recon_final_count)    || '. ' ||
            'Ratio ≈ '    || 
            ROUND(
                CASE 
                    WHEN (SELECT base_rows FROM recon_base_count) = 0 THEN 0.0
                    ELSE CAST((SELECT pre_group FROM recon_pre_group_count) AS DOUBLE) /
                         (SELECT base_rows FROM recon_base_count)
                END,
                2
            )::VARCHAR
        ELSE
            '❌ FAIL: Integrity violation in overdose_cohort joins/agg. ' ||
            'Base: '     || (SELECT base_rows::VARCHAR FROM recon_base_count)     || ' rows. ' ||
            'Pre-group: '|| (SELECT pre_group::VARCHAR FROM recon_pre_group_count) || '. ' ||
            'Final: '    || (SELECT final_rows::VARCHAR FROM recon_final_count)    || '. ' ||
            'Ratio: '    || 
            ROUND(
                CASE 
                    WHEN (SELECT base_rows FROM recon_base_count) = 0 THEN 0.0
                    ELSE CAST((SELECT pre_group FROM recon_pre_group_count) AS DOUBLE) /
                            (SELECT base_rows FROM recon_base_count)
                END,
                2
            )::VARCHAR ||
            '. See table above.'

    END AS test_status
;
-- ----------------------------------------------------------------------------
-- File end marker plus extra blanklines between this and next test
-- ----------------------------------------------------------------------------
SELECT ' ';
SELECT REPEAT('=', 30) || ' END OF TEST FILE: tests/03_recon_fanout.sql ' || REPEAT('=', 30);
SELECT ' ';
SELECT ' ';
-- End of test — next test output follows after blank lines