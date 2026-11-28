# Copyright (c) 2026 Hanspeter Wieland - PolyForm Noncommercial License 1.0.0 (see LICENSE, NOTICE.md)
# =============================================================================
# R/update.R  -  Download and compile new GLORIA releases from Google Drive
# =============================================================================
# Used by the "Data & updates" tab of the app and by update/update_gloria.R.
# Only R packages are needed (googledrive from CRAN) - no extra programs.
#
# HOW AN UPDATE WORKS
#   1. The GLORIA team publishes each release in a Google Drive folder
#      (links on https://ielab.info/labs/ielab-gloria). The user pastes the
#      link of the release folder into the app.
#   2. The user connects the app to Google Drive once (browser login, read
#      only). The login is stored on this PC (folder <data_root>/.google_token)
#      so that the background process can use it too.
#   3. Only the needed files are downloaded (MRIO tables in basic prices =
#      part I, satellite accounts = part III, ReadMe, release notes) into
#      <data_root>/v<version>/raw. Finished files are skipped, so an
#      interrupted download simply continues when started again.
#   4. The parser (parser/run_parser.R) compiles all years, deletes the raw
#      files afterwards, and the new version becomes the active version.
# Steps 3-4 run in a separate background R process, so the app stays usable.
# Progress is written to a log file that the app displays.
# =============================================================================

# Where the Google login token is cached (shared by app and background process)
google_token_dir <- function() file.path(data_root, ".google_token")

# Configure googledrive: read-only access, token cache on this PC
google_setup <- function(email = TRUE) {
  if (!requireNamespace("googledrive", quietly = TRUE)) {
    stop("The R package 'googledrive' is missing: install.packages(\"googledrive\")")
  }
  dir.create(google_token_dir(), recursive = TRUE, showWarnings = FALSE)
  options(gargle_oauth_cache = google_token_dir(),
          gargle_oauth_email = email)
}

# Interactive login (opens the browser). Call from the app or the console.
google_login <- function() {
  google_setup(email = NULL)
  googledrive::drive_auth(scopes = "https://www.googleapis.com/auth/drive.readonly",
                          cache = google_token_dir())
  googledrive::drive_user()$emailAddress
}

# Non-interactive login with the cached token (background process).
# Returns the e-mail address, or NA if there is no valid stored login.
google_login_cached <- function() {
  # no stored token at all -> not connected (and never open a browser here)
  if (!dir.exists(google_token_dir()) || length(list.files(google_token_dir())) == 0) {
    return(NA_character_)
  }
  google_setup(email = TRUE)
  op <- options(rlang_interactive = FALSE)   # never start the browser login here
  on.exit(options(op), add = TRUE)
  ok <- tryCatch({
    googledrive::drive_auth(scopes = "https://www.googleapis.com/auth/drive.readonly",
                            cache = google_token_dir(), email = TRUE)
    googledrive::drive_has_token()
  }, error = function(e) FALSE)
  if (isTRUE(ok)) googledrive::drive_user()$emailAddress else NA_character_
}

# Extract the folder id from a Google Drive link (or accept a bare id)
drive_folder_id <- function(link) {
  link <- trimws(link)
  m <- regmatches(link, regexpr("folders/[A-Za-z0-9_-]+", link))
  if (length(m) == 1) return(sub("folders/", "", m))
  if (grepl("^[A-Za-z0-9_-]{20,}$", link)) return(link)
  NA_character_
}

# List all files below a Drive folder with their relative path and size.
# max_depth limits the recursion (GLORIA releases are at most 2-3 levels deep).
drive_list_files <- function(folder_id, path = "", max_depth = 4) {
  items <- googledrive::drive_ls(googledrive::as_id(folder_id))
  if (nrow(items) == 0) return(data.table(path = character(), id = character(), size = numeric()))
  mime <- vapply(items$drive_resource, function(r) r$mimeType, "")
  size <- vapply(items$drive_resource, function(r) as.numeric(r$size %||% NA), 0)
  is_folder <- mime == "application/vnd.google-apps.folder"
  files <- data.table(path = file.path(path, items$name[!is_folder]),
                      id = as.character(items$id[!is_folder]), size = size[!is_folder])
  files[, path := sub("^/", "", path)]
  if (max_depth > 0) {
    for (k in which(is_folder)) {
      files <- rbind(files, drive_list_files(items$id[k], file.path(path, items$name[k]), max_depth - 1))
    }
  }
  files
}
`%||%` <- function(a, b) if (is.null(a)) b else a

# Which files of a release are needed? ReadMe, release notes, part I and III
# of the given version (a folder may contain several versions, e.g. 059a + 060)
needed_files <- function(files, version) {
  v <- sprintf("0%d", version)
  files[grepl(sprintf("GLORIA_(ReadMe|ReleaseNotes)_%s", v), basename(path)) |
          grepl(sprintf("Loop%s_part_(I|III)_", v), path)]
}

