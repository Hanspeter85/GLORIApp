# =============================================================================
# R/texts.R  -  All explanatory texts shown in the app
# =============================================================================
# Kept in one place so that wording can be improved without touching the app
# logic. Plain language for non-experts on purpose.
# =============================================================================

result_type_choices <- c(
  "Footprint: where the pressure happens (from-to)" = "footprint_origin",
  "Footprint: by final product bought"              = "footprint_product",
  "Overview: production- vs. consumption-based"     = "overview",
  "Production-based (territorial) account"          = "production",
  "Trade in value added / embodied in exports (TiVA)" = "tiva"
)

result_type_help <- list(
  footprint_origin = paste(
    "Consumption-based footprint. Answers: 'Final demand of country B causes how much",
    "pressure in country A (and in which sector)?'. Example: CO2 emitted in Chinese power",
    "plants because of products bought by Austrian households. The sum over all origins",
    "is the footprint of the consumer region."),
  footprint_product = paste(
    "Consumption-based footprint split by the FINAL products that are bought (e.g. food,",
    "cars, construction). Each product carries all pressures of its whole supply chain.",
    "The sum over all products equals the footprint of the consumer region."),
  overview = paste(
    "One line per region with three numbers: production-based (what happens inside the",
    "region), consumption-based (footprint of its final demand) and the difference",
    "(net imports; positive = the region outsources pressure to other regions)."),
  production = paste(
    "Pressure where it physically happens (territorial principle), e.g. emissions of all",
    "factories, farms and households located in a country. This is what national",
    "inventories usually report."),
  tiva = paste(
    "Value added (or another indicator) embodied in GROSS exports, split into domestic",
    "and foreign origin. With 'Value added' this is the classic Trade in Value Added",
    "(TiVA) indicator, e.g. how much of German car exports is value created in Germany",
    "vs. in its suppliers abroad. Note: based on gross exports, so some value is counted",
    "more than once when goods cross several borders.")
)

help_texts <- list(
  expert = paste(
    "Any of the 5 982 raw GLORIA satellite rows (e.g. a single gas from a single emission",
    "source). Calculations with these rows are slower because the full Leontief inverse",
    "(1.5 GB per year) has to be loaded for some result types."),
  years = paste(
    "1990-2029. Years after the latest available statistics are nowcasts/projections of",
    "the GLORIA team and should be interpreted with care."),
  regions = paste(
    "Own grouping: a csv file with the columns 'region_acronym' and 'group' (e.g. EU27,",
    "Rest of world). Start from the template below."),
  fd = paste(
    "Final demand = households, non-profit institutions, government, investment (gross",
    "fixed capital formation), changes in inventories, acquisitions less disposals of",
    "valuables. Footprints usually include all six categories.")
)

# -----------------------------------------------------------------------------
# Plain-language description of the current settings
# -----------------------------------------------------------------------------
describe_spec <- function(sp, meta) {
  if (length(sp$indicators) == 0 || length(sp$years) == 0) {
    return(div(class = "alert alert-warning", "Choose indicators and years in the sidebar, then click 'Calculate'."))
  }
  ind <- vapply(sp$indicators, function(i) indicator_info(i, meta)$label, "")
  reg_name <- function(col) nice_name(col)
  yrs <- if (length(sp$years) > 4) sprintf("%d years (%d-%d)", length(sp$years), min(sp$years), max(sp$years))
         else paste(sort(sp$years), collapse = ", ")
  fd <- if (length(sp$fd_codes) == nrow(meta$fd)) "all final demand categories"
        else paste(meta$fd$fd_name[meta$fd$fd_code %in% sp$fd_codes], collapse = ", ")
  txt <- switch(sp$type,
    footprint_origin = sprintf("Footprint of %s, shown by origin (%s%s) and consumer (%s).",
                               fd, reg_name(sp$region_from),
                               if (sp$by_sector) paste0(" x ", nice_name(sp$sector_col)) else "",
                               reg_name(sp$region_to)),
    footprint_product = sprintf("Footprint of %s, shown by final product (%s%s) and consumer (%s).",
                                fd, reg_name(sp$region_from),
                                if (sp$by_sector) paste0(" x ", nice_name(sp$sector_col)) else "",
                                reg_name(sp$region_to)),
    overview = sprintf("Production-based vs. consumption-based totals per region (%s).",
                       reg_name(sp$region_from)),
    production = sprintf("Production-based (territorial) totals per region (%s)%s.",
                         reg_name(sp$region_from),
                         if (sp$by_sector) paste0(" and sector (", nice_name(sp$sector_col), ")") else ""),
    tiva = sprintf("Indicator embodied in gross exports: exporter (%s) to partner (%s), split into domestic/foreign origin%s.",
                   reg_name(sp$region_from), reg_name(sp$region_to),
                   if (sp$by_sector) paste0(", by exporting sector (", nice_name(sp$sector_col), ")") else "")
  )
  div(class = "alert alert-light",
      tags$b("You are about to calculate: "), txt, tags$br(),
      tags$b("Indicators: "), paste(ind, collapse = "; "), tags$br(),
      tags$b("Years: "), yrs)
}
