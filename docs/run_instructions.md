# Run Instructions & Environment Notes

## Environment

* SQL engine: **DuckDB**
* Execution context: local CLI + DuckDB interactive shell
* Operating system: macOS (portable to Linux/Windows)
* No external services required

This project is intentionally SQL-first and does not depend on Python, dbt, or orchestration tooling.

---

## Data Setup

This repository includes sample CSV data for reproducible execution.

Sample dataset location:

`datasets/sample/`


The pipeline can also be run against a separate prod dataset locally (not committed), by placing files under:

`datasets/prod/`

### Required Source Files

Both datasets/sample/ and datasets/prod/ are expected to contain:

* encounters.csv
* patients.csv
* medications.csv

Column names and expected fields are documented in:

`/docs/data-dictionary-csvs`

### Dataset Selector

`10_normalize_sources.sql` contains a dataset selector macro:
```sql
CREATE OR REPLACE MACRO dataset_root() AS '../../datasets/sample';
-- CREATE OR REPLACE MACRO dataset_root() AS '../../datasets/prod';
```

To switch datasets, comment/uncomment the appropriate line.

---

## Recommended Setup (DuckDB CLI)

### macOS (Homebrew)
```bash
brew install duckdb
duckdb --version
```
### Linux
Use your package manager if available, or download the DuckDB CLI binary from DuckDB releases.

### Windows
Download the DuckDB CLI executable from DuckDB releases and add it to your PATH (optional).

## Start DuckDB

Navigate to the pipeline directory:

```bash
cd sql/pipeline
```
Then launch DuckDB:
```bash
duckdb
```
---

## Pipeline Execution Order

SQL scripts are **numbered and intended to be run in order**.

### 1. Create TEMP VIEWS from normalized source tables

```text
.read 10_normalize_sources.sql
```

This step standardizes field names and ensures required TEMP VIEWs exist for downstream logic.

### 2. Build the cohort

```text
.read 20_build_cohort.sql
```

This script creates a TEMP VIEW:

`overdose_cohort`

The view represents one row per `patient_id + encounter_id` and includes all derived metrics.

A trailing `SELECT` is included for interactive inspection.

---

## Validation & QA

Validation queries live under:

```
sql/pipeline/tests/
```
Tests can be run using this syntax:

```text
.read tests/<test_name>
```

These scripts **recalculate key metrics independently** to confirm correctness of the pipeline logic.
Tests are read-only and do not modify pipeline outputs.

---

## Outputs

To output the TEMP VIEW overdose_cohort as a .csv for later use:
```text
.read 30_output_csv.sql
```
* Any exported CSVs or derived files should be written to `/output`
* `/output` is gitignored and intended for local inspection only

---

## Notes

* TEMP VIEWs are session-scoped; restarting DuckDB requires re-running ingestion and cohort creation scripts
* The pipeline is designed for clarity and correctness rather than maximum performance
* This structure mirrors analytics-engineering workflows used in production environments