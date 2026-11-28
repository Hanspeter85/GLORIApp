# Copyright (c) 2026 Hanspeter Wieland - PolyForm Noncommercial License 1.0.0 (see LICENSE, NOTICE.md)
# =============================================================================
# R/export.R  -  Write a result table to csv, Excel or text files
# =============================================================================
# Used by the download button of the app; can also be used in scripts:
#   write_result_file(res, "my_result.xlsx", "xlsx")
#
# type:  "csv"   comma-separated, decimal point (international standard)
#        "csv2"  semicolon-separated, decimal comma (German/Austrian Excel)
#        "txt"   tab-separated text
#        "xlsx"  Excel workbook: sheet "result" + sheet "info" (settings and
#                plausibility checks); Excel allows at most 1,048,576 rows
# Text formats are written in blocks of 200 000 rows so that the app can show
# a progress bar (only inside a Shiny session).
# =============================================================================

EXCEL_MAX_ROWS <- 1048575L   # one row is needed for the column names

write_result_file <- function(res, file, type = "csv", spec = NULL, checks = NULL) {
  in_shiny <- !is.null(shiny::getDefaultReactiveDomain())
  progress <- function(p, detail = NULL) {
    if (in_shiny) shiny::setProgress(p, message = sprintf("Writing file: %d %%", round(100 * p)), detail = detail)
  }
  run <- function(expr) if (in_shiny) shiny::withProgress(message = "Writing file: 0 %", value = 0, expr) else expr

  if (type == "xlsx") {
    if (nrow(res) > EXCEL_MAX_ROWS) {
      stop(sprintf("The result has %s rows, Excel allows at most 1,048,576. Please choose CSV or text, or group the result more coarsely.",
                   format(nrow(res), big.mark = ",")))
    }
    run({
      progress(0.1, "preparing workbook")
      wb <- openxlsx::createWorkbook()
      openxlsx::addWorksheet(wb, "result")
      openxlsx::writeDataTable(wb, "result", res, tableStyle = "TableStyleLight9")
      openxlsx::setColWidths(wb, "result", cols = seq_along(res), widths = "auto")
      openxlsx::freezePane(wb, "result", firstRow = TRUE)
      progress(0.6, "writing settings and checks")
      openxlsx::addWorksheet(wb, "info")
      legal <- get0("legal", ifnotfound = list(copyright = "GLORIApp (c) 2026 Hanspeter Wieland", licence = "see LICENSE",
                                               gloria = "see NOTICE.md", citation = "see NOTICE.md", disclaimer = "see NOTICE.md"))
      info <- data.frame(item = c("Created", "GLORIA version", "Settings", "Copyright", "Licence",
                                  "GLORIA data", "Citation", "Disclaimer"),
                         value = c(format(Sys.time()), as.character(gloria_version),
                                   if (is.null(spec)) "" else paste(names(spec), vapply(spec, function(v) paste(v, collapse = ", "), ""),
                                                                    sep = " = ", collapse = "; "),
                                   legal$copyright, legal$licence, legal$gloria, legal$citation, legal$disclaimer))
      openxlsx::writeData(wb, "info", info)
      if (!is.null(checks)) openxlsx::writeData(wb, "info", checks, startRow = nrow(info) + 3)
      progress(0.8, "saving")
      openxlsx::saveWorkbook(wb, file, overwrite = TRUE)
      progress(1)
    })
  } else {
    sep <- c(csv = ",", csv2 = ";", txt = "\t")[[type]]
    dec <- if (type == "csv2") "," else "."
    n <- nrow(res); step <- 200000L
    run({
      for (s in seq(1L, max(n, 1L), by = step)) {
        rows <- s:min(n, s + step - 1L)
        data.table::fwrite(res[rows], file, sep = sep, dec = dec, append = s > 1L,
                           bom = (type == "csv2" && s == 1L))
        progress(max(rows) / max(n, 1L), sprintf("%s of %s rows", format(max(rows), big.mark = ","),
                                                   format(n, big.mark = ",")))
      }
    })
  }
  invisible(file)
}
