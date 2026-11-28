# =============================================================================
# app/full_app.R  -  Full footprint calculator (used when parsed data exist)
# =============================================================================
# Sourced by app/app.R. Defines `ui` and `server`.
#
# The sidebar has 7 steps:
#   1 what to calculate    2 indicators     3 years
#   4 breakdown of the result (origin / final product / consumer)
#   5 final demand         6 own groupings  7 output table
# All calculations are done by run_calculation() in R/engine.R.
# =============================================================================

meta <- readRDS(meta_file)

# Always use the newest concordance csv files from the repo, so that new
# aggregation columns added there appear in the app without re-parsing.
meta$regions <- fread(file.path(paths$input, "concordances", "regions.csv"))
meta$sectors <- fread(file.path(paths$input, "concordances", "sectors.csv"))

years_avail <- available_years()

# --- Choices for the drop-down menus ---------------------------------------------
# Region groupings = all columns of regions.csv except the codes, sector
# groupings = all columns of sectors.csv. The names are what the user sees.
nice_name <- function(x) {
  lookup <- c(none = "Do not split (total)",
              region_name = "Countries/regions (164)",
              region_acronym = "Countries/regions (164, ISO codes)",
              world_region_7 = "7 world regions",
              income_group_worldbank = "World Bank income groups (FY26, July 2025)",
              region_worldbank = "World Bank regions",
              development_group = "Development groups (LDCs etc.)",
              world = "World total",
              sector_name = "Sectors (120)",
              isic_section = "ISIC Rev.4 sections (20)",
              broad_sector = "6 broad sectors",
              total = "All sectors together",
              own_grouping = "Own grouping (step 6)")
  unname(ifelse(x %in% names(lookup), lookup[x], x))
}
agg_choices <- function(cols) setNames(cols, nice_name(cols))
base_region_cols <- setdiff(names(meta$regions), c("region_code", "world"))
base_sector_cols <- setdiff(names(meta$sectors), c("sector_code", "total"))

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

# Little helper: a bold sub heading inside a sidebar step
sub_head <- function(txt) tags$p(tags$b(txt), class = "mb-1 mt-2")

