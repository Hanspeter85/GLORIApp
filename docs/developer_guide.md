---
title: "GLORIApp - Developer guide"
subtitle: "Parser, data format, calculation engine and app internals"
---

# Overview

GLORIApp has three layers that can be used independently:

1. **Parser** (`parser/`): turns a raw GLORIA release (zip files from Google Drive) into analysis-ready binary/RDS files, one folder per year.
2. **Engine** (`R/engine.R`): all footprint calculations on the parsed data. Pure R functions, no Shiny, usable from any script.
3. **App** (`app/`): Shiny user interface on top of the engine, plus the update function (`R/update.R`, `update/update_gloria.R`).

Dependencies: R >= 4.3 with `data.table`, `Matrix`, `openxlsx`, `jsonlite` (parser/engine), `shiny`, `bslib`, `DT` (app), `googledrive` (updates), `officer`, `mschart` (slides only). The parser uses the `tar.exe` that ships with Windows 10+ to read zip files larger than 4 GB.

# Repository layout

| Path | Purpose |
|---|---|
| `config.R` | single place for paths, GLORIA version and parser options |
| `R/functions_io.R` | float32 file format, csv reader, aggregation helpers, logging |
| `R/engine.R` | calculation engine (footprints, production, overview, gross exports) |
| `R/texts.R` | all user-facing texts of the app |
| `R/update.R` | Google Drive helpers, installed versions, background update start |
| `parser/01_build_concordances.R` | builds `input/concordances/regions.csv` and `sectors.csv` |
| `parser/02_build_meta.R` | builds `meta.rds` (labels, index tables, indicator catalogue) |
| `parser/03_parse_year.R` | parses one year |
| `parser/run_parser.R` | parses all available years (resumable), cleans up raw data |
| `update/update_gloria.R` | download + parse a release year by year (background process) |
| `app/app.R`, `app/full_app.R`, `app/update_tab.R` | Shiny app |
| `input/` | ReadMe of the GLORIA version, concordances, indicator catalogue |
| `tests/test_pipeline.R` | end-to-end test on a synthetic mini GLORIA |
| `docs/` | user/developer guides (Markdown sources, Word output), slides |
| `legacy/` | original GLORIA-MRIO_Parser scripts (v059), not used |

# Configuration

`config.R` is sourced by every entry point. Key settings:

- `data_root`: data folder, default `C:/Users/<user>/Data/GLORIA`, overridable with the environment variable `GLORIA_DATA_ROOT` (e.g. in `~/.Renviron`).
- `gloria_version`: from env `GLORIA_VERSION`, else `<data_root>/active_version.txt`, else 60.
- `paths`: `raw`, `unzip_tmp`, `parsed`, `meta`, `logs` below `<data_root>/v<version>/`; `input` (repo folder, overridable with `GLORIA_INPUT_DIR`).
- `parser_options`: `store_L`, `delete_unzipped`, `skip_existing`, `delete_raw_after_parse`.

# Raw data and parsing

## GLORIA raw files

A release folder (e.g. `060/`) contains part I (`GLORIA_MRIO_Loop060_part_I_MRIOdatabase/GLORIA_MRIOs_60_<year>.zip`, ~5.5 GB per year) and part III (`..._part_III_satelliteaccounts/GLORIA_SatelliteAccounts_060_<year>.zip`). Per year the parser needs five csv files without header (Markup001 = basic prices):

| File | Dimensions | Content |
|---|---|---|
| `T-Results` | 39,360 × 39,360 | multi-regional supply-use table: per region 120 industries followed by 120 products |
| `Y-Results` | 39,360 × 984 | final demand (164 regions × 6 categories) |
| `V-Results` | 984 × 39,360 | value added (164 regions × 6 components) |
| `TQ-Results` | 6,130 × 39,360 | satellite accounts of industries |
| `YQ-Results` | 6,130 × 984 | satellite accounts of final demand |

Region, sector, final demand, value added and satellite labels come from `GLORIA_ReadMe_0<version>.xlsx` (copied to `input/`).

## Method

Same as the original GLORIA-MRIO_Parser:

