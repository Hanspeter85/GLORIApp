# =============================================================================
# parser/03_parse_year.R  -  Parse ONE year of GLORIA into analysis-ready files
# =============================================================================
# Input  (raw GLORIA csv files, see README for the download):
#   T-Results   transaction matrix of the multi-regional supply-use table (SUT)
#               39 360 x 39 360 = 164 regions x (120 industries + 120 products)
#   Y-Results   final demand, 39 360 x 984 (164 regions x 6 categories)
#   V-Results   value added, 984 x 39 360 (164 regions x 6 components)
#   TQ-Results  satellite accounts of industries, 5 982 x 39 360
#   YQ-Results  satellite accounts of final demand (direct household
#               emissions etc.), 5 982 x 984
# All in basic prices ("Markup001").
#
# Output in <parsed>/<year>/ :
#   Z.rds    inter-industry flows (product x industry, 19 680 x 19 680), sparse
#   Y.rds    final demand (19 680 x 984)
#   V.rds    value added by component (6 x 19 680)
#   x.rds    gross output (19 680)
#   Q.rds    satellite accounts of industries (5 982 x 19 680), sparse
#   QY.rds   satellite accounts of final demand (5 982 x 984), sparse
#   L.f32    Leontief inverse (19 680 x 19 680), float32 (see R/functions_io.R)
#   LY.f32   L %*% Y (19 680 x 984): output needed for each final demand column
#   M.rds    total multipliers of all catalogue indicators (n_cat x 19 680)
#   E.rds    gross exports by partner region (19 680 x 164)
#   checks.csv  plausibility checks (balances, min of L, ...)
#   _DONE    marker file: the year is complete
#
# Method (same as the original GLORIA-MRIO_Parser):
#   - Z is the use block of the SUT (products of region r used by industries
#     of region s). Products and industries both have 120 sectors and supply
#     in GLORIA is (close to) diagonal, so Z can be treated as a square
#     sector-by-sector matrix.
#   - x = row sums of Z + row sums of Y (gross output by product)
#   - A = Z %*% diag(1/x)      technical coefficients
#   - L = (I - A)^-1           Leontief inverse
# =============================================================================

# -----------------------------------------------------------------------------
# Make sure the raw csv files of one year are available (unzip if needed)
# -----------------------------------------------------------------------------
# Returns the folder in which the csv files of `year` can be found.
#
# GLORIA releases are distributed as big zip archives ("parts"), which may
# contain csv files of all years directly or one zip per year. To save disk
# space we never unpack a whole archive. Instead we
#   1) look at the list of files inside each archive (cheap),
#   2) extract only the 5 csv files of the requested year, or the inner zip
#      of that year (which is then treated the same way).
# We use the `tar` tool that ships with Windows 10+ (and Linux/macOS) because
# R's own unzip() cannot handle zip files larger than 4 GB.

# The five raw tables needed per year (see header of this file)
raw_csv_pattern <- function(year) {
  sprintf("_(T|Y|V|TQ|YQ)-Results_%d_0%d_Markup001.*\\.csv$", year, gloria_version)
}

# On Windows use the built-in tar.exe (bsdtar, reads zip files). Other "tar"
# programs on the PATH (e.g. from Git or Rtools) are GNU tar and cannot read zip.
tar_exe <- function() {
  if (.Platform$OS.type == "windows") {
    w <- file.path(Sys.getenv("SystemRoot", "C:/Windows"), "System32", "tar.exe")
    if (file.exists(w)) return(w)
  }
  "tar"
}

.zip_list_cache <- new.env()
zip_contents <- function(zip) {
  key <- normalizePath(zip)
  if (is.null(.zip_list_cache[[key]])) {
    .zip_list_cache[[key]] <- system2(tar_exe(), c("-tf", shQuote(zip)), stdout = TRUE)
  }
  .zip_list_cache[[key]]
}

