-- ============================================================
-- 20_cohort_criteria.sql
-- Purpose:
--   Validate cohort criteria are satisfied in the final output.
-- PASS condition:
--   0 rows returned in each test.
-- ============================================================

-- 1) Encounter is actually a Drug overdose encounter in encounters source
SELECT
    overdose_cohort.patient_id
    ,overdose_cohort.encounter_id
    ,encounters.encounter_reason
FROM overdose_cohort
INNER JOIN encounters
    ON encounters.encounter_id = overdose_cohort.encounter_id
WHERE 1 = 1
    AND encounters.encounter_reason <> 'Drug overdose';

-- 2) Date threshold
SELECT
    overdose_cohort.patient_id
    ,overdose_cohort.encounter_id
    ,overdose_cohort.encounter_start_timestamp
FROM overdose_cohort
WHERE 1 = 1
    AND overdose_cohort.encounter_start_timestamp <= TIMESTAMP '1999-07-16 00:00:00';

-- 3) Age range (18–35 inclusive)
SELECT
    overdose_cohort.patient_id
    ,overdose_cohort.encounter_id
    ,overdose_cohort.age_at_visit
FROM overdose_cohort
WHERE 1 = 1
    AND overdose_cohort.age_at_visit NOT BETWEEN 18 AND 35;
