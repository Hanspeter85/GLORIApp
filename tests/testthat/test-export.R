# Copyright (c) 2026 Hanspeter Wieland - PolyForm Noncommercial License 1.0.0 (see LICENSE, NOTICE.md)
# Unit tests for R/export.R (download formats)

res <- run_calculation(list(type = "footprint", indicators = "ghg_edgar", years = 2020,
                            production_region = "world_region_7"), META)

test_that("csv, csv2 and txt files contain the full table", {
  for (tp in c("csv", "csv2", "txt")) {
    f <- tempfile(fileext = ".csv")
    write_result_file(res, f, tp)
    sep <- c(csv = ",", csv2 = ";", txt = "\t")[[tp]]
    back <- fread(f, sep = sep, dec = if (tp == "csv2") "," else ".", encoding = "UTF-8")
    expect_equal(nrow(back), nrow(res))
    expect_equal(names(back), names(res))
    expect_true(near(sum(back$value), sum(res$value), 1e-9))
  }
})

test_that("xlsx has the result sheet and an info sheet with the checks", {
  f <- tempfile(fileext = ".xlsx")
  write_result_file(res, f, "xlsx", spec = list(type = "footprint"), checks = attr(res, "checks"))
  expect_equal(openxlsx::getSheetNames(f), c("result", "info"))
  info <- openxlsx::read.xlsx(f, "info")
  expect_true(any(grepl("PolyForm Noncommercial", info$value)))
  expect_true(any(grepl("without warranty", info$value)))
  back <- openxlsx::read.xlsx(f, "result")
  expect_equal(nrow(back), nrow(res))
  expect_true(near(sum(back$value), sum(res$value), 1e-9))
})

test_that("too many rows for Excel give a clear error", {
  big <- data.table(value = numeric(EXCEL_MAX_ROWS + 1))
  expect_error(write_result_file(big, tempfile(fileext = ".xlsx"), "xlsx"), "Excel allows at most")
})
