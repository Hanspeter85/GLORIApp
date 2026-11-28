# Copyright (c) 2026 Hanspeter Wieland - PolyForm Noncommercial License 1.0.0 (see LICENSE, NOTICE.md)
# =============================================================================
# parser/run_parser.R  -  Parse all GLORIA years in one go
# =============================================================================
# HOW TO USE
#   1. Download the raw GLORIA data into the folder paths$raw (see config.R
#      and README.md). Zip files can stay zipped.
#   2. Open GLORIA_app.Rproj in RStudio (sets the working directory).
#   3. Run:  source("parser/run_parser.R")
#
# The parser is RESUMABLE: years that already have a "_DONE" marker are
# skipped. If something crashes, just run the script again.
#
# Expected run time on a desktop PC (8 cores, 32 GB RAM): roughly 10-20
# minutes per year, dominated by reading the 39 360 x 39 360 csv and by the
# matrix inversion. Memory peak ~ 15 GB.
#
# Disk space per parsed year: ~3.5 GB (of which L: 1.55 GB).
# =============================================================================

source("config.R")
source("R/functions_io.R")
source("parser/02_build_meta.R")
source("parser/03_parse_year.R")

dir.create(paths$parsed, recursive = TRUE, showWarnings = FALSE)
dir.create(paths$logs, recursive = TRUE, showWarnings = FALSE)
logfile <- file.path(paths$logs, sprintf("parser_%s.log", format(Sys.time(), "%Y%m%d_%H%M")))

# Use all CPU cores for reading csv files
setDTthreads(0)

# --- Step 0: copy the ReadMe of this version into the repo --------------------------
# The ReadMe (labels of regions, sectors, satellites) comes with the download.
readme_name <- sprintf("GLORIA_ReadMe_0%d.xlsx", gloria_version)
readme_raw <- list.files(paths$raw, paste0("^", readme_name, "$"), recursive = TRUE, full.names = TRUE)
if (length(readme_raw) > 0 && !file.exists(file.path(paths$input, readme_name))) {
  file.copy(readme_raw[1], file.path(paths$input, readme_name))
  log_msg("Copied ", readme_name, " to ", paths$input, file = logfile)
}

# --- Step 1: concordances (if missing or built from another ReadMe) -------------------
conc_file <- file.path(paths$input, "concordances", "regions.csv")
rebuild <- !file.exists(conc_file)
if (!rebuild) {
  # rebuild if the number of regions/sectors in the ReadMe has changed
  n_now <- nrow(openxlsx::read.xlsx(file.path(paths$input, readme_name), sheet = "Regions"))
  rebuild <- n_now != nrow(fread(conc_file))
}
if (rebuild) source("parser/01_build_concordances.R")

# --- Years: take those that are actually in the raw data ------------------------------
# (years of zips that were already parsed and deleted are added back via the
#  parsed folders; config.R's year range is the minimum expectation)
expected_years <- sort(unique(c(gloria_years, detect_raw_years())))
yrs <- detect_raw_years()
if (length(yrs) > 0) gloria_years <- yrs
log_msg("GLORIA v", gloria_version, ": years ", min(gloria_years), "-", max(gloria_years), file = logfile)

# --- Step 2: metadata --------------------------------------------------------------
log_msg("Building metadata (labels, indicator catalogue)", file = logfile)
meta <- build_meta()

# Keep the GLORIA documentation of this version (release notes, ReadMe) next to
# the parsed data, so that the app can show it (tab "How it works")
gdocs <- list.files(c(paths$raw, paths$input), sprintf("GLORIA_(ReadMe|ReleaseNotes)_0%d[.](xlsx|pdf)$", gloria_version),
                    recursive = TRUE, full.names = TRUE)
if (length(gdocs)) file.copy(gdocs, paths$meta, overwrite = FALSE)

# --- Step 3: loop over years -------------------------------------------------------
all_checks <- list()
for (year in gloria_years) {
  done <- file.exists(file.path(paths$parsed, year, "_DONE"))
  if (done && isTRUE(parser_options$skip_existing)) {
    log_msg(year, ": already parsed, skipping", file = logfile)
    next
  }
  # tryCatch: an error in one year (e.g. missing file) does not stop the loop
  res <- tryCatch(parse_year(year, meta, logfile),
                  error = function(e) {
                    log_msg(year, ": ERROR - ", conditionMessage(e), file = logfile)
                    # remove half-unpacked files of this year (they are re-extracted next time)
                    unlink(file.path(paths$unzip_tmp, year), recursive = TRUE)
                    NULL
                  })
  if (!is.null(res)) all_checks[[as.character(year)]] <- res
  gc(verbose = FALSE)
}

# --- Step 4: collect plausibility checks of all years ---------------------------------
chk_files <- list.files(paths$parsed, "^checks\\.csv$", recursive = TRUE, full.names = TRUE)
if (length(chk_files) > 0) {
  checks <- rbindlist(lapply(chk_files, fread))
  fwrite(checks, file.path(paths$parsed, "checks_all_years.csv"))
  print(checks)
}

# --- Step 5: remove all raw data once every year is parsed -------------------------------
# Only the parsed tables are kept. ReadMe and release notes are kept as
# documentation in parsed/meta. Everything can be downloaded again from Drive.
all_done <- all(file.exists(file.path(paths$parsed, expected_years, "_DONE")))
# never delete while a download is still running (the downloader writes *.partial files)
download_running <- length(list.files(paths$raw, "\\.partial$", recursive = TRUE)) > 0
all_done <- all_done && !download_running
if (isTRUE(parser_options$delete_raw_after_parse) && all_done && dir.exists(paths$raw)) {
  docs <- list.files(paths$raw, sprintf("GLORIA_(ReadMe|ReleaseNotes)_0%d\\.(xlsx|pdf)$", gloria_version),
                     recursive = TRUE, full.names = TRUE)
  file.copy(docs, paths$meta, overwrite = TRUE)
  unlink(paths$raw, recursive = TRUE)
  unlink(paths$unzip_tmp, recursive = TRUE)
  log_msg("All years parsed: raw data deleted (ReadMe/release notes kept in ", paths$meta, ")",
          file = logfile)
} else if (!all_done) {
  log_msg("Not all years are parsed yet - raw data are kept. Run the parser again.", file = logfile)
}
log_msg("Parser finished.", file = logfile)
