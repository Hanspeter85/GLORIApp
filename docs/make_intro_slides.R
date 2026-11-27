# =============================================================================
# docs/make_intro_slides.R  -  Builds docs/GLORIApp_intro.pptx
# =============================================================================
# Slides for the introduction session (see docs/intro_session.md). All example
# numbers are calculated live with the engine, so re-running this script after
# a GLORIA update refreshes the deck. Run from the repo root:
#   source("docs/make_intro_slides.R")
# Needs the packages officer and mschart.
# =============================================================================

suppressPackageStartupMessages({ library(officer); library(mschart); library(data.table) })
source("config.R"); source("R/functions_io.R"); source("R/engine.R")
meta <- readRDS(file.path(paths$meta, "meta.rds"))
meta$regions <- fread("input/concordances/regions.csv")
meta$sectors <- fread("input/concordances/sectors.csv")
yr <- 2019   # example year (latest year before the pandemic with full statistics)

# -----------------------------------------------------------------------------
# 1) Example numbers
# -----------------------------------------------------------------------------
base <- list(region_from = "region_name", region_to = "region_name", sector_col = "broad_sector",
             by_sector = FALSE, by_fd = FALSE, fd_codes = 1:6, include_direct_fd = TRUE)
fo  <- run_calculation(modifyList(base, list(type = "footprint_origin", indicators = "ghg_edgar",
                                             years = yr, region_from = "world_region_7")), meta)
aut <- fo[to_region == "Austria", .(region = from_region, Mt = value / 1000)][order(-Mt)]
pr  <- run_calculation(modifyList(base, list(type = "production", indicators = "ghg_edgar", years = yr)), meta)
aut_pba <- pr[region == "Austria", sum(value)] / 1000
aut_fp  <- sum(aut$Mt)
world_ghg <- sum(pr$value) / 1e6
ov <- run_calculation(modifyList(base, list(type = "overview", indicators = c("ghg_edgar", "mat_total"),
                                            years = c(2000, yr), region_from = "income_group_worldbank")), meta)
ov <- ov[account == "net_imports" & region != "Rest-of-world regions (mixed)"]
tv <- run_calculation(modifyList(base, list(type = "tiva", indicators = "va_total", years = yr,
                                            by_sector = TRUE, region_to = "world")), meta)
deu <- tv[exporter == "Germany" & export_sector == "Manufacturing"]
deu_fva <- deu[origin_type == "foreign", sum(value)] / sum(deu$value)

# -----------------------------------------------------------------------------
# 2) Design: 16:9 canvas, palette, fonts
# -----------------------------------------------------------------------------
# officer's default template is 4:3; we copy it and switch the slide size.
tmpl <- tempfile(fileext = ".pptx"); tdir <- tempfile()
unzip(system.file("template/template.pptx", package = "officer"), exdir = tdir)
pf <- file.path(tdir, "ppt", "presentation.xml")
xml <- readLines(pf, warn = FALSE)
xml <- gsub('<p:sldSz cx="[0-9]+" cy="[0-9]+"[^/]*/>', '<p:sldSz cx="12192000" cy="6858000"/>', xml)
writeLines(xml, pf)
# re-zip with the zip package (installed together with officer)
zip::zip(tmpl, files = list.files(tdir, recursive = TRUE, all.files = TRUE), root = tdir)

W <- 13.333; H <- 7.5
col <- list(dark = "#1F3B2D", green = "#3E7A4F", moss = "#8DB46A", amber = "#E0A030",
            light = "#EEF4EC", text = "#1E2A22", muted = "#5D6B62", white = "#FFFFFF")
HEAD <- "Cambria"; BODY <- "Calibri"

