# =============================================================================
# parser/01_build_concordances.R  -  Build region and sector concordances
# =============================================================================
# Output (versioned in the repo, may be edited by hand):
#   input/concordances/regions.csv   one row per GLORIA region (164)
#   input/concordances/sectors.csv   one row per GLORIA sector (120)
#
# The app ONLY reads these two csv files. If you need your own aggregation,
# simply add a new column there - it automatically shows up as an option in
# the app (column name = name of the aggregation).
#
# Re-run this script only if GLORIA regions/sectors change or if the World
# Bank income groups should be updated.
# =============================================================================

source("config.R")
suppressPackageStartupMessages({
  library(openxlsx)
  library(jsonlite)
  library(data.table)
})

dir.create(file.path(paths$input, "concordances"), showWarnings = FALSE, recursive = TRUE)

# --- Find the GLORIA ReadMe of the current version ------------------------------
readme <- file.path(paths$input, sprintf("GLORIA_ReadMe_0%d.xlsx", gloria_version))
if (!file.exists(readme)) {
  # Fall back to the newest ReadMe in the input folder
  readme <- tail(sort(list.files(paths$input, "^GLORIA_ReadMe_0\\d+\\.xlsx$", full.names = TRUE)), 1)
  warning("ReadMe for v", gloria_version, " missing, using ", readme)
}

# =============================================================================
# 1) REGIONS
# =============================================================================
reg <- as.data.table(read.xlsx(readme, sheet = "Regions"))
setnames(reg, c("Lfd_Nr", "Region_acronyms", "Region_names"),
         c("region_code", "region_acronym", "region_name"))

# --- 1a) Existing groupings from GLORIA_164RegAgg.xlsx ---------------------------
# Each grouping is a 0/1 matrix (regions x groups) there. We turn it into a
# single column holding the group name.
regagg <- file.path(paths$input, "GLORIA_164RegAgg.xlsx")
onehot_to_label <- function(sheet) {
  d <- read.xlsx(regagg, sheet = sheet)
  m <- as.matrix(d[, -1])
  lab <- colnames(m)[apply(m, 1, which.max)]
  gsub(".", " ", lab, fixed = TRUE)
}
reg[, world_region_7 := onehot_to_label("164Regions_To_7WorldRegs")]
reg[, development_group := onehot_to_label("164Regions_To_LDCs")]

# --- 1b) World Bank income groups and regions ------------------------------------
# Source: World Bank API (https://api.worldbank.org/v2/country). The API always
# returns the CURRENT classification (renewed every year on 1 July). To keep
# results reproducible, the download is stored as csv in the repo and only
# fetched again if that file is missing.
wb_file <- file.path(paths$input, "concordances", "worldbank_country_classification.csv")
if (!file.exists(wb_file)) {
  j <- fromJSON("https://api.worldbank.org/v2/country?format=json&per_page=400")[[2]]
  wb <- data.table(iso3 = j$id, wb_name = j$name,
                   wb_income = trimws(j$incomeLevel$value),
                   wb_region = trimws(j$region$value))
  wb <- wb[wb_region != "Aggregates"]
  wb[, retrieved := as.character(Sys.Date())]
  fwrite(wb, wb_file)
}
wb <- fread(wb_file)

# GLORIA acronyms that differ from the ISO code
iso_fix <- c(SDS = "SSD",   # South Sudan
             DYE = "YEM")   # DR Yemen (Aden) -> today's Yemen
reg[, iso3 := fifelse(region_acronym %in% names(iso_fix), iso_fix[region_acronym], region_acronym)]
reg <- merge(reg, wb[, .(iso3, wb_income, wb_region)], by = "iso3", all.x = TRUE, sort = FALSE)

# The four "Rest of ..." regions contain countries from different income groups.
# They are kept as a separate group so that nothing is silently misassigned.
reg[is.na(wb_income) | wb_income == "Not classified", wb_income := "Rest-of-world regions (mixed)"]
reg[is.na(wb_region), wb_region := "Rest-of-world regions (mixed)"]
reg[, iso3 := NULL]
setorder(reg, region_code)

# Rename columns so that they read nicely in the app
setnames(reg, c("wb_income", "wb_region"), c("income_group_worldbank", "region_worldbank"))
reg[, world := "World"]

fwrite(reg, file.path(paths$input, "concordances", "regions.csv"))

# =============================================================================
# 2) SECTORS
# =============================================================================
sec <- as.data.table(read.xlsx(readme, sheet = "Sectors"))
setnames(sec, c("Lfd_Nr", "Sector_names"), c("sector_code", "sector_name"))

# ISIC Rev.4 sections from the GLORIA ReadMe (0/1 matrix -> label)
isic <- read.xlsx(readme, sheet = "GLORIA to ISIC concordance", startRow = 2)
m <- as.matrix(isic[, -1])
sec[, isic_section := gsub(".", " ", colnames(m)[apply(m, 1, which.max)], fixed = TRUE)]

# Coarse grouping into 6 broad sectors (derived from the ISIC sections)
broad <- function(s) {
  fcase(s == "Agriculture, forestry and fishing", "Agriculture, forestry, fishing",
        s == "Mining and quarrying", "Mining and quarrying",
        s == "Manufacturing", "Manufacturing",
        grepl("^Electricity|^Water supply", s), "Utilities (energy, water, waste)",
        s == "Construction", "Construction",
        default = "Services")
}
sec[, broad_sector := broad(isic_section)]
sec[, total := "All sectors"]

fwrite(sec, file.path(paths$input, "concordances", "sectors.csv"))

message("Concordances written: ", nrow(reg), " regions, ", nrow(sec), " sectors.")
print(reg[, .N, by = income_group_worldbank])
