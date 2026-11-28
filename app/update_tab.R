# =============================================================================
# app/update_tab.R  -  Tab "Data & updates": install new GLORIA releases
# =============================================================================
# UI and server part of the update function. The download and compilation
# run in a background R process (update/update_gloria.R, see R/update.R).
# Only R packages are used (googledrive), no extra programs.
# =============================================================================

update_ui <- function() {
  nav_panel(
    "Data & updates",
    h4("Installed GLORIA versions"),
    tableOutput("upd_versions"),
    uiOutput("upd_activate_ui"),
    hr(),
    h4("Where the data are stored"),
    p("The compiled GLORIA (MRIO, about 125 GB for 40 years) and the raw downloads can be stored in",
      "different folders, e.g. the MRIO on a large internal disk and the temporary raw files on another drive.",
      "The raw files are deleted again after each year has been compiled."),
    textInput("upd_data_root", "Folder for the compiled MRIO", value = data_root, width = "100%"),
    textInput("upd_raw_root", "Folder for raw downloads (empty = same as MRIO folder)", value = raw_root, width = "100%"),
    uiOutput("upd_space"),
    actionButton("upd_save_folders", "Save folders as default", icon = icon("floppy-disk"), class = "btn-sm"),
    hr(),
    h4("Download and compile a new GLORIA release"),
    p("New GLORIA releases are published by the Industrial Ecology Virtual Laboratory",
      "(University of Sydney) as Google Drive folders, see",
      tags$a("ielab.info/labs/ielab-gloria", href = "https://ielab.info/labs/ielab-gloria", target = "_blank"),
      ". Only the needed parts are downloaded (MRIO tables in basic prices and satellite",
      "accounts, about 5.5 GB per year). The release is processed year by year",
      "(download, compile, delete the raw files), so at most ~10 GB of raw data are",
      "on disk at any time. A full release takes several hours; the app can be used",
      "(or closed) meanwhile. If the process is interrupted, start it again:",
      "finished years are skipped."),
    tags$b("Step 1: connect to Google Drive (once per PC)"),
    uiOutput("upd_google"),
    actionButton("upd_login", "Connect Google Drive", icon = icon("google")),
    tags$p(class = "small text-muted mt-1",
           "Opens the Google login in your browser. Read-only access; the login is stored in",
           code(file.path(data_root, ".google_token")), "."),
    tags$b("Step 2: paste the link of the release folder"),
    textInput("upd_link", NULL, width = "100%",
              placeholder = "https://drive.google.com/drive/folders/..."),
    actionButton("upd_check", "Check folder", icon = icon("magnifying-glass")),
    uiOutput("upd_check_result"),
    hr(),
    h4("Progress of the latest update"),
    verbatimTextOutput("upd_log")
  )
}