# Look into a release folder: which version, which files, how big?
inspect_drive_folder <- function(folder_id) {
  files <- drive_list_files(folder_id)
  v <- regmatches(files$path, regexpr("GLORIA_ReadMe_0\\d+", files$path))
  version <- if (length(v)) max(as.integer(sub("GLORIA_ReadMe_0", "", v))) else NA_integer_
  need <- if (is.na(version)) files[0] else needed_files(files, version)
  list(version = version, files = files, needed = need,
       download_gb = round(sum(need$size, na.rm = TRUE) / 1e9, 1))
}

# Download a set of files (rows of drive_list_files) into raw_dir.
# - files that already exist with the right size are skipped (resume)
# - each file is first written as *.partial and renamed when complete
# - every file is tried up to 3 times
download_files <- function(files, raw_dir, log = message) {
  for (i in seq_len(nrow(files))) {
    f <- files[i]
    dest <- file.path(raw_dir, f$path)
    if (file.exists(dest) && (is.na(f$size) || file.size(dest) == f$size)) next
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    tmp <- paste0(dest, ".partial")
    for (attempt in 1:3) {
      log(sprintf("downloading %s (%.2f GB), attempt %d", f$path, f$size / 1e9, attempt))
      ok <- tryCatch({
        googledrive::drive_download(googledrive::as_id(f$id), path = tmp, overwrite = TRUE, verbose = FALSE)
        is.na(f$size) || file.size(tmp) == f$size
      }, error = function(e) { log("  error: ", conditionMessage(e)); FALSE })
      if (ok) { file.rename(tmp, dest); break }
      Sys.sleep(10 * attempt)
    }
    if (!file.exists(dest)) stop("Download failed three times: ", f$path, ". Start the update again later.")
  }
  invisible(TRUE)
}

# Installed (parsed) versions in data_root
installed_versions <- function() {
  d <- list.dirs(data_root, full.names = FALSE, recursive = FALSE)
  d <- d[grepl("^v\\d+$", d)]
  if (length(d) == 0) return(data.table())
  rbindlist(lapply(d, function(v) {
    p <- file.path(data_root, v, "parsed")
    yrs <- suppressWarnings(as.integer(list.dirs(p, full.names = FALSE, recursive = FALSE)))
    yrs <- yrs[!is.na(yrs)]
    yrs <- yrs[file.exists(file.path(p, yrs, "_DONE"))]
    data.table(
      version = as.integer(sub("v", "", v)),
      parsed_years = if (length(yrs)) sprintf("%d (%d-%d)", length(yrs), min(yrs), max(yrs)) else "none",
      ready_for_app = file.exists(file.path(p, "meta", "meta.rds")) && length(yrs) > 0,
      active = as.integer(sub("v", "", v)) == gloria_version)
  }))
}

set_active_version <- function(version) {
  dir.create(data_root, recursive = TRUE, showWarnings = FALSE)
  writeLines(as.character(version), file.path(data_root, "active_version.txt"))
}

# Free disk space (GB) of the drive holding `path` (Windows only, else NA)
free_disk_gb <- function(path = data_root) {
  if (.Platform$OS.type != "windows" || length(path) != 1 || !nzchar(path)) return(NA_real_)
  drive <- substr(normalizePath(path, mustWork = FALSE), 1, 1)
  out <- tryCatch(system2("powershell", c("-NoProfile", "-Command",
                   shQuote(sprintf("(Get-PSDrive %s).Free", drive))), stdout = TRUE),
                  error = function(e) NA)
  round(as.numeric(out[1]) / 1e9, 1)
}

# Check that a folder exists or can be created and is writable
folder_ok <- function(path) {
  if (!nzchar(path)) return(FALSE)
  if (!dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
  dir.exists(path) && file.access(path, 2) == 0
}

# Start download + parsing in a separate background R process.
# data_dir / raw_dir: where the compiled MRIO and the raw files go (default:
# the current settings). Returns the path of the log file.
start_update <- function(folder_id, version, repo_root = ".", download_only = FALSE,
                         data_dir = data_root, raw_dir = raw_root) {
  logdir <- file.path(data_dir, sprintf("v%02d", version), "logs")
  dir.create(logdir, recursive = TRUE, showWarnings = FALSE)
  log <- file.path(logdir, sprintf("update_%s.log", format(Sys.time(), "%Y%m%d_%H%M%S")))
  rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  args <- c(shQuote(normalizePath(file.path(repo_root, "update", "update_gloria.R"))),
            folder_id, version, if (download_only) "--download-only",
            shQuote(paste0("--data-root=", data_dir)),
            if (nzchar(raw_dir)) shQuote(paste0("--raw-root=", raw_dir)))
  # wait = FALSE: the app does not wait, the process runs on its own
  system2(rscript, args, wait = FALSE, stdout = log, stderr = log)
  log
}