- $Z$ = use block of $T$ (rows: products, columns: industries), treated as a square 19,680 × 19,680 sector-by-sector matrix (GLORIA supply is near-diagonal).
- $x = Z\mathbf{1} + Y\mathbf{1}$ (output by product; the parser also reports the deviation from the column view $\mathbf{1}'Z + \mathbf{1}'V$).
- $A = Z\,\mathrm{diag}(x)^{-1}$ with zero output giving zero coefficients.
- $L = (I - A)^{-1}$ via `solve()` (about 2 minutes on a desktop PC; memory peak ~15 GB).

## Parsed files (`<data_root>/v<version>/parsed/<year>/`)

| File | Content | Format |
|---|---|---|
| `Z.f32` or `Z.rds` | inter-industry flows | float32 if dense (>30% non-zeros), else sparse `dgCMatrix`; read with `read_Z(year)` |
| `Y.rds` | final demand 19,680 × 984 | dense matrix |
| `V.rds` | value added 6 × 19,680 | dense matrix, row names = components |
| `x.rds` | gross output | vector |
| `Q.rds`, `QY.rds` | all satellite rows (industries / final demand) | sparse `dgCMatrix` |
| `E.rds` | gross exports 19,680 × 164 partners | dense matrix |
| `L.f32` | Leontief inverse | float32 |
| `LY.f32` | $L\,Y$ (19,680 × 984) | float32 |
| `M.rds` | multipliers $s\,L$ of all catalogue indicators | dense matrix, row names = indicator ids |
| `checks.csv` | balance checks, e.g. `output_reproduced_by_L` (must be 1) | csv |
| `_DONE` | marker: year complete | empty file |

`meta/meta.rds` holds a list with `regions`, `sectors`, `fd`, `va`, `satellites`, `idx_Z` (region/sector code of each of the 19,680 rows), `idx_Y` (region/category of each of the 984 final demand columns), `catalogue` (indicator presets with the satellite rows they sum) and `raw_index`.

**float32 format** (`write_f32` / `read_f32`): 4 bytes `GLF4`, nrow and ncol as int32 little endian, then the data column-major as float32. In Python: `np.fromfile(f, "<f4", offset=12).reshape((ncol, nrow)).T`.

A parsed year needs ~3.3 GB; 1990-2029 ~124 GB.

## Running the parser

```r
source("parser/run_parser.R")
```

It copies the ReadMe to `input/`, rebuilds the concordances if the number of regions changed, builds `meta.rds`, detects the years present in the raw zips, and parses every year without a `_DONE` marker. For each year it extracts only the five needed csv files into `tmp_unzip/<year>`, deletes them afterwards, and deletes that year's raw zips if the checks pass. When all years are done, the raw folder is deleted (ReadMe and release notes are kept in `parsed/meta`).

# The engine

```r
source("config.R"); source("R/functions_io.R"); source("R/engine.R")
meta <- readRDS(file.path(paths$meta, "meta.rds"))
res <- run_calculation(list(
  type = "footprint", indicators = c("ghg_edgar", "va_total"), years = 2015:2022,
  origin_region = "world_region_7", origin_sector = "broad_sector",
  product_region = "none", product_sector = "none",
  consumer_region = "region_name", by_fd = FALSE), meta)
```

## Specification

| Field | Meaning | Default |
|---|---|---|
| `type` | `"footprint"`, `"overview"`, `"production"`, `"exports"` | - |
| `indicators` | catalogue ids (`input/indicator_catalogue.csv`) or `"sat:<code>"` for a raw satellite row | - |
| `years` | integer vector | - |
| `origin_region`, `origin_sector` | grouping of the origin dimension, or `"none"` | `"region_name"`, `"none"` |
| `product_region`, `product_sector` | grouping of the final product dimension, or `"none"` | `"none"`, `"none"` |
| `consumer_region` | grouping of consumers | `"region_name"` |
| `by_fd` | split by final demand category | `FALSE` |
| `fd_codes` | final demand categories included (1-6) | all |
| `include_direct_fd` | add direct emissions of final users | `TRUE` |
| `keep_zeros` | keep zero rows | `FALSE` |

Grouping values are column names of `meta$regions` / `meta$sectors` (i.e. of the concordance csv files). The result is a long `data.table` with `year`, `indicator`, `unit`, the dimension columns and `value`. `to_wide(res, "year")` turns it into a cross table.

