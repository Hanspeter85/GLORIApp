# Copyright (c) 2026 Hanspeter Wieland - PolyForm Noncommercial License 1.0.0 (see LICENSE, NOTICE.md)
# =============================================================================
# docs/make_diagrams.R  -  Architecture diagrams for the developer guide
# =============================================================================
# Draws docs/fig_dataflow.png and docs/fig_runtime.png with base R (grid).
# Run from the repo root:  source("docs/make_diagrams.R")
# =============================================================================
library(grid)

col <- list(dark = "#1F3B2D", green = "#3E7A4F", light = "#EEF4EC", amber = "#E0A030",
            grey = "#5D6B62", blue = "#DCE8F2", text = "#1E2A22")

box <- function(x, y, w, h, title, body = NULL, fill = col$light, border = col$green, tcol = col$text) {
  grid.roundrect(x, y, w, h, r = unit(0.04, "snpc"), gp = gpar(fill = fill, col = border, lwd = 1.5))
  grid.text(title, x, y + h / 2 - 0.035, gp = gpar(fontface = "bold", fontsize = 11, col = tcol))
  if (!is.null(body)) grid.text(body, x, y - 0.015, gp = gpar(fontsize = 8.5, col = tcol, lineheight = 1.05))
}
arrow_ <- function(x0, y0, x1, y1, label = NULL, lty = 1) {
  grid.segments(x0, y0, x1, y1, gp = gpar(col = col$grey, lwd = 1.6, lty = lty, fill = col$grey),
                arrow = arrow(length = unit(0.12, "inches"), type = "closed"))
  if (!is.null(label)) grid.text(label, (x0 + x1) / 2, (y0 + y1) / 2 + 0.03,
                                 gp = gpar(fontsize = 8, col = col$grey, fontface = "italic"))
}

# --- 1) Data flow ----------------------------------------------------------------------
png("docs/fig_dataflow.png", width = 2000, height = 1150, res = 220)
grid.newpage()
grid.text("GLORIApp - data flow", 0.5, 0.95, gp = gpar(fontsize = 14, fontface = "bold", col = col$dark))
box(0.12, 0.68, 0.19, 0.28, "Google Drive",
    "GLORIA release\n(zip files, ~5.5 GB\nper year)", fill = col$blue, border = "#7A9CB8")
box(0.37, 0.68, 0.21, 0.28, "raw/",
    "zips of the year\nbeing processed\n(deleted after\nparsing)")
box(0.63, 0.68, 0.21, 0.28, "Parser",
    "parser/run_parser.R\n03_parse_year.R\nZ, Y, V, Q -> A -> L\n(~3 min per year)", fill = col$green, border = col$dark, tcol = "white")
box(0.88, 0.68, 0.19, 0.28, "parsed/<year>/",
    "L.f32, LY.f32, Y, V,\nQ, QY, E, M, x\n+ meta/meta.rds\n(~3.3 GB per year)")
arrow_(0.215, 0.68, 0.26, 0.68, "download")
arrow_(0.48, 0.68, 0.52, 0.68)
arrow_(0.74, 0.68, 0.785, 0.68, "write")
box(0.88, 0.25, 0.19, 0.26, "Engine",
    "R/engine.R\nrun_calculation()\nfootprint, overview,\nproduction, exports", fill = col$green, border = col$dark, tcol = "white")
box(0.60, 0.25, 0.21, 0.26, "Shiny app",
    "app/app.R\nfull_app.R\n(user interface)")
box(0.33, 0.25, 0.19, 0.26, "csv file",
    "long or wide table\nfor Excel, R, Python")
box(0.10, 0.25, 0.15, 0.26, "input/",
    "concordances,\nindicator\ncatalogue,\nReadMe")
arrow_(0.88, 0.54, 0.88, 0.385, "read")
arrow_(0.785, 0.25, 0.71, 0.25, "result")
arrow_(0.495, 0.25, 0.425, 0.25, "download")
arrow_(0.175, 0.385, 0.53, 0.55, "labels, concordances", lty = 2)
grid.text("Update function (tab 'Data & updates', update/update_gloria.R) runs the top row year by year in the background",
          0.5, 0.05, gp = gpar(fontsize = 8.5, col = col$grey))
dev.off()

# --- 2) Runtime architecture of the app -------------------------------------------------
png("docs/fig_runtime.png", width = 2000, height = 1250, res = 220)
grid.newpage()
grid.text("GLORIApp - what runs where", 0.5, 0.95, gp = gpar(fontsize = 14, fontface = "bold", col = col$dark))
box(0.14, 0.62, 0.22, 0.42, "Web browser",
    "HTML page built from\nthe UI definition:\nsidebar with 7 steps,\nresult table, tabs\n\nsends inputs,\nshows outputs", fill = col$blue, border = "#7A9CB8")
grid.roundrect(0.58, 0.55, 0.56, 0.70, r = unit(0.03, "snpc"), gp = gpar(fill = "white", col = col$dark, lwd = 2, lty = 2))
grid.text("R process (Shiny server, started by runApp() or Start GLORIApp.exe)", 0.58, 0.875,
          gp = gpar(fontsize = 9.5, fontface = "bold", col = col$dark))
box(0.43, 0.68, 0.22, 0.24, "server()",
    "app/full_app.R\nspec() collects inputs\nresult() on 'Calculate'\nmeta_r() own groups")
box(0.73, 0.68, 0.22, 0.24, "Engine",
    "R/engine.R\nrun_calculation(spec)\nloads parsed files\n(cache: one big matrix)", fill = col$green, border = col$dark, tcol = "white")
box(0.43, 0.36, 0.22, 0.2, "Update tab",
    "app/update_tab.R\nGoogle login,\ncheck folder")
box(0.73, 0.36, 0.22, 0.2, "Texts & helpers",
    "R/texts.R, R/update.R\nR/functions_io.R")
arrow_(0.25, 0.69, 0.32, 0.69, "inputs")
arrow_(0.32, 0.62, 0.25, 0.62, "outputs")
arrow_(0.54, 0.68, 0.62, 0.68)
arrow_(0.43, 0.56, 0.43, 0.46)
box(0.40, 0.08, 0.38, 0.11, "Background R process",
    "update/update_gloria.R: download -> parse -> delete", fill = col$light)
arrow_(0.43, 0.26, 0.43, 0.135); grid.text("start_update()", 0.37, 0.165, gp = gpar(fontsize = 8, col = col$grey, fontface = "italic"))
box(0.86, 0.08, 0.24, 0.11, "Data folder", "C:/Users/<user>/Data/GLORIA/v60/", fill = col$light)
grid.lines(c(0.84, 0.90, 0.90), c(0.64, 0.64, 0.30), gp = gpar(col = col$grey, lwd = 1.6, lty = 2)); arrow_(0.90, 0.30, 0.90, 0.135, lty = 2); grid.text("read", 0.925, 0.45, gp = gpar(fontsize = 8, col = col$grey, fontface = "italic"))
arrow_(0.59, 0.08, 0.74, 0.08, "write")
dev.off()
message("Diagrams written to docs/")