tx <- function(txt, size = 16, color = col$text, bold = FALSE, font = BODY, italic = FALSE) {
  ftext(txt, fp_text(font.size = size, color = color, bold = bold, font.family = font, italic = italic))
}
par <- function(..., align = "left") fpar(..., fp_p = fp_par(text.align = align, padding.bottom = 4))
loc <- function(l, t, w, h, bg = NULL, geom = NULL, label = NULL) {
  # a fill colour needs a shape geometry, otherwise PowerPoint ignores it
  if (!is.null(bg) && is.null(geom)) geom <- "rect"
  ph_location(left = l, top = t, width = w, height = h, bg = bg, geom = geom,
              newlabel = label)
}
add_text <- function(doc, l, t, w, h, ..., bg = NULL, geom = NULL, label = NULL) {
  ph_with(doc, block_list(...), location = loc(l, t, w, h, bg, geom, label))
}
title <- function(doc, txt, sub = NULL, dark = FALSE) {
  doc <- add_text(doc, 0.6, 0.45, W - 1.2, 0.9,
                  par(tx(txt, 30, if (dark) col$white else col$dark, TRUE, HEAD)), label = "Title")
  if (!is.null(sub)) doc <- add_text(doc, 0.6, 1.3, W - 1.2, 0.5,
                                     par(tx(sub, 16, if (dark) col$moss else col$muted, italic = TRUE)), label = "Subtitle")
  doc
}
new_slide <- function(doc, dark = FALSE) {
  doc <- add_slide(doc, layout = "Blank", master = "Office Theme")
  ph_with(doc, empty_content(), location = loc(0, 0, W, H, bg = if (dark) col$dark else col$white, geom = "rect", label = "Background"))
}
# Big number with a small label below
stat <- function(doc, l, t, w, num, label, color = col$green) {
  doc <- add_text(doc, l, t, w, 1.0, par(tx(num, 48, color, TRUE, HEAD)), label = paste("Stat", label))
  add_text(doc, l, t + 1.0, w, 0.8, par(tx(label, 14, col$muted)), label = paste("Stat label", label))
}
# Numbered circle + heading + text (used for steps)
step <- function(doc, l, t, w, n, head, body) {
  doc <- add_text(doc, l, t, 0.6, 0.6, par(tx(as.character(n), 18, col$white, TRUE), align = "center"),
                  bg = col$green, geom = "ellipse", label = paste("Step", n))
  add_text(doc, l + 0.75, t - 0.05, w - 0.75, 1.1,
           par(tx(head, 17, col$dark, TRUE)), par(tx(body, 14, col$muted)), label = paste("Step text", n))
}
fmt <- function(x, d = 0) formatC(x, format = "f", digits = d, big.mark = ",")

doc <- read_pptx(tmpl)

# -----------------------------------------------------------------------------
# 3) Slides
# -----------------------------------------------------------------------------
# 1 Title
doc <- new_slide(doc, dark = TRUE)
doc <- add_text(doc, 0.9, 2.2, 11, 1.4, par(tx("GLORIApp", 54, col$white, TRUE, HEAD)), label = "Title")
doc <- add_text(doc, 0.9, 3.5, 11, 1.0,
                par(tx("Footprints and trade in value added with the GLORIA MRIO, without writing code", 22, col$moss)),
                label = "Subtitle")
doc <- add_text(doc, 0.9, 5.6, 11, 0.6, par(tx(sprintf("Introduction session  |  GLORIA v%d, 164 regions x 120 sectors, 1990-2029", meta$version), 14, col$light)),
                label = "Footer")

# 2 Why footprints
doc <- new_slide(doc)
doc <- title(doc, "Where pressures happen is not where they are caused",
             sprintf("Greenhouse gases of Austria in %d (GLORIA v%d, EDGAR GWP100)", yr, meta$version))
doc <- stat(doc, 0.8, 2.3, 3.6, paste(fmt(aut_pba), "Mt"), "emitted inside Austria (production-based)", col$muted)
doc <- stat(doc, 4.8, 2.3, 3.6, paste(fmt(aut_fp), "Mt"), "caused worldwide by Austrian final demand (footprint)", col$green)
doc <- stat(doc, 8.8, 2.3, 3.8, paste0("+", fmt(100 * (aut_fp / aut_pba - 1)), " %"), "net import of emissions embodied in goods", col$amber)
doc <- add_text(doc, 0.8, 5.0, 11.7, 1.0,
                par(tx("Production-based accounts follow the chimney, footprints follow the consumer. ", 16, col$text, TRUE),
                    tx("Both views are correct and add up to the same world total. The difference shows how much a region relies on pressures abroad.", 16)),
                bg = col$light, label = "Message box")

