# GLORIApp

A Shiny app that lets **non-experts** calculate footprints and trade-embodied
indicators with the global multi-regional input-output database
**GLORIA** (v60, 164 regions x 120 sectors, 1990-2029), plus a reusable parser
that turns the raw GLORIA release into analysis-ready data.

Built on the earlier repository `GLORIA-MRIO_Parser` (scripts kept in `legacy/`).

What you can do in the app (no programming needed):

- choose **indicators**: materials, greenhouse gases, air pollutants, land, energy,
  employment, water, biodiversity, value added, or any of the ~6 000 raw GLORIA
  satellite rows (expert mode)
- choose **years** (1990-2029)
- aggregate **regions** (countries, 7 world regions, World Bank income groups and
  regions, development groups, or your own grouping via csv upload) and **sectors**
  (120 sectors, ISIC sections, 6 broad sectors, or your own grouping)
- choose **final demand categories** (households, government, investment, ...)
- choose the **result type**: footprint from-to (origin -> consumer), footprint by
  final product, production- vs. consumption-based overview, territorial account,
  Trade in Value Added (TiVA) / indicators embodied in exports
- download the result as **csv** in long format or as a pivot (wide) table

The app has no charts on purpose: it produces clean tables for Excel, R, Python, ...

---

## 1. One-time setup

1. Install **R** (>= 4.3) and **RStudio**.
2. Install the R packages (once):
   ```r
   install.packages(c("shiny", "bslib", "DT", "data.table", "Matrix", "openxlsx", "jsonlite"))
   ```
3. Clone this repository and open `GLORIApp.Rproj` in RStudio.

Hardware: the parser needs ~16 GB RAM (32 GB recommended) and ~150 GB free disk
space for the parsed data of all years (plus ~60 GB for the downloaded raw data,
which can be deleted after parsing).

### Where the data live

Data never go into the git repository. By default they live in

```
C:/Users/<user>/Data/GLORIA/
   active_version.txt      <- which version the app uses
   v60/
      raw/                 <- downloaded zip files
      parsed/<year>/       <- analysis-ready data (one folder per year)
      parsed/meta/meta.rds <- labels and indicator catalogue
      logs/                <- parser and update logs
```

To use another folder, add `GLORIA_DATA_ROOT=D:/somewhere/GLORIA` to the file
`~/.Renviron` (in R: `usethis::edit_r_environ()` or `file.edit("~/.Renviron")`).

## 2. Getting the GLORIA data

