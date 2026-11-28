# Copyright (c) 2026 Hanspeter Wieland - PolyForm Noncommercial License 1.0.0 (see LICENSE, NOTICE.md)
# =============================================================================
# app/gloria_reading.R  -  Tab "About GLORIA"
# =============================================================================
# 1. A short introduction to GLORIA, the Global MRIO Lab and the Industrial
#    Ecology Virtual Laboratory (IELab), written for GLORIApp (based on the
#    GLORIA release notes and the GLORIA publications).
# 2. Three sections of the GLORIA release notes written by the GLORIA team
#    (Manfred Lenzen et al., University of Sydney), shown as images of the
#    original pages:
#      "General explainer and disclaimer"
#      "A plain-English short philosophy of MRIO-building"
#      "A plain-English explanation of MRIO-based footprinting"
#    They are NOT copied into GLORIApp: at start-up the app finds the pages in
#    the release notes PDF of the GLORIA version in use (data folder,
#    parsed/meta) and renders them once to PNG (parsed/meta/release_notes_pages/).
#    Needs the R package pdftools; otherwise only a link to the PDF is shown.
# =============================================================================

gloria_notes_file <- sprintf("GLORIA_ReleaseNotes_0%d.pdf", gloria_version)

# Find the pages of the three sections and render them to PNG (once)
gloria_reading_pages <- local({
  f <- file.path(paths$meta, gloria_notes_file)
  out <- list(sections = list())
  if (!file.exists(f) || !requireNamespace("pdftools", quietly = TRUE)) return(out)
  txt <- tryCatch(pdftools::pdf_text(f), error = function(e) character(0))
  first_after_toc <- function(pattern) {
    hit <- grep(pattern, txt); hit <- hit[hit > 3]       # skip the table of contents
    if (length(hit)) hit[1] else NA_integer_
  }
  ex  <- first_after_toc("General explainer and disclaimer")
  b   <- first_after_toc("plain-English short philosophy of MRIO-building")
  fp  <- first_after_toc("plain-English explanation of MRIO-based footprinting")
  ref <- first_after_toc("(^|\n)[[:space:]]*References[[:space:]]*(\n|$)")
  if (is.na(b) || is.na(fp)) return(out)
  last <- if (!is.na(ref) && ref > fp) ref - 1L else fp + 2L
  keep <- function(p) p[nchar(gsub("[[:space:]]", "", txt[p])) > 200]   # skip (almost) empty pages
  sections <- list(
    explainer    = list(title = "General explainer and disclaimer",
                        pages = if (!is.na(ex) && ex < b) keep(ex:(b - 1L)) else integer(0)),
    building     = list(title = "A plain-English short philosophy of MRIO-building",
                        pages = keep(b:(fp - 1L))),
    footprinting = list(title = "A plain-English explanation of MRIO-based footprinting",
                        pages = keep(fp:last)))
  # the building section may end on the first page of the footprinting section
  if (length(sections$building$pages) == 0) sections$building$pages <- b
  dir <- file.path(paths$meta, "release_notes_pages")
  dir.create(dir, showWarnings = FALSE)
  for (p in unique(unlist(lapply(sections, `[[`, "pages")))) {
    png <- file.path(dir, sprintf("page_%02d.png", p))
    if (!file.exists(png)) {
      try(suppressWarnings(pdftools::pdf_convert(f, format = "png", pages = p, dpi = 130,
                                                 filenames = png, verbose = FALSE)), silent = TRUE)
    }
  }
  for (s in names(sections)) {
    p <- sections[[s]]$pages
    sections[[s]]$pages <- p[file.exists(file.path(dir, sprintf("page_%02d.png", p)))]
  }
  list(sections = sections)
})