# 3 GLORIA in numbers
doc <- new_slide(doc)
doc <- title(doc, "GLORIA in four numbers", "Global multi-regional input-output database, University of Sydney / UN International Resource Panel")
nums <- list(c("164", "countries and regions"), c("120", "sectors in each region"),
             c("40", "years, 1990-2029 (recent years are nowcasts)"),
             c(fmt(nrow(meta$satellites)), "satellite indicators: materials, emissions, land, water, energy, jobs"))
for (i in seq_along(nums)) {
  l <- 0.8 + (i - 1) * 3.0
  doc <- add_text(doc, l, 2.4, 2.7, 2.6, par(tx(nums[[i]][1], 44, col$green, TRUE, HEAD)),
                  par(tx(nums[[i]][2], 14, col$text)), bg = col$light, geom = "roundRect", label = paste("Card", i))
}
doc <- add_text(doc, 0.8, 5.5, 11.7, 1.0,
                par(tx("Monetary flows in 1000 USD (current prices, basic prices). The app uses the MRIO in basic prices plus all satellite accounts.", 14, col$muted)),
                label = "Note")

# 4 IO logic
doc <- new_slide(doc)
doc <- title(doc, "One formula follows every supply chain", "Footprint = s x L x Y")
boxes <- list(c("s", "Direct intensity", "pressure per 1000 USD of output, e.g. kt CO2-eq of Chinese steel"),
              c("L", "Leontief inverse", "output of every sector worldwide needed for 1 USD of final product - all supply-chain rounds at once"),
              c("Y", "Final demand", "what households, governments and investors buy, by country"))
for (i in 1:3) {
  l <- 0.8 + (i - 1) * 4.2
  doc <- add_text(doc, l, 2.3, 3.4, 3.3,
                  par(tx(boxes[[i]][1], 40, col$white, TRUE, HEAD)), par(tx(boxes[[i]][2], 18, col$white, TRUE)),
                  par(tx(boxes[[i]][3], 14, col$light)), bg = if (i == 2) col$green else col$dark,
                  geom = "roundRect", label = paste("Formula box", i))
  if (i < 3) doc <- ph_with(doc, empty_content(), location = loc(l + 3.5, 3.7, 0.6, 0.5, bg = col$amber, geom = "rightArrow",
                                                                    label = paste("Arrow", i)))
}
doc <- add_text(doc, 0.8, 6.0, 11.7, 0.8,
                par(tx("Split the result by origin (where it happens) or by final product (what was bought): same total, different question.", 15, col$text)),
                label = "Note")

# 5 Chart: Austria footprint by origin
doc <- new_slide(doc)
doc <- title(doc, sprintf("%s of Austria's carbon footprint occurs outside Europe", paste0(fmt(100 * aut[region != "Europe", sum(Mt)] / aut_fp), " %")),
             sprintf("Austrian GHG footprint %d by world region of emission, Mt CO2-eq (incl. direct household emissions)", yr))
ch <- ms_barchart(aut, x = "region", y = "Mt")
ch <- chart_settings(ch, dir = "horizontal")
ch <- chart_labels(ch, title = NULL, xlab = NULL, ylab = NULL)
ch <- chart_data_fill(ch, values = col$green); ch <- chart_data_stroke(ch, values = col$green)
ch <- chart_data_labels(ch, show_val = TRUE, num_fmt = "0.0", position = "outEnd")
ch <- chart_labels_text(ch, values = fp_text(font.size = 12, color = col$text, font.family = BODY))
ch <- chart_theme(ch, legend_position = "n", grid_major_line_y = fp_border(width = 0),
                  grid_major_line_x = fp_border(color = "#DDDDDD", width = 0.5),
                  axis_text_x = fp_text(font.size = 12, color = col$muted, font.family = BODY),
                  axis_text_y = fp_text(font.size = 13, color = col$text, font.family = BODY))
