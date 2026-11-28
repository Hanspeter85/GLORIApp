# =============================================================================
# app/charts_tab.R  -  Tab "Charts": quick visualisation of the last result
# =============================================================================
# Shows the table calculated in the "Result" tab as an interactive chart
# (hover shows exact values). Three chart types:
#   Ranking      horizontal bars of the largest groups of one dimension
#   Time series  one line per group over the calculated years
#   Composition  stacked bars: one dimension on the axis, another as colour
# Colours: fixed categorical order (max. 8 groups, the rest is folded into
# "Other" in grey), one hue for single-series charts. Uses the plotly package.
# =============================================================================

# Validated categorical palette (fixed order, never cycled) and neutrals
chart_cols <- c("#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#6250d6", "#e34948")
chart_other <- "#b5b3ad"
chart_ink <- list(primary = "#0b0b0b", secondary = "#52514e", muted = "#898781", grid = "#e8e7e3")

charts_ui <- function() {
  nav_panel(
    "Charts",
    uiOutput("chart_hint"),
    layout_sidebar(
      sidebar = sidebar(
        width = 260, open = "always",
        selectInput("ch_type", "Chart type",
                    c("Ranking (bars)" = "rank", "Time series (lines)" = "time",
                      "Composition (stacked bars)" = "stack")),
        selectInput("ch_indicator", "Indicator", choices = NULL),
        selectInput("ch_dim", "Show by", choices = NULL),
        conditionalPanel("input.ch_type == 'stack'", selectInput("ch_colour", "Colour by", choices = NULL)),
        conditionalPanel("input.ch_type != 'time'", selectInput("ch_year", "Year", choices = NULL)),
        numericInput("ch_top", "Groups shown (rest = 'Other')", value = 12, min = 3, max = 30),
        uiOutput("ch_filter_ui"),
        hr(),
        selectInput("ch_img_format", "Export chart as", c("PNG image" = "png", "JPEG image" = "jpeg",
                                                         "SVG (vector, for editing)" = "svg", "PDF (vector)" = "pdf")),
        downloadButton("ch_download", "Download image", class = "btn-sm btn-success w-100 mb-2"),
        actionButton("ch_save", "Save image in folder (step 7)", icon = icon("folder-open"),
                     class = "btn-sm btn-outline-success w-100")
      ),
      plotly::plotlyOutput("chart", height = "560px"),
      helpText("Hover over the chart for exact values. Use 'Export chart as' (left) to save the chart as PNG, JPEG, SVG or PDF (300 dpi, 10 x 6 inch).")
    )
  )
}

