# =============================================================================
# config.R  -  Central settings for the parser, the updater and the Shiny app
# =============================================================================
# This is the ONLY place where paths and the GLORIA version are set.
# Normally nothing has to be changed here: new GLORIA releases are installed
# with the update function of the app (tab "Data & updates") or with
# update/update_gloria.R, which also switch the active version.
#
# The file is loaded with source() by the parser, the updater and app/app.R.
# =============================================================================

# --- Data folders -------------------------------------------------------------
# The data deliberately live OUTSIDE the git repository (far too big for GitHub).
# Default: C:/Users/<user>/Data/GLORIA  with one sub folder per version (v60, v61, ...)
# Can be overridden with the environment variable GLORIA_DATA_ROOT, e.g. by
# adding the line  GLORIA_DATA_ROOT=D:/Data/GLORIA  to the file ~/.Renviron
data_root <- Sys.getenv(
  "GLORIA_DATA_ROOT",
  unset = file.path(Sys.getenv("USERPROFILE", unset = path.expand("~")), "Data", "GLORIA")
)

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

paths <- list(
  # Raw data as downloaded from Google Drive (zip archives)
  raw       = file.path(version_dir, "raw"),
  # Scratch folder where ONE year is unzipped at a time (emptied after parsing)
  unzip_tmp = file.path(version_dir, "tmp_unzip"),
  # Analysis-ready parsed data (one sub folder per year)
  parsed    = file.path(version_dir, "parsed"),
  # Metadata (labels, indicator catalogue) used by parser and app
  meta      = file.path(version_dir, "parsed", "meta"),
  # Parser and updater log files
  logs      = file.path(version_dir, "logs"),
  # Small input files inside the repo (concordances, ReadMe, catalogue)
  input     = Sys.getenv("GLORIA_INPUT_DIR", unset = "input")
)

# --- Download settings (used by the update function) ---------------------------------
download <- list(
  # rclone = free command line tool for Google Drive downloads (https://rclone.org).
  # Path to rclone.exe; if empty, rclone must be on the system PATH.
  rclone_exe = Sys.getenv("RCLONE_EXE",
                          unset = file.path(Sys.getenv("USERPROFILE"), "Tools", "rclone.exe")),
  # Name of the rclone remote for Google Drive (created once with
  #   rclone config create gdrive drive scope=drive.readonly )
  rclone_remote = "gdrive",
  # Only these parts of a GLORIA release are needed (rclone filter rules):
  # part I = MRIO tables in basic prices, part III = satellite accounts,
  # plus ReadMe (xlsx) and release notes (pdf) of THIS version only.
  # A pattern without leading "/" matches at any folder depth; "**" = any sub path.
  include = function(version) {
    v <- sprintf("0%d", version)
    c(sprintf("GLORIA_ReadMe_%s*.xlsx", v),
      sprintf("GLORIA_ReleaseNotes_%s*.pdf", v),
      sprintf("*Loop%s_part_I_*/**", v),  sprintf("*Loop%s_part_I_*.zip", v),
      sprintf("*Loop%s_part_III_*/**", v), sprintf("*Loop%s_part_III_*.zip", v))
  }
)

# --- Parser options -----------------------------------------------------------
parser_options <- list(
  # Store the Leontief inverse L? (~1.55 GB per year as float32).
  # The app needs L for product-based footprints of expert indicators and TiVA.
  store_L = TRUE,
  # Delete the unzipped raw csv files after a year has been parsed (saves space).
  delete_unzipped = TRUE,
  # Skip years that are already parsed (makes the parser resumable).
  skip_existing = TRUE,
  # Delete the raw zip of a year (MRIO part I, a few GB) once that year has
  # been parsed successfully. Saves ~60-120 GB; the zips stay on Google Drive.
  delete_raw_after_parse = TRUE
)
