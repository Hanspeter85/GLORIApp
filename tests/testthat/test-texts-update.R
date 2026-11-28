# Copyright (c) 2026 Hanspeter Wieland - PolyForm Noncommercial License 1.0.0 (see LICENSE, NOTICE.md)
# Unit tests for R/texts.R and R/update.R helpers

test_that("format_secs", {
  expect_equal(format_secs(30), "30 s")
  expect_equal(format_secs(600), "10 min")
  expect_equal(format_secs(NA), "?")
})

test_that("Drive folder ids are extracted from links", {
  expect_equal(drive_folder_id("https://drive.google.com/drive/folders/1tm1Cs5ABVRuE3fDkT80TfE5fPmnWPrA7?usp=sharing"),
               "1tm1Cs5ABVRuE3fDkT80TfE5fPmnWPrA7")
  expect_true(is.na(drive_folder_id("https://example.com")))
})

test_that("only part I, part III and documentation of the version are downloaded", {
  f <- data.table(path = c("060/GLORIA_ReadMe_060.xlsx", "059a/GLORIA_ReadMe_059a.xlsx",
                           "060/GLORIA_MRIO_Loop060_part_I_MRIOdatabase/GLORIA_MRIOs_60_1990.zip",
                           "060/GLORIA_MRIO_Loop060_part_III_satelliteaccounts/x_1990.zip",
                           "060/GLORIA_MRIO_Loop060_part_IV_commodityprices.zip",
                           "059a/GLORIA_MRIO_Loop059_part_I_MRIOdatabase/a.zip"), id = "x", size = 1)
  expect_equal(nrow(needed_files(f, 60)), 3)
})

test_that("installed versions are listed", {
  v <- installed_versions()
  expect_true(60 %in% v$version)
  expect_true(v[version == 60, ready_for_app])
})

test_that("folders are checked and created", {
  d <- file.path(tempdir(), "gloriapp_folder_test", "sub")
  expect_true(folder_ok(d))
  expect_true(dir.exists(d))
  expect_false(folder_ok(""))
})
