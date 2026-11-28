# Tests of the Shiny server logic (shiny::testServer, no browser needed)

app_env <- new.env()
local({
  root <- REPO
  meta_file <- file.path(paths$meta, "meta.rds")
  suppressPackageStartupMessages({ library(shiny); library(bslib) })
  for (f in c("R/texts.R", "R/export.R", "app/update_tab.R", "app/charts_tab.R", "app/full_app.R")) {
    source(file.path(REPO, f), local = environment())
  }
  assign("server", server, envir = app_env)
  assign("ui", ui, envir = app_env)
})

test_that("the user interface can be built", {
  expect_s3_class(app_env$ui, "shiny.tag.list")
})

test_that("clicking Calculate produces a result with passing checks", {
  shiny::testServer(app_env$server, {
    session$setInputs(type = "footprint", indicators = "ghg_edgar", expert = FALSE, sat_rows = NULL,
                      years = c("2019", "2020"), production_region = "world_region_7",
                      production_sector = "broad_sector", product_made_in = "none",
                      consumption_product = "none", consumption_region = "region_name",
                      by_fd = FALSE, fd_codes = as.character(1:6), include_direct_fd = TRUE,
                      keep_zeros = FALSE, format = "long", pivot_col = "year", file_type = "csv",
                      grp_rest_regions = "Rest of world", grp_rest_sectors = "Other sectors")
    session$setInputs(go = 1)
    res <- result()
    expect_true(nrow(res) > 0)
    expect_true(all(c("production_region", "production_sector", "consumption_region") %in% names(res)))
    expect_false(any(attr(res, "checks")$status == "FAILED"))
    # wide format: one column per year
    session$setInputs(format = "wide")
    expect_true(all(c("2019", "2020") %in% names(result_formatted())))
    # downloads in all formats
    for (tp in c("csv", "csv2", "txt", "xlsx")) {
      session$setInputs(file_type = tp)
      f <- output$download
      expect_true(file.exists(f) && file.size(f) > 0)
    }
    expect_equal(openxlsx::getSheetNames(f), c("result", "info"))
    # chart export in all image formats, for all chart types
    for (ct in c("rank", "time", "stack")) {
      session$setInputs(ch_type = ct, ch_indicator = res$indicator[1], ch_dim = "production_region",
                        ch_colour = "production_sector", ch_year = "2020", ch_top = 5, ch_filter_dim = "")
      for (fmt in c("png", "jpeg", "svg", "pdf")) {
        session$setInputs(ch_img_format = fmt)
        img <- output$ch_download
        expect_true(file.exists(img) && file.size(img) > 1000)
      }
    }
    # save directly into a folder
    dir <- file.path(tempdir(), "gloriapp_save_test"); unlink(dir, recursive = TRUE)
    session$setInputs(results_dir = dir, file_type = "csv", save_result = 1, ch_save = 1)
    expect_equal(length(list.files(dir, "[.]csv$")), 1)
    expect_equal(length(list.files(dir, "[.]pdf$")), 1)
  })
})

test_that("own groups are added as 'own_grouping'", {
  shiny::testServer(app_env$server, {
    session$setInputs(grp_kind = "regions", grp_name = "Rich", grp_members = c("AUT", "USA"),
                      grp_rest_regions = "Rest of world", grp_rest_sectors = "Other sectors")
    session$setInputs(grp_add = 1)
    m <- meta_r()
    expect_equal(sort(unique(m$regions$own_grouping)), c("Rest of world", "Rich"))
    expect_equal(m$regions[region_acronym == "CHN", own_grouping], "Rest of world")
  })
})