prepare_year_files <- function(year) {
  out <- file.path(paths$unzip_tmp, year)
  pat <- raw_csv_pattern(year)
  n_found <- function(dir) {
    if (!dir.exists(dir)) return(0L)
    f <- list.files(dir, pattern = "\\.csv$", recursive = TRUE)
    length(unique(sub(".*_(T|Y|V|TQ|YQ)-Results_.*", "\\1", basename(f[grepl(pat, basename(f))]))))
  }
  # Case 1: the user has already unzipped everything into the raw folder
  if (n_found(paths$raw) == 5) return(paths$raw)

  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  year_token <- sprintf("(^|[^0-9])%d([^0-9]|$)", year)
  done_zips <- character(0)
  # Case 2: extract what is needed from the zip archives (repeat for inner zips)
  repeat {
    zips <- c(list.files(paths$raw, "\\.zip$", recursive = TRUE, full.names = TRUE),
              list.files(out, "\\.zip$", recursive = TRUE, full.names = TRUE))
    zips <- setdiff(zips, done_zips)
    if (length(zips) == 0 || n_found(out) == 5) break
    for (z in zips) {
      entries <- zip_contents(z)
      want <- entries[grepl(pat, basename(entries)) |
                        (grepl("\\.zip$", entries) & grepl(year_token, basename(entries)))]
      if (length(want) > 0) {
        log_msg("  extracting ", length(want), " file(s) for ", year, " from ", basename(z))
        res <- system2(tar_exe(), c("-xf", shQuote(z), "-C", shQuote(out), shQuote(want)))
        if (res != 0) stop("Unzipping failed: ", z)
      }
      done_zips <- c(done_zips, z)
    }
  }
  if (n_found(out) < 5) {
    stop("Could not find all 5 raw tables (T, Y, V, TQ, YQ) for ", year,
         " in ", paths$raw, ". Is the download complete?")
  }
  out
}

# Years for which raw data are available (from file names inside the archives)
detect_raw_years <- function() {
  zips <- list.files(paths$raw, "\\.zip$", recursive = TRUE, full.names = TRUE)
  csvs <- list.files(paths$raw, "\\.csv$", recursive = TRUE)
  names <- c(basename(csvs), unlist(lapply(zips, function(z) basename(zip_contents(z)))))
  m <- regmatches(names, regexpr(sprintf("_T-Results_\\d{4}_0%d", gloria_version), names))
  sort(unique(as.integer(substr(m, 12, 15))))
}

