# =============================================================================
# R/engine.R  -  Calculation engine of the GLORIA footprint app
# =============================================================================
# All calculations of the app happen here, separated from the user interface.
# The functions can therefore also be used directly from an R script, e.g.
#
#   source("config.R"); source("R/functions_io.R"); source("R/engine.R")
#   meta <- readRDS(file.path(paths$meta, "meta.rds"))
#   res  <- run_calculation(list(type = "footprint", indicators = "ghg_edgar",
#                                years = 2020, ...), meta)
#
# NOTATION (standard environmentally-extended input-output analysis)
#   n   = 164 regions x 120 sectors = 19 680 region-sectors
#   x   gross output of each region-sector                      (n)
#   q   direct pressure of each region-sector, e.g. kt CO2-eq   (n)
#   s   direct intensity  s = q / x  (pressure per 1000 USD output)
#   L   Leontief inverse (I - A)^-1                              (n x n)
#   Y   final demand (n x 164 regions*6 categories)
#   m   total multiplier  m = s L  (pressure along the whole supply chain
#       per 1000 USD of final product)
#
# RESULT TYPES
#   "footprint_origin"   s * (L Y): where the pressure physically happens
#                        (origin region/sector) for whose final demand
#                        (consumer region / category).
#   "footprint_product"  m * Y: footprint attributed to the final products
#                        bought (supplying region / product sector).
#   "production"         q: direct pressure where it happens (territorial,
#                        production-based account).
#   "overview"           per region: production-based vs. consumption-based
#                        total and the difference (net imports).
#   "tiva"               pressure / value added embodied in gross exports
#                        (exporter -> partner, by origin of the value).
# =============================================================================

# -----------------------------------------------------------------------------
# Loading parsed data (with a small cache, because L is 3 GB in memory)
# -----------------------------------------------------------------------------
.cache <- new.env()

year_file <- function(year, name) file.path(paths$parsed, year, name)

load_var <- function(year, name) {
  key <- paste(year, name, sep = "_")
  if (!is.null(.cache[[key]])) return(.cache[[key]])
  f <- year_file(year, name)
  if (!file.exists(f)) stop("Parsed file missing: ", f, " - has this year been parsed?")
  val <- if (grepl("\\.f32$", name)) read_f32(f) else readRDS(f)
  # Keep small objects of all years, but only ONE big matrix (L or LY) at a time
  if (name %in% c("L.f32", "LY.f32")) {
    for (k in ls(.cache)) if (grepl("_(L|LY)\\.f32$", k)) rm(list = k, envir = .cache)
    gc(verbose = FALSE)
  }
  .cache[[key]] <- val
  val
}

available_years <- function() {
  d <- list.dirs(paths$parsed, full.names = FALSE, recursive = FALSE)
  y <- suppressWarnings(as.integer(d))
  y <- y[!is.na(y)]
  sort(y[file.exists(file.path(paths$parsed, y, "_DONE"))])
}

# -----------------------------------------------------------------------------
# Indicators
# -----------------------------------------------------------------------------
# An indicator is either a catalogue id (e.g. "ghg_edgar") or a single raw
# GLORIA satellite row written as "sat:<code>" (expert mode).
indicator_info <- function(id, meta) {
  if (startsWith(id, "sat:")) {
    code <- as.integer(sub("sat:", "", id))
    s <- meta$satellites[sat_code == code]
    return(list(id = id, label = paste0(s$head, ": ", s$indicator), unit = s$unit,
                source = "Q", rows = code, in_catalogue = FALSE))
  }
  sel <- id   # local copy: inside [ ] 'id' would mean the column of the table
  r <- meta$catalogue[meta$catalogue$id == sel, ]
  if (nrow(r) != 1) stop("Unknown indicator: ", sel)
  list(id = id, label = r$label, unit = r$unit, source = r$source,
       rows = r$rows[[1]], in_catalogue = TRUE)
}

# Direct pressure q (n) of an indicator in one year
direct_pressure <- function(info, year) {
  if (info$source == "VA") {
    V <- load_var(year, "V.rds")
    colSums(V[info$rows, , drop = FALSE])
  } else {
    Q <- load_var(year, "Q.rds")
    colSums(Q[info$rows, , drop = FALSE])
  }
}

