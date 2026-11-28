# =============================================================================
# app/how_it_works.R  -  Tab "How it works" with links to the documentation
# =============================================================================
# The docs folder of the repo is served by the app under the URL path "docs/",
# so the Word guides and slides can be opened/downloaded from the browser.
addResourcePath("docs", normalizePath(file.path(root, "docs")))
how_it_works_panel <- function() {
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
        )),
    includeMarkdown(file.path(root, "app", "help.md"))
  )
}

