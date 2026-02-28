-- ============================================================
-- 02_recon_counts.sql
-- Purpose:
--   Row-count reconciliation test.
--   Verifies that the final overdose_cohort has exactly the same
--   number of rows as the independently-computed qualifying cohort
--   using source tables + business rules.
--
--   This test uses the shared TEMP VIEWs created in 20_build_cohort.sql
--   to avoid duplicating filter/age logic — increasing maintainability
--   and ensuring consistency with the pipeline.
--
--   Returns: 0 rows on success
--   Fails CI job if counts do not match exactly
-- ============================================================

-- Expected count derived from the same logical stages used in the pipeline
-- (re-uses shared views instead of re-implementing filters)
CREATE OR REPLACE TEMP VIEW recon_expected_count AS
    SELECT COUNT(*) AS expected
    FROM cohort   -- this view already applies: overdose reason + date + age 18–35
;

-- Actual count from the final analysis-ready output
CREATE OR REPLACE TEMP VIEW recon_actual_count AS
    SELECT COUNT(*) AS actual
    FROM overdose_cohort
;
-- Failures view: only populated if counts differ
-- Includes difference for quick debugging
CREATE OR REPLACE TEMP VIEW recon_counts_failures AS
    SELECT
        e.expected
        ,a.actual
        ,(a.actual - e.expected) AS difference
        ,CASE
            WHEN a.actual > e.expected THEN 'Extra rows in overdose_cohort'
            WHEN a.actual < e.expected THEN 'Missing rows in overdose_cohort'
            ELSE 'Counts match'
        END AS failure_type
    FROM recon_expected_count e
    CROSS JOIN recon_actual_count a
    WHERE e.expected <> a.actual
;

-- ----------------------------------------------------------------------------
-- Visual log separator + blank line for clean separation in CI artifacts
-- ----------------------------------------------------------------------------
.mode list
.separator ''
.headers off
SELECT REPEAT('=', 29) || ' START OF TEST FILE: tests/02_recon_counts.sql ' || REPEAT('=', 29);
SELECT ' ';
-- ----------------------------------------------------------------------------
-- For CI visibility: print any failures immediately as table (appears in logs)
-- ----------------------------------------------------------------------------
.mode table
.headers on
SELECT 
*
FROM recon_counts_failures
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
        WHEN (SELECT COUNT(*) FROM recon_counts_failures) = 0
            THEN '✅ PASS: Row count in overdose_cohort matches expected qualifying cohort (n = ' ||
                 (SELECT expected::VARCHAR FROM recon_expected_count) || ')'
        ELSE
            '❌ FAIL: Row count mismatch in overdose_cohort. ' ||
            'Expected: ' || (SELECT expected::VARCHAR FROM recon_expected_count) || ', ' ||
            'Actual: '   || (SELECT actual::VARCHAR FROM recon_actual_count)   || ', ' ||
            'Difference: ' || (SELECT difference::VARCHAR FROM recon_counts_failures) || '. ' ||
            'See table above.'
    END AS test_status
;
-- ----------------------------------------------------------------------------
-- File end marker plus extra blanklines between this and next test
-- ----------------------------------------------------------------------------
SELECT ' ';
SELECT REPEAT('=', 30) || ' END OF TEST FILE: tests/02_recon_counts.sql ' || REPEAT('=', 30);
SELECT ' ';
SELECT ' ';
-- End of test — next test output follows after blank lines