ch <- chart_ax_x(ch, rotation = 0); ch <- chart_ax_y(ch, num_fmt = "0")
doc <- ph_with(doc, ch, location = loc(0.8, 2.0, 7.6, 5.0, label = "Chart"))
doc <- add_text(doc, 8.9, 2.4, 3.8, 3.6,
                par(tx("How to get this table", 17, col$dark, TRUE)),
                par(tx("Result type: Footprint, where it happens", 14)),
                par(tx("Indicator: Greenhouse gases (EDGAR)", 14)),
                par(tx(paste("Year:", yr), 14)),
                par(tx("Origin: 7 world regions; consumer: countries", 14)),
                par(tx("Filter the csv for to_region = Austria", 14)),
                bg = col$light, label = "Recipe")

# 6 Chart: income groups net imports
doc <- new_slide(doc)
doc <- title(doc, "High-income countries are net importers of pressures",
             "Net imports = footprint minus production-based account, by World Bank income group")
for (k in 1:2) {
  ind <- c("Greenhouse gases (GWP100; EDGAR)", "Material footprint (raw material extraction total)")[k]
  d <- ov[indicator == ind, .(region = factor(region, levels = c("Low income", "Lower middle income", "Upper middle income", "High income")),
                              year = as.character(year), value = value / c(1e6, 1e9)[k])]
  ch <- ms_barchart(d, x = "region", y = "value", group = "year")
  ch <- chart_labels(ch, title = c("Greenhouse gases, Gt CO2-eq", "Materials, Gt")[k], xlab = NULL, ylab = NULL)
  ch <- chart_data_fill(ch, values = c("2000" = col$moss, "2019" = col$dark))
  ch <- chart_data_stroke(ch, values = c("2000" = col$moss, "2019" = col$dark))
  ch <- chart_theme(ch, legend_position = "b", grid_major_line_x = fp_border(width = 0),
                    grid_major_line_y = fp_border(color = "#DDDDDD", width = 0.5),
                    axis_text_x = fp_text(font.size = 11, color = col$muted, font.family = BODY),
                    axis_text_y = fp_text(font.size = 11, color = col$muted, font.family = BODY),
                    main_title = fp_text(font.size = 15, bold = TRUE, color = col$dark, font.family = BODY),
                    legend_text = fp_text(font.size = 12, color = col$muted, font.family = BODY))
  ch <- chart_ax_y(ch, num_fmt = "0.0")
  ch <- chart_ax_x(ch, tick_label_pos = "low")
  doc <- ph_with(doc, ch, location = loc(0.6 + (k - 1) * 6.2, 2.0, 5.9, 4.9, label = paste("Chart", k)))
}

# 7 App in six steps
doc <- new_slide(doc)
doc <- title(doc, "The app in six steps", "Left sidebar, top to bottom - then click Calculate and download the csv")
steps <- list(c("What to calculate", "footprint by origin or by product, overview, territorial, TiVA"),
              c("Indicators", "35+ recommended indicators with explanations, or any raw GLORIA row"),
              c("Years", "any selection of 1990-2029"),
              c("Regions", "countries, world regions, World Bank income groups, or your own csv"),
              c("Sectors and final demand", "120 sectors, ISIC sections, 6 broad sectors; households, government, investment ..."),
              c("Output table", "long format for R/Python/pivot tables, or wide with one column per year"))
for (i in seq_along(steps)) {
  l <- if (i <= 3) 0.8 else 6.9; t <- 2.1 + ((i - 1) %% 3) * 1.6
  doc <- step(doc, l, t, 5.6, i, steps[[i]][1], steps[[i]][2])
}

# 8 Result types
doc <- new_slide(doc)
doc <- title(doc, "Five result types answer five questions")
rt <- data.frame(
  `Result type` = c("Footprint: where it happens", "Footprint: by final product", "Overview", "Production-based", "TiVA / embodied in exports"),
  `Typical question` = c("Which countries emit CO2 for Austrian consumption?",
                         "Which products drive the EU's land footprint?",
                         "Is a country a net importer of materials?",
                         "How much is emitted inside each country?",
                         "How much of German car exports is value created abroad?"),
  check.names = FALSE)

