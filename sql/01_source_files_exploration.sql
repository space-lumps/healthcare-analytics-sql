/*
01_source_files_exploration.sql

Purpose
-------
1) Register each CSV as a temp view (portable, relative paths)
2) Produce a quick dataset summary report (rows, columns)
3) Show small row samples (SELECT * LIMIT N)
4) Add profiling checks:
   - null counts per column
   - 'NA' (string) counts per column
   - inferred datatypes + any type anomalies (e.g., mixed types)

Constraints
-----------
- No joins
- No transformations beyond loading
- Relative paths only (assume sibling repo layout)
- Designed for DuckDB

Inputs (relative paths)
-----------------------
- datasets/allergies.csv
- datasets/encounters.csv
- datasets/medications.csv
- datasets/patients.csv
- datasets/procedures.csv

Sections
--------
A) Register datasets as temp views
B) Summary report: row_count + column_count per dataset
C) Row samples (LIMIT N per dataset)
D) Datatype inspection (pragma_table_info)
E) Null profiling (per table, per column)
F) 'NA' profiling (per table, per column)
G) Notes / findings (to be filled after running)
*/

-----------------------------------------------------------------------
-- A) Register datasets as temp views
-----------------------------------------------------------------------

CREATE OR REPLACE TEMP VIEW allergies AS
SELECT *
FROM read_csv_auto(
	'datasets/allergies.csv'
	, SAMPLE_SIZE = -1
);

CREATE OR REPLACE TEMP VIEW encounters AS
SELECT *
FROM read_csv_auto(
	'datasets/encounters.csv'
	, SAMPLE_SIZE = -1
);

CREATE OR REPLACE TEMP VIEW medications AS
SELECT *
FROM read_csv_auto(
	'datasets/medications.csv'
	, SAMPLE_SIZE = -1
);

CREATE OR REPLACE TEMP VIEW patients AS
SELECT *
FROM read_csv_auto(
	'datasets/patients.csv'
	, SAMPLE_SIZE = -1
);

CREATE OR REPLACE TEMP VIEW procedures AS
SELECT *
FROM read_csv_auto(
	'datasets/procedures.csv'
	, SAMPLE_SIZE = -1
);


-----------------------------------------------------------------------
-- B) Summary report: row_count + column_count per dataset
-----------------------------------------------------------------------
SELECT
	'datasets/allergies.csv'                                  AS dataset
	, (SELECT COUNT(*) FROM allergies)                          AS row_count
	, (SELECT COUNT(*) FROM pragma_table_info('allergies'))     AS column_count

UNION ALL

SELECT
	'datasets/encounters.csv'                                 AS dataset
	, (SELECT COUNT(*) FROM encounters)                         AS row_count
	, (SELECT COUNT(*) FROM pragma_table_info('encounters'))    AS column_count

UNION ALL

SELECT
	'datasets/medications.csv'                                AS dataset
	, (SELECT COUNT(*) FROM medications)                        AS row_count
	, (SELECT COUNT(*) FROM pragma_table_info('medications'))   AS column_count

UNION ALL

SELECT
	'datasets/patients.csv'                                   AS dataset
	, (SELECT COUNT(*) FROM patients)                           AS row_count
	, (SELECT COUNT(*) FROM pragma_table_info('patients'))      AS column_count

UNION ALL

SELECT
	'datasets/procedures.csv'                                 AS dataset
	, (SELECT COUNT(*) FROM procedures)                         AS row_count
	, (SELECT COUNT(*) FROM pragma_table_info('procedures'))    AS column_count
;


-----------------------------------------------------------------------
-- C) Row samples (LIMIT N per dataset)
-----------------------------------------------------------------------

SELECT * FROM allergies LIMIT 10;
SELECT * FROM encounters LIMIT 10;
SELECT * FROM medications LIMIT 10;
SELECT * FROM patients LIMIT 10;
SELECT * FROM procedures LIMIT 10;


-----------------------------------------------------------------------
-- D) Datatype inspection (DuckDB inferred types)
-----------------------------------------------------------------------

SELECT
	'allergies' AS dataset
	, *
FROM pragma_table_info('allergies');

SELECT
	'encounters' AS dataset
	, *
