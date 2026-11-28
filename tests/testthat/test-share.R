# Unit tests for R/share.R (using an already compiled GLORIA from a folder)

vdir <- file.path(data_root, "v60")

test_that("the GLORIA root is found from different starting folders", {
  root <- normalizePath(data_root, winslash = "/")
  expect_equal(find_gloria_root(data_root), root)
  expect_equal(find_gloria_root(vdir), root)
  expect_equal(find_gloria_root(file.path(vdir, "parsed")), root)
  expect_true(is.na(find_gloria_root(tempdir())))
})

test_that("a complete installation passes, a damaged one fails", {
  write_manifest(vdir, md5 = TRUE)
  chk <- check_installation(vdir, check_md5 = TRUE)
  expect_true(chk$ok)
  expect_equal(chk$years, 2019:2020)
  # truncate one file: wrong size must be detected
  f <- file.path(vdir, "parsed", "2020", "x.rds")
  bak <- tempfile(); file.copy(f, bak)
  writeBin(as.raw(1:3), f)
  chk2 <- check_installation(vdir)
  expect_false(chk2$ok)
  expect_true(any(grepl("wrong size", chk2$problems)))
  file.copy(bak, f, overwrite = TRUE)
  expect_true(check_installation(vdir, check_md5 = TRUE)$ok)
  unlink(file.path(vdir, "parsed", "manifest.csv"))
})