for (i in seq_len(nrow(rt))) {
  t <- 1.75 + (i - 1) * 1.0
  doc <- add_text(doc, 0.8, t, 4.0, 0.8, par(tx(rt[i, 1], 16, col$white, TRUE)), bg = col$green,
                  geom = "roundRect", label = paste("Type", i))
  doc <- add_text(doc, 5.0, t, 7.5, 0.8, par(tx(rt[i, 2], 16, col$text)), bg = col$light,
                  geom = "roundRect", label = paste("Question", i))
}

# 9 TiVA
doc <- new_slide(doc)
doc <- title(doc, "One third of German export value is created abroad",
             sprintf("Trade in value added, %d: value added embodied in Germany's gross manufacturing exports", yr))
doc <- stat(doc, 0.8, 2.4, 4.5, paste0(fmt(100 * deu_fva), " %"), "foreign value added (suppliers abroad)", col$amber)
doc <- stat(doc, 5.5, 2.4, 4.5, paste0(fmt(100 * (1 - deu_fva)), " %"), "domestic value added (created in Germany)", col$green)
doc <- add_text(doc, 0.8, 4.9, 11.7, 1.15,
                par(tx("Same machinery works for any indicator: ", 15, col$text, TRUE),
                    tx("choose Greenhouse gases instead of Value added to see where the emissions embodied in a country's exports happen. ", 15),
                    tx("Gross-export based indicators double count goods that cross borders several times - for 'who causes what' use footprints.", 15, col$muted)),
                bg = col$light, label = "Message box")

# 10 Exercises
doc <- new_slide(doc)
doc <- title(doc, "Hands-on: five exercises in pairs", "Details and expected steps in docs/intro_session.md")
ex <- list(c("Carbon footprint of Austria", "where do the emissions happen?"),
           c("Production vs. consumption", "who is a net importer, 2000 vs 2019?"),
           c("What drives the land footprint", "products and final demand categories"),
           c("Own region grouping", "upload an EU27 csv and repeat exercise 1"),
           c("Trade in value added", "foreign value in German and Chinese exports"))
for (i in seq_along(ex)) {
  doc <- step(doc, if (i <= 3) 0.8 else 6.9, 2.1 + ((i - 1) %% 3) * 1.6, 5.6, i, ex[[i]][1], ex[[i]][2])
}

# 11 Pitfalls
doc <- new_slide(doc)
doc <- title(doc, "Five things to keep in mind")
pit <- list(c("Units", "kt vs Mt, tonnes, 1000 ha, persons, 1000 USD at current prices"),
            c("Recent years", "after ~2022 GLORIA nowcasts and projects - use for trends, with care"),
            c("Rest-of-world regions", "four regions bundle many small countries of mixed income"),
            c("Direct household emissions", "heating and private cars: included only if ticked in step 5"),
            c("Gross exports", "TiVA on gross exports double counts multi-border trade"))
for (i in seq_along(pit)) {
  doc <- step(doc, if (i <= 3) 0.8 else 6.9, 2.1 + ((i - 1) %% 3) * 1.6, 5.6, "!", pit[[i]][1], pit[[i]][2])
}

# 12 Closing: data and updates
doc <- new_slide(doc, dark = TRUE)
doc <- title(doc, "Getting started", dark = TRUE)
doc <- add_text(doc, 0.8, 1.8, 11.7, 4.5,
                par(tx("Start the app: ", 18, col$moss, TRUE), tx("open GLORIApp.Rproj in RStudio, then shiny::runApp(\"app\")", 18, col$white)),
                par(tx("New GLORIA release: ", 18, col$moss, TRUE), tx("tab 'Data & updates' - paste the Google Drive link, download and compile run in the background", 18, col$white)),
                par(tx("Own aggregations: ", 18, col$moss, TRUE), tx("add a column to input/concordances/regions.csv or sectors.csv", 18, col$white)),
                par(tx("Scripts: ", 18, col$moss, TRUE), tx("R/engine.R works without the app - see README.md", 18, col$white)),
                label = "Getting started")
doc <- add_text(doc, 0.8, 6.4, 11.7, 0.6,
                par(tx("Please cite: Lenzen et al. (2022) Nature Sustainability 5, 157-166, and the GLORIA v60 release notes", 12, col$light)),
                label = "Citation")

out <- "docs/GLORIApp_intro.pptx"
print(doc, target = out)
message("Written: ", out)
