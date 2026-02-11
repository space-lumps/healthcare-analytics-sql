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
CREATE OR REPLACE MACRO dataset_root() AS '../../datasets/sample';
-- CREATE OR REPLACE MACRO dataset_root() AS '../../datasets/prod';


-- ==============================================================================
-- CREATE OR REPLACE TEMP VIEW encounters
--   - patient, id, start (DATE), stop (DATE), reasondescription
--   - encounters.csv START/STOP are timestamps → parse TIMESTAMP → cast to DATE
--   - 'NA' → NULL before casting
-- ==============================================================================
CREATE OR REPLACE TEMP VIEW encounters AS
SELECT
    "PATIENT" AS patient
    ,"Id" AS id
    ,"Code" AS code -- used for tests, not intended for final output
    ,"Description" as description -- used for tests, not intended for final output

    -- for testing only:
    -- ,TRY_CAST(NULLIF("START", 'NA') AS TIMESTAMP) AS start
    -- ,TRY_CAST(NULLIF("STOP",  'NA') AS TIMESTAMP) AS stop

    ,CAST(TRY_CAST(NULLIF("START", 'NA') AS TIMESTAMP) AS DATE) AS start
    ,CAST(TRY_CAST(NULLIF("STOP",  'NA') AS TIMESTAMP) AS DATE) AS stop
    ,NULLIF("REASONDESCRIPTION", 'NA') AS reasondescription
FROM read_csv(
    dataset_root() || '/encounters.csv'
    ,ALL_VARCHAR = true
);

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
    "PATIENT" AS patient
    ,"ENCOUNTER" AS encounter
    ,"CODE" AS code
    ,"DESCRIPTION" AS description
    ,TRY_CAST("START" AS DATE) AS start
    ,TRY_CAST("STOP"  AS DATE) AS stop
FROM medications_src
;

-- ==============================================================================
-- CREATE OR REPLACE TEMP VIEW patients
--   - id, birthdate (DATE), deathdate (DATE | NULL)
--   - deathdate contains 'NA' → NULL → CAST
-- ==============================================================================
CREATE OR REPLACE TEMP VIEW patients AS
SELECT
    id
    ,CAST(birthdate AS DATE) AS birthdate
    ,CAST(deathdate AS DATE) AS deathdate
    -- other columns as-is
FROM read_csv_auto(
    dataset_root() || '/patients.csv'
    ,SAMPLE_SIZE = -1
    ,NULLSTR = 'NA'
);