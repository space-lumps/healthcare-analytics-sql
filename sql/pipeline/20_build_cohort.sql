-- ============================================================
-- 20_build_cohort.sql
-- Purpose:
--   Build an analysis-ready cohort of drug overdose hospital encounters.
--
-- Cohort criteria:
--   - encounters.reasondescription = 'Drug overdose'
--   - encounter start date > 1999-07-15
--   - age at encounter between 18 and 35 (inclusive)
--
-- Metrics produced (one row per patient_id + encounter_id):
--   - death_at_visit_ind
--   - count_current_meds
--   - current_opioid_ind
--   - readmission_90_day_ind
--   - readmission_30_day_ind
--   - first_readmission_date
--
-- Output:
--   Final SELECT returning the cohort at patient_id + encounter_id grain
--
-- Notes:
--   - Requires 10_normalize_sources.sql to be executed first
--     (encounters, medications, patients TEMP VIEWs must exist)
-- ============================================================

-- Define qualifying_encounters
--   - filter encounters to drug overdose + date threshold

-- Define cohort
--   - join patients
--   - compute age_at_visit
--   - apply age filter

-- Define current_meds
--   - medications active at encounter start

-- Define opioids_list
--   - keyword/token list for opioid identification

-- Define current_opioids
--   - subset of current_meds matching opioid tokens

-- Define readmissions
--   - first overdose readmission within 90 days

-- Final SELECT
--   - aggregate to one row per patient_id + encounter_id
--   - compute indicator and count columns
