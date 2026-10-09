# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

End-to-end IPL (Indian Premier League) cricket analytics pipeline built on Cricsheet
data. The flow is: **ingest → Azure blob → Databricks Bronze (Delta) → dbt Silver/Gold
(Databricks SQL warehouse)**. The README mentions Airflow, but `dags/` is currently empty —
there is no orchestration yet; stages are run manually.

## Pipeline stages

1. **Ingest** — `ingest/fetch_cricsheet.py` downloads the Cricsheet IPL CSV zip
   (`ipl_csv2.zip`), unzips new files into `raw_data/cricsheet/`, then uploads any new CSVs
   to the Azure blob container `cricsheet-raw`. Both steps are idempotent (they skip files
   that already exist locally / in the container). `all_matches.csv` is intentionally kept
   but **must be excluded downstream** — it repeats every ball already present in the
   per-match files.

2. **Bronze** — `notebooks/Load_Bronze.py` is a Databricks notebook (not run locally). It
   reads the Azure container and writes two Delta tables in catalog `ipl_analytics`, schema
   `bronze`:
   - `deliveries_raw` — one row per ball (from `<matchid>.csv` files, header + inferred schema).
   - `match_info_raw` — one row per line of each `<matchid>_info.csv` file. These info files
     have **no header and variable-width rows**, so they are loaded with a fixed 5-column
     schema (`info_type, field, value1, value2, value3`) plus a derived `source_file` column.
   Re-running the notebook drops and rebuilds both tables.

3. **Silver/Gold (dbt)** — `dbt_project/` transforms Bronze into staging and mart models.

## dbt layout

- **sources** (`models/staging/sources.yml`) point at the Databricks `ipl_analytics.bronze`
  tables above.
- **staging** (`models/staging/`, materialized as views by default):
  - `stg_deliveries` — thin passthrough / column selection over `deliveries_raw`.
  - `stg_match_info` — **pivots** the tall key/value `match_info_raw` into one row per match
    using `MAX(CASE WHEN field = ... THEN valueN END)`. When a new match-info field is needed,
    add it to both the `MAX(CASE ...)` list **and** the `WHERE field IN (...)` filter.
- **marts** (`models/marts/`, materialized as `table`):
  - `dim_matches` — one row per match (keyed on `match_id`), reads from `stg_match_info`.
  - `fct_deliveries` — one row per delivery (keyed on a composed `delivery_id`), reads from
    `stg_deliveries` and adds the derived cricket metrics (`runs_on_ball`, `bowler_runs`,
    `is_legal_delivery`, `is_four`/`is_six`, `is_wicket`/`is_bowler_wicket`, `is_super_over`).
    Cricket rules live here — e.g. innings > 2 is the super over, retired hurt is not a wicket,
    bowler wickets exclude run-outs.

## Common commands

dbt commands run from inside `dbt_project/`:

```bash
source venv/bin/activate          # from repo root; venv/ is the project virtualenv
cd dbt_project
dbt debug                         # verify connection + profile
dbt run                           # build all models
dbt run --select stg_deliveries   # build a single model (+ for downstream, e.g. stg_deliveries+)
dbt test                          # run tests (none defined yet)
```

Run the ingest step (from repo root, venv active):

```bash
python -m ingest.fetch_cricsheet
```

## Configuration & connections

- **dbt profile** `dbt_project` lives at `~/.dbt/profiles.yml` (not in the repo). It targets a
  Databricks SQL warehouse: `type: databricks`, `catalog: ipl_analytics`, `schema: analytics`.
  So dbt **reads** from `bronze` and **writes** to the `analytics` schema on Databricks — not
  to the local DuckDB file.
- `ipl.duckdb` and `dbt-duckdb` exist in the repo/requirements but the active target is
  Databricks. Don't assume DuckDB is the warehouse.
- `.env` (gitignored) holds secrets read by the ingest script and notebook:
  `AZURE_STORAGE_CONNECTION_STRING`, `DATABRICKS_TOKEN`, `DATABRICKS_HOST`,
  `DATABRICKS_HTTP_PATH`.
