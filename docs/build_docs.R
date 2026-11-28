# =============================================================================
# docs/build_docs.R  -  Convert the Markdown guides to Word (.docx)
# =============================================================================
# The guides are written in Markdown (docs/user_guide.md, docs/developer_guide.md)
# so that they can be edited and versioned easily. This script converts them to
# Word with pandoc (ships with RStudio). Formulas become real Word equations.
# The diagrams (docs/fig_*.png) are drawn by docs/make_diagrams.R.
# Run from the repo root:  source("docs/build_docs.R")
# =============================================================================

find_pandoc <- function() {
  p <- Sys.which("pandoc")
  if (nzchar(p)) return(p)
  cand <- c(Sys.getenv("RSTUDIO_PANDOC"),
            "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools/pandoc.exe",
            "C:/Program Files/RStudio/bin/quarto/bin/tools/pandoc.exe",
            "C:/Program Files/RStudio/resources/app/bin/pandoc/pandoc.exe")
  cand <- cand[nzchar(cand)]
  cand <- ifelse(dir.exists(cand), file.path(cand, "pandoc.exe"), cand)
  hit <- cand[file.exists(cand)]
  if (length(hit) == 0) stop("pandoc not found - it is installed together with RStudio.")
  hit[1]
}

pandoc <- find_pandoc()
for (doc in c("user_guide", "developer_guide")) {
  src <- file.path("docs", paste0(doc, ".md"))
  out <- file.path("docs", paste0("GLORIApp_", doc, ".docx"))
  res <- system2(pandoc, c(shQuote(src), "-o", shQuote(out), "--toc", "--toc-depth=2",
                           "--resource-path=docs",
                           "--number-sections"))
  if (res != 0) stop("pandoc failed for ", src)
  message("Written: ", out)
}
