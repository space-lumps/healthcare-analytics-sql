-- ============================================================
-- 02__grain_and_uniqueness.sql
-- Purpose:
--   Enforce cohort grain + key integrity.
-- PASS condition:
--   0 rows returned in each test.
-- ============================================================

-- 1) Null keys
SELECT
    overdose_cohort.*
FROM overdose_cohort
WHERE 1 = 1
    AND overdose_cohort.patient_id IS NULL
    OR  overdose_cohort.encounter_id IS NULL;

-- 2) Duplicate patient_id + encounter_id
WITH dupes AS (
    SELECT
        overdose_cohort.patient_id
        ,overdose_cohort.encounter_id
        ,COUNT(*) AS row_count
    FROM overdose_cohort
    GROUP BY
        overdose_cohort.patient_id
        ,overdose_cohort.encounter_id
    HAVING COUNT(*) > 1
)
SELECT
    dupes.*
FROM dupes;
