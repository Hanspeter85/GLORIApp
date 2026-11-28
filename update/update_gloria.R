# =============================================================================
# update/update_gloria.R  -  Download and compile a GLORIA release
# =============================================================================
# Normally started by the app (tab "Data & updates"). Can also be run by hand
# from the repo root in a terminal:
#
#   Rscript update/update_gloria.R <drive-folder-id> <version> [--download-only]
#
# e.g.  Rscript update/update_gloria.R 1tm1Cs5ABVRuE3fDkT80TfE5fPmnWPrA7 60
#
# Requires a stored Google Drive login (button "Connect Google Drive" in the
# app, or google_login() from R/update.R in the console).
#
# To keep disk usage low, the release is processed YEAR BY YEAR:
#   download the zips of one year -> parse that year -> delete its raw zips.
# A full release needs ~5.5 GB of raw data per year, but at no time more than
# one year of raw data is on disk. Finished years are skipped, so an
# interrupted update just continues when it is started again.
# At the end the version becomes the active version of the app.
# =============================================================================

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("Usage: Rscript update/update_gloria.R <drive-folder-id> <version> [--download-only] [--data-root=<folder>] [--raw-root=<folder>]")
folder_id <- args[1]
version <- as.integer(args[2])
download_only <- "--download-only" %in% args

# Folders for the compiled MRIO and for the raw files (chosen in the app)
opt <- function(name) { a <- grep(paste0("^--", name, "="), args, value = TRUE); if (length(a)) sub("^--[a-z-]+=", "", a[1]) else "" }
if (nzchar(opt("data-root"))) Sys.setenv(GLORIA_DATA_ROOT = opt("data-root"))
if (nzchar(opt("raw-root")))  Sys.setenv(GLORIA_RAW_ROOT  = opt("raw-root"))

# Work from the repo root (this script lives in <repo>/update/)
script_path <- sub("--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
if (length(script_path) == 1) setwd(dirname(dirname(normalizePath(script_path))))

# The version is passed to config.R via an environment variable
Sys.setenv(GLORIA_VERSION = version)
source("config.R")
source("R/functions_io.R")
source("R/update.R")

stage <- function(txt) cat(sprintf("\n[%s] ===== %s =====\n", format(Sys.time(), "%H:%M:%S"), txt))
logf  <- function(...) cat(sprintf("[%s] %s\n", format(Sys.time(), "%H:%M:%S"), paste0(...)))

# --- 0) Google Drive login (stored token) ---------------------------------------------
email <- google_login_cached()
if (is.na(email)) stop("No Google Drive login found. Click 'Connect Google Drive' in the app first.")
logf("Google Drive: logged in as ", email)
logf("Free disk space: ", free_disk_gb(), " GB")

# --- 1) What is in the release folder? ----------------------------------------------
stage(sprintf("Reading the release folder (GLORIA v%d)", version))
info <- inspect_drive_folder(folder_id)
need <- needed_files(info$files, version)
if (nrow(need) == 0) stop("No GLORIA v", version, " files found in this folder.")
year_of <- function(p) {
  m <- regmatches(basename(p), regexpr("(?<![0-9])(19|20)[0-9]{2}(?![0-9])", basename(p), perl = TRUE))
  if (length(m) == 1) as.integer(m) else NA_integer_
}
need[, year := vapply(path, year_of, 0L)]
years <- sort(unique(na.omit(need$year)))
logf(nrow(need), " files, ", length(years), " years (", min(years), "-", max(years), "), ",
     round(sum(need$size, na.rm = TRUE) / 1e9, 1), " GB")

dl <- function(files) download_files(files, paths$raw, log = logf)

# --- 2) Documentation files first (ReadMe is needed by the parser) ------------------------
dl(need[is.na(year)])

# --- 3) Year by year: download -> parse -> raw zips are deleted by the parser ---------------
for (y in years) {
  if (file.exists(file.path(paths$parsed, y, "_DONE"))) { logf(y, ": already parsed, skipped"); next }
  stage(sprintf("Year %d: download", y))
  dl(need[year == y])
  if (download_only) next
  stage(sprintf("Year %d: compile", y))
  # run_parser.R only parses years whose raw files are complete and skips
  # finished years; it deletes the raw zips of each parsed year
  source("parser/run_parser.R", local = new.env())
}
if (download_only) { stage("Download complete"); quit(save = "no") }

# --- 4) Activate ----------------------------------------------------------------------------
all_done <- all(file.exists(file.path(paths$parsed, years, "_DONE")))
if (all_done) {
  set_active_version(version)
  stage(sprintf("FINISHED. GLORIA v%d is now the active version. Restart the app to use it.", version))
} else {
  stage("Not all years could be compiled - see the messages above. Start the update again to retry.")
}
