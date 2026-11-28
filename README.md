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
- choose the **result type** (footprint, production- vs. consumption-based overview,
  territorial account) and the **breakdown**:
  production side (where, what) and consumption side (where, what, who)
- download the result as **csv** in long format (pivot-ready) or as a wide cross table

The main output is a clean csv table for Excel, R, Python, ...; the tab **Charts**
gives a quick interactive look at the result (ranking, time series, composition).

---

## 1. One-time setup

1. Install **R** (>= 4.3) and **RStudio**.
2. Install the R packages (once):
   ```r
   install.packages(c("shiny", "bslib", "DT", "plotly", "ggplot2", "data.table", "Matrix", "arrow", "openxlsx", "jsonlite", "googledrive", "markdown"))
   # optional: install.packages(c("testthat", "officer", "mschart"))  # tests and intro slides
   ```
3. Clone this repository and open `GLORIApp.Rproj` in RStudio.

**Disk space and memory** (GLORIA v60, 164 regions x 120 sectors, 1990-2029):

| What | Needed |
|---|---|
| Compiled GLORIA (all 40 years) | ~121 GB free disk space (~3 GB per year) |
| Compiling it yourself (option B) | ~12 GB more while it runs (raw files of one year, deleted afterwards) |
| RAM for the app | up to ~8 GB (16 GB PC is enough) |
| RAM for compiling | ~16 GB (32 GB recommended) |
| App itself / portable version | < 0.1 GB / ~0.5 GB unpacked |

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

The folders can be changed in the app (tab **Data & updates** > *Where the data are
stored*): one folder for the compiled MRIO and, optionally, a separate folder for
the temporary raw downloads (e.g. on another drive). They are saved in a small
settings file of the user (`tools::R_user_dir("GLORIApp", "config")`). Alternatively
set `GLORIA_DATA_ROOT` / `GLORIA_RAW_ROOT` in `~/.Renviron`.

## 2. Getting the GLORIA data

There are two ways - the app works the same with both.

### Option A: use an already compiled GLORIA (no Google account, no compiling)

Someone who has compiled GLORIA shares the folder `v60` (~121 GB) e.g. via Box,
a network drive or an external disk. Before sharing, run once in R (repo root):

```r
source("config.R"); source("R/functions_io.R"); source("R/share.R")
write_manifest()     # writes v60/parsed/manifest.csv with sizes and MD5 checksums
```

Users download the whole `v60` folder, put it into any folder (e.g. `D:/GLORIA/v60`)
and enter that folder in the app: tab **Data & updates** > *Option A* > *Check and
use this folder*. The app checks that all years and files are complete (sizes,
optionally checksums), saves the folder as data folder and uses it after a restart.

### Option B: download and compile from Google Drive