# Direct pressure of final demand (e.g. household heating, car fuel) (984)
direct_pressure_fd <- function(info, year) {
  if (info$source == "VA") return(NULL)
  QY <- load_var(year, "QY.rds")
  colSums(QY[info$rows, , drop = FALSE])
}

# Direct intensity s = q / x
intensity <- function(info, year) {
  x <- load_var(year, "x.rds")
  q <- direct_pressure(info, year)
  ifelse(x > 0, q / x, 0)
}

# Total multiplier m = s L. Catalogue indicators are pre-computed by the parser
# (fast); other indicators need L (slower, ~5-10 s per year for loading L).
multiplier <- function(info, year) {
  if (info$in_catalogue) {
    M <- load_var(year, "M.rds")
    return(M[info$id, ])
  }
  as.vector(intensity(info, year) %*% load_var(year, "L.f32"))
}

# -----------------------------------------------------------------------------
# Aggregation keys
# -----------------------------------------------------------------------------
# Returns, for each of the n region-sectors, the label of its region group and
# sector group according to the chosen concordance columns. A sector column of
# NULL means "do not show sectors" (all sectors summed up).
rs_keys <- function(meta, region_col, sector_col = NULL) {
  reg <- meta$regions[[region_col]][match(meta$idx_Z$region_code, meta$regions$region_code)]
  if (is.null(sector_col)) return(data.table(region = reg))
  sec <- meta$sectors[[sector_col]][match(meta$idx_Z$sector_code, meta$sectors$sector_code)]
  data.table(region = reg, sector = sec)
}

fd_keys <- function(meta, region_col, by_fd) {
  reg <- meta$regions[[region_col]][match(meta$idx_Y$region_code, meta$regions$region_code)]
  if (!by_fd) return(data.table(region = reg))
  fd <- meta$fd$fd_name[match(meta$idx_Y$fd_code, meta$fd$fd_code)]
  data.table(region = reg, fd = fd)
}

# Collapse several key columns into one string so that agg_matrix() can use it
key_string <- function(keys) do.call(paste, c(keys, sep = "\r"))

# Aggregate rows AND columns of matrix m and return a long table.
# row_keys / col_keys: data.tables with one row per row/column of m.
aggregate_long <- function(m, row_keys, col_keys, row_names, col_names) {
  rk <- key_string(row_keys); ck <- key_string(col_keys)
  rl <- unique(rk); cl <- unique(ck)
  Gr <- agg_matrix(rk, rl); Gc <- agg_matrix(ck, cl)
  agg <- as.matrix(crossprod(Gr, m) %*% Gc)
  out <- data.table(r = rep(rl, times = length(cl)),
                    c = rep(cl, each = length(rl)),
                    value = as.vector(agg))
  out[, (row_names) := tstrsplit(r, "\r", fixed = TRUE)]
  out[, (col_names) := tstrsplit(c, "\r", fixed = TRUE)]
  out[, c("r", "c") := NULL]
  out
}

# -----------------------------------------------------------------------------
# Result type 1: footprint by ORIGIN (where the pressure happens)
# -----------------------------------------------------------------------------
calc_footprint_origin <- function(info, year, meta, sp) {
  fd_sel <- meta$idx_Y$fd_code %in% sp$fd_codes
  LY <- load_var(year, "LY.f32")[, fd_sel, drop = FALSE]
  s  <- intensity(info, year)
  F  <- s * LY                     # pressure at origin i caused by fd column j

  row_keys <- rs_keys(meta, sp$region_from, if (sp$by_sector) sp$sector_col else NULL)
  col_keys <- fd_keys(meta, sp$region_to, sp$by_fd)[fd_sel]
  row_names <- c("from_region", if (sp$by_sector) "from_sector")
  col_names <- c("to_region", if (sp$by_fd) "final_demand")
  res <- aggregate_long(F, row_keys, col_keys, row_names, col_names)

  # Direct pressure of final demand (e.g. household emissions): it happens in
  # the consumer region itself and is reported as a separate origin "sector".
  if (isTRUE(sp$include_direct_fd)) {
    qy <- direct_pressure_fd(info, year)
    if (!is.null(qy) && any(qy[fd_sel] != 0)) {
      reg_from <- meta$regions[[sp$region_from]][match(meta$idx_Y$region_code, meta$regions$region_code)][fd_sel]
      d <- data.table(from_region = reg_from)
      if (sp$by_sector) d[, from_sector := "Direct emissions of final users (households etc.)"]
      d <- cbind(d, col_keys[, setNames(.SD, col_names)], value = qy[fd_sel])
      d <- d[, .(value = sum(value)), by = c(row_names, col_names)]
      res <- rbind(res, d, use.names = TRUE)
    }
  }
  res
}