# =============================================================================
# 2. USER INTERFACE
# =============================================================================
# Each step in the sidebar is one "accordion panel". The help texts come from
# R/texts.R so that they can be edited without touching the app logic.
ui <- page_sidebar(
  title = paste0("GLORIApp - footprint calculator (GLORIA v", meta$version, ")"),
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  sidebar = sidebar(
    width = 440,
    accordion(
      open = c("step1", "step2", "step3", "step4"),
      multiple = TRUE,

      # --- Step 1: what to calculate ---------------------------------------------
      accordion_panel(
        "1. What do you want to calculate?", value = "step1",
        radioButtons("type", NULL, choices = result_type_choices, selected = "footprint"),
        uiOutput("type_help")
      ),

      # --- Step 2: indicators -------------------------------------------------------
      accordion_panel(
        "2. Indicators", value = "step2",
        selectizeInput("indicators", "Recommended indicators",
                       choices = indicator_choices, selected = "ghg_edgar",
                       multiple = TRUE,
                       options = list(placeholder = "Type to search ...", plugins = list("remove_button"))),
        helpText(help_texts$indicators),
        checkboxInput("expert", "Expert mode: choose raw GLORIA satellite rows", FALSE),
        conditionalPanel(
          "input.expert",
          selectizeInput("sat_rows", sprintf("Raw satellite rows (%s available)",
                                             format(nrow(meta$satellites), big.mark = ",")),
                         choices = NULL, multiple = TRUE,
                         options = list(placeholder = "e.g. 'co2' or 'Iron ores'")),
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

      # --- Step 4: breakdown (which dimensions appear in the table) -------------------
      # Same logic on both sides: WHERE (region), WHAT (sector / product) and, on
      # the consumption side, WHO (final demand category). "Do not split (total)"
      # removes that dimension from the table.
      accordion_panel(
        "4. Breakdown of the result", value = "step4",
        helpText(help_texts$breakdown),
        # Production side: where the pressure physically occurs
        tags$div(
          class = "border rounded p-2 mb-2",
          sub_head(uiOutput("lab_production", inline = TRUE)),
          selectInput("production_region", "Where: region", choices = NULL),
          conditionalPanel("input.type != 'overview'",
                           selectInput("production_sector", "What: sector", choices = NULL))
        ),
        # Consumption side: who buys what where (footprint only)
        conditionalPanel(
          "input.type == 'footprint'",
          tags$div(
            class = "border rounded p-2 mb-2",
            sub_head(uiOutput("lab_consumption", inline = TRUE)),
            selectInput("consumption_region", "Where: region", choices = NULL),
            selectInput("consumption_product", "What: final product (sector)", choices = NULL),
            conditionalPanel("input.type == 'footprint'",
                             checkboxInput("by_fd", "Who: split by final demand category (households, government, investment, ...)", FALSE)),
            selectInput("product_made_in", "Optional: region where the final product was made",
                        choices = NULL),
            conditionalPanel("input.type == 'footprint'", uiOutput("detail_warning"))
          )
        )
      ),

      # --- Step 5: final demand ----------------------------------------------------------
      accordion_panel(
        "5. Final demand", value = "step5",
        checkboxGroupInput("fd_codes", "Final demand categories to include",
                           choices = fd_choices, selected = meta$fd$fd_code),
        checkboxInput("include_direct_fd",
                      "Include direct emissions of households (heating, private cars, ...)", TRUE),
        helpText(help_texts$fd)
      ),

      # --- Step 6: own groupings ---------------------------------------------------------
      accordion_panel(
        "6. Own groupings (optional)", value = "step6",
        helpText(help_texts$own_groups),
        radioButtons("grp_kind", NULL, inline = TRUE,
                     choices = c("Regions" = "regions", "Sectors" = "sectors")),
        textInput("grp_name", "Name of the group", placeholder = "e.g. EU27 or Food"),
        selectizeInput("grp_members", "Members", choices = NULL, multiple = TRUE,
                       options = list(placeholder = "Type to search ...", plugins = list("remove_button"))),
        actionButton("grp_add", "Add group", icon = icon("plus"), class = "btn-sm btn-outline-primary"),
        tags$div(class = "mt-2", tableOutput("grp_table")),
        textInput("grp_rest_regions", "Name for all other regions", "Rest of world"),
        textInput("grp_rest_sectors", "Name for all other sectors", "Other sectors"),
        actionLink("grp_clear", "remove all own groups"), " | ",
        downloadLink("grp_download", "save groupings (csv)"),
        fileInput("grp_upload", "Load saved groupings (csv)", accept = ".csv")
      ),

      # --- Step 7: output format ----------------------------------------------------------
      accordion_panel(
        "7. Output table", value = "step7",
        radioButtons("format", NULL, choices = output_format_choices),
        conditionalPanel(
          "input.format == 'wide'",
          selectInput("pivot_col", "One column per", choices = c("year", "indicator"))
        ),
        checkboxInput("keep_zeros", "Keep rows with value 0", FALSE),
        selectInput("file_type", "File format for the download", choices = file_type_choices),
        helpText(help_texts$file_type),
        textInput("results_dir", "Folder for 'Save in folder' (results and charts)", value = results_dir),
        actionLink("save_results_dir", "remember this folder")
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
      uiOutput("checks_ui"),
      uiOutput("download_ui"),
      DT::DTOutput("table")
    ),
    charts_ui(),
    nav_panel("Indicator explanations", DT::DTOutput("catalogue")),
    update_ui(),
    how_it_works_panel()
  )
)

# =============================================================================
# 3. SERVER
# =============================================================================
server <- function(input, output, session) {

  # Tab "Data & updates" (see app/update_tab.R)
  update_server(input, output, session, root)

  # Tab "Charts" (see app/charts_tab.R) - uses result() defined further below;
  # reactives are evaluated lazily, so it can be referenced here.
  charts_server(input, output, session, reactive(result()), reactive(trimws(input$results_dir)))

  # Expert mode: the list of all satellite rows is loaded on the server side
  # (much faster than sending it all to the browser at once)
  updateSelectizeInput(session, "sat_rows", choices = sat_choices, server = TRUE)

  # Short explanation of the chosen result type
  output$type_help <- renderUI(helpText(result_type_help[[input$type]]))

  # Headings of the three breakdown blocks depend on the result type
  output$lab_production  <- renderText(dimension_labels[[input$type]][["production"]])
  output$lab_consumption <- renderText(dimension_labels[[input$type]][["consumption"]])

  # Quick year selection links
  observeEvent(input$all_years, updateSelectizeInput(session, "years", selected = years_avail))
  observeEvent(input$five_years, updateSelectizeInput(session, "years",
                                                      selected = years_avail[years_avail %% 5 == 0]))

  # ---------------------------------------------------------------------------
  # Own groupings (step 6)
  # ---------------------------------------------------------------------------
  # Stored as a table: kind (regions/sectors), group name, member code.
  # Region members are ISO codes (region_acronym), sector members sector codes.
  groups <- reactiveVal(data.table(kind = character(), group = character(), member = character()))

  member_choices <- function(kind) {
    if (kind == "regions") setNames(meta$regions$region_acronym, meta$regions$region_name)
    else setNames(as.character(meta$sectors$sector_code), meta$sectors$sector_name)
  }
  observeEvent(input$grp_kind, {
    updateSelectizeInput(session, "grp_members", choices = member_choices(input$grp_kind),
                         selected = character(0), server = TRUE)
  })
  observeEvent(input$grp_add, {
    nm <- trimws(input$grp_name)
    if (!nzchar(nm) || length(input$grp_members) == 0) {
      showNotification("Please give the group a name and choose at least one member.", type = "warning")
      return()
    }
    g <- groups()[!(kind == input$grp_kind & (group == nm | member %in% input$grp_members))]
    groups(rbind(g, data.table(kind = input$grp_kind, group = nm, member = input$grp_members)))
    updateTextInput(session, "grp_name", value = "")
    updateSelectizeInput(session, "grp_members", selected = character(0))
  })
  observeEvent(input$grp_clear, groups(groups()[0]))
  observeEvent(input$grp_upload, {
    up <- fread(input$grp_upload$datapath, colClasses = "character")
    if (!all(c("kind", "group", "member") %in% names(up))) {
      showNotification("The csv needs the columns kind, group, member (as saved by this app).", type = "error")
      return()
    }
    groups(up[, .(kind, group, member)])
  })
  output$grp_download <- downloadHandler("GLORIApp_own_groupings.csv", function(f) fwrite(groups(), f))
  output$grp_table <- renderTable({
    g <- groups()
    if (nrow(g) == 0) return(data.frame(Info = "No own groups defined yet."))
    g[, .(Members = .N), by = .(Type = kind, Group = group)]
  })

  # Metadata including the column "own_grouping" (if own groups exist)
  meta_r <- reactive({
    m <- meta
    g <- groups()
    if (nrow(g[kind == "regions"]) > 0) {
      rg <- g[kind == "regions"]
      m$regions <- copy(m$regions)[, own_grouping := rg$group[match(region_acronym, rg$member)]]
      m$regions[is.na(own_grouping), own_grouping := input$grp_rest_regions]
    }
    if (nrow(g[kind == "sectors"]) > 0) {
      sg <- g[kind == "sectors"]
      m$sectors <- copy(m$sectors)[, own_grouping := sg$group[match(as.character(sector_code), sg$member)]]
      m$sectors[is.na(own_grouping), own_grouping := input$grp_rest_sectors]
    }
    m
  })

  # (Re)fill the grouping drop-downs; keeps the current selection if possible
  set_choices <- function(id, choices, default) {
    sel <- isolate(input[[id]])
    if (is.null(sel) || !sel %in% choices) sel <- default
    updateSelectInput(session, id, choices = agg_choices(choices), selected = sel)
  }
  observe({
    g <- groups()
    own_r <- if (nrow(g[kind == "regions"]) > 0) "own_grouping"
    own_s <- if (nrow(g[kind == "sectors"]) > 0) "own_grouping"
    reg <- c(base_region_cols, own_r)
    sec <- c(base_sector_cols, own_s)
    set_choices("production_region",   c("none", reg, "world"), "region_name")
    set_choices("production_sector",   c("none", sec), "none")
    set_choices("product_made_in",  c("none", reg, "world"), "none")
    set_choices("consumption_product",  c("none", sec), "none")
    set_choices("consumption_region", c(reg, "world"), "region_name")
  })

  # Warn when origin AND final product are split (slower, needs L)
  output$detail_warning <- renderUI({
    origin_split  <- !identical(input$production_region, "none") || !identical(input$production_sector, "none")
    product_split <- !identical(input$product_made_in, "none") || !identical(input$consumption_product, "none")
    if (origin_split && product_split) div(class = "alert alert-warning py-1 small", help_texts$detail)
  })

  # --- Collect all choices into one specification list ---------------------------
  spec <- reactive({
    req(input$production_region, input$consumption_region)
    list(type = input$type,
         indicators = c(input$indicators, if (isTRUE(input$expert)) input$sat_rows),
         years = as.integer(input$years),
         production_region = input$production_region,
         production_sector = if (input$type == "overview") "none" else input$production_sector,
         product_made_in = if (input$type == "footprint") input$product_made_in else "none",
         consumption_product = if (input$type == "footprint") input$consumption_product else "none",
         consumption_region = input$consumption_region,
         by_fd = isTRUE(input$by_fd) && input$type == "footprint",
         fd_codes = as.integer(input$fd_codes),
         include_direct_fd = isTRUE(input$include_direct_fd),
         keep_zeros = isTRUE(input$keep_zeros))
  })

  # Plain-language description of what will be calculated (updates live)
  output$description <- renderUI(describe_spec(spec(), meta_r()))

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
    # Progress bar with percentage and estimated remaining time
    res <- withProgress(message = "Calculating: 0 %", value = 0, {
      run_calculation(sp, meta_r(), progress = function(p, msg) {
        el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
        eta <- if (p > 0.02 && p < 1) sprintf(" - about %s left", format_secs(el / p - el)) else ""
        setProgress(p, message = sprintf("Calculating: %d %%%s", round(100 * p), eta), detail = msg)
      })
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

  # The download button only appears once there is a result
  output$download_ui <- renderUI({
    n <- nrow(result_formatted())
    if (input$file_type == "xlsx" && n > EXCEL_MAX_ROWS) {
      return(div(class = "alert alert-warning",
                 sprintf("The result has %s rows - too many for Excel (max. 1,048,576). Choose CSV or text in step 7, or group the result more coarsely.",
                         format(n, big.mark = ","))))
    }
    div(class = "d-flex gap-2 align-items-start flex-wrap",
        downloadButton("download", sprintf("Download (%s)", names(file_type_choices)[file_type_choices == input$file_type]),
                       class = "btn-success mb-3"),
        actionButton("save_result", "Save in folder (step 7)", icon = icon("folder-open"),
                     class = "btn-outline-success mb-3"))
  })

  # --- Save result directly into a folder on this PC ---------------------------------
  # (the app runs locally, so the server can write to the chosen folder)
  observeEvent(input$save_results_dir, {
    if (!folder_ok(trimws(input$results_dir))) {
      showNotification("This folder does not exist and could not be created.", type = "error"); return()
    }
    save_user_settings(results_dir = trimws(input$results_dir))
    showNotification("Folder remembered for the next start.", type = "message")
  })
  result_file_name <- function(ext) {
    sprintf("GLORIA_v%d_%s_%s.%s", meta$version, input$type, format(Sys.time(), "%Y%m%d_%H%M%S"), ext)
  }
  observeEvent(input$save_result, {
    dir <- trimws(input$results_dir)
    if (!folder_ok(dir)) {
      showNotification("The folder in step 7 does not exist and could not be created.", type = "error"); return()
    }
    ext <- c(csv = "csv", csv2 = "csv", xlsx = "xlsx", txt = "txt")[[input$file_type]]
    f <- file.path(dir, result_file_name(ext))
    ok <- tryCatch({
      write_result_file(result_formatted(), f, input$file_type, spec(), attr(result(), "checks")); TRUE
    }, error = function(e) { showNotification(conditionMessage(e), type = "error", duration = NULL); FALSE })
    if (ok) showNotification(paste("Saved:", normalizePath(f)), type = "message", duration = 15)
  })

  # Plausibility checks of the calculation (computed by run_calculation, see
  # check_job() in R/engine.R): green = all passed, red = something is wrong
  output$checks_ui <- renderUI({
    chk <- attr(result(), "checks")
    if (is.null(chk) || nrow(chk) == 0) return(NULL)
    n_ok <- sum(chk$status == "OK"); n_fail <- sum(chk$status == "FAILED"); n_skip <- sum(chk$status == "skipped")
    cls <- if (n_fail > 0) "alert alert-danger" else "alert alert-success"
    head_txt <- if (n_fail > 0) sprintf("Plausibility checks: %d FAILED, %d passed", n_fail, n_ok)
                else sprintf("Plausibility checks: all %d passed%s", n_ok,
                             if (n_skip > 0) sprintf(" (%d not applicable)", n_skip) else "")
    num <- function(v) vapply(v, function(z) if (is.na(z)) "-" else
      format(signif(z, 8), big.mark = ",", scientific = FALSE, trim = TRUE), "")
    tab <- chk[, .(Check = check, Year = ifelse(is.na(year), "all", as.character(year)), Indicator = indicator,
                   Expected = num(expected), Calculated = num(calculated),
                   `Rel. difference` = ifelse(is.na(rel_difference), "-", formatC(rel_difference, format = "e", digits = 1)),
                   Status = status, Note = note)]
    div(class = cls,
        tags$details(
          tags$summary(tags$b(head_txt), " - click for details"),
          tags$p(class = "small mt-2",
                 "Input-output identities that must hold if the calculation is correct, e.g. the footprints of all",
                 "consumers add up to the total of the satellite account. Tolerance: 0.01 %."),
          div(class = "bg-white text-dark p-2 rounded small", renderTable(tab, striped = TRUE))
        ))
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
    # preview rounded to 2 decimals with thousands separator (csv keeps full precision)
    num_cols <- which(vapply(prev, is.numeric, TRUE) & !names(prev) %in% "year")
    DT::datatable(prev, rownames = FALSE, options = list(pageLength = 25, scrollX = TRUE)) |>
      DT::formatRound(columns = num_cols, digits = 2, mark = ",")
  })

  output$download <- downloadHandler(
    filename = function() {
      ext <- c(csv = "csv", csv2 = "csv", xlsx = "xlsx", txt = "txt")[[input$file_type]]
      sprintf("GLORIA_v%d_%s_%s.%s", meta$version, input$type, format(Sys.time(), "%Y%m%d_%H%M"), ext)
    },
    content = function(file) write_result_file(result_formatted(), file, input$file_type,
                                               spec(), attr(result(), "checks"))
  )

  # Indicator explanation table
  output$catalogue <- DT::renderDT({
    DT::datatable(cat_tab[, .(Theme = theme, Indicator = label, Unit = unit, Explanation = explanation)],
                  rownames = FALSE, options = list(pageLength = 50))
  })
}
