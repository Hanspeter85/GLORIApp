# =============================================================================
# R/update.R  -  Helper functions to download and compile new GLORIA releases
# =============================================================================
# Used by the "Data & updates" tab of the app and by update/update_gloria.R.
#
# HOW AN UPDATE WORKS
#   1. The GLORIA team publishes each release in a Google Drive folder
#      (links on https://ielab.info/labs/ielab-gloria). The user pastes the
#      link of the release folder.
#   2. rclone (free tool, https://rclone.org) downloads ONLY the needed parts
#      (MRIO in basic prices + satellite accounts + ReadMe) into
#      <data_root>/v<version>/raw. Interrupted downloads simply continue.
#   3. The parser (parser/run_parser.R) compiles all years.
#   4. The new version becomes the active version of the app.
# Steps 2-4 run in a separate background R process, so the app stays usable.
# Progress is written to a log file that the app displays.
#
# ONE-TIME SETUP (see README.md)
#   - rclone.exe in C:/Users/<user>/Tools/ (or set RCLONE_EXE in ~/.Renviron)
#   - Google Drive login for rclone:
#       rclone config create gdrive drive scope=drive.readonly
# =============================================================================

rclone_path <- function() {
  if (nzchar(download$rclone_exe) && file.exists(download$rclone_exe)) return(download$rclone_exe)
  p <- Sys.which("rclone")
  if (nzchar(p)) p else NA_character_
}

# Is rclone installed and is the Google Drive remote configured?
rclone_status <- function() {
  exe <- rclone_path()
  if (is.na(exe)) return(list(ok = FALSE, msg = "rclone not found. See README.md, section 'Updates'."))
  remotes <- tryCatch(system2(exe, "listremotes", stdout = TRUE, stderr = TRUE), error = function(e) "")
  if (!any(remotes == paste0(download$rclone_remote, ":"))) {
    return(list(ok = FALSE, msg = sprintf(
      "rclone found, but no Google Drive connection named '%s'. Run once in a terminal:  %s config create %s drive scope=drive.readonly",
      download$rclone_remote, exe, download$rclone_remote)))
  }
  list(ok = TRUE, msg = "rclone and Google Drive connection are ready.")
}

# Extract the folder id from a Google Drive link (or accept a bare id)
drive_folder_id <- function(link) {
  link <- trimws(link)
  m <- regmatches(link, regexpr("folders/[A-Za-z0-9_-]+", link))
  if (length(m) == 1) return(sub("folders/", "", m))
  if (grepl("^[A-Za-z0-9_-]{20,}$", link)) return(link)
  NA_character_
}

drive_remote <- function(folder_id) {
  sprintf("%s,root_folder_id=%s:", download$rclone_remote, folder_id)
}

# List the files of a release folder on Google Drive and detect the version
inspect_drive_folder <- function(folder_id) {
  exe <- rclone_path()
  out <- system2(exe, c("lsf", shQuote(drive_remote(folder_id)), "-R", "--max-depth", "2",
                        "--format", "sp", "--separator", shQuote(";")),
                 stdout = TRUE, stderr = TRUE)
  st <- attr(out, "status")
  if (!is.null(st) && st != 0) stop(paste(out, collapse = "\n"))
  files <- data.table::fread(text = paste(out, collapse = "\n"), sep = ";", header = FALSE,
                             col.names = c("size", "path"))
  # A folder may contain several releases (e.g. 059a and 060): take the newest
  v <- regmatches(files$path, regexpr("GLORIA_ReadMe_0\\d+", files$path))
  version <- if (length(v)) max(as.integer(sub("GLORIA_ReadMe_0", "", v))) else NA_integer_
  vv <- sprintf("0%d", version)
  files[, needed := grepl(sprintf("GLORIA_(ReadMe|ReleaseNotes)_%s", vv), path) |
          grepl(sprintf("Loop%s_part_(I|III)_", vv), path)]
  list(version = version, files = files,
       download_gb = round(sum(files$size[files$needed & files$size > 0]) / 1e9, 1))
}

# Installed (parsed) versions in data_root
installed_versions <- function() {
  d <- list.dirs(data_root, full.names = FALSE, recursive = FALSE)
  d <- d[grepl("^v\\d+$", d)]
  if (length(d) == 0) return(data.table::data.table())
  active <- gloria_version
  data.table::rbindlist(lapply(d, function(v) {
    p <- file.path(data_root, v, "parsed")
    yrs <- suppressWarnings(as.integer(list.dirs(p, full.names = FALSE, recursive = FALSE)))
    yrs <- yrs[!is.na(yrs)]
    yrs <- yrs[file.exists(file.path(p, yrs, "_DONE"))]
    data.table::data.table(
      version = as.integer(sub("v", "", v)),
      parsed_years = if (length(yrs)) sprintf("%d (%d-%d)", length(yrs), min(yrs), max(yrs)) else "none",
      ready_for_app = file.exists(file.path(p, "meta", "meta.rds")) && length(yrs) > 0,
      active = as.integer(sub("v", "", v)) == active)
  }))
}

set_active_version <- function(version) {
  dir.create(data_root, recursive = TRUE, showWarnings = FALSE)
  writeLines(as.character(version), file.path(data_root, "active_version.txt"))
}

# Free disk space (GB) of the drive holding data_root (Windows only, else NA)
free_disk_gb <- function() {
  if (.Platform$OS.type != "windows") return(NA_real_)
  drive <- substr(normalizePath(data_root, mustWork = FALSE), 1, 1)
  out <- tryCatch(system2("powershell", c("-NoProfile", "-Command",
                   shQuote(sprintf("(Get-PSDrive %s).Free", drive))), stdout = TRUE),
                  error = function(e) NA)
  round(as.numeric(out[1]) / 1e9, 1)
}

# Start download + parsing in a separate background R process.
# Returns the path of the log file.
start_update <- function(folder_id, version, repo_root = ".", download_only = FALSE) {
  logdir <- file.path(data_root, sprintf("v%02d", version), "logs")
  dir.create(logdir, recursive = TRUE, showWarnings = FALSE)
  log <- file.path(logdir, sprintf("update_%s.log", format(Sys.time(), "%Y%m%d_%H%M%S")))
  rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  args <- c(shQuote(normalizePath(file.path(repo_root, "update", "update_gloria.R"))),
            folder_id, version, if (download_only) "--download-only")
  # wait = FALSE: the app does not wait, the process runs on its own
  system2(rscript, args, wait = FALSE, stdout = log, stderr = log)
  log
}
