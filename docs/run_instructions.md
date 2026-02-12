# Run Instructions & Environment Notes

## Environment

* SQL engine: **DuckDB**
* Execution context: local CLI + DuckDB interactive shell
* Operating system: macOS (portable to Linux/Windows)
* No external services required

This project is intentionally SQL-first and does not depend on Python, dbt, or orchestration tooling.

---

## Data Setup

Raw healthcare data files are **not committed** to this repository.

To run the pipeline, source data must be available locally and loaded into DuckDB as TEMP VIEWs. At minimum, the following views must exist:

* `encounters`
* `patients`
* `medications`

Column names and expected fields are documented in `/docs/data-dictionary-csvs`.

---

## Recommended Setup (DuckDB CLI)
## Install DuckDB (CLI)

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
From the repository root:

```bash
duckdb
```

---

## Pipeline Execution Order

SQL scripts are **numbered and intended to be run in order**.

### 1. Create TEMP VIEWS from normalized source tables

```text
.read sql/pipeline/10_normalize_sources.sql
```

This step standardizes field names and ensures required TEMP VIEWs exist for downstream logic.

### 2. Build the cohort

```text
.read sql/pipeline/20_build_cohort.sql
```

This script creates a TEMP VIEW:

* `overdose_cohort`

The view represents one row per `patient_id + encounter_id` and includes all derived metrics.

A trailing `SELECT` is included for interactive inspection.

---

## Validation & QA

Validation queries live under:

```
sql/pipeline/tests/
```

These scripts **recalculate key metrics independently** to confirm correctness of the pipeline logic.
Tests are read-only and do not modify pipeline outputs.

---

## Outputs

* Any exported CSVs or derived files should be written to `/output`
* `/output` is gitignored and intended for local inspection only

---

## Notes

* TEMP VIEWs are session-scoped; restarting DuckDB requires re-running setup scripts
* The pipeline is designed for clarity and correctness rather than maximum performance
* This structure mirrors analytics-engineering workflows used in production environments