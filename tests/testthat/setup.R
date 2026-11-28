# Runs once before all tests: build and parse the mini GLORIA
REPO <- normalizePath(file.path(testthat::test_path(), "..", ".."))
TMP  <- file.path(tempdir(), "gloria_unit_tests")
MINI <- build_mini_gloria(TMP, REPO)
META <- MINI$meta
withr_cleanup <- function() unlink(TMP, recursive = TRUE)
