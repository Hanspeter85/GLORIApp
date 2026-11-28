# Unit tests for R/functions_io.R

test_that("float32 Arrow matrix files round-trip with ~7 digits", {
  m <- matrix(runif(20 * 7), 20, 7)
  f <- tempfile(fileext = ".arrow")
  write_matrix(m, f)
  r <- read_matrix(f)
  expect_equal(dim(r), dim(m))
  expect_lt(max(abs(r - m) / pmax(abs(m), 1e-12)), 1e-6)
})

test_that("agg_matrix, agg_rows and agg_cols sum by key", {
  m <- matrix(1:12, 4, 3)
  key <- c("a", "b", "a", "b")
  expect_equal(unname(agg_rows(m, key)), rbind(colSums(m[c(1, 3), ]), colSums(m[c(2, 4), ])))
  expect_equal(unname(agg_cols(t(m), key)), cbind(rowSums(t(m)[, c(1, 3)]), rowSums(t(m)[, c(2, 4)])))
  expect_error(agg_matrix(c("a", "x"), levels = c("a", "b")))
})

test_that("find_raw_file finds the Markup001 table of the right year", {
  d <- tempfile(); dir.create(d)
  f1 <- file.path(d, "x_T-Results_2019_060_Markup001(full).csv"); writeLines("1", f1)
  writeLines("1", file.path(d, "x_T-Results_2019_060_Markup002(full).csv"))
  expect_equal(normalizePath(find_raw_file(d, "T", 2019, 60)), normalizePath(f1))
  expect_error(find_raw_file(d, "Y", 2019, 60))
})

test_that("read_gloria_csv reads selected rows and columns", {
  f <- tempfile(fileext = ".csv")
  fwrite(as.data.table(matrix(1:20, 4, 5)), f, col.names = FALSE)
  m <- read_gloria_csv(f, rows = c(2, 4), cols = c(1, 3))
  expect_equal(m, matrix(c(2, 4, 10, 12), 2, 2))
})
