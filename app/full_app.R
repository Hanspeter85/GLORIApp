# =============================================================================
# app/full_app.R  -  Full footprint calculator (used when parsed data exist)
# =============================================================================
# Sourced by app/app.R. Defines `ui` and `server`.

meta <- readRDS(meta_file)

# Always use the newest concordance csv files from the repo, so that new
# aggregation columns added there appear in the app without re-parsing.
meta$regions <- fread(file.path(paths$input, "concordances", "regions.csv"))
meta$sectors <- fread(file.path(paths$input, "concordances", "sectors.csv"))

years_avail <- available_years()

# --- Choices for the drop-down menus ---------------------------------------------
# Region aggregations = all columns of regions.csv except the codes.
# The names of the list are what the user sees.
nice_name <- function(x) {
  lookup <- c(region_name = "No aggregation (164 countries/regions)",
              region_acronym = "No aggregation (ISO codes)",
              world_region_7 = "7 world regions",
              income_group_worldbank = "World Bank income groups",
              region_worldbank = "World Bank regions",
              development_group = "Development groups (LDCs etc.)",
              world = "World total",
              sector_name = "No aggregation (120 sectors)",
              isic_section = "ISIC Rev.4 sections (20)",
              broad_sector = "6 broad sectors",
              total = "All sectors together")
  ifelse(x %in% names(lookup), lookup[x], x)
}
agg_choices <- function(tab, drop) {
  cols <- setdiff(names(tab), drop)
  setNames(cols, nice_name(cols))
}
region_choices <- agg_choices(meta$regions, c("region_code"))
sector_choices <- agg_choices(meta$sectors, c("sector_code", "total"))

# Indicator choices grouped by theme (shown as groups in the drop-down)
cat_tab <- meta$catalogue
indicator_choices <- lapply(split(cat_tab, cat_tab$theme, drop = TRUE),
                            function(d) setNames(d$id, paste0(d$label, " [", d$unit, "]")))
indicator_choices <- indicator_choices[unique(cat_tab$theme)]

# All raw satellite rows for the expert mode
sat_choices <- setNames(paste0("sat:", meta$satellites$sat_code),
                        sprintf("%s | %s [%s]", meta$satellites$head,
                                meta$satellites$indicator, meta$satellites$unit))

fd_choices <- setNames(meta$fd$fd_code, meta$fd$fd_name)

