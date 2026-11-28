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
        uiOutput("ch_filter_ui")
      ),
      plotly::plotlyOutput("chart", height = "560px"),
      helpText("Hover over the chart for exact values. The camera icon (top right) saves the chart as PNG.")
    )
  )
}

charts_server <- function(input, output, session, result) {

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
}

# Readable names of the result columns
nice_dim <- function(x) {
  lookup <- c(production_region = "production region", production_sector = "production sector",
              consumption_region = "consumption region", consumption_product = "final product",
              product_made_in = "product made in", consumption_category = "final demand category",
              region = "region", account = "account")
  ifelse(x %in% names(lookup), lookup[x], x)
}
