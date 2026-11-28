# Copyright (c) 2026 Hanspeter Wieland - PolyForm Noncommercial License 1.0.0 (see LICENSE, NOTICE.md)
# =============================================================================
# parser/02_build_meta.R  -  Labels, index tables and indicator catalogue
# =============================================================================
# Creates  <parsed>/meta/meta.rds , a list that parser and app share:
#   $regions, $sectors        concordance tables (from input/concordances)
#   $fd, $va                  names of the 6 final demand / value added categories
#   $satellites               all GLORIA satellite rows (Lfd_Nr, head, indicator, unit)
#   $idx_Z                    labels of the 19 680 rows/cols of Z, A, L (region x sector)
#   $idx_Y                    labels of the 984 columns of Y (region x fd category)
#   $catalogue                recommended indicators ("presets") incl. the
#                             satellite rows that are summed for each of them
#   $raw_index                positions of industries/products in the raw
#                             39 360 x 39 360 supply-use (SUT) layout
# =============================================================================

build_meta <- function() {
  suppressPackageStartupMessages(library(openxlsx))

  readme <- file.path(paths$input, sprintf("GLORIA_ReadMe_0%d.xlsx", gloria_version))
  if (!file.exists(readme)) {
    readme <- tail(sort(list.files(paths$input, "^GLORIA_ReadMe_0\\d+\\.xlsx$", full.names = TRUE)), 1)
    warning("ReadMe for v", gloria_version, " missing, using ", readme)
  }

  regions <- fread(file.path(paths$input, "concordances", "regions.csv"))
  sectors <- fread(file.path(paths$input, "concordances", "sectors.csv"))
  n_reg <- nrow(regions); n_sec <- nrow(sectors)

  fdva <- as.data.table(read.xlsx(readme, sheet = "Value added and final demand"))
  fd <- data.table(fd_code = fdva$Lfd_Nr, fd_name = fdva$Final_demand_names)
  va <- data.table(va_code = fdva$Lfd_Nr, va_name = fdva$Value_added_names)
  n_fd <- nrow(fd)

  sat <- as.data.table(read.xlsx(readme, sheet = "Satellites"))
  setnames(sat, c("sat_code", "head", "indicator", "unit"))
  # Indicator names in the ReadMe are partly wrapped in single quotes -> remove
  sat[, indicator := gsub("^'|'$", "", indicator)]

  # --- Labels for the parsed matrices -------------------------------------------
  # Order in GLORIA: region 1 (sectors 1..120), region 2 (sectors 1..120), ...
  idx_Z <- data.table(
    index        = seq_len(n_reg * n_sec),
    region_code  = rep(regions$region_code, each = n_sec),
    sector_code  = rep(sectors$sector_code, times = n_reg)
  )
  idx_Y <- data.table(
    index        = seq_len(n_reg * n_fd),
    region_code  = rep(regions$region_code, each = n_fd),
    fd_code      = rep(fd$fd_code, times = n_reg)
  )

  # --- Positions in the raw SUT layout ---------------------------------------------
  # Each region block in the raw T matrix has 120 industry rows/cols followed
  # by 120 product rows/cols ("MR-SUT structure" sheet of the ReadMe).
  block <- rep(c("industry", "product"), each = n_sec)
  raw_type <- rep(block, times = n_reg)
  raw_index <- list(ind = which(raw_type == "industry"),
                    pro = which(raw_type == "product"))

  # --- Indicator catalogue -----------------------------------------------------------
  # Each preset sums all satellite rows with the given `head` whose indicator
  # name matches `pattern` (regular expression). Optional `material_group`
  # uses input/concordance_material_groups.xlsx. Value added presets
  # (head = VALUE_ADDED) select rows of the VA matrix instead.
  cat_tab <- fread(file.path(paths$input, "indicator_catalogue.csv"), encoding = "UTF-8")
  matgrp <- as.data.table(read.xlsx(file.path(paths$input, "concordance_material_groups.xlsx")))
  setnames(matgrp, c("sat_code", "indicator", "material_group"))

  cat_tab[, rows := lapply(seq_len(.N), function(i) {
    r <- cat_tab[i]
    if (r$head == "VALUE_ADDED") {
      return(va[grepl(r$pattern, va_name), va_code])
    }
    cand <- sat[head == r$head & grepl(r$pattern, indicator)]
    if (!is.na(r$material_group) && nzchar(r$material_group)) {
      cand <- cand[indicator %in% matgrp[material_group == r$material_group, indicator]]
    }
    cand$sat_code
  })]
  cat_tab[, source := fifelse(head == "VALUE_ADDED", "VA", "Q")]
  empty <- cat_tab[lengths(rows) == 0, id]
  if (length(empty) > 0) {
    warning("Catalogue entries without matching rows (check names in the ReadMe): ",
            paste(empty, collapse = ", "))
  }

  meta <- list(version = gloria_version, years = gloria_years,
               regions = regions, sectors = sectors, fd = fd, va = va,
               satellites = sat, idx_Z = idx_Z, idx_Y = idx_Y,
               catalogue = cat_tab, raw_index = raw_index,
               n = list(reg = n_reg, sec = n_sec, fd = n_fd, rs = n_reg * n_sec))

  dir.create(paths$meta, recursive = TRUE, showWarnings = FALSE)
  saveRDS(meta, file.path(paths$meta, "meta.rds"))
  invisible(meta)
}