FROM pragma_table_info('encounters');
--NOTES:
--"START" is type TIMESTAMP
--"STOP" is type TIMESTAMP

SELECT
	'medications' AS dataset
	, *
FROM pragma_table_info('medications');

SELECT
	'patients' AS dataset
	, *
FROM pragma_table_info('patients');

SELECT
	'procedures' AS dataset
	, *
FROM pragma_table_info('procedures');


-- TODO (later): Identify columns that should be DATE/TIMESTAMP/INT/BOOL
-- but are inferred as VARCHAR due to mixed values.

-----------------------------------------------------------------------
-- E) Null profiling
-----------------------------------------------------------------------
-- Goal: for each table, produce a result set:
--  column_name, null_count, total_rows, null_pct
--
-- TODO: generate per-column null counts.
-- Notes:
-- - DuckDB doesn't have a built-in "profile all columns" statement in SQL alone
--   without dynamic SQL; we will implement a pragmatic approach next:
--   - either hand-write for key columns, or
--   - use a DuckDB macro / generated SQL (still within DuckDB), or
--   - run via a small driver script and materialize results.

-- E1) Full-column profile (includes null stats) via DuckDB SUMMARIZE
-- Note: this prints one result set per table.
SUMMARIZE allergies;
SUMMARIZE encounters;
SUMMARIZE medications;
SUMMARIZE patients;
SUMMARIZE procedures;

-----------------------------------------------------------------------
-- F) 'NA' (string) profiling
-----------------------------------------------------------------------
-- Goal: for each table, count values exactly equal to 'NA' (case-sensitive),
-- by column. Same shape as null profiling.
--
-- TODO: per-column 'NA' counts.
-- Notes:
-- - Only applies to VARCHAR columns; numeric/date columns may contain 'NA'
--   only if inferred as VARCHAR.

-- Since this logic is extensive, it will be placed in a new file, namely 02_source_files_exploration_NA.sql

-----------------------------------------------------------------------
-- G) Primary key candidates + date coverage (per dataset)
-----------------------------------------------------------------------
-- Goal:
-- For each dataset, report:
--  - row_count
--  - distinct_pk (or distinct_pk_candidate for compound keys)
--  - min_date, max_date (for the primary date column)
--  - null_date_count
--  - (optional) duplicate_count = row_count - distinct_pk_candidate
--
-- Notes:
-- - Some tables use a natural compound key (PATIENT + ENCOUNTER + CODE + START/DATE).
-- - Some tables have a single Id column suitable as a PK.
-- - Date columns differ by table (e.g., START, DATE, BIRTHDATE).
-----------------------------------------------------------------------
-- G) Primary key candidates + date coverage (per dataset)
-----------------------------------------------------------------------
-- Assumes typed temp views already exist:
--   allergies, encounters, medications, patients, procedures
-----------------------------------------------------------------------

-- allergies
-- result: row_count and distinct_pk_count are equivalent
WITH src AS (
	SELECT *
	FROM allergies
)
SELECT
	'allergies' AS dataset
	, COUNT(*) AS row_count
	, COUNT(
		DISTINCT concat_ws(
			'|'
			, "PATIENT"
			, "ENCOUNTER"
			, CAST("CODE" AS VARCHAR)
			, CAST("START" AS VARCHAR)
		)
	) AS distinct_pk_candidate
	, COUNT(*) - COUNT(
		DISTINCT concat_ws(
			'|'
			, "PATIENT"
			, "ENCOUNTER"
			, CAST("CODE" AS VARCHAR)
			, CAST("START" AS VARCHAR)
		)
	) AS duplicate_count
	, MIN("START") AS min_date
	, MAX("START") AS max_date
	, COUNT(*) - COUNT("START") AS null_date_count
FROM src;

-- encounters
-- result: row_count and distinct_pw are equivalent
WITH src AS (
	SELECT *
	FROM encounters
)
SELECT
	'encounters' AS dataset
	, COUNT(*) AS row_count
	, COUNT(DISTINCT "Id") AS distinct_pk
	, COUNT(*) - COUNT(DISTINCT "Id") AS duplicate_count
	--, MIN("START") AS min_date
	--, MAX("START") AS max_date
	, COUNT(*) - COUNT("START") AS null_date_count