charts_server <- function(input, output, session, result, results_dir) {

  # Dimension columns of the result (everything except year/indicator/unit/value)
  dims <- reactive({
    res <- result()
    setdiff(names(res), c("year", "indicator", "unit", "value"))
  })

  output$chart_hint <- renderUI({
    if (is.null(tryCatch(result(), error = function(e) NULL)))
      div(class = "alert alert-info", "Calculate a result first (sidebar, 'Calculate'). The charts show that result.")
  })

  # Fill the drop-downs whenever a new result is available
  observeEvent(result(), {
    res <- result(); d <- dims()
    updateSelectInput(session, "ch_indicator", choices = unique(res$indicator))
    dn <- setNames(d, nice_dim(d))
    updateSelectInput(session, "ch_dim", choices = dn, selected = d[1])
    updateSelectInput(session, "ch_colour", choices = dn, selected = if (length(d) > 1) d[2] else d[1])
    yrs <- sort(unique(res$year))
    updateSelectInput(session, "ch_year", choices = yrs, selected = max(yrs))
    if (length(yrs) > 1) updateSelectInput(session, "ch_type", selected = "time")
  })

  # Optional filter on one other dimension (e.g. show only consumer = Austria)
  output$ch_filter_ui <- renderUI({
    req(result()); d <- setdiff(dims(), c(input$ch_dim, if (input$ch_type == "stack") input$ch_colour))
    if (length(d) == 0) return(NULL)
    res <- result()
    tagList(
      selectInput("ch_filter_dim", "Filter on", choices = c("(no filter)" = "", setNames(d, nice_dim(d)))),
      selectizeInput("ch_filter_val", "Keep only", choices = NULL, multiple = TRUE)
    )
  })
  observeEvent(input$ch_filter_dim, {
    req(result())
    vals <- if (nzchar(input$ch_filter_dim)) sort(unique(result()[[input$ch_filter_dim]])) else character(0)
    updateSelectizeInput(session, "ch_filter_val", choices = vals, server = TRUE)
  })

  # Data for the chart: selected indicator, filtered, top groups + "Other"
  chart_data <- reactive({
    res <- result(); req(input$ch_indicator, input$ch_dim %in% names(res))
    d <- res[indicator == input$ch_indicator]
    if (!is.null(input$ch_filter_dim) && nzchar(input$ch_filter_dim) && length(input$ch_filter_val) > 0) {
      d <- d[get(input$ch_filter_dim) %in% input$ch_filter_val]
    }
    if (input$ch_type != "time") d <- d[year == as.integer(input$ch_year)]
    validate(need(nrow(d) > 0, "No data for this selection."))
    top_n <- if (input$ch_type == "rank") input$ch_top else min(input$ch_top, length(chart_cols))
    # rank groups by absolute total and fold the rest into "Other"
    fold <- function(v, w) {
      tot <- tapply(abs(w), v, sum)
      keep <- names(sort(tot, decreasing = TRUE))[seq_len(min(top_n, length(tot)))]
      ifelse(v %in% keep, v, "Other")
    }
    d[, grp := fold(get(input$ch_dim), value)]
    if (input$ch_type == "stack") {
      d[, col := {
        tot <- tapply(abs(value), get(input$ch_colour), sum)
        keep <- names(sort(tot, decreasing = TRUE))[seq_len(min(length(chart_cols), length(tot)))]
        ifelse(get(input$ch_colour) %in% keep, get(input$ch_colour), "Other")
      }]
      d <- d[, .(value = sum(value)), by = .(grp, col)]
    } else if (input$ch_type == "time") {
      d <- d[, .(value = sum(value)), by = .(grp, year)]
    } else {
      d <- d[, .(value = sum(value)), by = .(grp)]
    }
    list(d = d, unit = res[indicator == input$ch_indicator, unit[1]])
  })

  # Common, quiet layout: recessive grid, ink colours, one y axis only
  base_layout <- function(p, title, xlab, ylab, legend = TRUE) {
    plotly::layout(p,
      title = list(text = title, x = 0, font = list(size = 15, color = chart_ink$primary)),
      paper_bgcolor = "#fcfcfb", plot_bgcolor = "#fcfcfb",
      font = list(color = chart_ink$secondary, size = 12),
      xaxis = list(title = list(text = if (is.null(xlab)) "" else xlab), gridcolor = chart_ink$grid, zerolinecolor = chart_ink$muted,
                   tickfont = list(color = chart_ink$muted)),
      yaxis = list(title = list(text = if (is.null(ylab)) "" else ylab), gridcolor = chart_ink$grid, zerolinecolor = chart_ink$muted,
                   tickfont = list(color = chart_ink$muted), automargin = TRUE),
      showlegend = legend, legend = list(orientation = "h", y = -0.15),
      hoverlabel = list(bgcolor = "white", font = list(color = chart_ink$primary)),
      margin = list(t = 50))
  }

  output$chart <- plotly::renderPlotly({
    cd <- chart_data(); d <- cd$d; unit <- cd$unit
    lab <- nice_dim(input$ch_dim)
    if (input$ch_type == "rank") {
      # single series -> one hue, no legend; largest bar on top
      d <- d[order(value)]
      d[, grp := factor(grp, levels = grp)]
      p <- plotly::plot_ly(d, x = ~value, y = ~grp, type = "bar", orientation = "h",
                           marker = list(color = ifelse(d$grp == "Other", chart_other, chart_cols[1])),
                           hovertemplate = paste0("%{y}<br>%{x:,.4g} ", unit, "<extra></extra>"))
      base_layout(p, sprintf("%s, %s", input$ch_indicator, input$ch_year), unit, NULL, legend = FALSE)
    } else if (input$ch_type == "time") {
      grps <- d[, .(t = sum(abs(value))), by = grp][order(-t), grp]
      grps <- c(setdiff(grps, "Other"), intersect(grps, "Other"))
      cols <- setNames(c(chart_cols, rep(chart_other, 40))[seq_along(grps)], grps)
      cols["Other"] <- chart_other
      p <- plotly::plot_ly()
      for (g in grps) {
        dg <- d[grp == g][order(year)]
        p <- plotly::add_trace(p, data = dg, x = ~year, y = ~value, type = "scatter", mode = "lines+markers",
                               name = g, line = list(width = 2, color = cols[[g]]),
                               marker = list(size = 8, color = cols[[g]]),
                               hovertemplate = paste0(g, "<br>%{x}: %{y:,.4g} ", unit, "<extra></extra>"))
      }
      p <- plotly::layout(p, hovermode = "x unified", xaxis = list(dtick = if (length(unique(d$year)) <= 15) 1 else NULL, tickformat = "d"))
      base_layout(p, input$ch_indicator, NULL, unit, legend = length(grps) > 1)
    } else {
      cols_g <- d[, .(t = sum(abs(value))), by = col][order(-t), col]
      cols_g <- c(setdiff(cols_g, "Other"), intersect(cols_g, "Other"))
      cols <- setNames(c(chart_cols, chart_other)[seq_along(cols_g)], cols_g)
      cols["Other"] <- chart_other
      ord <- d[, .(t = sum(value)), by = grp][order(t), grp]
      d[, grp := factor(grp, levels = ord)]
      p <- plotly::plot_ly()
      for (g in cols_g) {
        p <- plotly::add_trace(p, data = d[col == g], x = ~value, y = ~grp, type = "bar", orientation = "h",
                               name = g, marker = list(color = cols[[g]], line = list(color = "#fcfcfb", width = 1)),
                               hovertemplate = paste0("%{y}<br>", g, ": %{x:,.4g} ", unit, "<extra></extra>"))
      }
      p <- plotly::layout(p, barmode = "relative")
      base_layout(p, sprintf("%s, %s - by %s", input$ch_indicator, input$ch_year, nice_dim(input$ch_colour)),
                  unit, NULL)
    }
  })

  # --- Static version of the chart for export (ggplot2) -------------------------------
  # Same data, colours and order as the interactive chart.
  chart_gg <- reactive({
    cd <- chart_data(); d <- copy(cd$d); unit <- cd$unit
    th <- ggplot2::theme_minimal(base_size = 12) +
      ggplot2::theme(panel.grid.major.y = ggplot2::element_blank(),
                     panel.grid.minor = ggplot2::element_blank(),
                     panel.grid.major.x = ggplot2::element_line(colour = chart_ink$grid),
                     text = ggplot2::element_text(colour = chart_ink$secondary),
                     plot.title = ggplot2::element_text(colour = chart_ink$primary, face = "bold"),
                     legend.position = "bottom", plot.background = ggplot2::element_rect(fill = "white", colour = NA))
    src <- ggplot2::labs(caption = sprintf("Source: GLORIA v%s, calculated with GLORIApp", gloria_version))
    if (input$ch_type == "rank") {
      d <- d[order(value)]; d[, grp := factor(grp, levels = grp)]
      ggplot2::ggplot(d, ggplot2::aes(value, grp)) +
        ggplot2::geom_col(fill = ifelse(d$grp == "Other", chart_other, chart_cols[1]), width = 0.7) +
        ggplot2::scale_x_continuous(labels = function(v) format(v, big.mark = ",", scientific = FALSE)) +
        ggplot2::labs(title = sprintf("%s, %s", input$ch_indicator, input$ch_year), x = unit, y = NULL) + th + src
    } else if (input$ch_type == "time") {
      grps <- d[, .(t = sum(abs(value))), by = grp][order(-t), grp]
      grps <- c(setdiff(grps, "Other"), intersect(grps, "Other"))
      cols <- setNames(c(chart_cols, rep(chart_other, 40))[seq_along(grps)], grps); cols["Other"] <- chart_other
      d[, grp := factor(grp, levels = grps)]
      ggplot2::ggplot(d, ggplot2::aes(year, value, colour = grp)) +
        ggplot2::geom_line(linewidth = 0.9) + ggplot2::geom_point(size = 2) +
        ggplot2::scale_x_continuous(breaks = if (length(unique(d$year)) <= 15) sort(unique(d$year)) else ggplot2::waiver()) +
        ggplot2::scale_colour_manual(values = cols, name = NULL) +
        ggplot2::scale_y_continuous(labels = function(v) format(v, big.mark = ",", scientific = FALSE)) +
        ggplot2::labs(title = input$ch_indicator, x = NULL, y = unit) + th +
        ggplot2::theme(panel.grid.major.y = ggplot2::element_line(colour = chart_ink$grid),
                       panel.grid.major.x = ggplot2::element_blank()) + src
    } else {
      cols_g <- d[, .(t = sum(abs(value))), by = col][order(-t), col]
      cols_g <- c(setdiff(cols_g, "Other"), intersect(cols_g, "Other"))
      cols <- setNames(c(chart_cols, chart_other)[seq_along(cols_g)], cols_g); cols["Other"] <- chart_other
      ord <- d[, .(t = sum(value)), by = grp][order(t), grp]
      d[, `:=`(grp = factor(grp, levels = ord), col = factor(col, levels = rev(cols_g)))]
      ggplot2::ggplot(d, ggplot2::aes(value, grp, fill = col)) +
        ggplot2::geom_col(width = 0.7, colour = "white", linewidth = 0.3) +
        ggplot2::scale_fill_manual(values = cols, name = NULL, breaks = cols_g) +
        ggplot2::scale_x_continuous(labels = function(v) format(v, big.mark = ",", scientific = FALSE)) +
        ggplot2::labs(title = sprintf("%s, %s - by %s", input$ch_indicator, input$ch_year, nice_dim(input$ch_colour)),
                      x = unit, y = NULL) + th + src
    }
  })

  chart_file_name <- function() {
    sprintf("GLORIA_chart_%s_%s.%s", input$ch_type, format(Sys.time(), "%Y%m%d_%H%M%S"), input$ch_img_format)
  }
  output$ch_download <- downloadHandler(
    filename = chart_file_name,
    content = function(file) save_chart(chart_gg(), file, input$ch_img_format)
  )
  observeEvent(input$ch_save, {
    dir <- results_dir()
    if (!folder_ok(dir)) {
      showNotification("The folder in step 7 does not exist and could not be created.", type = "error"); return()
    }
    f <- file.path(dir, chart_file_name())
    save_chart(chart_gg(), f, input$ch_img_format)
    showNotification(paste("Saved:", normalizePath(f)), type = "message", duration = 15)
  })
}

# Write a ggplot chart to a file: png/jpeg (300 dpi), svg or pdf (vector)
save_chart <- function(p, file, format = "png", width = 10, height = 6) {
  dev <- switch(format,
                png  = "png",
                jpeg = "jpeg",
                svg  = function(filename, ...) grDevices::svg(filename, ...),
                pdf  = grDevices::cairo_pdf,
                stop("Unknown image format: ", format))
  ggplot2::ggsave(file, p, device = dev, width = width, height = height, dpi = 300, bg = "white")
  invisible(file)
}

# Readable names of the result columns
nice_dim <- function(x) {
  lookup <- c(production_region = "production region", production_sector = "production sector",
              consumption_region = "consumption region", consumption_product = "final product",
              product_made_in = "product made in", consumption_category = "final demand category",
              region = "region", account = "account")
  ifelse(x %in% names(lookup), lookup[x], x)
}
