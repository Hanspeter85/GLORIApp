# Copyright (c) 2026 Hanspeter Wieland - PolyForm Noncommercial License 1.0.0 (see LICENSE, NOTICE.md)
# Unit tests for R/engine.R: input-output identities on the mini GLORIA

base <- list(indicators = c("ghg_edgar", "mat_metals", "va_total"), years = 2019:2020,
             fd_codes = 1:6, include_direct_fd = TRUE, consumption_region = "region_name", by_fd = TRUE)
run <- function(...) run_calculation(modifyList(base, list(...)), META)

fo <- run(type = "footprint", production_region = "region_name", production_sector = "broad_sector")
fp <- run(type = "footprint", production_region = "none", product_made_in = "region_name", consumption_product = "broad_sector")
fx <- run(type = "footprint", production_region = "region_name", production_sector = "broad_sector",
          product_made_in = "world_region_7", consumption_product = "sector_name")
pr <- run(type = "production", production_region = "region_name", production_sector = "broad_sector")
ov <- run(type = "overview", production_region = "region_name")
tot <- function(d, by) d[, .(v = sum(value)), keyby = by]$v

test_that("world footprint = world production-based account (incl. households)", {
  expect_true(near(tot(fo, c("year", "indicator")), tot(pr, c("year", "indicator"))))
})

test_that("production-side, product and both-side splits agree", {
  key <- c("year", "indicator", "consumption_region", "consumption_category")
  expect_true(near(tot(fo, key), tot(fp, key)))
  expect_true(near(tot(fo, key), tot(fx, key)))
  key2 <- c("year", "indicator", "production_region", "production_sector", "consumption_region", "consumption_category")
  expect_true(near(tot(fx, key2), tot(fo, key2)))
})

test_that("both branches of the production-side case give the same result", {
  # few consumer groups (L %*% Yc first) vs. many consumer groups (s L first)
  a <- run(type = "footprint", production_region = "region_name", by_fd = FALSE, consumption_region = "world")
  b <- run(type = "footprint", production_region = "region_name", by_fd = TRUE)
  expect_true(near(tot(a, c("year", "indicator", "production_region")),
                   tot(b, c("year", "indicator", "production_region"))))
})

test_that("net imports sum to zero and VA footprint equals world value added", {
  expect_true(all(ov[account == "net_imports", abs(sum(value)), by = .(year, indicator)]$V1 <=
                    1e-5 * ov[account == "production_based", sum(abs(value)), by = .(year, indicator)]$V1))
  w <- run(type = "footprint", indicators = "va_total", production_region = "none",
           consumption_region = "world", by_fd = FALSE)
  expect_true(near(tot(w, "year"), tot(pr[indicator == "Value added (total)"], "year")))
})

test_that("gross exports: domestic + foreign value added = gross exports", {
  tv <- run(type = "exports", indicators = "va_total", years = 2020, production_region = "region_name",
            product_made_in = "region_name", consumption_product = "broad_sector")
  expect_true(near(sum(tv$value), sum(gross_exports(2020, META)), 1e-5))
})

test_that("plausibility checks are attached and pass", {
  for (r in list(fo, fp, fx, pr, ov)) {
    chk <- attr(r, "checks")
    expect_s3_class(chk, "data.table")
    expect_false(any(chk$status == "FAILED"))
    expect_true(any(chk$status == "OK"))
  }
  sub <- run(type = "footprint", fd_codes = 1:2)
  expect_true(any(attr(sub, "checks")$status == "skipped"))
})

test_that("a wrong result is detected by the checks", {
  bad <- data.table(value = 1)
  info <- indicator_info("ghg_edgar", META)
  chk <- check_job(bad, info, 2020, META, modifyList(base, list(type = "footprint")))
  expect_equal(chk$status, "FAILED")
})

test_that("no duplicate rows, sensible columns and wide format", {
  fo2 <- run(type = "footprint", production_region = "region_name", by_fd = FALSE)
  expect_equal(anyDuplicated(fo2[, .(year, indicator, production_region, consumption_region)]), 0)
  expect_equal(names(fo)[1:3], c("year", "indicator", "unit"))
  expect_equal(tail(names(fo), 1), "value")
  w <- to_wide(fo, "year")
  expect_true(all(c("2019", "2020") %in% names(w)))
})

test_that("raw satellite rows and unknown indicators", {
  r <- run(type = "footprint", indicators = "sat:3", production_region = "none", by_fd = FALSE)
  g <- run(type = "footprint", indicators = "ghg_edgar", production_region = "none", by_fd = FALSE)
  expect_true(near(tot(r, "year"), tot(g, "year")))       # sat row 3 = GHG total
  expect_error(indicator_info("does_not_exist", META))
})

test_that("cache: L Y is computed once per year and grouping", {
  run(type = "footprint", indicators = "ghg_edgar", years = 2020, production_region = "region_name", by_fd = FALSE)
  k <- grep("^2020_LY_", ls(.cache), value = TRUE)
  expect_length(k, 1)
  expect_equal(digest_key(c("a", "b", "a")), digest_key(c("x", "y", "x")))
  expect_false(digest_key(c("a", "b", "a")) == digest_key(c("a", "a", "b")))
})
