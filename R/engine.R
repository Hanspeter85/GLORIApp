# =============================================================================
# R/engine.R  -  Calculation engine of the GLORIA footprint app
# =============================================================================
# All calculations of the app happen here, separated from the user interface.
# The functions can therefore also be used directly from an R script, e.g.
#
#   source("config.R"); source("R/functions_io.R"); source("R/engine.R")
#   meta <- readRDS(file.path(paths$meta, "meta.rds"))
#   res  <- run_calculation(list(type = "footprint", indicators = "ghg_edgar",
#                                years = 2020, production_region = "world_region_7",
#                                consumption_region = "region_name"), meta)
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
#   "footprint"   consumption-based account s L Y, split freely by
#                 the production side (where/what the pressure occurs) and the
#                 consumption side (where/what/who: consumer region, final
#                 product, final demand category). Works for every indicator:
#                 with "Value added" it is the value-added footprint, i.e.
#                 Trade in Value Added from the final-demand perspective.
#   "production"  q: direct pressure where it happens (territorial account).
#   "overview"    per region: production-based vs. consumption-based total
#                 and the difference (net imports).
#   "exports"     scripts only (not in the app): embodied in GROSS exports (OECD TiVA
#                 style, exporter -> partner, domestic/foreign origin).
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
# A "dimension" is described by a region grouping and a sector grouping, each
# a column name of the concordance tables (input/concordances/*.csv) or "none"
# (= do not split, everything is summed up).
#
# keys_rs() returns, for each of the n region-sectors, its region group and
# sector group as a data.table with 0, 1 or 2 columns (named region_name and
# sector_name; only for the dimensions that are split).
keys_rs <- function(meta, region_col, sector_col, region_name, sector_name) {
  out <- data.table(.dummy = seq_len(meta$n$rs))
  if (!identical(region_col, "none")) {
    out[, (region_name) :=
          meta$regions[[region_col]][match(meta$idx_Z$region_code, meta$regions$region_code)]]
  }
  if (!identical(sector_col, "none")) {
    out[, (sector_name) :=
          meta$sectors[[sector_col]][match(meta$idx_Z$sector_code, meta$sectors$sector_code)]]
  }
  out[, .dummy := NULL]
  out
}

# Keys of the 984 final demand columns (consumer region x category)
keys_fd <- function(meta, region_col, by_fd) {
  out <- data.table(consumption_region =
                      meta$regions[[region_col]][match(meta$idx_Y$region_code, meta$regions$region_code)])
  if (by_fd) out[, consumption_category := meta$fd$fd_name[match(meta$idx_Y$fd_code, meta$fd$fd_code)]]
  out
}

# Collapse several key columns into one string so that agg_matrix() can use it.
# A table without columns means "no split": everything gets the same key.
key_string <- function(keys, n) {
  if (ncol(keys) == 0) return(rep("all", n))
  do.call(paste, c(keys, sep = "\r"))
}
split_key <- function(out, col, names) {
  if (length(names) > 0) out[, (names) := tstrsplit(get(col), "\r", fixed = TRUE)]
  out[, (col) := NULL]
  out
}

# Aggregate rows AND columns of matrix m and return a long table.
# row_keys / col_keys: data.tables with one row per row/column of m.
aggregate_long <- function(m, row_keys, col_keys) {
  rk <- key_string(row_keys, nrow(m)); ck <- key_string(col_keys, ncol(m))
  rl <- unique(rk); cl <- unique(ck)
  agg <- as.matrix(crossprod(agg_matrix(rk, rl), m) %*% agg_matrix(ck, cl))
  out <- data.table(.r = rep(rl, times = length(cl)), .c = rep(cl, each = length(rl)),
                    value = as.vector(agg))
  out <- split_key(out, ".r", names(row_keys))
  split_key(out, ".c", names(col_keys))
}

# Label for pressures that are not caused by any industry but occur directly
# at the final users (e.g. heating and car fuel of households)
DIRECT_LABEL <- "Direct emissions of final users (households etc.)"

