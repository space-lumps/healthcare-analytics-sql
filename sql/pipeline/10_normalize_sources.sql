-- ==============================================================================
-- 10_normalize_sources.sql
-- Purpose:
--   Normalize raw CSV sources into typed, analysis-ready TEMP VIEWs.
--   - Treat literal 'NA' as NULL via NULLSTR to prevent casting failures
--   - Standardize column names across sources (patient_id, encounter_id, etc.)
--   - Preserve encounter start/stop as TIMESTAMP for time-based comparisons
--   - Deduplicate exact duplicate rows where present (SELECT DISTINCT)
--
-- Output TEMP VIEWs:
--   - encounters
--   - medications
--   - patients
--
-- Notes:
--   - This script is limited to ingestion + light normalization only.
--   - SAMPLE_SIZE = -1 forces DuckDB to infer types using the full file.
--
-- Run context:
--   Start DuckDB from sql/pipeline/ so relative paths resolve:
--     duckdb
--     .read 10_normalize_sources.sql
--     .read 20_build_cohort.sql
--     .read tests/<test_name>.sql
--     .read 30_output_csv.sql
-- ==============================================================================

-- ==============================================================================
-- Dataset selector (toggle between sample and production data)
-- ==============================================================================
CREATE OR REPLACE MACRO dataset_root() AS '../../datasets/sample';
-- CREATE OR REPLACE MACRO dataset_root() AS '../../datasets/prod';

-- ==============================================================================
-- encounters
--   - Preserve START/STOP as TIMESTAMP
--   - Convert 'NA' to NULL (NULLSTR) before casting
--   - SELECT DISTINCT removes exact duplicate rows only
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
	,"CODE" AS encounter_code
	,"DESCRIPTION" AS encounter_description
	,TRY_CAST("START" AS TIMESTAMP) AS encounter_start_timestamp
	,TRY_CAST("STOP" AS TIMESTAMP) AS encounter_stop_timestamp
	,"REASONDESCRIPTION" AS encounter_reason
FROM encounters_src
;

-- ==============================================================================
-- medications
--   - START/STOP are DATE fields in the provided datasets
--   - STOP may be NULL (after NULLSTR='NA'), so use TRY_CAST
--   - SELECT DISTINCT removes exact duplicate rows only
-- ==============================================================================
CREATE OR REPLACE TEMP VIEW medications AS
WITH medications_src AS (
	SELECT *
	FROM read_csv_auto(
		dataset_root() || '/medications.csv'
		,SAMPLE_SIZE = -1
		,NULLSTR = 'NA'
		,types = { 'CODE':'VARCHAR' }
	)
)
SELECT DISTINCT
	"PATIENT" AS patient_id
	,"ENCOUNTER" AS encounter_id
	,"CODE" AS medication_code
	,"DESCRIPTION" AS medication_description
	,TRY_CAST("START" AS DATE) AS medication_start_date
	,TRY_CAST("STOP" AS DATE) AS medication_stop_date
FROM medications_src
;

-- ==============================================================================
-- patients
--   - BIRTHDATE is required
--   - DEATHDATE may be NULL (after NULLSTR='NA')
-- ==============================================================================
CREATE OR REPLACE TEMP VIEW patients AS
SELECT
	"Id" AS patient_id
	,TRY_CAST("BIRTHDATE" AS DATE) AS birthdate
	,TRY_CAST("DEATHDATE" AS DATE) AS deathdate
FROM read_csv_auto(
	dataset_root() || '/patients.csv'
	,SAMPLE_SIZE = -1
	,NULLSTR = 'NA'
);