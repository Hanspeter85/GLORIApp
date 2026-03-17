### Parser for compiling basic IO variables for the GLORIA MRIO from the raw tables in Tvy format

# Load R packages
library(stringr)
library(data.table)
library(reshape2)
library(openxlsx)
library(tidyverse)
# library(parallel)

## Set paths where tables in Tvy format are located and where the results should be stored
## In case functions or certain scripts don't work, the reason might be found here!

# Set GLORIA version we want to use
ver <- 60
path <- list("rawMRIO" = str_c("/home/RegIOLab/data/GLORIA/GLORIA_version_",ver,"/Raw/"),
             "rawExtension" = str_c("/home/RegIOLab/data/GLORIA/GLORIA_version_",ver,"/Raw/GLORIA_MRIO_Loop0",ver,"_part_III_satelliteaccounts/"),
             "storeMRIOModel" = str_c("/home/RegIOLab/data/GLORIA/GLORIA_version_",ver,"/Parsed/"),
             "storeResults" = str_c("/home/RegIOLab/data/GLORIA/GLORIA_version_",ver,"/Results/"))

filename <- list("labels" = str_c("GLORIA_ReadMe_0",ver,".xlsx"),
                 "RegConcordance" = "GLORIA_164RegAgg.xlsx")



# Load all labels, codes, concordances and other meta information including the agg function
source("./R/0_create_labels.R")

TIME <- 1990:2029

# source("./R/5_time_series_footprint_of_final_demand.R")

# Execute script for parsing the extensions (materials, labor, carbon, energy, land)
source("./R/1_Extension_parser.R")

# Load function for parsing the basic MRIO variables (L, A, S, U, Y, ...)
source("./R/1_MRIO_parser.R")

year <- 1990
for(year in TIME)
{
  print(year)

  source("./R/2_prepare_MRIO_for_calculation.R")
  source("./R/2_calculate_all_footprints_FromTo.R")
}

# Load function for performing basic MRIO footprint analysis

# source("./R/2_calculate_all_sector_footprints_for_single_region.R")


## Set years of the time series and perform parsing
# TIME <- 1995:2022
# year <- 1995

# region <- "CHE"   # Switzerland
# year <- 1995





# Select year and stressor (biomass, metals, minerals, fossilfuels, energy, GWP100, landuse, employment 
# and caculate from-to flow results. Set region to 1:164 for getting results for all countries
# calculate_footprint_FromTo(stressor = "biomass", year = 2008, region = 1)
# calculate_footprint_FromTo(stressor = "biomass", year = 2008, region = 1:164)


