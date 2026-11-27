# =============================================================================
# tests/test_pipeline.R  -  End-to-end test of parser + engine on a MINI GLORIA
# =============================================================================
# Builds a tiny fake GLORIA (3 regions x 4 sectors, random numbers) with the
# same file layout as the real raw data, runs the real parser on it and checks
# basic input-output identities of the engine results:
#   * total footprint (consumption-based) = total production-based account
#   * footprint by origin and by product give the same totals per consumer
#   * TiVA with value added: domestic + foreign VA in exports = gross exports
#   * L reproduces gross output
# Run from the repo root:  Rscript tests/test_pipeline.R
# =============================================================================

suppressPackageStartupMessages({ library(openxlsx); library(data.table) })
set.seed(1)

tmp <- Sys.getenv("GLORIA_TEST_DIR", unset = file.path(tempdir(), "gloria_test"))
unlink(tmp, recursive = TRUE)
Sys.setenv(GLORIA_DATA_ROOT = tmp)
source("config.R")
gloria_years <- 2020
paths$input <- file.path(tmp, "input")
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
saveWorkbook(wb, file.path(paths$input, sprintf("GLORIA_ReadMe_0%d.xlsx", gloria_version)))
write.xlsx(data.frame(Lfd_Nr = 1, Sat_indicator = "Iron ores", material_group = "Metals"),
           file.path(paths$input, "concordance_material_groups.xlsx"))
file.copy("input/indicator_catalogue.csv", paths$input)
fwrite(data.table(region_code = 1:nr, region_acronym = regions$Region_acronyms,
                  region_name = regions$Region_names,
                  world_region_7 = c("Europe", "Asia-Pacific", "North America"),
                  income_group_worldbank = c("High income", "Upper middle income", "High income"),
                  world = "World"),
       file.path(paths$input, "concordances", "regions.csv"))
fwrite(data.table(sector_code = 1:ns, sector_name = sectors$Sector_names,
                  broad_sector = c("Primary", "Primary", "Secondary", "Tertiary"), total = "All"),
       file.path(paths$input, "concordances", "sectors.csv"))

# --- fake raw SUT: industries supply their own product, products are used --------
n2 <- nr * ns * 2
type <- rep(rep(c("ind", "pro"), each = ns), nr)
T <- matrix(0, n2, n2)
ind <- which(type == "ind"); pro <- which(type == "pro")
U <- matrix(runif(length(pro) * length(ind), 0, 10), length(pro))    # use block
Yraw <- matrix(0, n2, nr * nfd)
Yraw[pro, ] <- matrix(runif(length(pro) * nr * nfd, 0, 20), length(pro))
Yraw[pro, 5] <- -1                                                    # a negative inventory change
T[pro, ind] <- U
x <- rowSums(U) + rowSums(Yraw[pro, ])
T[ind, pro] <- diag(x)                                                # supply block (diagonal)
Vraw <- matrix(0, nr * nva, n2)
va_tot <- x - colSums(U)                                              # balance: VA = x - inputs
for (r in 1:nr) {
  cols <- ind[((r - 1) * ns + 1):(r * ns)]
  Vraw[(r - 1) * nva + 1, cols] <- 0.6 * va_tot[(r - 1) * ns + 1:ns]
  Vraw[(r - 1) * nva + 4, cols] <- 0.4 * va_tot[(r - 1) * ns + 1:ns]
}
TQ <- matrix(0, nrow(sat), n2); TQ[, ind] <- matrix(runif(nrow(sat) * length(ind), 0, 5), nrow(sat))
YQ <- matrix(0, nrow(sat), nr * nfd); YQ[2:3, seq(1, nr * nfd, by = nfd)] <- 7   # household CO2

fname <- function(t) file.path(paths$raw, sprintf("20250101_120secMother_AllCountries_002_%s-Results_2020_0%d_Markup001(full).csv", t, gloria_version))
fwrite(as.data.table(T), fname("T"), col.names = FALSE)
fwrite(as.data.table(Yraw), fname("Y"), col.names = FALSE)
fwrite(as.data.table(Vraw), fname("V"), col.names = FALSE)
fwrite(as.data.table(TQ), fname("TQ"), col.names = FALSE)
fwrite(as.data.table(YQ), fname("YQ"), col.names = FALSE)

# --- run the real parser ------------------------------------------------------------
source("R/functions_io.R"); source("parser/02_build_meta.R"); source("parser/03_parse_year.R")
meta <- suppressWarnings(build_meta())
chk <- parse_year(2020, meta)
print(chk)

# --- engine checks ------------------------------------------------------------------------
source("R/engine.R")
ok <- function(cond, msg) { cat(if (cond) "PASS " else "FAIL ", msg, "\n"); if (!cond) quit(status = 1) }
near <- function(a, b) abs(a - b) <= 1e-4 * max(1, abs(b))
sp <- list(indicators = c("ghg_edgar", "mat_metals", "va_total"), years = 2020,
           region_from = "region_name", region_to = "region_name", sector_col = "broad_sector",
           by_sector = TRUE, by_fd = TRUE, fd_codes = 1:6, include_direct_fd = TRUE,
           tiva_origin_detail = TRUE)

fo <- run_calculation(modifyList(sp, list(type = "footprint_origin")), meta)
fp <- run_calculation(modifyList(sp, list(type = "footprint_product")), meta)
pr <- run_calculation(modifyList(sp, list(type = "production")), meta)
ov <- run_calculation(modifyList(sp, list(type = "overview")), meta)
tv <- run_calculation(modifyList(sp, list(type = "tiva", indicators = "va_total")), meta)

for (ind in unique(pr$indicator)) {
  ok(near(fo[indicator == ind, sum(value)], pr[indicator == ind, sum(value)]),
     paste("footprint total = production total:", ind))
}
a <- fo[!grepl("^Direct", from_sector), .(v = sum(value)), by = .(indicator, to_region)]
b <- fp[, .(v = sum(value)), by = .(indicator, to_region)]
m <- merge(a, b, by = c("indicator", "to_region"))
ok(all(near(m$v.x, m$v.y)), "origin- and product-based footprints agree per consumer")
ok(ov[account == "net_imports", near(sum(value), 0)], "net imports sum to zero globally")
E <- readRDS(file.path(paths$parsed, 2020, "E.rds"))
ok(near(tv[, sum(value)], sum(E)), "TiVA: domestic + foreign VA = gross exports")
ok(near(chk$output_reproduced_by_L, 1), "L reproduces gross output")
w <- to_wide(fo, "year"); ok(nrow(w) > 0, "wide format works")
fo2 <- run_calculation(modifyList(sp, list(type = "footprint_origin", by_sector = FALSE, by_fd = FALSE)), meta)
ok(!anyDuplicated(fo2[, .(indicator, from_region, to_region)]), "no duplicate rows without sector detail")
pr2 <- run_calculation(modifyList(sp, list(type = "production", by_sector = FALSE)), meta)
ok(!anyDuplicated(pr2[, .(indicator, region)]), "no duplicate rows in production account")
cat("All tests passed.\n")
