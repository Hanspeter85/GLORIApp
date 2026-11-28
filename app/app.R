# =============================================================================
# app/app.R  -  GLORIApp: footprint calculator for the GLORIA MRIO
# =============================================================================
# START THE APP
#   Open GLORIApp.Rproj in RStudio, open this file and click "Run App",
#   or run in the console:   shiny::runApp("app")
#
# The main output are clean csv tables for Excel, R, Python, Tableau, ...;
# the tab "Charts" (app/charts_tab.R) gives a quick interactive look at them.
#
# STRUCTURE OF THIS FILE
#   1. Setup: load settings, helper functions and metadata
#   2. User interface (UI): see app/full_app.R (sidebar with 7 steps, tabs)
#   3. Server: reacts to the user's choices, runs the calculation, offers
#      the download
# The actual calculations are in R/engine.R.
# =============================================================================

# =============================================================================
# 1. SETUP
# =============================================================================
suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(data.table)
})

# The app can be started from the repo root or from inside app/ -> find root
root <- if (file.exists("config.R")) "." else ".."
source(file.path(root, "config.R"), local = TRUE)
# Relative input path -> relative to the repo root (absolute paths stay as they are)
if (!grepl("^([A-Za-z]:|/)", paths$input)) paths$input <- file.path(root, paths$input)
source(file.path(root, "R", "functions_io.R"), local = TRUE)
source(file.path(root, "R", "engine.R"), local = TRUE)
source(file.path(root, "R", "export.R"), local = TRUE)
source(file.path(root, "R", "texts.R"), local = TRUE)

source(file.path(root, "R", "update.R"), local = TRUE)
source(file.path(root, "R", "share.R"), local = TRUE)
source(file.path(root, "app", "update_tab.R"), local = TRUE)
source(file.path(root, "app", "charts_tab.R"), local = TRUE)
source(file.path(root, "app", "how_it_works.R"), local = TRUE)

# Metadata created by the parser (labels, concordances, indicator catalogue).
meta_file <- file.path(paths$meta, "meta.rds")
data_ready <- file.exists(meta_file) && length(available_years()) > 0

if (data_ready) {
  # Normal mode: the full footprint calculator (defines `ui` and `server`)
  source(file.path(root, "app", "full_app.R"), local = TRUE)
} else {
  # Setup mode: no parsed GLORIA data yet -> only show the update tab, which
  # downloads and compiles a GLORIA release.
  ui <- page_navbar(
    title = "GLORIApp - setup",
    theme = bs_theme(version = 5, bootswatch = "flatly"),
    nav_panel("Start", div(class = "alert alert-warning m-3",
      sprintf("No compiled GLORIA data found for version %d in %s.", gloria_version, paths$parsed),
      "Use the tab 'Data & updates': either point the app to an already compiled GLORIA (e.g. downloaded",
      "from Box - option A) or download and compile it from Google Drive (option B; or run",
      tags$code("parser/run_parser.R"), "if the raw data are already downloaded).")),
    update_ui(),
    how_it_works_panel()
  )
  server <- function(input, output, session) update_server(input, output, session, root)
}

# Portable version (started by "Start GLORIApp.exe"): stop R when the browser
# tab is closed, otherwise R would keep running invisibly in the background.
if (identical(Sys.getenv("GLORIAPP_PORTABLE"), "1")) {
  app_server <- server
  server <- function(input, output, session) {
    session$onSessionEnded(function() stopApp())
    app_server(input, output, session)
  }
}

shinyApp(ui, server)
