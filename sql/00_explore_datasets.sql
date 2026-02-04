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
- ~/datasets/allergies.csv
- ~/datasets/encounters.csv
- ~/datasets/medications.csv
- ~/datasets/patients.csv
- ~/datasets/procedures.csv

Sections
--------
A) Register datasets as temp views
B) Summary report: row_count + column_count per dataset
C) Row samples (LIMIT N per dataset)
D) Datatype inspection (pragma_table_info)
E) Null profiling (per table, per column)
F) 'NA' profiling (per table, per column)
G) Notes / findings (to be filled after running)

-----------------------------------------------------------------------
A) Register datasets as temp views
-----------------------------------------------------------------------
-- TODO: CREATE OR REPLACE TEMP VIEW allergies AS ... read_csv_auto(...)
-- TODO: CREATE OR REPLACE TEMP VIEW encounters AS ... read_csv_auto(...)
-- TODO: CREATE OR REPLACE TEMP VIEW medications AS ... read_csv_auto(...)
-- TODO: CREATE OR REPLACE TEMP VIEW patients AS ... read_csv_auto(...)
-- TODO: CREATE OR REPLACE TEMP VIEW procedures AS ... read_csv_auto(...)

-----------------------------------------------------------------------
B) Summary report: row_count + column_count per dataset
-----------------------------------------------------------------------
-- TODO: UNION ALL query returning:
--  - dataset (path string)
--  - row_count (COUNT(*))
--  - column_count (COUNT(*) from pragma_table_info)

-----------------------------------------------------------------------
C) Row samples (LIMIT N per dataset)
-----------------------------------------------------------------------
-- TODO: SELECT * FROM allergies LIMIT 10;
-- TODO: SELECT * FROM encounters LIMIT 10;
-- TODO: SELECT * FROM medications LIMIT 10;
-- TODO: SELECT * FROM patients LIMIT 10;
-- TODO: SELECT * FROM procedures LIMIT 10;

-----------------------------------------------------------------------
D) Datatype inspection (DuckDB inferred types)
-----------------------------------------------------------------------
-- TODO: SELECT * FROM pragma_table_info('allergies');
-- TODO: SELECT * FROM pragma_table_info('encounters');
-- TODO: SELECT * FROM pragma_table_info('medications');
-- TODO: SELECT * FROM pragma_table_info('patients');
-- TODO: SELECT * FROM pragma_table_info('procedures');

-- TODO (later): Identify columns that should be DATE/TIMESTAMP/INT/BOOL
-- but are inferred as VARCHAR due to mixed values.

-----------------------------------------------------------------------
E) Null profiling
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

-----------------------------------------------------------------------
F) 'NA' (string) profiling
-----------------------------------------------------------------------
-- Goal: for each table, count values exactly equal to 'NA' (case-sensitive),
-- by column. Same shape as null profiling.
--
-- TODO: per-column 'NA' counts.
-- Notes:
-- - Only applies to VARCHAR columns; numeric/date columns may contain 'NA'
--   only if inferred as VARCHAR.

-----------------------------------------------------------------------
G) Notes / findings
-----------------------------------------------------------------------
-- TODO: Record:
-- - row counts per table
-- - key columns + inferred types
-- - columns with high null/%NA rates
-- - any obvious data quality issues (duplicates, malformed dates, etc.)
*/
