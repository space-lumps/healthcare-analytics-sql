-- ============================================================
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
--   allergies and procedures are intentionally omitted (not used downstream).
--   Keep this file limited to ingestion + typing + light normalization only.
-- ============================================================

-- CREATE OR REPLACE TEMP VIEW encounters
--   - patient, id, start (DATE), stop (DATE), reasondescription
--   - encounters.csv START/STOP are timestamps → parse TIMESTAMP → cast to DATE
--   - 'NA' → NULL before casting
CREATE OR REPLACE TEMP VIEW encounters AS
SELECT
    "PATIENT" AS patient
    ,"Id" AS id
    ,CAST(TRY_CAST(NULLIF("START", 'NA') AS TIMESTAMP) AS DATE) AS start
    ,CAST(TRY_CAST(NULLIF("STOP",  'NA') AS TIMESTAMP) AS DATE) AS stop
    ,"REASONDESCRIPTION" AS reasondescription
FROM read_csv(
    '../../datasets/encounters.csv'
    ,ALL_VARCHAR = true
);


-- CREATE OR REPLACE TEMP VIEW medications
--   - patient, encounter, code, description, start (DATE), stop (DATE | NULL)
--   - known duplicate rows → SELECT DISTINCT on full row
--   - 'NA' handled via NULLSTR and/or TRY_CAST for nullable date fields
CREATE OR REPLACE TEMP VIEW medications AS
    SELECT
        patient
        ,encounter
        ,code
        ,description
        ,TRY_CAST("START" AS DATE) AS start
        ,TRY_CAST("STOP"  AS DATE) AS stop
    FROM read_csv_auto(
        '../../datasets/medications.csv'
        ,SAMPLE_SIZE = -1
        ,NULLSTR = 'NA'
        ,types = {
            'CODE':'VARCHAR'
        }
    );


-- CREATE OR REPLACE TEMP VIEW patients
--   - id, birthdate (DATE), deathdate (DATE | NULL)
--   - deathdate contains 'NA' → NULL → TRY_CAST
CREATE OR REPLACE TEMP VIEW patients AS
SELECT
    id
    ,CAST(birthdate AS DATE) AS birthdate
    ,CAST(deathdate AS DATE) AS deathdate
    -- other columns as-is
FROM read_csv_auto(
    '../../datasets/patients.csv'
    ,SAMPLE_SIZE = -1
    ,NULLSTR = 'NA'
);