# --- Introduction text (written for GLORIApp) ------------------------------------------
gloria_intro <- function() {
  ext <- function(href, label) tags$a(href = href, target = "_blank", label)
  tagList(
    h4("What is GLORIA?"),
    p("GLORIA (Global Resource Input-Output Assessment) is a global multi-regional input-output (MRIO)",
      "database. It describes, in money, who sells to whom in the world economy - for 164 countries and",
      "regions, 120 sectors and every year from 1990 onwards - together with satellite accounts that",
      "record what each sector takes from or releases to the environment and society: raw materials,",
      "greenhouse gases and air pollutants, land, water, energy, employment and biodiversity impacts.",
      "Combining both makes it possible to follow pressures along global supply chains to the final",
      "consumer, i.e. to calculate footprints."),
    p("GLORIA is released as multi-regional supply-use tables with the same 120 sectors in every",
      "country, which makes countries directly comparable. The data come with estimates of their",
      "uncertainty (standard deviations). New releases appear about once a year; the app currently",
      sprintf("uses release 0%d. The most recent years are nowcasts and projections (to 2029 based on", gloria_version),
      "IMF GDP projections) and therefore less certain than the historical years."),
    h4("Who makes GLORIA? The Global MRIO Lab and the IELab"),
    p("GLORIA is built in the", tags$b("Global MRIO Lab,"), "a branch of the",
      tags$b("Industrial Ecology Virtual Laboratory (IELab)."), "The IELab is a cloud-based research",
      "platform, originally funded through Australia's National eResearch Collaboration Tools and",
      "Resources project (NeCTAR), in which research teams jointly build and run large input-output",
      "databases on shared high-performance computers (", ext("https://ielab.info", "ielab.info"), ").",
      "The Global MRIO Lab also produced the Eora MRIO database and is described in Lenzen et al. (2017)."),
    p("GLORIA is a collaboration of the", tags$b("University of Sydney"), "(Integrated Sustainability",
      "Analysis, led by Manfred Lenzen), the", tags$b("CSIRO"), "(Australia), the",
      tags$b("Vienna University of Economics and Business (WU Vienna)"), "and", tags$b("UNSW Sydney."),
      "Its development was funded by the United Nations Environment Programme (UNEP) - through the",
      "Life Cycle Initiative, the One Planet Network and the International Resource Panel (IRP) in the",
      "context of the SCP Hotspot Analysis Tool (SCP-HAT) and the IRP work on resource indicators - and",
      "by the Australian Research Council. GLORIA underpins the material footprint calculations of the",
      "International Resource Panel (Lenzen et al. 2021)."),
    p("Contacts named in the release notes: Manfred Lenzen (University of Sydney) for the monetary tables,",
      "greenhouse gases and employment; Stephan Lutter and Stefan Giljum (WU Vienna) for the other",
      "satellite accounts. GLORIA data:", ext("https://ielab.info/labs/ielab-gloria", "ielab.info/labs/ielab-gloria"), "."),
    h4("Licence and citation"),
    p("GLORIA is made available under a Creative Commons Attribution-NonCommercial licence",
      "(CC BY-NC 3.0 AU); for commercial applications contact the GLORIA team. Please cite Lenzen et al.",
      "(2017) The Global MRIO Lab - charting the world economy, Economic Systems Research 29, 158-186, and",
      "Lenzen et al. (2021) Implementing the material footprint to measure progress towards SDGs 8 and 12,",
      "Nature Sustainability, doi:10.1038/s41893-021-00811-6.")
  )
}

gloria_reading_ui <- function() {
  sec <- gloria_reading_pages$sections
  sec <- sec[vapply(sec, function(s) length(s$pages) > 0, TRUE)]
  pages_txt <- if (length(sec)) paste(range(unlist(lapply(sec, `[[`, "pages"))), collapse = "-") else ""
  src_note <- tags$p(class = "small text-muted mb-0",
    sprintf(paste("Source of the pages below: Lenzen, M., Li, M., Wei, L., Fry, J. (ISA, The University of",
                  "Sydney): GLORIA MRIO database, Release 0%d - release notes%s. Global MRIO Lab (University",
                  "of Sydney, CSIRO, WU Vienna, UNSW Sydney), Creative Commons Attribution-NonCommercial",
                  "(CC BY-NC 3.0 AU). These texts were written by the GLORIA team, not by the authors of",
                  "GLORIApp - please cite them as such."),
            gloria_version, if (nzchar(pages_txt)) paste0(", pages ", pages_txt) else ""),
    if (file.exists(file.path(paths$meta, gloria_notes_file)))
      tags$a(href = paste0("gloria_docs/", gloria_notes_file), target = "_blank",
             "Open the complete release notes (PDF)."))
  page_img <- function(p) {
    tags$img(src = sprintf("gloria_docs/release_notes_pages/page_%02d.png", p),
             alt = sprintf("GLORIA release notes, page %d", p), class = "mb-4",
             style = "width: 100%; max-width: 900px; display: block; margin: auto; box-shadow: 0 1px 6px rgba(0,0,0,.15);")
  }
  nav_panel(
    "About GLORIA",
    div(style = "max-width: 950px;",
      div(class = "alert alert-light", gloria_intro()),
      if (length(sec) == 0) {
        div(class = "alert alert-warning",
            "The GLORIA release notes (or the R package pdftools) are not available, so the background",
            "texts by the GLORIA team cannot be shown here.", src_note)
      } else tagList(
        div(class = "alert alert-light",
            h4("Background reading by the GLORIA team"),
            p("The GLORIA release notes contain short, very readable introductions written by the developers",
              "of GLORIA. They are shown below as pages of the original document:"),
            tags$ul(lapply(names(sec), function(s)
              tags$li(tags$a(href = paste0("#gloria_sec_", s), sec[[s]]$title),
                      sprintf(" (page%s %s)", if (length(sec[[s]]$pages) > 1) "s" else "",
                              paste(unique(range(sec[[s]]$pages)), collapse = "-"))))),
            src_note),
        lapply(names(sec), function(s) tags$div(id = paste0("gloria_sec_", s),
                                                lapply(sec[[s]]$pages, page_img))),
        div(class = "alert alert-light", src_note)
      )
    )
  )
}
