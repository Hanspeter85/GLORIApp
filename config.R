# =============================================================================
# config.R  -  Central settings for the parser, the updater and the Shiny app
# =============================================================================
# This is the ONLY place where paths and the GLORIA version are set.
# Normally nothing has to be changed here: the folders are chosen in the app
# (tab "Data & updates"), new GLORIA releases are installed with the update
# function of the app or with update/update_gloria.R.
#
# The file is loaded with source() by the parser, the updater and app/app.R.
# =============================================================================

# --- Data folders -------------------------------------------------------------
# The data deliberately live OUTSIDE the git repository (far too big for GitHub).
#   data_root  compiled GLORIA (MRIO) - one sub folder per version (v60, v61, ...)
#   raw_root   raw downloads and unpacked files while parsing (temporary; they
#              are deleted after parsing). Empty = inside data_root.
# Priority for each: 1) environment variable (GLORIA_DATA_ROOT / GLORIA_RAW_ROOT,
#                       e.g. in ~/.Renviron or set by the updater),
#                    2) the folders saved in the app (user settings file),
#                    3) default C:/Users/<user>/Data/GLORIA
settings_file <- file.path(tools::R_user_dir("GLORIApp", "config"), "settings.dcf")
user_settings <- if (file.exists(settings_file)) as.list(read.dcf(settings_file)[1, ]) else list()
first_set <- function(...) { for (v in list(...)) if (!is.null(v) && !is.na(v) && nzchar(v)) return(v); "" }

data_root <- first_set(Sys.getenv("GLORIA_DATA_ROOT"), user_settings$data_root,
                       file.path(Sys.getenv("USERPROFILE", unset = path.expand("~")), "Data", "GLORIA"))
raw_root  <- first_set(Sys.getenv("GLORIA_RAW_ROOT"), user_settings$raw_root)
# Folder where the app saves results and charts with the "Save in folder" buttons
results_dir <- first_set(user_settings$results_dir,
                         file.path(Sys.getenv("USERPROFILE", unset = path.expand("~")), "Documents", "GLORIApp_results"))

# Save settings chosen in the app (used from the next start on). Only the
# given entries are changed, the others are kept.
save_user_settings <- function(...) {
  new <- list(...)
  cur <- if (file.exists(settings_file)) as.list(read.dcf(settings_file)[1, ]) else list()
  cur[names(new)] <- new
  dir.create(dirname(settings_file), recursive = TRUE, showWarnings = FALSE)
  write.dcf(as.data.frame(cur, stringsAsFactors = FALSE), settings_file)
}

# --- GLORIA version -----------------------------------------------------------
# Version number as it appears in the raw file names ("..._060_Markup001...").
# Priority: 1) environment variable GLORIA_VERSION (used by the updater),
#           2) file <data_root>/active_version.txt (written by the updater),
#           3) default below.
gloria_version <- local({
  v <- Sys.getenv("GLORIA_VERSION")
  f <- file.path(data_root, "active_version.txt")
  if (nzchar(v)) as.integer(v)
  else if (file.exists(f)) as.integer(readLines(f, warn = FALSE)[1])
  else 60L
})

# Years to parse / years offered in the app. The parser replaces this by the
# years it actually finds in the raw data.
gloria_years <- 1990:2029

version_dir <- file.path(data_root, sprintf("v%02d", gloria_version))
raw_dir     <- file.path(if (nzchar(raw_root)) raw_root else data_root, sprintf("v%02d", gloria_version))

paths <- list(
  # Raw data as downloaded from Google Drive (zip archives)
  raw       = file.path(raw_dir, "raw"),
  # Scratch folder where ONE year is unzipped at a time (emptied after parsing)
  unzip_tmp = file.path(raw_dir, "tmp_unzip"),
  # Analysis-ready parsed data (one sub folder per year)
  parsed    = file.path(version_dir, "parsed"),
  # Metadata (labels, indicator catalogue) used by parser and app
  meta      = file.path(version_dir, "parsed", "meta"),
  # Parser and updater log files
  logs      = file.path(version_dir, "logs"),
  # Small input files inside the repo (concordances, ReadMe, catalogue)
  input     = Sys.getenv("GLORIA_INPUT_DIR", unset = "input")
)

# --- Parser options -----------------------------------------------------------
parser_options <- list(
  # Delete the unzipped raw csv files after a year has been parsed (saves space).
  delete_unzipped = TRUE,
  # Skip years that are already parsed (makes the parser resumable).
  skip_existing = TRUE,
  # Delete the raw zip of a year (MRIO part I, a few GB) once that year has
  # been parsed successfully. Saves ~60-120 GB; the zips stay on Google Drive.
  delete_raw_after_parse = TRUE
)
