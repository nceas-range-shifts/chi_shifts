## Project

`chi_shifts` examines how cumulative human impacts change as stressors and species ranges shift over time. Analysis combines species distribution models (SDMs), species vulnerability traits, and stressor (pressure) maps on a common global raster grid.

## Directory structure

- `data_mgmt/` — Quarto (`.qmd`) scripts (numbered `1_...` through `6_...`, plus `X_...` ad hoc ones) that download/build raw inputs into `_data/`. Run these before analysis scripts if a needed dataset is missing.
- `scripts/` — Quarto (`.qmd`) analysis/mapping scripts (numbered `1_...` through `5_...`, plus `X_...` exploratory ones).
- `_data/` — single consolidated data directory (previously split into `_data` and `_data_raw`; now merged). Subfolders by source/vintage:
  - `biooracle_2026/` — Bio-ORACLE ocean temperature layers
  - `eezs/` — EEZ and UN M49 georegion rasters/lookups
  - `halpern_2025/` — Halpern et al. 2025 stressor/pressure/impact rasters (habitat maps, raw & rescaled pressures, impacts by pressure, cumulative impact)
  - `iucn_redlist_2026/` — IUCN Red List assessments, WoRMS/AphiaID crosswalks
  - `ohara_2024/` — species vulnerability framework traits/scores, functional entity traits
  - `unep_wcmc_2026/` — MPA (WDPA/WDOECM) data
- `_output/` — generated intermediate/final outputs (e.g. reprojected rasters, vuln maps by taxon).
- `common_fxns.R` — shared helper functions (see below); source this at the top of scripts.
- AquaX SDM source data lives outside the repo on the shared server at `/home/shares/data-aquax/` (accessed via `here_aquax()`), not under `_data/`.

## Grid conventions

Rasters/tables use a global lon-lat grid, default resolution `res = 0.05`, `ncols = 360/res`, with a 1-indexed row-major `cell_id` (row 1 = cells 1..ncols, scanning left to right). Convert between representations with the helpers in `common_fxns.R`:

- `cell_id_to_xy(df, cell_id_col = 'cell_id', res = 0.05, drop = TRUE)` — cell_id → x/y cell-center coordinates.
- `xy_to_cell_id(df, x_col = 'x', y_col = 'y', res = 0.05, drop = TRUE)` — inverse of the above.
- `calc_cellrange(i, yslice_w, res = 0.05)` — computes a `cell_id` range for a latitude slice, for chunked/batched processing.

## Key helper functions (`common_fxns.R`)

- `here_aquax(f, ...)` — builds a path under the shared AquaX data directory.
- `get_aquax_meta(meta, sdm = TRUE)` — loads AquaX species metadata.
- `get_spp_traits()` / `get_spp_vuln()` — load species trait / vulnerability framework tables from `_data/ohara_2024/...` (requires the corresponding `data_mgmt/` script to have been run first).
- `get_sdm(aphia_id, scenario, cellrange, apply_thresh, batch_size, threads, memory_limit)` — reads per-species SDM parquet files via DuckDB, with thresholding and batching for scale.
- `sample_decomp(df)` — pools mean/sd/n across grouped samples (e.g. across species within a cell) using `collapse`.

## Coding conventions

- Use the base R pipe `|>` (not magrittr `%>%`), except where existing code already uses `%>%` for consistency within a file.
- Prefer `collapse` (`fmutate`, `fsubset`, `fsum`, `GRP`, ...) over base/dplyr equivalents in performance-sensitive code operating on large per-cell/per-species tables.
- Large per-file datasets (e.g. SDM parquet files) are queried via DuckDB (`duckdb`/`DBI`) rather than loaded fully into R.
- Use `here::here()` / `here_aquax()` for paths rather than hardcoded absolute paths (except for the shared AquaX root, which is inherently absolute).
- Use `janitor::clean_names()` when reading in external/raw tabular data.
- When commenting for explanation, use triple hash `###` to start comment line

## Behavioral rules for Posit Assistant

- This runs on a **shared server** — when writing or modifying DuckDB queries or other parallelized code, always cap `threads` and `memory_limit` (see `get_sdm()` for existing defaults) rather than letting them run unbounded.
- Treat `/home/shares/data-aquax/` (via `here_aquax()`) as **read-only**; never write, delete, or modify files there.
- Before overwriting or deleting existing files in `_data/`, `_output/`, or elsewhere, confirm with the user first — these are expensive to regenerate.
- Do not assume `_data_raw/` still exists; all raw and processed data now live under a single `_data/` directory (as of the recent consolidation).
- When adding new grid-indexed data, follow the existing `cell_id`/`x`/`y` conventions above rather than introducing a new indexing scheme.