# -----------------------------------------------------------------------------
# Result type 2: footprint by FINAL PRODUCT (what is bought)
# -----------------------------------------------------------------------------
calc_footprint_product <- function(info, year, meta, sp) {
  fd_sel <- meta$idx_Y$fd_code %in% sp$fd_codes
  Y <- load_var(year, "Y.rds")[, fd_sel, drop = FALSE]
  m <- multiplier(info, year)
  F <- m * Y
  row_keys <- rs_keys(meta, sp$region_from, if (sp$by_sector) sp$sector_col else NULL)
  col_keys <- fd_keys(meta, sp$region_to, sp$by_fd)[fd_sel]
  row_names <- c("product_from_region", if (sp$by_sector) "product_sector")
  col_names <- c("to_region", if (sp$by_fd) "final_demand")
  aggregate_long(F, row_keys, col_keys, row_names, col_names)
}

# -----------------------------------------------------------------------------
# Result type 3: production-based (territorial) account
# -----------------------------------------------------------------------------
calc_production <- function(info, year, meta, sp) {
  q <- direct_pressure(info, year)
  keys <- rs_keys(meta, sp$region_from, if (sp$by_sector) sp$sector_col else NULL)
  res <- keys[, .(value = sum(q[.I])), by = names(keys)]
  setnames(res, c("region", if (sp$by_sector) "sector", "value"))
  if (isTRUE(sp$include_direct_fd)) {
    qy <- direct_pressure_fd(info, year)
    if (!is.null(qy)) {
      fd_sel <- meta$idx_Y$fd_code %in% sp$fd_codes
      reg <- meta$regions[[sp$region_from]][match(meta$idx_Y$region_code, meta$regions$region_code)]
      d <- data.table(region = reg[fd_sel], value = qy[fd_sel])[, .(value = sum(value)), by = region]
      if (sp$by_sector) d[, sector := "Direct emissions of final users (households etc.)"]
      res <- rbind(res, d, use.names = TRUE)
    }
  }
  res
}

# -----------------------------------------------------------------------------
# Result type 4: overview production- vs consumption-based per region
# -----------------------------------------------------------------------------
calc_overview <- function(info, year, meta, sp) {
  sp2 <- modifyList(sp, list(by_sector = FALSE, by_fd = FALSE))
  prod <- calc_production(info, year, meta, sp2)[, .(production_based = sum(value)), by = .(region)]
  sp2$region_to <- sp$region_from
  fp <- calc_footprint_origin(info, year, meta, sp2)[, .(consumption_based = sum(value)), by = .(region = to_region)]
  res <- merge(prod, fp, by = "region", all = TRUE)
  res[is.na(res)] <- 0
  res[, net_imports := consumption_based - production_based]
  melt(res, id.vars = "region", variable.name = "account", value.name = "value")
}

