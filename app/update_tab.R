# =============================================================================
# app/update_tab.R  -  Tab "Data & updates": install new GLORIA releases
# =============================================================================
# UI and server part of the update function. The work itself is done by
# update/update_gloria.R in a background R process (see R/update.R).
# =============================================================================

update_ui <- function() {
  nav_panel(
    "Data & updates",
    h4("Installed GLORIA versions"),
    tableOutput("upd_versions"),
    uiOutput("upd_activate_ui"),
    hr(),
    h4("Download and compile a new GLORIA release"),
    p("New GLORIA releases are published by the Industrial Ecology Virtual Laboratory",
      "(University of Sydney) as Google Drive folders, see",
      tags$a("ielab.info/labs/ielab-gloria", href = "https://ielab.info/labs/ielab-gloria", target = "_blank"),
      ". Paste the link of the release folder below. Only the needed parts are downloaded",
      "(MRIO tables in basic prices and satellite accounts, roughly 50-100 GB),",
      "then all years are compiled. Downloading and compiling take several hours;",
      "the app can be used (or closed) meanwhile. If the process is interrupted,",
      "just start it again: finished downloads and years are skipped."),
    uiOutput("upd_rclone"),
    textInput("upd_link", "Google Drive link of the release folder", width = "100%",
              placeholder = "https://drive.google.com/drive/folders/..."),
    actionButton("upd_check", "1. Check folder", icon = icon("magnifying-glass")),
    uiOutput("upd_check_result"),
    hr(),
    h4("Progress of the latest update"),
    verbatimTextOutput("upd_log")
  )
}

update_server <- function(input, output, session, repo_root) {
  rv <- reactiveValues(check = NULL, log = NULL, refresh = 0)

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

  output$upd_rclone <- renderUI({
    st <- rclone_status()
    div(class = if (st$ok) "alert alert-success" else "alert alert-warning",
        st$msg, tags$br(), sprintf("Free disk space for the data folder (%s): %s GB",
                                   data_root, free_disk_gb()))
  })

  # Step 1: look into the Drive folder (which version? how big?)
  observeEvent(input$upd_check, {
    id <- drive_folder_id(input$upd_link)
    if (is.na(id)) {
      rv$check <- list(error = "This does not look like a Google Drive folder link.")
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
    if (!is.null(ck$error)) return(div(class = "alert alert-danger", ck$error))
    if (is.na(ck$version)) return(div(class = "alert alert-danger",
                                      "No GLORIA ReadMe found in this folder - is it a GLORIA release?"))
    inst <- installed_versions()
    already <- nrow(inst) > 0 && ck$version %in% inst$version
    tagList(
      div(class = "alert alert-info",
          sprintf("Found GLORIA version %d. Files to download: %d (about %s GB).",
                  ck$version, sum(ck$files$needed), ck$download_gb),
          if (already) tags$p(tags$b("This version is already (partly) installed: only missing files and years will be processed."))),
      actionButton("upd_start", sprintf("2. Download and compile v%d", ck$version),
                   class = "btn-primary", icon = icon("download")),
      checkboxInput("upd_download_only", "Download only (compile later)", FALSE)
    )
  })

  # Step 2: start the background process
  observeEvent(input$upd_start, {
    ck <- rv$check
    rv$log <- start_update(ck$id, ck$version, repo_root = repo_root,
                           download_only = isTRUE(input$upd_download_only))
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
