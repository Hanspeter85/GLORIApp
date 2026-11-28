# Copyright (c) 2026 Hanspeter Wieland - PolyForm Noncommercial License 1.0.0 (see LICENSE, NOTICE.md)
# =============================================================================
# Helper: build a MINI GLORIA (3 regions x 4 sectors, random numbers) in the
# same raw file layout as the real data and parse it with the real parser.
# Used by all tests (see setup.R). Nothing here touches the real data.
# =============================================================================

build_mini_gloria <- function(tmp, repo) {
  suppressPackageStartupMessages({ library(openxlsx); library(data.table) })
  set.seed(1)
  unlink(tmp, recursive = TRUE)
  Sys.setenv(GLORIA_DATA_ROOT = tmp, GLORIA_VERSION = "60")
  source(file.path(repo, "config.R"), local = globalenv())
  assign("gloria_years", 2019:2020, envir = globalenv())
  paths$input <<- file.path(tmp, "input")
  dir.create(file.path(paths$input, "concordances"), recursive = TRUE)
  dir.create(paths$raw, recursive = TRUE)

  nr <- 3; ns <- 4; nfd <- 6; nva <- 6
  regions <- data.table(Lfd_Nr = 1:nr, Region_acronyms = c("AUT", "CHN", "USA"),
                        Region_names = c("Austria", "China", "United States"))
  sectors <- data.table(Lfd_Nr = 1:ns, Sector_names = c("Agri", "Mining", "Manuf", "Services"))
  fdva <- data.table(Lfd_Nr = 1:6,
                     Value_added_names = c("Compensation of employees", "Taxes on production",
                                           "Subsidies on production", "Net operating surplus",
                                           "Net mixed income", "Consumption of fixed capital"),
                     Final_demand_names = c("Household final consumption", "Non-profit institutions serving households",
                                            "Government final consumption", "Gross fixed capital formation",
                                            "Changes in inventories", "Acquisitions less disposals of valuables"))
  sat <- data.table(Lfd_Nr = 1:4,
                    Sat_head_indicator = c("Material", "Emissions (EDGAR)", "Emissions (EDGAR)", "Employment"),
                    Sat_indicator = c("Iron ores", "'co2_excl_short_cycle_org_c_total_EDGAR_consistent'",
                                      "'GHG_total_EDGAR_consistent'", "Female"),
                    Sat_unit = c("tonnes", "kilotonnes", "kilotonnes CO2-equivalent", "ppl"))
  wb <- createWorkbook()
  for (s in list(list("Regions", regions), list("Sectors", sectors),
                 list("Value added and final demand", fdva), list("Satellites", sat))) {
    addWorksheet(wb, s[[1]]); writeData(wb, s[[1]], s[[2]])
  }
  saveWorkbook(wb, file.path(paths$input, "GLORIA_ReadMe_060.xlsx"))
  write.xlsx(data.frame(Lfd_Nr = 1, Sat_indicator = "Iron ores", material_group = "Metals"),
             file.path(paths$input, "concordance_material_groups.xlsx"))
  file.copy(file.path(repo, "input", "indicator_catalogue.csv"), paths$input)
  fwrite(data.table(region_code = 1:nr, region_acronym = regions$Region_acronyms,
                    region_name = regions$Region_names,
                    world_region_7 = c("Europe", "Asia-Pacific", "North America"),
                    income_group_worldbank = c("High income", "Upper middle income", "High income"),
                    world = "World"),
         file.path(paths$input, "concordances", "regions.csv"))
  fwrite(data.table(sector_code = 1:ns, sector_name = sectors$Sector_names,
                    broad_sector = c("Primary", "Primary", "Secondary", "Tertiary"), total = "All"),
         file.path(paths$input, "concordances", "sectors.csv"))

  # fake raw supply-use table: industries supply their own product
  n2 <- nr * ns * 2
  type <- rep(rep(c("ind", "pro"), each = ns), nr)
  ind <- which(type == "ind"); pro <- which(type == "pro")
  for (year in 2019:2020) {
    T <- matrix(0, n2, n2)
    U <- matrix(runif(length(pro) * length(ind), 0, 10), length(pro))
    Yraw <- matrix(0, n2, nr * nfd)
    Yraw[pro, ] <- matrix(runif(length(pro) * nr * nfd, 0, 20), length(pro))
    Yraw[pro, 5] <- -1                                       # a negative inventory change
    T[pro, ind] <- U
    x <- rowSums(U) + rowSums(Yraw[pro, ])
    T[ind, pro] <- diag(x)
    Vraw <- matrix(0, nr * nva, n2)
    va_tot <- x - colSums(U)                                 # VA = output - inputs
    for (r in 1:nr) {
      cols <- ind[((r - 1) * ns + 1):(r * ns)]
      Vraw[(r - 1) * nva + 1, cols] <- 0.6 * va_tot[(r - 1) * ns + 1:ns]
      Vraw[(r - 1) * nva + 4, cols] <- 0.4 * va_tot[(r - 1) * ns + 1:ns]
    }
    TQ <- matrix(0, nrow(sat), n2); TQ[, ind] <- matrix(runif(nrow(sat) * length(ind), 0, 5), nrow(sat))
    YQ <- matrix(0, nrow(sat), nr * nfd); YQ[2:3, seq(1, nr * nfd, by = nfd)] <- 7   # household CO2
    fname <- function(t) file.path(paths$raw, sprintf(
      "20250101_120secMother_AllCountries_002_%s-Results_%d_060_Markup001(full).csv", t, year))
    fwrite(as.data.table(T), fname("T"), col.names = FALSE)
    fwrite(as.data.table(Yraw), fname("Y"), col.names = FALSE)
    fwrite(as.data.table(Vraw), fname("V"), col.names = FALSE)
    fwrite(as.data.table(TQ), fname("TQ"), col.names = FALSE)
    fwrite(as.data.table(YQ), fname("YQ"), col.names = FALSE)
  }

  # run the real parser
  for (f in c("R/functions_io.R", "parser/02_build_meta.R", "parser/03_parse_year.R",
              "R/engine.R", "R/export.R", "R/texts.R", "R/update.R", "R/share.R")) {
    source(file.path(repo, f), local = globalenv())
  }
  meta <- suppressWarnings(build_meta())
  checks <- rbindlist(lapply(2019:2020, function(y) suppressMessages(parse_year(y, meta))))
  list(meta = meta, checks = checks)
}

# numeric comparison with relative tolerance
near <- function(a, b, tol = 1e-6) all(abs(a - b) <= tol * pmax(1, abs(b)))