# -----------------------------------------------------------------------------
# Main function
# -----------------------------------------------------------------------------
parse_year <- function(year, meta, logfile = NULL) {
  out_dir <- file.path(paths$parsed, year)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  t0 <- Sys.time()
  L_ <- function(...) log_msg(year, ": ", ..., file = logfile)

  src <- prepare_year_files(year)
  ind <- meta$raw_index$ind      # columns/rows of industries in the raw SUT
  pro <- meta$raw_index$pro      # columns/rows of products in the raw SUT
  ver <- gloria_version

  # --- 1) Inter-industry flows Z (products x industries) --------------------------
  L_("reading T (transaction matrix)")
  Z <- read_gloria_csv(find_raw_file(src, "T", year, ver), rows = pro, cols = ind)

  # --- 2) Final demand Y (products x final demand categories) ------------------------
  L_("reading Y (final demand)")
  Y <- read_gloria_csv(find_raw_file(src, "Y", year, ver), rows = pro)

  # --- 3) Value added V (components x industries) --------------------------------------
  # The raw V matrix has one row per region and VA component (164 x 6). As
  # VA of region r only appears in the columns of region r, we can sum the
  # rows over regions and keep 6 rows (one per VA component).
  L_("reading V (value added)")
  V_raw <- read_gloria_csv(find_raw_file(src, "V", year, ver), cols = ind)
  if (nrow(V_raw) == meta$n$reg * nrow(meta$va)) {
    V <- agg_rows(V_raw, rep(meta$va$va_code, times = meta$n$reg), levels = meta$va$va_code)
  } else {
    V <- V_raw
  }
  rownames(V) <- meta$va$va_name
  rm(V_raw)

  # --- 4) Satellite accounts ------------------------------------------------------------
  L_("reading TQ and YQ (satellite accounts)")
  Q  <- Matrix(read_gloria_csv(find_raw_file(src, "TQ", year, ver), cols = ind), sparse = TRUE)
  QY <- Matrix(read_gloria_csv(find_raw_file(src, "YQ", year, ver)), sparse = TRUE)

  # --- 5) Gross output and balance check ----------------------------------------------
  x <- rowSums(Z) + rowSums(Y)                  # output by product (row view)
  x_ind <- colSums(Z) + colSums(V)              # output by industry (column view)

  # --- 6) Gross exports by partner region ----------------------------------------------
  # E[i, p] = everything sector i (of region r) delivers to region p != r,
  # as intermediate input (Z) or final product (Y).
  reg_of_Zcol <- meta$idx_Z$region_code
  reg_of_Ycol <- meta$idx_Y$region_code
  E <- agg_cols(Z, reg_of_Zcol, meta$regions$region_code) +
       agg_cols(Y, reg_of_Ycol, meta$regions$region_code)
  own <- cbind(seq_len(nrow(E)), match(meta$idx_Z$region_code, meta$regions$region_code))
  E[own] <- 0

  # Save the basic variables now (frees memory before the inversion)
  L_("saving Z, Y, V, x, Q, QY, E")
  saveRDS(Matrix(Z, sparse = TRUE), file.path(out_dir, "Z.rds"))
  saveRDS(Y,  file.path(out_dir, "Y.rds"))
  saveRDS(V,  file.path(out_dir, "V.rds"))
  saveRDS(x,  file.path(out_dir, "x.rds"))
  saveRDS(Q,  file.path(out_dir, "Q.rds"))
  saveRDS(QY, file.path(out_dir, "QY.rds"))
  saveRDS(E,  file.path(out_dir, "E.rds"))

  # --- 7) Technical coefficients and Leontief inverse ---------------------------------
  # A = Z / x (column-wise). Sectors without output (x = 0) get coefficients 0.
  L_("computing A and L = (I - A)^-1")
  xinv <- ifelse(x > 0, 1 / x, 0)
  # Build I - A in place to keep memory low (Z becomes I - A)
  for (j in seq_len(ncol(Z))) Z[, j] <- -Z[, j] * xinv[j]
  diag(Z) <- diag(Z) + 1
  L <- solve(Z)
  rm(Z); gc(verbose = FALSE)

  # --- 8) Pre-computed products for the app --------------------------------------------
  L_("computing LY and catalogue multipliers")
  LY <- L %*% Y                                  # output triggered by each fd column

  # Direct intensities (pressure per unit of output) of all catalogue
  # indicators, then total multipliers M = S %*% L
  cat_tab <- meta$catalogue
  S <- t(vapply(seq_len(nrow(cat_tab)), function(k) {
    r <- cat_tab$rows[[k]]
    v <- if (cat_tab$source[k] == "VA") colSums(V[r, , drop = FALSE]) else colSums(Q[r, , drop = FALSE])
    v * xinv
  }, numeric(ncol(L))))
  rownames(S) <- cat_tab$id
  M <- S %*% L
  saveRDS(M, file.path(out_dir, "M.rds"))
  write_f32(LY, file.path(out_dir, "LY.f32"))
  if (isTRUE(parser_options$store_L)) {
    L_("saving L (float32)")
    write_f32(L, file.path(out_dir, "L.f32"))
  }

  # --- 9) Plausibility checks -----------------------------------------------------------
  checks <- data.table(
    year = year,
    total_output = sum(x),
    max_rel_diff_output_row_vs_col = max(abs(x - x_ind) / pmax(x, 1)),
    output_reproduced_by_L = sum(LY) / sum(x),      # should be 1
    min_L = min(L),
    n_negative_Y = sum(Y < 0),
    seconds = as.numeric(difftime(Sys.time(), t0, units = "secs"))
  )
  fwrite(checks, file.path(out_dir, "checks.csv"))
  rm(L, LY); gc(verbose = FALSE)

  # --- 10) Clean up ----------------------------------------------------------------------
  if (isTRUE(parser_options$delete_unzipped) && src != paths$raw) {
    unlink(src, recursive = TRUE)
  }
  file.create(file.path(out_dir, "_DONE"))
  L_(sprintf("done in %.1f min", checks$seconds / 60))
  invisible(checks)
}