# =============================================================================
# 2. USER INTERFACE
# =============================================================================
# Each step in the sidebar is one "accordion panel". The help texts come from
# R/texts.R so that they can be edited without touching the app logic.
ui <- page_sidebar(
  title = paste0("GLORIApp - footprint calculator (GLORIA v", meta$version, ")"),
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  sidebar = sidebar(
    width = 420,
    accordion(
      open = c("step1", "step2", "step3"),
      multiple = TRUE,

      # --- Step 1: what to calculate ---------------------------------------------
      accordion_panel(
        "1. What do you want to calculate?", value = "step1",
        radioButtons("type", NULL, choices = result_type_choices, selected = "footprint_origin"),
        uiOutput("type_help")
      ),

      # --- Step 2: indicators -------------------------------------------------------
      accordion_panel(
        "2. Indicators (pressures)", value = "step2",
        selectizeInput("indicators", "Recommended indicators",
                       choices = indicator_choices, selected = "ghg_edgar",
                       multiple = TRUE,
                       options = list(placeholder = "Type to search ...", plugins = list("remove_button"))),
        checkboxInput("expert", "Expert mode: choose raw GLORIA satellite rows", FALSE),
        conditionalPanel(
          "input.expert",
          selectizeInput("sat_rows", "Raw satellite rows (5 982 available)", choices = NULL,
                         multiple = TRUE, options = list(placeholder = "e.g. 'co2' or 'Iron ores'")),
          helpText(help_texts$expert)
        )
      ),

      # --- Step 3: years ----------------------------------------------------------------
      accordion_panel(
        "3. Years", value = "step3",
        selectizeInput("years", NULL, choices = years_avail,
                       # default: latest year with (mostly) real statistics, i.e. <= 2022
                       selected = tail(c(years_avail[1], years_avail[years_avail <= 2022]), 1),
                       multiple = TRUE, options = list(plugins = list("remove_button"))),
        actionLink("all_years", "select all years"), " | ",
        actionLink("five_years", "every 5th year"),
        helpText(help_texts$years)
      ),

      # --- Step 4: regions ---------------------------------------------------------------
      accordion_panel(
        "4. Regions", value = "step4",
        selectInput("region_from", "Origin / producing / exporting regions",
                    choices = region_choices, selected = "region_name"),
        selectInput("region_to", "Consumer / partner regions",
                    choices = region_choices, selected = "region_name"),
        fileInput("region_upload", "Optional: own region grouping (csv)", accept = ".csv"),
        helpText(help_texts$regions),
        downloadLink("dl_region_template", "Download template with all regions")
      ),

      # --- Step 5: sectors and final demand ---------------------------------------------
      accordion_panel(
        "5. Sectors and final demand", value = "step5",
        checkboxInput("by_sector", "Show sector detail", FALSE),
        conditionalPanel(
          "input.by_sector",
          selectInput("sector_col", "Sector aggregation", choices = sector_choices,
                      selected = "broad_sector"),
          fileInput("sector_upload", "Optional: own sector grouping (csv)", accept = ".csv"),
          downloadLink("dl_sector_template", "Download template with all sectors")
        ),
        checkboxGroupInput("fd_codes", "Final demand categories to include",
                           choices = fd_choices, selected = meta$fd$fd_code),
        checkboxInput("by_fd", "Show final demand categories separately", FALSE),
        checkboxInput("include_direct_fd",
                      "Include direct emissions of households (heating, cars, ...)", TRUE),
        conditionalPanel(
          "input.type == 'tiva'",
          checkboxInput("tiva_origin_detail", "TiVA: show origin region of value added", FALSE)
        ),
        helpText(help_texts$fd)
      ),

      # --- Step 6: output format ----------------------------------------------------------
      accordion_panel(
        "6. Output table", value = "step6",
        radioButtons("format", NULL,
                     choices = c("Long format (one value per row; best for R, Python, pivot tables)" = "long",
                                 "Pivot / wide format (one column per ...)" = "wide")),
        conditionalPanel(
          "input.format == 'wide'",
          selectInput("pivot_col", "Columns", choices = c("year", "indicator"))
        ),
        checkboxInput("keep_zeros", "Keep rows with value 0", FALSE)
      )
    ),
    actionButton("go", "Calculate", class = "btn-primary btn-lg w-100", icon = icon("play"))
  ),

  # --- Main area: result and documentation ------------------------------------------
  navset_card_tab(
    nav_panel(
      "Result",
      uiOutput("description"),
      uiOutput("status"),
      downloadButton("download", "Download csv", class = "btn-success mb-3"),
      DT::DTOutput("table")
    ),
    nav_panel("Indicator explanations", DT::DTOutput("catalogue")),
    update_ui(),
    nav_panel("How it works", includeMarkdown(file.path(root, "app", "help.md")))
  )
)