## Footprint algorithm (`calc_footprint`)

With $s = q/x$, three cases are distinguished (all give identical totals per consumer):

1. **Origin split only**: $F = \mathrm{diag}(s)\,(LY)$ using the pre-computed `LY.f32`; rows and columns are aggregated with sparse 0/1 matrices (`agg_matrix`). ~1 s per year and indicator.
2. **Final product split only**: $F = (sL) \circ Y$ using the multipliers `M.rds` (catalogue indicators) or $sL$ computed from `L.f32` (raw satellite rows).
3. **Origin × final product**: $F_{o,p,c} = \sum_{i\in o}\sum_{j\in p} s_i L_{ij} y_{jc}$. Implementation: $A_1 = G_o'\,\mathrm{diag}(s)\,L$ (origins × n), then for every consumer group $c$: $A_1\,\mathrm{diag}(y_c)\,G_p$. Needs `L.f32`; ~10-60 s per year.

Direct emissions of final users (`QY`) are added with origin = consumer region and the sector/product label `DIRECT_LABEL`.

`calc_overview` combines `calc_production` and `calc_footprint` per region. `calc_exports` computes $\mathrm{diag}(s) L e_c$ for the gross exports $e_c$ of each exporter (`E.rds`) and splits domestic/foreign origin.

Caching: `load_var()` keeps small objects of all years in memory but only one big matrix (`L.f32` or `LY.f32`). Loop over years in the outer loop (as `run_calculation` does).

## Extending

- **New indicator preset**: add a row to `input/indicator_catalogue.csv` (`head` = satellite head indicator, `pattern` = regex on the indicator name, optional `material_group`; `VALUE_ADDED` for value-added components). Re-run the parser for `M.rds`, or use the indicator directly; non-catalogue indicators fall back to $sL$ from `L.f32`.
- **New region or sector grouping**: add a column to `input/concordances/regions.csv` or `sectors.csv`. It appears in the app automatically (give it a nice label in `nice_name()` in `app/full_app.R`).
- **World Bank classification year**: `wb_fiscal_year` in `parser/01_build_concordances.R`.
- **New result type**: write `calc_<name>(info, year, meta, sp)` returning a `data.table` with dimension columns and `value`, add it to the `switch` in `run_calculation`, and add texts in `R/texts.R`.

# The app

`app/app.R` sources config, helpers, engine and texts with `local = TRUE`. If no parsed data exist it starts in setup mode (only the update tab). Otherwise `app/full_app.R` defines `ui` and `server`:

- `spec()` collects all inputs into the engine specification; `describe_spec()` (R/texts.R) shows it in plain language.
- `meta_r()` adds the column `own_grouping` to regions/sectors from the groups defined in step 6 (stored as a table kind/group/member, saved/loaded as csv).
- `result()` runs `run_calculation()` with a progress bar on *Calculate*; `result_formatted()` applies long/wide.

## Update function

`R/update.R` uses `googledrive`. `google_login()` performs the browser OAuth login (scope `drive.readonly`) and stores the token in `<data_root>/.google_token`; `google_login_cached()` reuses it non-interactively. `inspect_drive_folder()` lists a release folder recursively and selects the needed files (`needed_files()`). `start_update()` launches `update/update_gloria.R` as a separate `Rscript` process that, for each year, downloads the year's zips (`download_files()`: skip complete files, `.partial` + rename, 3 retries), runs `parser/run_parser.R` and lets it delete the raw zips. Finally `set_active_version()` writes `active_version.txt`.

# Testing

```r
Rscript tests/test_pipeline.R
```

Builds a synthetic GLORIA (3 regions × 4 sectors) in the same raw format, runs the real parser and checks input-output identities: footprint total = production total, origin/product/origin × product splits agree, net imports sum to zero, value added in gross exports = gross exports, world value-added footprint = world value added, $L$ reproduces output. Run it after every change to parser or engine.

# Other languages

The parsed files can be read without R: `.f32` with the snippet above, `.rds` via `pyreadr` (dense) or by re-exporting from R. For heavy use from Python, adding a parquet export to `parser/03_parse_year.R` is straightforward.
