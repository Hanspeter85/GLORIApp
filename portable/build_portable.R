# =============================================================================
# portable/build_portable.R  -  Build GLORIApp as a portable folder (no R needed)
# =============================================================================
# Result (default: next to the repo, ../GLORIApp_portable):
#
#   GLORIApp_portable/
#     Start GLORIApp.exe     <- double click: starts the app in the browser
#     R/                     <- complete R incl. all packages the app needs
#     GLORIApp/              <- app, engine, parser, updater, input files, guides
#     README.txt
#   GLORIApp_portable.zip    <- the same folder as one zip file to pass on
#
# The GLORIA DATA are not included (124 GB). On a new PC the app starts in setup
# mode and downloads/compiles GLORIA via the tab "Data & updates", or the data
# folder is copied to C:/Users/<user>/Data/GLORIA.
#
# Run from the repo root in the R that should be shipped (here R 4.6):
#   source("portable/build_portable.R")
# Needs: all app packages installed; Windows (uses the built-in C# compiler).
# =============================================================================

out_root <- normalizePath(file.path("..", "GLORIApp_portable"), mustWork = FALSE)
make_zip <- TRUE

message("Building portable GLORIApp in ", out_root)
# If the portable app is currently running, its files are locked. Renaming the
# folder fails in that case - stop BEFORE deleting anything.
if (dir.exists(out_root)) {
  old <- paste0(out_root, "_old")
  unlink(old, recursive = TRUE)
  if (!file.rename(out_root, old)) {
    stop("The portable GLORIApp seems to be running (files in use). Close the app's ",
         "browser tab (or end Rscript.exe in the task manager) and try again.")
  }
  unlink(old, recursive = TRUE)
}
dir.create(out_root, recursive = TRUE)

# --- 1) Copy R itself --------------------------------------------------------------------
# R on Windows is relocatable: the whole R home folder can simply be copied.
r_home <- normalizePath(R.home())
r_out <- file.path(out_root, "R")
dir.create(r_out)
ok <- file.copy(list.files(r_home, full.names = TRUE), r_out, recursive = TRUE)
if (!all(ok)) stop("Copying R failed")
# documentation and tests of R are not needed (saves ~40 MB)
unlink(file.path(r_out, c("doc", "tests")), recursive = TRUE)

# --- 2) Copy the packages the app needs (with all dependencies) -------------------------
# (markdown is needed by shiny::includeMarkdown for the help page)
pkgs <- c("shiny", "bslib", "DT", "data.table", "Matrix", "openxlsx", "jsonlite", "googledrive", "markdown")
ip <- installed.packages()
deps <- tools::package_dependencies(pkgs, db = ip, recursive = TRUE,
                                    which = c("Depends", "Imports", "LinkingTo"))
need <- setdiff(unique(c(pkgs, unlist(deps))), rownames(ip)[ip[, "Priority"] %in% "base"])
lib_out <- file.path(r_out, "library")
for (p in need) {
  src <- find.package(p)
  if (!file.exists(file.path(lib_out, p))) file.copy(src, lib_out, recursive = TRUE)
}
dir.create(file.path(r_out, "library-user"))
message(length(need), " packages copied")

# --- 3) Copy the app ----------------------------------------------------------------------
app_out <- file.path(out_root, "GLORIApp")
dir.create(app_out)
for (d in c("R", "app", "parser", "update", "input")) {
  file.copy(d, app_out, recursive = TRUE)
}
file.copy(c("config.R", "README.md"), app_out)
dir.create(file.path(app_out, "docs"))
file.copy(list.files("docs", "\\.(docx|pptx|md)$", full.names = TRUE), file.path(app_out, "docs"))

# --- 4) Compile the launcher "Start GLORIApp.exe" -------------------------------------------
csc <- file.path(Sys.getenv("SystemRoot"), "Microsoft.NET", "Framework64", "v4.0.30319", "csc.exe")
if (!file.exists(csc)) stop("C# compiler not found: ", csc)
exe <- file.path(out_root, "Start GLORIApp.exe")
res <- system2(csc, c("/nologo", "/target:winexe", "/reference:System.Windows.Forms.dll",
                      paste0("/out:", shQuote(exe)), shQuote(normalizePath("portable/launcher.cs"))))
if (res != 0 || !file.exists(exe)) stop("Compiling the launcher failed")

# --- 5) Short readme -----------------------------------------------------------------------
writeLines(c(
  "GLORIApp - portable version",
  "===========================",
  "",
  "Start: double click 'Start GLORIApp.exe'. The app opens in your web browser.",
  "Closing the browser tab ends the app. No R installation is needed.",
  "",
  "GLORIA data: the app looks for compiled data in C:\\Users\\<your name>\\Data\\GLORIA.",
  "- If you received the data folder, copy it there.",
  "- Otherwise use the tab 'Data & updates' in the app to download and compile",
  "  GLORIA (needs a Google account, about 130 GB free disk space, several hours).",
  "",
  "Messages of the last start are written to GLORIApp_log.txt.",
  "User guide: GLORIApp\\docs\\GLORIApp_user_guide.docx",
  sprintf("Built %s with R %s.", format(Sys.Date()), getRversion())
), file.path(out_root, "README.txt"))

# --- 6) Zip ----------------------------------------------------------------------------------
if (make_zip) {
  zf <- paste0(out_root, ".zip")
  unlink(zf)
  zip::zipr(zf, out_root)
  message("Zip: ", zf, " (", round(file.size(zf) / 1e6), " MB)")
}
message("Done: ", out_root)
