# =============================================================================
# R/texts.R  -  All explanatory texts shown in the app
# =============================================================================
# Kept in one place so that wording can be improved without touching the app
# logic. Plain language for non-experts on purpose.
# =============================================================================

result_type_choices <- c(
  "Footprint (consumption-based)"                   = "footprint",
  "Overview: production- vs. consumption-based"     = "overview",
  "Production-based (territorial) account"          = "production"
)
result_type_expert <- c(
  "Expert: embodied in gross exports (OECD TiVA style)" = "exports"
)

result_type_help <- list(
  footprint = paste(
    "Everything that final demand causes along the whole global supply chain.",
    "Works the same for every indicator: materials, emissions, land, jobs or value added",
    "(the value-added footprint is the 'trade in value added' of final demand).",
    "In step 4 you choose how to split it: where the pressure occurs, which final",
    "products are bought, and who buys them."),
  overview = paste(
    "One line per region with three numbers: production-based (what happens inside the",
    "region), consumption-based (footprint of its final demand) and the difference",
    "(net imports; positive = the region relies on pressures in other regions)."),
  production = paste(
    "Pressure where it physically happens (territorial principle), e.g. emissions of all",
    "factories, farms and households located in a country. This is what national",
    "inventories usually report."),
  exports = paste(
    "EXPERT. Indicator embodied in a country's GROSS exports (all exports, including",
    "intermediate goods), split into domestic and foreign origin - the classic OECD TiVA",
    "view. Goods that cross borders several times are counted more than once, so the",
    "numbers are larger than footprints. For 'who causes what' use the footprint.")
)

# Headings of the three breakdown blocks in step 4, per result type
dimension_labels <- list(
  footprint  = c(origin = "Where the pressure occurs (origin)",
                 product = "What is bought (final product)",
                 consumer = "Who buys (consumer)"),
  overview   = c(origin = "Regions", product = "", consumer = ""),
  production = c(origin = "Where the pressure occurs", product = "", consumer = ""),
  exports    = c(origin = "Where the embodied value/pressure originates",
                 product = "Exporting country and exporting sector",
                 consumer = "Partner (importing) country")
)

output_format_choices <- c(
  "Long format: one value per row (ready for pivot tables in Excel, R, Python)" = "long",
  "Wide format: cross table with one column per year or indicator" = "wide"
)

help_texts <- list(
  indicators = paste(
    "Value added (theme 'Value added') is an indicator like any other: its footprint",
    "shows where the income behind a country's consumption is earned."),
  expert = paste(
    "Any of the raw GLORIA satellite rows (e.g. a single gas from a single emission",
    "source). Some calculations with these rows are slower because the full Leontief",
    "inverse (1.5 GB per year) has to be loaded."),
  years = paste(
    "1990-2029. Years after the latest available statistics (roughly 2023+) are",
    "nowcasts/projections of the GLORIA team and should be interpreted with care."),
  breakdown = paste(
    "Choose for each dimension how to group regions and sectors.",
    "'Do not split (total)' leaves that dimension out of the table.",
    "Typical: origin by region (+ sector) OR final product by sector, plus the consumer."),
  detail = paste(
    "Origin AND final product are split: very detailed from-to table. This needs the",
    "full Leontief inverse and takes roughly 10-60 seconds per year and indicator."),
  fd = paste(
    "Final demand = households, non-profit institutions, government, investment (gross",
    "fixed capital formation), changes in inventories, valuables. Footprints usually",
    "include all six categories. Direct household emissions are not caused by any",
    "industry; if ticked they are added where the households live."),
  own_groups = paste(
    "Define your own groups of regions (e.g. EU27) or sectors (e.g. Food). They appear as",
    "'Own grouping (step 6)' in all drop-downs of step 4. Everything not assigned goes into",
    "the 'other' group named below. Save the groupings as csv to reuse them next time.")
)

# -----------------------------------------------------------------------------
# Plain-language description of the current settings
# -----------------------------------------------------------------------------
describe_spec <- function(sp, meta) {
  if (length(sp$indicators) == 0 || length(sp$years) == 0) {
    return(div(class = "alert alert-warning", "Choose indicators and years in the sidebar, then click 'Calculate'."))
  }
  ind <- vapply(sp$indicators, function(i) indicator_info(i, meta)$label, "")
  yrs <- if (length(sp$years) > 4) sprintf("%d years (%d-%d)", length(sp$years), min(sp$years), max(sp$years))
         else paste(sort(sp$years), collapse = ", ")
  fd <- if (length(sp$fd_codes) == nrow(meta$fd)) "all final demand categories"
        else paste(meta$fd$fd_name[meta$fd$fd_code %in% sp$fd_codes], collapse = ", ")
  dim_txt <- function(reg, sec) {
    parts <- c(if (!identical(reg, "none")) nice_name(reg), if (!identical(sec, "none")) nice_name(sec))
    if (length(parts) == 0) "not split" else paste(parts, collapse = " x ")
  }
  txt <- switch(sp$type,
    footprint = sprintf("Footprint of %s. Origin: %s. Final product: %s. Consumer: %s%s.",
                        fd, dim_txt(sp$origin_region, sp$origin_sector),
                        dim_txt(sp$product_region, sp$product_sector),
                        nice_name(sp$consumer_region), if (isTRUE(sp$by_fd)) " x final demand category" else ""),
    overview = sprintf("Production-based vs. consumption-based totals per region (%s).",
                       dim_txt(sp$origin_region, "none")),
    production = sprintf("Production-based (territorial) totals by %s.",
                         dim_txt(sp$origin_region, sp$origin_sector)),
    exports = sprintf("Embodied in gross exports: exporter (%s) to partner (%s), domestic/foreign origin%s.",
                      dim_txt(sp$product_region, sp$product_sector), nice_name(sp$consumer_region),
                      if (!identical(sp$origin_region, "none")) paste0(" by ", nice_name(sp$origin_region)) else "")
  )
  div(class = "alert alert-light",
      tags$b("You are about to calculate: "), txt, tags$br(),
      tags$b("Indicators: "), paste(ind, collapse = "; "), tags$br(),
      tags$b("Years: "), yrs)
}