# -----------------------------------------------------------------------------
# FOOTPRINT (consumption-based account) with free choice of dimensions
# -----------------------------------------------------------------------------
# The footprint of final demand column j is distributed over
#   PRODUCTION side  o: where (production_region) and what (production_sector)
#                       - where the pressure physically occurs
#   CONSUMPTION side j: where (consumption_region), what (consumption_product =
#                       sector of the final product bought, optionally with
#                       product_made_in = region that made it) and who
#                       (consumption_category = households, government, ...)
# Full detail:  F[o, p, j] = s_o * L[o, p] * Y[p, j]
#
# Three cases, from fast to slower:
#   1) origin split only    F = s * (L Y)        uses the pre-computed L Y
#   2) product split only   F = (s L) * Y        uses pre-computed multipliers
#   3) origin AND product   loops over consumer groups, needs L (1.5 GB)
# All three give the same totals per consumer.
calc_footprint <- function(info, year, meta, sp) {
  fd_sel <- meta$idx_Y$fd_code %in% sp$fd_codes
  o_keys <- keys_rs(meta, sp$production_region, sp$production_sector, "production_region", "production_sector")
  p_keys <- keys_rs(meta, sp$product_made_in, sp$consumption_product, "product_made_in", "consumption_product")
  c_keys <- keys_fd(meta, sp$consumption_region, isTRUE(sp$by_fd))[fd_sel]

  if (ncol(p_keys) == 0) {
    # --- case 1: by origin ---------------------------------------------------
    F <- intensity(info, year) * load_var(year, "LY.f32")[, fd_sel, drop = FALSE]
    res <- aggregate_long(F, o_keys, c_keys)
  } else if (ncol(o_keys) == 0) {
    # --- case 2: by final product ------------------------------------------
    F <- multiplier(info, year) * load_var(year, "Y.rds")[, fd_sel, drop = FALSE]
    res <- aggregate_long(F, p_keys, c_keys)
  } else {
    # --- case 3: origin x final product (expert, slower) -------------------
    L  <- load_var(year, "L.f32")
    s  <- intensity(info, year)
    ok <- key_string(o_keys, meta$n$rs); ol <- unique(ok)
    pk <- key_string(p_keys, meta$n$rs); pl <- unique(pk)
    ck <- key_string(c_keys, nrow(c_keys)); cl <- unique(ck)
    Go <- agg_matrix(ok, ol); Gp <- agg_matrix(pk, pl)
    A1 <- as.matrix(crossprod(Go, s * L))                      # origins x n
    Yc <- as.matrix(load_var(year, "Y.rds")[, fd_sel, drop = FALSE] %*% agg_matrix(ck, cl))
    res <- rbindlist(lapply(seq_along(cl), function(k) {
      v <- as.matrix(A1 %*% (Yc[, k] * Gp))                    # origins x products
      data.table(.o = rep(ol, times = length(pl)), .p = rep(pl, each = length(ol)),
                 .c = cl[k], value = as.vector(v))[value != 0]
    }))
    res <- split_key(res, ".o", names(o_keys))
    res <- split_key(res, ".p", names(p_keys))
    res <- split_key(res, ".c", names(c_keys))
  }

  # Direct pressure of final users (households' heating, cars, ...): it occurs
  # in the consumer region itself and belongs to no product.
  if (isTRUE(sp$include_direct_fd)) {
    qy <- direct_pressure_fd(info, year)
    if (!is.null(qy) && any(qy[fd_sel] != 0)) {
      reg_of_fd <- function(col) meta$regions[[col]][match(meta$idx_Y$region_code, meta$regions$region_code)][fd_sel]
      d <- copy(c_keys)[, value := qy[fd_sel]]
      if ("production_region" %in% names(o_keys)) d[, production_region := reg_of_fd(sp$production_region)]
      if ("production_sector" %in% names(o_keys)) d[, production_sector := DIRECT_LABEL]
      if ("product_made_in" %in% names(p_keys)) d[, product_made_in := reg_of_fd(sp$product_made_in)]
      if ("consumption_product" %in% names(p_keys)) d[, consumption_product := DIRECT_LABEL]
      res <- rbind(res, d, use.names = TRUE, fill = TRUE)
    }
  }
  res[, .(value = sum(value)), by = setdiff(names(res), "value")]
}

# -----------------------------------------------------------------------------
# PRODUCTION-BASED (territorial) account
# -----------------------------------------------------------------------------
calc_production <- function(info, year, meta, sp) {
  q <- direct_pressure(info, year)
  keys <- keys_rs(meta, sp$production_region, sp$production_sector, "production_region", "production_sector")
  res <- aggregate_long(matrix(q, ncol = 1), keys, data.table())
  if (isTRUE(sp$include_direct_fd)) {
    qy <- direct_pressure_fd(info, year)
    if (!is.null(qy)) {
      fd_sel <- meta$idx_Y$fd_code %in% sp$fd_codes
      d <- data.table(value = qy[fd_sel])
      if ("production_region" %in% names(keys)) {
        d[, production_region := meta$regions[[sp$production_region]][
          match(meta$idx_Y$region_code, meta$regions$region_code)][fd_sel]]
      }
      if ("production_sector" %in% names(keys)) d[, production_sector := DIRECT_LABEL]
      res <- rbind(res, d, use.names = TRUE, fill = TRUE)
    }
  }
  res[, .(value = sum(value)), by = setdiff(names(res), "value")]
}

# -----------------------------------------------------------------------------
# OVERVIEW: production- vs consumption-based per region
# -----------------------------------------------------------------------------
calc_overview <- function(info, year, meta, sp) {
  reg <- if (identical(sp$production_region, "none")) "world" else sp$production_region
  sp2 <- modifyList(sp, list(production_region = reg, production_sector = "none",
                             product_made_in = "none", consumption_product = "none",
                             consumption_region = reg, by_fd = FALSE))
  prod <- calc_production(info, year, meta, sp2)[, .(production_based = sum(value)), by = .(region = production_region)]
  fp <- calc_footprint(info, year, meta, sp2)[, .(consumption_based = sum(value)), by = .(region = consumption_region)]
  res <- merge(prod, fp, by = "region", all = TRUE)
  res[is.na(res)] <- 0
  res[, net_imports := consumption_based - production_based]
  melt(res, id.vars = "region", variable.name = "account", value.name = "value")
}