# =============================================================================
# 3. SERVER
# =============================================================================
server <- function(input, output, session) {

  # Tab "Data & updates" (see app/update_tab.R)
  update_server(input, output, session, root)

  # Expert mode: the list of 5 982 satellite rows is loaded on the server side
  # (much faster than sending it all to the browser at once)
  updateSelectizeInput(session, "sat_rows", choices = sat_choices, server = TRUE)

  # Short explanation of the chosen result type
  output$type_help <- renderUI(helpText(result_type_help[[input$type]]))

  # Quick year selection links
  observeEvent(input$all_years, updateSelectizeInput(session, "years", selected = years_avail))
  observeEvent(input$five_years, updateSelectizeInput(session, "years",
                                                      selected = years_avail[years_avail %% 5 == 0]))

  # --- Optional user-defined groupings (uploaded csv) -------------------------------
  # Region csv: columns region_acronym, group. Sector csv: sector_code, group.
  # The uploaded grouping is added as a new column "own_grouping".
  meta_r <- reactive({
    m <- meta
    if (!is.null(input$region_upload)) {
      up <- fread(input$region_upload$datapath)
      validate(need(all(c("region_acronym", "group") %in% names(up)),
                    "Region csv needs the columns 'region_acronym' and 'group'."))
      m$regions[, own_grouping := up$group[match(region_acronym, up$region_acronym)]]
      m$regions[is.na(own_grouping), own_grouping := "Not assigned"]
    }
    if (!is.null(input$sector_upload)) {
      up <- fread(input$sector_upload$datapath)
      validate(need(all(c("sector_code", "group") %in% names(up)),
                    "Sector csv needs the columns 'sector_code' and 'group'."))
      m$sectors[, own_grouping := up$group[match(sector_code, up$sector_code)]]
      m$sectors[is.na(own_grouping), own_grouping := "Not assigned"]
    }
    m
  })
  observeEvent(input$region_upload, {
    ch <- c(region_choices, "Own grouping (uploaded)" = "own_grouping")
    updateSelectInput(session, "region_from", choices = ch, selected = "own_grouping")
    updateSelectInput(session, "region_to", choices = ch)
  })
  observeEvent(input$sector_upload, {
    updateSelectInput(session, "sector_col",
                      choices = c(sector_choices, "Own grouping (uploaded)" = "own_grouping"),
                      selected = "own_grouping")
  })
  output$dl_region_template <- downloadHandler(
    "region_grouping_template.csv",
    function(f) fwrite(meta$regions[, .(region_acronym, region_name, group = world_region_7)], f))
  output$dl_sector_template <- downloadHandler(
    "sector_grouping_template.csv",
    function(f) fwrite(meta$sectors[, .(sector_code, sector_name, group = broad_sector)], f))

  # --- Collect all choices into one specification list ---------------------------
  spec <- reactive({
    list(type = input$type,
         indicators = c(input$indicators, if (isTRUE(input$expert)) input$sat_rows),
         years = as.integer(input$years),
         region_from = input$region_from,
         region_to = input$region_to,
         sector_col = input$sector_col,
         by_sector = isTRUE(input$by_sector),
         by_fd = isTRUE(input$by_fd),
         fd_codes = as.integer(input$fd_codes),
         include_direct_fd = isTRUE(input$include_direct_fd),
         tiva_origin_detail = isTRUE(input$tiva_origin_detail),
         keep_zeros = isTRUE(input$keep_zeros))
  })

  # Plain-language description of what will be calculated (updates live)
  output$description <- renderUI({
    describe_spec(spec(), meta_r())
  })

  # --- Run the calculation when the button is clicked ----------------------------
  result <- eventReactive(input$go, {
    sp <- spec()
    validate(
      need(length(sp$indicators) > 0, "Please choose at least one indicator (step 2)."),
      need(length(sp$years) > 0, "Please choose at least one year (step 3)."),
      need(length(sp$fd_codes) > 0 || sp$type == "production",
           "Please choose at least one final demand category (step 5).")
    )
    t0 <- Sys.time()
    res <- withProgress(message = "Calculating", value = 0, {
      run_calculation(sp, meta_r(), progress = function(p, msg) setProgress(p, detail = msg))
    })
    attr(res, "seconds") <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    res
  })

  # Result table in the chosen format (long or wide)
  result_formatted <- reactive({
    res <- result()
    if (input$format == "wide") res <- to_wide(res, input$pivot_col)
    res
  })

  output$status <- renderUI({
    res <- result()
    div(class = "alert alert-info",
        sprintf("Done in %.0f seconds: %s rows. The preview shows the first 1 000 rows; the download contains everything.",
                attr(res, "seconds"), format(nrow(result_formatted()), big.mark = ",")))
  })

  output$table <- DT::renderDT({
    res <- result_formatted()
    prev <- res[seq_len(min(nrow(res), 1000))]
    # show numbers with 4 significant digits (the csv keeps full precision)
    num_cols <- which(vapply(prev, is.numeric, TRUE) & !names(prev) %in% "year")
    DT::datatable(prev, rownames = FALSE, options = list(pageLength = 25, scrollX = TRUE)) |>
      DT::formatSignif(columns = num_cols, digits = 4)
  })

  output$download <- downloadHandler(
    filename = function() {
      sprintf("GLORIA_v%d_%s_%s.csv", meta$version, input$type, format(Sys.time(), "%Y%m%d_%H%M"))
    },
    content = function(file) fwrite(result_formatted(), file)
  )

  # Indicator explanation table
  output$catalogue <- DT::renderDT({
    DT::datatable(cat_tab[, .(Theme = theme, Indicator = label, Unit = unit, Explanation = explanation)],
                  rownames = FALSE, options = list(pageLength = 50))
  })
}

