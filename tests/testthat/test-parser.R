# Copyright (c) 2026 Hanspeter Wieland - PolyForm Noncommercial License 1.0.0 (see LICENSE, NOTICE.md)
# Unit tests for the parser (parser/*.R), using the mini GLORIA from setup.R

test_that("metadata has the right dimensions and labels", {
  expect_equal(META$n$reg, 3); expect_equal(META$n$sec, 4); expect_equal(META$n$rs, 12)
  expect_equal(nrow(META$idx_Y), 18)
  expect_true(all(c("ghg_edgar", "mat_metals", "va_total") %in% META$catalogue$id))
  expect_equal(META$catalogue[id == "mat_metals", rows][[1]], 1)
})

test_that("only the standard matrices are stored", {
  files <- list.files(file.path(paths$parsed, 2020))
  expect_true(all(c("Y.rds", "V.rds", "x.rds", "Q.rds", "QY.rds", "L.arrow", "_DONE") %in% files))
  expect_true(any(c("Z.arrow", "Z.rds") %in% files))
  expect_false(any(c("LY.f32", "LY.arrow", "M.rds", "E.rds") %in% files))
})

test_that("Leontief inverse reproduces gross output and is non-negative", {
  expect_true(near(MINI$checks$output_reproduced_by_L, c(1, 1)))
  L <- read_matrix(file.path(paths$parsed, 2020, "L.arrow"))
  Y <- readRDS(file.path(paths$parsed, 2020, "Y.rds"))
  x <- readRDS(file.path(paths$parsed, 2020, "x.rds"))
  expect_true(near(as.vector(L %*% rowSums(Y)), x, 1e-5))
  expect_gte(min(L), -1e-9)
})

test_that("value added equals output minus inputs", {
  V <- readRDS(file.path(paths$parsed, 2020, "V.rds"))
  Z <- read_Z(2020)
  x <- readRDS(file.path(paths$parsed, 2020, "x.rds"))
  expect_true(near(colSums(V), x - colSums(as.matrix(Z)), 1e-5))
})

test_that("raw years are detected from file names", {
  expect_equal(detect_raw_years(), 2019:2020)
})
