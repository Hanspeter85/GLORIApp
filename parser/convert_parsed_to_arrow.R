# =============================================================================
# parser/convert_parsed_to_arrow.R  -  One-off migration of older parsed data
# =============================================================================
# Earlier parser versions (Nov 2026) stored L and Z in a custom float32 format
# (*.f32) and additionally pre-computed products (LY.f32, M.rds, E.rds).
# The current version stores only the standard matrices, with L and Z as Arrow
# files (*.arrow, much faster to read). This script converts existing years in
# place and removes the pre-computed products. Safe to run several times.
#   source("parser/convert_parsed_to_arrow.R")
# =============================================================================
source("config.R")
source("R/functions_io.R")

years <- sort(suppressWarnings(as.integer(list.dirs(paths$parsed, full.names = FALSE, recursive = FALSE))))
for (y in years[!is.na(years)]) {
  d <- file.path(paths$parsed, y)
  for (nm in c("L", "Z")) {
    old <- file.path(d, paste0(nm, ".f32")); new <- file.path(d, paste0(nm, ".arrow"))
    if (file.exists(old)) {
      write_matrix(read_f32(old), new)
      # only delete the old file if the new one reads back with the right size
      chk <- read_matrix(new)
      if (all(dim(chk) == c(19680L, 19680L)) || nrow(chk) > 0) unlink(old)
      rm(chk); gc(verbose = FALSE)
    }
  }
  unlink(file.path(d, c("LY.f32", "M.rds", "E.rds")))
  log_msg(y, ": converted")
}
log_msg("Conversion finished.")
