
## Set years of the time series and perform parsing
TIME <- 1995:2020

fd <- "Household final consumption"

fd_index <- labels$parsed$Y %>% 
  filter(sector_name == fd) %>% 
  pull(index)

result <- list()

for(year in TIME)
{
  print(year)
  
  ## Load MRIO model                                          
  Y <- fread( str_c(path$storeMRIOModel, year, "_Y.csv" ) ) %>% 
    as.matrix()
  
  # Select final demand categories
  Y_sel <- Y[,fd_index]
  
  L <- fread( str_c(path$storeMRIOModel, year, "_L.csv" ) ) %>% 
    as.matrix()
  
  # Calculate gross production vector
  x <- colSums(t(L) * rowSums(Y))
  
  # Load direct intensities
  Q <- fread( str_c(path$storeMRIOModel, year, "_Q.csv" ) )[,1:4] %>% 
    rowSums()

  # Calculate direct intensities
  f <- Q/x
  f[is.na(f)] <- 0  
  f[is.infinite(f)] <- 0
  
  remove(Y, Q)
  
  MP <- colSums(L * f)
  
  result[[str_c(year)]] <- unique$region %>% 
    mutate(indicator = "material_footprint",
           unit = "metric_tons_per_year",
           year = year,
           final_demand = fd,
           value = colSums(Y_sel * MP))
}

FIN <- result %>% 
  bind_rows()

write.xlsx(FIN, str_c(path$storeResults,"GLORIA_Material_Footprint_of_Households_1995-2020.xlsx"))