GLORIA releases are distributed as Google Drive folders by the Industrial Ecology
Virtual Laboratory (https://ielab.info/labs/ielab-gloria). Only two parts are needed:
**part I** (MRIO tables in basic prices) and **part III** (satellite accounts).

Downloads are done with **rclone**, a free command line tool that handles huge
Google Drive folders reliably (the browser download often breaks):

1. Download `rclone-current-windows-amd64.zip` from https://rclone.org/downloads/ ,
   unzip it and put `rclone.exe` into `C:/Users/<user>/Tools/`
   (other location: set `RCLONE_EXE=...` in `~/.Renviron`).
2. Connect rclone to Google Drive once (opens a browser window for the login):
   ```powershell
   C:\Users\<user>\Tools\rclone.exe config create gdrive drive scope=drive.readonly
   ```
3. Then either use the app (tab **Data & updates**, see below) or download by hand:
   ```powershell
   C:\Users\<user>\Tools\rclone.exe copy "gdrive,root_folder_id=<FOLDER-ID>:" "C:\Users\<user>\Data\GLORIA\v60\raw" --progress --transfers 4 --drive-acknowledge-abuse --include "GLORIA_ReadMe_060*.xlsx" --include "*Loop060_part_I_*/**" --include "*Loop060_part_III_*/**"
   ```
   `<FOLDER-ID>` is the part of the Drive link after `/folders/`. If the download
   breaks, run the same command again: finished files are skipped.

## 3. Compiling (parsing) the data

In RStudio (working directory = repo root):

```r
source("parser/run_parser.R")
```

This takes roughly 10-20 minutes per year (all 39 years: one night). The parser
is resumable: finished years are skipped, so it can be interrupted and restarted.
Plausibility checks for every year are written to `parsed/checks_all_years.csv`
(e.g. `output_reproduced_by_L` must be 1).

## 4. Running the app

```r
shiny::runApp("app")
```

or open `app/app.R` and click **Run App**. Results are computed on the fly; a
footprint for one indicator and year takes a few seconds.

## 5. Updating to a new GLORIA release

In the app, tab **Data & updates**:

1. paste the Google Drive link of the new release folder and click **Check folder**
   (shows the version found and the download size),
2. click **Download and compile**. Download and parsing run in the background
   (several hours); progress is shown in the tab, the log file is in
   `<data>/v<version>/logs/`,
3. when finished, the new version is activated; restart the app.

Several versions can be installed side by side and switched in the same tab.
The same is possible without the app:

```powershell
Rscript update/update_gloria.R <FOLDER-ID> <VERSION>
```

If a new release changes the regions or sectors, the concordances in
`input/concordances/` are rebuilt automatically. New satellite indicators can be
added to the recommended list in `input/indicator_catalogue.csv`.

## 6. Repository structure

| Path | Content |
|---|---|
| `config.R` | all paths and settings (single place to change) |
| `app/app.R`, `app/full_app.R` | Shiny user interface and server |
| `app/update_tab.R` | tab "Data & updates" |
| `app/help.md` | "How it works" page of the app |
| `R/engine.R` | all calculations (footprints, TiVA, aggregation); usable without the app |
| `R/functions_io.R` | reading/writing helpers, aggregation helpers |
| `R/texts.R` | all explanatory texts of the app |
| `R/update.R` | download helpers (rclone) |
| `parser/` | parser: concordances, metadata, one year, run all years |
| `update/update_gloria.R` | download + parse + activate a release (command line) |
| `input/concordances/regions.csv` | region groupings - **add a column to get a new aggregation in the app** |
| `input/concordances/sectors.csv` | sector groupings - same |
| `input/indicator_catalogue.csv` | recommended indicators with explanations |
| `tests/test_pipeline.R` | end-to-end test on a mini GLORIA (3 regions x 4 sectors) |
| `legacy/` | original v059 scripts of GLORIA-MRIO_Parser |
| `docs/` | material for the introduction session |

## 7. Using the engine from R scripts

```r
source("config.R"); source("R/functions_io.R"); source("R/engine.R")
meta <- readRDS(file.path(paths$meta, "meta.rds"))
res <- run_calculation(list(
  type = "footprint_origin", indicators = c("ghg_edgar", "mat_total"), years = 2015:2022,
  region_from = "world_region_7", region_to = "region_name", sector_col = "broad_sector",
  by_sector = TRUE, by_fd = FALSE, fd_codes = 1:6, include_direct_fd = TRUE), meta)
fwrite(res, "my_footprints.csv")
```

## 8. Method in brief

Standard environmentally-extended MRIO analysis, same as in `GLORIA-MRIO_Parser`:
`Z` = use block of the GLORIA supply-use table (products x industries, treated as
square sector x sector because GLORIA supply is near-diagonal),
`x = Z 1 + Y 1`, `A = Z diag(1/x)`, `L = (I - A)^-1`.
Footprints: `diag(q/x) L Y` (by origin) and `(q/x) L diag(y)` (by final product);
TiVA: `(v/x) L e` for gross exports `e` of each exporter. Direct emissions of
households (GLORIA `YQ`) are optionally added to the region where they occur.

Parsed files per year (`parsed/<year>/`): `Z.rds` (sparse), `Y.rds`, `V.rds`
(value added by component), `x.rds`, `Q.rds` / `QY.rds` (all satellite accounts,
sparse), `E.rds` (gross exports by partner), `L.f32` and `LY.f32` (float32 binary,
readable in Python with `np.fromfile(f, "<f4", offset=12)`), `M.rds` (multipliers
of the catalogue indicators).

World Bank income groups: classification of fiscal year **FY26** (published July 2025,
based on GNI per capita 2024) from the World Bank historical file
`input/concordances/worldbank_OGHIST.xlsx`; World Bank regions from the World Bank
API (`worldbank_country_classification.csv`). To switch the year, change
`wb_fiscal_year` in `parser/01_build_concordances.R` and re-run it (no re-parsing needed).
The four GLORIA "Rest of ..." regions form their own group because they mix
countries of different income levels.

## Citation

Please cite GLORIA: Lenzen, M. et al. (2022) Implementing the material footprint to
measure progress towards SDGs 8 and 12. *Nature Sustainability* 5, 157-166, and the
release notes of the version used.