update_server <- function(input, output, session, repo_root) {
  rv <- reactiveValues(check = NULL, log = NULL, refresh = 0, email = NULL)

  output$upd_versions <- renderTable({
    rv$refresh
    v <- installed_versions()
    if (nrow(v) == 0) return(data.frame(info = "No GLORIA data installed yet."))
    v
  })

  output$upd_activate_ui <- renderUI({
    rv$refresh
    v <- installed_versions()
    if (nrow(v) < 2) return(NULL)
    tagList(
      selectInput("upd_active", "Use this version in the app", choices = v$version[v$ready_for_app],
                  selected = gloria_version),
      actionButton("upd_activate", "Activate (then restart the app)")
    )
  })
  observeEvent(input$upd_activate, {
    set_active_version(input$upd_active)
    rv$refresh <- rv$refresh + 1
    showNotification(sprintf("Version %s activated. Please restart the app.", input$upd_active),
                     type = "message", duration = NULL)
  })


  # --- Folders for MRIO and raw files ------------------------------------------------
  output$upd_space <- renderUI({
    d <- trimws(input$upd_data_root); r <- trimws(input$upd_raw_root)
    msg <- sprintf("Free disk space - MRIO folder: %s GB", free_disk_gb(d))
    if (nzchar(r)) msg <- paste0(msg, sprintf(", raw folder: %s GB", free_disk_gb(r)))
    tags$p(class = "small text-muted", msg,
           " (needed: ~3.2 GB per year for the MRIO, ~11 GB temporarily for the raw files).")
  })
  observeEvent(input$upd_save_folders, {
    d <- trimws(input$upd_data_root); r <- trimws(input$upd_raw_root)
    if (!folder_ok(d) || (nzchar(r) && !folder_ok(r))) {
      showNotification("A folder does not exist and could not be created, or is not writable.", type = "error")
      return()
    }
    save_user_settings(data_root = d, raw_root = r)
    showNotification("Folders saved. They are used for updates right away and by the app after a restart.",
                     type = "message", duration = 8)
  })

  # --- Google Drive connection ----------------------------------------------------------
  output$upd_google <- renderUI({
    rv$refresh
    if (!requireNamespace("googledrive", quietly = TRUE)) {
      return(div(class = "alert alert-warning",
                 "The R package 'googledrive' is missing. Run in the R console: install.packages(\"googledrive\")"))
    }
    email <- if (!is.null(rv$email)) rv$email else google_login_cached()
    if (is.na(email)) div(class = "alert alert-warning", "Not connected to Google Drive yet.")
    else div(class = "alert alert-success",
             sprintf("Connected to Google Drive as %s.", email))
  })
  observeEvent(input$upd_login, {
    res <- tryCatch(google_login(), error = function(e) {
      showNotification(paste("Google login failed:", conditionMessage(e)), type = "error", duration = NULL)
      NA_character_
    })
    rv$email <- res
    rv$refresh <- rv$refresh + 1
  })

  # --- Look into the Drive folder (which version? how big?) -----------------------------
  observeEvent(input$upd_check, {
    id <- drive_folder_id(input$upd_link)
    if (is.na(id)) {
      rv$check <- list(error = "This does not look like a Google Drive folder link.")
      return()
    }
    if (is.na(google_login_cached())) {
      rv$check <- list(error = "Please connect to Google Drive first (step 1).")
      return()
    }
    rv$check <- withProgress(message = "Reading the Drive folder ...", {
      tryCatch(c(inspect_drive_folder(id), id = id),
               error = function(e) list(error = conditionMessage(e)))
    })
  })

  output$upd_check_result <- renderUI({
    ck <- rv$check
    if (is.null(ck)) return(NULL)
    if (!is.null(ck$error)) return(div(class = "alert alert-danger mt-2", ck$error))
    if (is.na(ck$version)) return(div(class = "alert alert-danger mt-2",
                                      "No GLORIA ReadMe found in this folder - is it a GLORIA release?"))
    inst <- installed_versions()
    already <- nrow(inst) > 0 && ck$version %in% inst$version
    tagList(
      div(class = "alert alert-info mt-2",
          sprintf("Found GLORIA version %d. Files to download: %d (about %s GB in total, processed year by year).",
                  ck$version, nrow(ck$needed), ck$download_gb),
          if (already) tags$p(tags$b("This version is already (partly) installed: only missing years will be processed."))),
      actionButton("upd_start", sprintf("Step 3: download and compile v%d", ck$version),
                   class = "btn-primary", icon = icon("download")),
      checkboxInput("upd_download_only", "Download only (compile later with parser/run_parser.R)", FALSE)
    )
  })

  # Start the background process
  observeEvent(input$upd_start, {
    ck <- rv$check
    d <- trimws(input$upd_data_root); r <- trimws(input$upd_raw_root)
    if (!folder_ok(d) || (nzchar(r) && !folder_ok(r))) {
      showNotification("Please check the folders above: they must exist (or be creatable) and be writable.", type = "error")
      return()
    }
    rv$log <- start_update(ck$id, ck$version, repo_root = repo_root,
                           download_only = isTRUE(input$upd_download_only),
                           data_dir = d, raw_dir = r)
    showNotification("Update started in the background. Progress is shown below.", type = "message")
  })

  # Show the newest update log, refreshed every 5 seconds
  output$upd_log <- renderText({
    invalidateLater(5000)
    log <- rv$log
    if (is.null(log)) {
      logs <- list.files(data_root, "^update_.*\\.log$", recursive = TRUE, full.names = TRUE)
      if (length(logs) == 0) return("No update started yet.")
      log <- logs[which.max(file.mtime(logs))]
    }
    if (!file.exists(log)) return("Starting ...")
    txt <- readLines(log, warn = FALSE)
    paste(c(paste("Log file:", log), tail(txt, 25)), collapse = "\n")
  })
}