# -----------------------------------------------------------------------------
# Result type 5: Trade in Value Added (TiVA) / pressure embodied in exports
# -----------------------------------------------------------------------------
# For exporter c with gross exports e_c (to each partner p) the value added
# (or pressure) generated in origin region o is
#      sum over sectors of origin o:  s_o * L[o, c] * e_c,p
# Origin = exporter itself -> "domestic value added in exports" (DVA),
# origin = other region    -> "foreign value added in exports" (FVA).
# Note: indicators based on GROSS exports contain some double counting when
# goods cross borders several times (see Koopman et al. 2014). For the
# footprint of a country's consumption use the footprint result types.
calc_tiva <- function(info, year, meta, sp) {
  L <- load_var(year, "L.f32")
  E <- load_var(year, "E.rds")
  s <- intensity(info, year)
  n_sec <- meta$n$sec
  reg_codes <- meta$regions$region_code
  # origin aggregation at country level (164) first, groups later
  G_orig <- agg_matrix(as.character(meta$idx_Z$region_code), as.character(reg_codes))
  sec_lab <- if (sp$by_sector) meta$sectors[[sp$sector_col]] else rep("All sectors", n_sec)
  sec_groups <- unique(sec_lab)

  out <- vector("list", length(reg_codes))
  for (k in seq_along(reg_codes)) {
    rows_c <- which(meta$idx_Z$region_code == reg_codes[k])
    Mc <- as.matrix(crossprod(G_orig, s * L[, rows_c]))     # 164 origins x 120 sectors
    e_c <- E[rows_c, , drop = FALSE]                          # 120 sectors x 164 partners
    out[[k]] <- rbindlist(lapply(sec_groups, function(g) {
      j <- which(sec_lab == g)
      v <- Mc[, j, drop = FALSE] %*% e_c[j, , drop = FALSE]   # origins x partners
      data.table(exporter = reg_codes[k], export_sector = g,
                 origin = rep(reg_codes, times = length(reg_codes)),
                 partner = rep(reg_codes, each = length(reg_codes)),
                 value = as.vector(v))
    }))
  }
  res <- rbindlist(out)[value != 0]
  res[, origin_type := fifelse(origin == exporter, "domestic", "foreign")]

  # map to the chosen region groups and aggregate
  lab <- function(code, col) meta$regions[[col]][match(code, reg_codes)]
  res[, `:=`(exporter = lab(exporter, sp$region_from),
             partner  = lab(partner,  sp$region_to),
             origin   = lab(origin,   sp$region_from))]
  by <- c("exporter", if (sp$by_sector) "export_sector", "partner",
          if (isTRUE(sp$tiva_origin_detail)) "origin", "origin_type")
  res[, .(value = sum(value)), by = by]
}

# -----------------------------------------------------------------------------
# Main entry point used by the app
# -----------------------------------------------------------------------------
# spec: list with
#   type          one of the result types above
#   indicators    character vector of indicator ids
#   years         integer vector
#   region_from   concordance column for origin / producing / exporting region
#   region_to     concordance column for consumer / partner region
#   sector_col    concordance column for sectors
#   by_sector     TRUE = show sector detail
#   by_fd         TRUE = show final demand categories separately
#   fd_codes      final demand categories to include (1..6)
#   include_direct_fd   add direct emissions of households etc.
#   tiva_origin_detail  TiVA: show origin regions (otherwise only domestic/foreign)
# progress: optional function(fraction, message) for a progress bar
run_calculation <- function(spec, meta, progress = NULL) {
  fun <- switch(spec$type,
                footprint_origin  = calc_footprint_origin,
                footprint_product = calc_footprint_product,
                production        = calc_production,
                overview          = calc_overview,
                tiva              = calc_tiva,
                stop("Unknown result type: ", spec$type))
  jobs <- CJ(year = spec$years, indicator = spec$indicators, sorted = FALSE)
  # Loop over years first: the big matrices of one year are loaded only once
  setorder(jobs, year)
  res <- vector("list", nrow(jobs))
  for (i in seq_len(nrow(jobs))) {
    info <- indicator_info(jobs$indicator[i], meta)
    if (!is.null(progress)) progress(i / nrow(jobs), sprintf("%d - %s", jobs$year[i], info$label))
    r <- fun(info, jobs$year[i], meta, spec)
    r[, `:=`(year = jobs$year[i], indicator = info$label, unit = info$unit)]
    res[[i]] <- r
  }
  res <- rbindlist(res, use.names = TRUE, fill = TRUE)
  if (!isTRUE(spec$keep_zeros)) res <- res[value != 0]
  # column order: year, indicator, unit, all dimensions, value last
  setcolorder(res, c("year", "indicator", "unit", setdiff(names(res), c("year", "indicator", "unit", "value")), "value"))
  res[]
}

# -----------------------------------------------------------------------------
# Reshape the long result into a "pivot" (wide) table
# -----------------------------------------------------------------------------
# pivot_col: the column whose values become separate columns (e.g. "year").
to_wide <- function(res, pivot_col = "year") {
  id_cols <- setdiff(names(res), c(pivot_col, "value"))
  f <- as.formula(paste(paste0("`", id_cols, "`", collapse = " + "), "~", pivot_col))
  dcast(res, f, value.var = "value", fun.aggregate = sum, fill = 0)
}