FROM src;

-- medications
-- result: row_count - distinct_pk_candidate = 26 ********** investigate this later
WITH src AS (
	SELECT *
	FROM medications
)
SELECT
	'medications' AS dataset
	, COUNT(*) AS row_count
	, COUNT(
		DISTINCT concat_ws(
			'|'
			, "PATIENT"
			, "ENCOUNTER"
			, CAST("CODE" AS VARCHAR)
			, CAST("START" AS VARCHAR)
		)
	) AS distinct_pk_candidate
	, COUNT(*) - COUNT(
		DISTINCT concat_ws(
			'|'
			, "PATIENT"
			, "ENCOUNTER"
			, CAST("CODE" AS VARCHAR)
			, CAST("START" AS VARCHAR)
		)
	) AS duplicate_count
	, MIN("START") AS min_date
	, MAX("START") AS max_date
	, COUNT(*) - COUNT("START") AS null_date_count
FROM src;

-- medications deduped (optional)
-- result: row_count and distinct_pk_candidate are equivalent
WITH medications_src AS (
	SELECT *
	FROM medications
)
, medications_deduped AS (
	SELECT DISTINCT
		"PATIENT"
		, "ENCOUNTER"
		, "CODE"
		, "DESCRIPTION"
		, "START"
		, "STOP"
		, "COST"
		, "DISPENSES"
		, "TOTALCOST"
		, "REASONCODE"
		, "REASONDESCRIPTION"
	FROM medications_src
)
SELECT
	'medications_deduped' AS dataset
	, COUNT(*) AS row_count
	, COUNT(
		DISTINCT concat_ws(
			'|'
			, "PATIENT"
			, "ENCOUNTER"
			, CAST("CODE" AS VARCHAR)
			, CAST("START" AS VARCHAR)
		)
	) AS distinct_pk_candidate
	, COUNT(*) - COUNT(
		DISTINCT concat_ws(
			'|'
			, "PATIENT"
			, "ENCOUNTER"
			, CAST("CODE" AS VARCHAR)
			, CAST("START" AS VARCHAR)
		)
	) AS duplicate_count
	, MIN("START") AS min_date
	, MAX("START") AS max_date
	, COUNT(*) - COUNT("START") AS null_date_count
FROM medications_deduped;

-- patients
WITH src AS (
	SELECT *
	FROM patients
)
SELECT
	'patients' AS dataset
	, COUNT(*) AS row_count
	, COUNT(DISTINCT "Id") AS distinct_pk
	, COUNT(*) - COUNT(DISTINCT "Id") AS duplicate_count
	, MIN("BIRTHDATE") AS min_date
	, MAX("BIRTHDATE") AS max_date
	, COUNT(*) - COUNT("BIRTHDATE") AS null_date_count
FROM src;

-- procedures
-- result: row_count and distinct_pk_candidate are equivalent
WITH src AS (
	SELECT *
	FROM procedures
)
SELECT
	'procedures' AS dataset
	, COUNT(*) AS row_count
	, COUNT(
		DISTINCT concat_ws(
			'|'
			, "PATIENT.x"
			, "ENCOUNTER"
			, "CODE.x"
			, CAST("DATE" AS VARCHAR)
		)
	) AS distinct_pk_candidate
	, COUNT(*) - COUNT(
		DISTINCT concat_ws(
			'|'
			, "PATIENT.x"
			, "ENCOUNTER"
			, "CODE.x"
			, CAST("DATE" AS VARCHAR)
		)
	) AS duplicate_count
	, MIN("DATE") AS min_date
	, MAX("DATE") AS max_date
	, COUNT(*) - COUNT("DATE") AS null_date_count
FROM src;

-----------------------------------------------------------------------
-- H) Notes / findings
-----------------------------------------------------------------------
-- TODO: Record:
-- - row counts per table
-- - key columns + inferred types
	-- - inferred types are recorded in output/inferred_types_snapshot.csv
-- - columns with high null/%NA rates
	-- - there are no nulls
	-- - instead there is 'NA'
-- - any obvious data quality issues (duplicates, malformed dates, etc.)