GLORIA releases are distributed as Google Drive folders by the Industrial Ecology
Virtual Laboratory (https://ielab.info/labs/ielab-gloria). Only two parts are needed:
**part I** (MRIO tables in basic prices, ~5.5 GB per year) and **part III**
(satellite accounts).

Everything is done inside the app (tab **Data & updates**), using only the R
package `googledrive` - no extra programs:

1. **Connect Google Drive** (once per PC): opens the Google login in the browser,
   read-only access. The login is stored in `<data>/.google_token`.
2. Paste the link of the release folder and click **Check folder** (shows the
   version found and the download size).
3. Click **Download and compile**. The release is processed year by year in a
   background R process: download one year, compile it, delete its raw files.
   So at most ~10 GB of raw data are on disk at any time. A full release takes
   several hours (mostly download time; compiling takes ~3 minutes per year).
   Progress is shown in the tab; logs are in `<data>/v<version>/logs/`.
4. When all years are done, the new version becomes the active version; restart
   the app. Several versions can be installed side by side and switched in the tab.

If the process is interrupted (PC off, network), just start it again: finished
years are skipped and interrupted downloads restart.

The same works without the app (after connecting Google Drive once):

```powershell
Rscript update/update_gloria.R <FOLDER-ID> <VERSION>
```

If the raw zip files are already on disk (e.g. downloaded by hand into
`<data>/v<version>/raw`), compile them in RStudio with
`source("parser/run_parser.R")`. Finished years are skipped, plausibility checks
for every year are written to `parsed/checks_all_years.csv`
(`output_reproduced_by_L` must be 1), and the raw files are deleted when all years
are done.

If a new release changes the regions or sectors, the concordances in
`input/concordances/` are rebuilt automatically. New satellite indicators can be
added to the recommended list in `input/indicator_catalogue.csv`.

## 3. Running the app

```r
shiny::runApp("app")
```

or open `app/app.R` and click **Run App**. Results are computed on the fly; a
footprint for one indicator and year takes a few seconds (the very detailed
production side x final product breakdown 10-60 seconds).


### Portable version (no R installation needed)

`source("portable/build_portable.R")` builds the folder `../GLORIApp_portable`
(and a zip of it, ~210 MB) with a copy of R, all needed packages, the app and a
small launcher `Start GLORIApp.exe` (compiled from `portable/launcher.cs` with the
C# compiler that ships with Windows). Users unpack the zip and double click the
exe; the app opens in the browser and R stops when the browser tab is closed.
The GLORIA data are not part of the bundle: copy the data folder to
`C:/Users/<user>/Data/GLORIA` or use the tab *Data & updates*.

## 4. Repository structure

| Path | Content |
|---|---|
| `config.R` | all paths and settings (single place to change) |
| `app/app.R`, `app/full_app.R` | Shiny user interface and server |
| `app/charts_tab.R` | tab "Charts" (interactive charts, image export) |
| `app/update_tab.R` | tab "Data & updates" |
| `app/help.md` | "How it works" page of the app |
| `R/engine.R` | all calculations (footprints, production, overview, aggregation, plausibility checks); usable without the app |
| `R/export.R` | download formats (csv, csv for German Excel, xlsx, txt) |
| `R/functions_io.R` | reading/writing helpers, aggregation helpers |
| `R/texts.R` | all explanatory texts of the app |
| `R/update.R` | Google Drive download helpers (package googledrive), data folders |
| `R/share.R` | using/sharing an already compiled GLORIA (manifest, completeness check) |
| `parser/` | parser: concordances, metadata, one year, run all years |
| `update/update_gloria.R` | download + parse + activate a release (command line) |
| `input/concordances/regions.csv` | region groupings - **add a column to get a new aggregation in the app** |
| `input/concordances/sectors.csv` | sector groupings - same |
| `input/indicator_catalogue.csv` | recommended indicators with explanations |
| `tests/run_tests.R`, `tests/testthat/` | unit tests (testthat) on a mini GLORIA (3 regions x 4 sectors) |
| `portable/` | build script and launcher for the portable version (no R installation needed) |
| `legacy/` | original v059 scripts of GLORIA-MRIO_Parser |
| `docs/` | user and developer guides (Markdown + Word via `docs/build_docs.R`), intro slides and exercises |

## 5. Using the engine from R scripts

```r
source("config.R"); source("R/functions_io.R"); source("R/engine.R")
meta <- readRDS(file.path(paths$meta, "meta.rds"))
res <- run_calculation(list(
  type = "footprint", indicators = c("ghg_edgar", "mat_total"), years = 2015:2022,
  production_region = "world_region_7", production_sector = "broad_sector",
  product_made_in = "none", consumption_product = "none", consumption_region = "region_name",
  by_fd = FALSE, fd_codes = 1:6, include_direct_fd = TRUE), meta)
fwrite(res, "my_footprints.csv")
```

## 6. Method in brief

Standard environmentally-extended MRIO analysis, same as in `GLORIA-MRIO_Parser`:
`Z` = use block of the GLORIA supply-use table (products x industries, treated as
square sector x sector because GLORIA supply is near-diagonal),
`x = Z 1 + Y 1`, `A = Z diag(1/x)`, `L = (I - A)^-1`.
Footprints: `diag(q/x) L Y` (by production side) and `(q/x) L diag(y)` (by final product).
For scripts only, the engine also offers value added embodied in gross exports
(`type = "exports"`, OECD TiVA style: `(v/x) L e`). Direct emissions of
households (GLORIA `YQ`) are optionally added to the region where they occur.

Parsed files per year (`parsed/<year>/`): only the standard matrices - `Z` (Arrow
float32 or sparse RDS), `Y.rds`, `V.rds` (value added by component), `x.rds`,
`Q.rds` / `QY.rds` (all satellite accounts, sparse) and `L.arrow` (Leontief inverse,
float32 Arrow file, ~1 s to load, also readable with Python/pyarrow). All footprint
products (L·Y, s·L, ...) are calculated by the engine when they are requested.

World Bank income groups: classification of fiscal year **FY26** (published July 2025,
based on GNI per capita 2024) from the World Bank historical file
`input/concordances/worldbank_OGHIST.xlsx`; World Bank regions from the World Bank
API (`worldbank_country_classification.csv`). To switch the year, change
`wb_fiscal_year` in `parser/01_build_concordances.R` and re-run it (no re-parsing needed).
The four GLORIA "Rest of ..." regions form their own group because they mix
countries of different income levels.

## Licence, citation and disclaimer

Copyright (c) 2026 Hanspeter Wieland. GLORIApp is licensed under the
**PolyForm Noncommercial License 1.0.0** ([`LICENSE`](LICENSE)): free for
non-commercial use (research, teaching, personal study, public institutions);
**commercial use requires prior written permission**. Documentation: CC BY-NC 4.0.

GLORIA data are licensed by the GLORIA team under **CC BY-NC 3.0 AU**; please cite
Lenzen et al. (2017) *Economic Systems Research* 29, 158-186 and Lenzen et al. (2021)
*Nature Sustainability* (doi:10.1038/s41893-021-00811-6).

GLORIApp and its results are provided "as is", **without any warranty**; the author
assumes no liability for the correctness of the footprints. Details, full citations
and the complete disclaimer: [`NOTICE.md`](NOTICE.md).
