-- ==============================================================================
-- 10_normalize_sources.sql
-- Purpose:
--   Normalize raw CSV sources into typed, analysis-ready TEMP VIEWs.
--   - Convert 'NA' placeholders to NULL (where applicable)
--   - Cast date/timestamp fields to DATE
--   - Deduplicate known-duplicated sources (medications)
--
-- Output:
--   TEMP VIEWs used by downstream pipeline steps:
--     - encounters
--     - medications
--     - patients
--
-- Notes:
--   Keep this file limited to ingestion + typing + light normalization only.
--
-- Instructions:
--   Run duckdb from pipieline/ directory
--   duckdb commands from inside pipeline/ should be as follows:
--   .read 10_normalize_sources.sql
--   .read 20_build_cohort.sql
--   .read test/<test_name>
-- ==============================================================================

-- ==============================================================================
-- Dataset selector -- toggle between sample and prod data
-- ==============================================================================
--CREATE OR REPLACE MACRO dataset_root() AS '../../datasets/sample';
 CREATE OR REPLACE MACRO dataset_root() AS '../../datasets/prod';

-- ==============================================================================
-- CREATE OR REPLACE TEMP VIEW encounters
--   - patient, id, start (DATE), stop (DATE), reasondescription
--   - encounters.csv START/STOP are timestamps → parse TIMESTAMP → cast to DATE
--   - 'NA' → NULL before casting
-- ==============================================================================
CREATE OR REPLACE TEMP VIEW encounters AS
WITH encounters_src AS (
    SELECT *
    FROM read_csv_auto(
        dataset_root() || '/encounters.csv'
        ,SAMPLE_SIZE = -1
        ,NULLSTR = 'NA'
    )
)
SELECT DISTINCT
    "PATIENT" AS patient_id
    ,"Id" AS encounter_id
    ,"CODE" AS encounter_code -- used for tests, not intended for final output
    ,"DESCRIPTION" as encounter_description -- used for tests, not intended for final output

    -- for testing only:
    -- ,TRY_CAST(NULLIF("START", 'NA') AS TIMESTAMP) AS start
    -- ,TRY_CAST(NULLIF("STOP",  'NA') AS TIMESTAMP) AS stop

    ,CAST("START" AS TIMESTAMP) AS encounter_start_timestamp
    ,CAST("STOP" AS TIMESTAMP) AS encounter_stop_timestamp
    ,"REASONDESCRIPTION" AS encounter_reason
FROM encounters_src
;

-- ==============================================================================
-- CREATE OR REPLACE TEMP VIEW medications
--   - patient, encounter, code, description, start (DATE), stop (DATE | NULL)
--   - known duplicate rows → SELECT DISTINCT on full row
--   - 'NA' handled via NULLSTR and/or TRY_CAST for nullable date fields
-- ==============================================================================
CREATE OR REPLACE TEMP VIEW medications AS
WITH medications_src AS (
    SELECT *
    FROM read_csv_auto(
        dataset_root() || '/medications.csv'
        ,SAMPLE_SIZE = -1
        ,NULLSTR = 'NA'
        ,types = {
            'CODE':'VARCHAR'
        }
    )
)

SELECT DISTINCT
    "PATIENT" AS patient_id
    ,"ENCOUNTER" AS encounter_id
    ,"CODE" AS medication_code
    ,"DESCRIPTION" AS medication_description
    ,CAST("START" AS DATE) AS medication_start_date -- these fields are provided in date format
    ,CAST("STOP"  AS DATE) AS medication_stop_date -- we only cast them as date in case read_csv_auto chose the wrong type
FROM medications_src
;

-- ==============================================================================
-- CREATE OR REPLACE TEMP VIEW patients
--   - id, birthdate (DATE), deathdate (DATE | NULL)
--   - deathdate contains 'NA' → NULL → CAST
-- ==============================================================================
CREATE OR REPLACE TEMP VIEW patients AS
SELECT
    "Id" as patient_id
    ,CAST("BIRTHDATE" AS DATE) AS birthdate
    ,CAST("DEATHDATE" AS DATE) AS deathdate
FROM read_csv_auto(
    dataset_root() || '/patients.csv'
    ,SAMPLE_SIZE = -1
    ,NULLSTR = 'NA'
);