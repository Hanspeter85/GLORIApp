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
# Steps: 1) download the needed parts with rclone (resumes if interrupted)
#        2) parse all years (parser/run_parser.R, skips finished years)
#        3) make this version the active version of the app
# =============================================================================

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("Usage: Rscript update/update_gloria.R <drive-folder-id> <version> [--download-only]")
folder_id <- args[1]
version <- as.integer(args[2])
download_only <- "--download-only" %in% args

# Work from the repo root (this script lives in <repo>/update/)
script_path <- sub("--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
if (length(script_path) == 1) setwd(dirname(dirname(normalizePath(script_path))))

# The version is passed to config.R via an environment variable
Sys.setenv(GLORIA_VERSION = version)
source("config.R")
source("R/functions_io.R")
source("R/update.R")

stage <- function(txt) cat(sprintf("\n[%s] ===== %s =====\n", format(Sys.time(), "%H:%M:%S"), txt))

# --- 1) Download ------------------------------------------------------------------
stage(sprintf("STEP 1/3: downloading GLORIA v%d (only parts I and III) to %s", version, paths$raw))
st <- rclone_status()
if (!st$ok) stop(st$msg)
dir.create(paths$raw, recursive = TRUE, showWarnings = FALSE)
cat("Free disk space:", free_disk_gb(), "GB\n")
inc <- as.vector(rbind("--include", shQuote(download$include(version))))
res <- system2(rclone_path(),
               c("copy", shQuote(drive_remote(folder_id)), shQuote(paths$raw), inc,
                 "--transfers", "4", "--drive-acknowledge-abuse",
                 "--stats", "30s", "--stats-one-line", "-v"))
if (res != 0) stop("Download failed or was interrupted (rclone exit code ", res, "). ",
                   "Start the update again - finished files are not downloaded twice.")
stage("Download complete")
if (download_only) quit(save = "no")

# --- 2) Parse -------------------------------------------------------------------------
stage("STEP 2/3: compiling the data (this takes several hours for all years)")
source("parser/run_parser.R")

# --- 3) Activate -------------------------------------------------------------------------
stage("STEP 3/3: activating the new version")
set_active_version(version)
stage(sprintf("FINISHED. GLORIA v%d is now the active version. Restart the app to use it.", version))
