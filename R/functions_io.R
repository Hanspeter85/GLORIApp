# =============================================================================
# R/functions_io.R  -  Helper functions for reading, writing and aggregating
# =============================================================================
# Loaded by the parser (parser/*.R) AND by the app (app/app.R).
# Only depends on base R, data.table and Matrix.
# =============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(Matrix)
})

# -----------------------------------------------------------------------------
# float32 binary format for big dense matrices (mainly the Leontief inverse L)
# -----------------------------------------------------------------------------
# R stores numbers as 8-byte doubles. L has 19 680 x 19 680 entries, i.e.
# 3.1 GB as double. Saved as 4-byte float it needs 1.55 GB, with ~7 significant
# digits of precision (more than enough for input-output analysis).
#
# File layout:  "GLF4" (4 bytes) | nrow (int32) | ncol (int32) | data column-wise
# The file can also be read in Python:
#   np.fromfile(f, dtype="<f4", offset=12).reshape((ncol, nrow)).T
# -----------------------------------------------------------------------------

write_f32 <- function(m, file) {
  stopifnot(is.matrix(m))
  con <- file(file, "wb")
  on.exit(close(con))
  writeBin(charToRaw("GLF4"), con)
  writeBin(as.integer(dim(m)), con, size = 4, endian = "little")
  # Write in column blocks so that as.vector() never copies the whole matrix
  step <- max(1L, floor(5e7 / nrow(m)))
  for (j in seq(1L, ncol(m), by = step)) {
    jj <- j:min(ncol(m), j + step - 1L)
    writeBin(as.vector(m[, jj]), con, size = 4, endian = "little")
  }
  invisible(file)
}

read_f32 <- function(file) {
  con <- file(file, "rb")
  on.exit(close(con))
  magic <- rawToChar(readBin(con, "raw", 4))
  if (magic != "GLF4") stop("Not a valid GLF4 file: ", file)
  d <- readBin(con, "integer", 2, size = 4, endian = "little")
  x <- readBin(con, "double", n = d[1] * d[2], size = 4, endian = "little")
  dim(x) <- d
  x
}

# -----------------------------------------------------------------------------
# Locate raw files
# -----------------------------------------------------------------------------
# GLORIA file names look like this:
#   20240111_120secMother_AllCountries_002_T-Results_2019_060_Markup001(full).csv
# We search robustly with a pattern made of variable type, year and version.
find_raw_file <- function(dir, type, year, version, markup = "Markup001") {
  pat <- sprintf("_%s-Results_%d_0%d_%s", type, year, version, markup)
  f <- list.files(dir, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)
  hit <- f[grepl(pat, basename(f), fixed = TRUE)]
  if (length(hit) == 0) {
    stop(sprintf("No raw file for %s / %d found (pattern '%s') in %s",
                 type, year, pat, dir))
  }
  if (length(hit) > 1) {
    # If there are several hits prefer the "(full)" variant
    full <- hit[grepl("full", hit, fixed = TRUE)]
    hit <- if (length(full) > 0) full[1] else hit[1]
  }
  hit
}

# -----------------------------------------------------------------------------
# Read a GLORIA csv file into a numeric matrix
# -----------------------------------------------------------------------------
# GLORIA csv files have no header and no row names. `cols` reads only the
# needed columns (halves the memory for the 39 360 x 39 360 T matrix), `rows`
# keeps only selected rows afterwards.
read_gloria_csv <- function(file, rows = NULL, cols = NULL) {
  dt <- fread(file, header = FALSE, select = cols, showProgress = FALSE)
  nr <- if (is.null(rows)) nrow(dt) else length(rows)
  m <- matrix(0, nrow = nr, ncol = ncol(dt))
  # Copy column by column starting from the last one and delete each column
  # from the table right away: a second full copy never exists in memory.
  for (k in rev(seq_len(ncol(dt)))) {
    v <- dt[[k]]
    m[, k] <- if (is.null(rows)) v else v[rows]
    set(dt, j = k, value = NULL)
  }
  rm(dt); gc(verbose = FALSE)
  m
}

# -----------------------------------------------------------------------------
# Aggregation
# -----------------------------------------------------------------------------
# An aggregation matrix G (n x k) has a 1 in row i in the column of the group
# that element i belongs to. Then:
#   aggregate rows:     t(G) %*% M
#   aggregate columns:  M %*% G
# G is built as a sparse matrix, which is small and fast.
agg_matrix <- function(key, levels = NULL) {
  key <- as.character(key)
  if (is.null(levels)) levels <- unique(key)
  j <- match(key, levels)
  if (anyNA(j)) stop("Aggregation key contains values that are not in 'levels'.")
  sparseMatrix(i = seq_along(key), j = j, x = 1,
               dims = c(length(key), length(levels)),
               dimnames = list(NULL, levels))
}

# Sum the rows of a (dense or sparse) matrix by key
agg_rows <- function(m, key, levels = NULL) {
  G <- agg_matrix(key, levels)
  as.matrix(crossprod(G, m))
}

# Sum the columns of a matrix by key
agg_cols <- function(m, key, levels = NULL) {
  G <- agg_matrix(key, levels)
  as.matrix(m %*% G)
}

# Small logging helper: prints to the console and (optionally) to a file
log_msg <- function(..., file = NULL) {
  msg <- sprintf("[%s] %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), paste0(...))
  message(msg)
  if (!is.null(file)) cat(msg, "\n", file = file, append = TRUE)
  invisible(msg)
}
