# Copyright (c) 2026 Hanspeter Wieland - PolyForm Noncommercial License 1.0.0 (see LICENSE, NOTICE.md)
# =============================================================================
# app/gloria_reading.R  -  Tab "MRIO explained": background texts by the GLORIA team
# =============================================================================
# The release notes of each GLORIA version contain two very readable sections
# written by the GLORIA team (Manfred Lenzen et al., University of Sydney):
#   "A plain-English short philosophy of MRIO-building"
#   "A plain-English explanation of MRIO-based footprinting"
# They are NOT copied into GLORIApp. At start-up the app finds these pages in
# the release notes PDF of the GLORIA version in use (data folder, parsed/meta)
# and shows them as images of the original pages - readable, with the original
# layout, figures and references, and with the authors and licence clearly
# named. The page images are cached in parsed/meta/release_notes_pages/.
# Needs the R package pdftools (otherwise only a link to the PDF is shown).
# =============================================================================

gloria_notes_file <- sprintf("GLORIA_ReleaseNotes_0%d.pdf", gloria_version)

# Find the pages of the two sections and render them to PNG (once)
gloria_reading_pages <- local({
  f <- file.path(paths$meta, gloria_notes_file)
  out <- list(pages = integer(0), building = NA_integer_, footprinting = NA_integer_)
  if (!file.exists(f) || !requireNamespace("pdftools", quietly = TRUE)) return(out)
  txt <- tryCatch(pdftools::pdf_text(f), error = function(e) character(0))
  first_after_toc <- function(pattern) {
    hit <- grep(pattern, txt); hit <- hit[hit > 3]       # skip the table of contents
    if (length(hit)) hit[1] else NA_integer_
  }
  b <- first_after_toc("plain-English short philosophy of MRIO-building")
  fp <- first_after_toc("plain-English explanation of MRIO-based footprinting")
  ref <- first_after_toc("(^|\n)[[:space:]]*References[[:space:]]*(\n|$)")
  if (is.na(b) || is.na(fp)) return(out)
  last <- if (!is.na(ref) && ref > fp) ref - 1L else fp + 2L
  pages <- b:last
  pages <- pages[nchar(gsub("[[:space:]]", "", txt[pages])) > 200]   # skip (almost) empty pages
  dir <- file.path(paths$meta, "release_notes_pages")
  dir.create(dir, showWarnings = FALSE)
  for (p in pages) {
    png <- file.path(dir, sprintf("page_%02d.png", p))
    if (!file.exists(png)) {
      try(suppressWarnings(pdftools::pdf_convert(f, format = "png", pages = p, dpi = 130, filenames = png, verbose = FALSE)),
          silent = TRUE)
    }
  }
  list(pages = pages[file.exists(file.path(dir, sprintf("page_%02d.png", pages)))],
       building = b, footprinting = fp)
})

gloria_reading_ui <- function() {
  pg <- gloria_reading_pages
  src_note <- tags$p(class = "small text-muted mb-0",
    sprintf(paste("Source: Lenzen, M., Li, M., Wei, L., Fry, J. (ISA, The University of Sydney):",
                  "GLORIA MRIO database, Release 0%d - release notes, pages %s. Global MRIO Lab (University",
                  "of Sydney, CSIRO, WU Vienna, UNSW Sydney), licensed under Creative Commons",
                  "Attribution-NonCommercial (CC BY-NC 3.0 AU). These texts were written by the GLORIA team,",
                  "not by the authors of GLORIApp - please cite them as such."),
            gloria_version, if (length(pg$pages)) paste(range(pg$pages), collapse = "-") else "22-24"),
    if (file.exists(file.path(paths$meta, gloria_notes_file)))
      tags$a(href = paste0("gloria_docs/", gloria_notes_file), target = "_blank",
             "Open the complete release notes (PDF)."))
  if (length(pg$pages) == 0) {
    return(nav_panel("MRIO explained", div(class = "alert alert-warning",
      "The GLORIA release notes (or the R package pdftools) are not available, so the background",
      "texts cannot be shown here.", src_note)))
  }
  page_img <- function(p) {
    tags$div(id = sprintf("gloria_page_%d", p), class = "mb-4",
             tags$img(src = sprintf("gloria_docs/release_notes_pages/page_%02d.png", p),
                      alt = sprintf("GLORIA release notes, page %d", p),
                      style = "width: 100%; max-width: 900px; display: block; margin: auto; box-shadow: 0 1px 6px rgba(0,0,0,.15);"))
  }
  nav_panel(
    "MRIO explained",
    div(class = "alert alert-light",
        tags$p(tags$b("Background reading by the GLORIA team."),
               "The GLORIA release notes contain two short, very readable introductions written by the",
               "developers of GLORIA. They are shown below as pages of the original document:"),
        tags$ul(
          tags$li(tags$a(href = sprintf("#gloria_page_%d", pg$building),
                         "A plain-English short philosophy of MRIO-building"), sprintf(" (page %d)", pg$building)),
          tags$li(tags$a(href = sprintf("#gloria_page_%d", pg$footprinting),
                         "A plain-English explanation of MRIO-based footprinting"), sprintf(" (page %d)", pg$footprinting))
        ),
        src_note),
    lapply(pg$pages, page_img),
    div(class = "alert alert-light", src_note)
  )
}