# -----------------------------------------------------------------------------
# SCRIPTS ONLY (not offered in the app): indicator embodied in GROSS exports
# -----------------------------------------------------------------------------
# NOTE: the value-added FOOTPRINT (indicator "Value added" with the normal
# footprint) is the consumption-based TiVA measure ("value added in final
# demand") and is the recommended way. This function gives the alternative
# view on GROSS exports: for exporter c with gross exports e_c to partner p
# the value added (or pressure) generated in origin region o is
#      sum over sectors of origin o:  s_o * L[o, c] * e_c,p
# Origin = exporter -> "domestic", other region -> "foreign" content.
# Gross exports count goods that cross borders several times more than once
# (Koopman et al. 2014), so totals are larger than footprints.
# Dimensions used: exporter = product_made_in (+ consumption_product = exporting
# sector), partner = consumption_region, origin = production_region.
calc_exports <- function(info, year, meta, sp) {
  L <- load_var(year, "L.f32")
  E <- load_var(year, "E.rds")
  s <- intensity(info, year)
  n_sec <- meta$n$sec
  reg_codes <- meta$regions$region_code
  G_orig <- agg_matrix(as.character(meta$idx_Z$region_code), as.character(reg_codes))
  by_sec <- !identical(sp$consumption_product, "none")
  sec_lab <- if (by_sec) meta$sectors[[sp$consumption_product]] else rep("All sectors", n_sec)
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

  lab <- function(code, col) {
    if (identical(col, "none")) return(rep("World", length(code)))
    meta$regions[[col]][match(code, reg_codes)]
  }
  res[, `:=`(exporter = lab(exporter, sp$product_made_in),
             partner  = lab(partner,  sp$consumption_region),
             origin   = lab(origin,   sp$production_region))]
  by <- c("exporter", if (by_sec) "export_sector", "partner",
          if (!identical(sp$production_region, "none")) "origin", "origin_type")
  res[, .(value = sum(value)), by = by]
}
# -----------------------------------------------------------------------------
# Main entry point used by the app
# -----------------------------------------------------------------------------
# spec: list with
#   type             "footprint", "overview", "production" or "exports" (expert)
#   indicators       character vector of indicator ids (see indicator_info)
#   years            integer vector
#   production_region    PRODUCTION side, where: region grouping (or "none")
#   production_sector    PRODUCTION side, what: sector grouping (or "none")
#   consumption_region   CONSUMPTION side, where: region grouping of consumers
#   consumption_product  CONSUMPTION side, what: sector grouping of final products (or "none")
#   product_made_in      CONSUMPTION side, optional: region that made the final product (or "none")
#   by_fd                CONSUMPTION side, who: TRUE = split by final demand category
#   fd_codes         final demand categories to include (1..6)
#   include_direct_fd  add direct emissions of households etc.
#   keep_zeros       keep rows with value 0
# Grouping values are column names of input/concordances/regions.csv and
# sectors.csv (e.g. "region_name", "income_group_worldbank", "broad_sector").
# progress: optional function(fraction, message) for a progress bar
run_calculation <- function(spec, meta, progress = NULL) {
  defaults <- list(production_region = "region_name", production_sector = "none",
                   product_made_in = "none", consumption_product = "none",
                   consumption_region = "region_name", by_fd = FALSE, fd_codes = meta$fd$fd_code,
                   include_direct_fd = TRUE, keep_zeros = FALSE)
  spec <- modifyList(defaults, spec)
  fun <- switch(spec$type,
                footprint  = calc_footprint,
                production = calc_production,
                overview   = calc_overview,
                exports    = calc_exports,
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
  # column order: year, indicator, unit, production side, consumption side, value
  dims <- setdiff(names(res), c("year", "indicator", "unit", "value"))
  pref <- c("production_region", "production_sector", "consumption_region", "consumption_product",
            "product_made_in", "consumption_category")
  dims <- c(intersect(pref, dims), setdiff(dims, pref))
  setcolorder(res, c("year", "indicator", "unit", dims, "value"))
  res[]
}

# -----------------------------------------------------------------------------
# Reshape the long result into a wide table (cross table)
# -----------------------------------------------------------------------------
# pivot_col: the column whose values become separate columns (e.g. "year").
to_wide <- function(res, pivot_col = "year") {
  id_cols <- setdiff(names(res), c(pivot_col, "value"))
  f <- as.formula(paste(paste0("`", id_cols, "`", collapse = " + "), "~", pivot_col))
  dcast(res, f, value.var = "value", fun.aggregate = sum, fill = 0)
}
