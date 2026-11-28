# Copyright (c) 2026 Hanspeter Wieland - PolyForm Noncommercial License 1.0.0 (see LICENSE, NOTICE.md)
# =============================================================================
# app/how_it_works.R  -  Tab "How it works" with links to the documentation
# =============================================================================
# The docs folder of the repo is served by the app under the URL path "docs/",
# so the Word guides and slides can be opened/downloaded from the browser.
addResourcePath("docs", normalizePath(file.path(root, "docs")))
# GLORIA documentation (release notes, ReadMe) of the active version; the parser
# keeps them in parsed/meta when it deletes the raw data
if (dir.exists(paths$meta)) addResourcePath("gloria_docs", normalizePath(paths$meta))
how_it_works_panel <- function() {
  gloria_link <- function(file, label, note) {
    if (!file.exists(file.path(paths$meta, file))) return(NULL)
    tags$li(tags$a(href = paste0("gloria_docs/", file), target = "_blank", label), " - ", note)
  }
  doc_link <- function(file, label, note) {
    if (!file.exists(file.path(root, "docs", file))) return(NULL)
    tags$li(tags$a(href = paste0("docs/", file), target = "_blank", download = NA, label), " - ", note)
  }
  nav_panel(
    "How it works",
    div(class = "alert alert-light",
        tags$b("Documentation"),
        tags$ul(
          doc_link("GLORIApp_user_guide.docx", "User guide (Word)",
                   "how to use the app, the footprint mathematics explained simply, recipes for typical questions"),
          doc_link("GLORIApp_developer_guide.docx", "Developer guide (Word)",
                   "architecture, parser, data format, engine, tests - for working with the R code"),
          doc_link("GLORIApp_intro.pptx", "Introduction slides (PowerPoint)", "for an introduction session"),
          doc_link("intro_session.md", "Exercises for the introduction session (text)", "five hands-on exercises")
        ),
        tags$b(sprintf("GLORIA v%d (data source)", gloria_version)),
        tags$ul(
          tags$li(actionLink("goto_about", "About GLORIA (tab)"), " - what GLORIA is, who builds it (Global MRIO Lab, IELab), ",
                  "and the two plain-English chapters of the release notes on MRIO-building and MRIO-based footprinting ",
                  "by the GLORIA team (Lenzen et al.), as text in the app"),
          gloria_link(sprintf("GLORIA_ReleaseNotes_0%d.pdf", gloria_version), "Release notes (PDF)",
                      "methods, data sources, changes of this GLORIA version, licence and citation"),
          gloria_link(sprintf("GLORIA_ReadMe_0%d.xlsx", gloria_version), "ReadMe (Excel)",
                      "lists of regions, sectors, final demand categories and all satellite indicators"),
          if (!file.exists(file.path(paths$meta, sprintf("GLORIA_ReleaseNotes_0%d.pdf", gloria_version))))
            tags$li(class = "text-muted", "Release notes not found in the data folder (they are copied there when GLORIA is compiled).")
        )),
    div(class = "alert alert-secondary small",
        tags$b("Copyright, licence and disclaimer"), tags$br(),
        legal$copyright, ". ", legal$licence, tags$br(),
        legal$gloria, tags$br(),
        legal$citation, tags$br(),
        tags$b(legal$disclaimer), tags$br(),
        "Full texts: files LICENSE and NOTICE.md in the app folder."),
    includeMarkdown(file.path(root, "app", "help.md"))
  )
}

