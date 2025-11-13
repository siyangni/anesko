# Improved Main Server with Session Cleanup and Enhanced Monitoring
# This file addresses critical production readiness issues:
# - Session cleanup (prevents memory leaks)
# - Connection pool per session (prevents connection exhaustion)
# - Structured logging
# - Performance monitoring

# To use: rename current server.R to server_original.R and this file to server.R

server <- function(input, output, session) {

  # =============================================================================
  # SESSION-SCOPED RESOURCES
  # =============================================================================

  # Create session-specific logger
  session_logger <- logger::layout_glue_generator(
    format = '[{time}] [{level}] [Session: {session$token}] {msg}'
  )
  logger::log_layout(session_logger)
  logger::log_info("Session started")

  # Session-scoped connection pool (prevents global pool exhaustion)
  session_pool <- tryCatch({
    logger::log_info("Creating session-scoped connection pool")
    create_db_pool()
  }, error = function(e) {
    logger::log_error("Failed to create session pool: {e$message}")
    showNotification(
      "Database connection failed. Please contact support.",
      type = "error",
      duration = NULL
    )
    NULL
  })

  # Store session-specific data
  session_data <- reactiveValues(
    start_time = Sys.time(),
    page_views = 0,
    queries_executed = 0,
    errors_count = 0
  )

  # =============================================================================
  # SESSION CLEANUP (CRITICAL FOR PRODUCTION)
  # =============================================================================

  # Clean up resources when session ends
  session$onSessionEnded(function() {
    logger::log_info("Session ending - cleaning up resources")

    # Calculate session duration
    session_duration <- as.numeric(difftime(Sys.time(), session_data$start_time, units = "mins"))

    # Log session statistics
    logger::log_info(paste(
      "Session statistics:",
      "Duration: {round(session_duration, 2)} minutes",
      "Page views: {session_data$page_views}",
      "Queries: {session_data$queries_executed}",
      "Errors: {session_data$errors_count}"
    ))

    # Close session-specific database pool
    if (!is.null(session_pool)) {
      tryCatch({
        logger::log_info("Closing session database pool")
        pool::poolClose(session_pool)
        logger::log_info("Session pool closed successfully")
      }, error = function(e) {
        logger::log_error("Error closing session pool: {e$message}")
      })
    }

    # Clean up any temporary files
    temp_dir <- file.path(tempdir(), paste0("shiny_session_", session$token))
    if (dir.exists(temp_dir)) {
      unlink(temp_dir, recursive = TRUE)
      logger::log_info("Cleaned up temporary directory")
    }

    logger::log_info("Session cleanup complete")
  })

  # =============================================================================
  # LOADING SCREEN
  # =============================================================================

  # Show loading screen on startup
  waiter <- waiter::Waiter$new(
    html = tagList(
      h3("Loading American Authorship Database..."),
      waiter::spin_fading_circles()
    ),
    color = "rgba(33, 37, 41, 0.85)"
  )

  waiter$show()

  # =============================================================================
  # DATABASE INITIALIZATION
  # =============================================================================

  # Initialize database connection and cache
  observe({
    tryCatch({
      # Ensure we have a valid database pool
      if (is.null(session_pool)) {
        showNotification(
          "Database connection failed - please refresh the page",
          type = "error",
          duration = 10
        )
        waiter$hide()
        return()
      }

      # Test database connection with session pool
      test_query <- tryCatch({
        pool::dbGetQuery(session_pool, "SELECT 1 as test")
      }, error = function(e) {
        logger::log_error("Database test query failed: {e$message}")
        NULL
      })

      if (is.null(test_query) || nrow(test_query) == 0) {
        showNotification(
          "Database connection failed - unable to execute test query",
          type = "error",
          duration = 10
        )
        waiter$hide()
        return()
      }

      logger::log_info("Database connection validated")

      # Pre-load summary data for better performance
      cache$books_summary <- safe_db_query("SELECT * FROM book_sales_summary LIMIT 100")
      cache$last_updated <- Sys.time()

      # Hide loading screen after initialization
      waiter$hide()

      showNotification("Dashboard loaded successfully!", type = "message", duration = 3)
      logger::log_info("Dashboard initialization complete")

    }, error = function(e) {
      logger::log_error("Dashboard initialization failed: {e$message}")
      waiter$hide()
      showNotification(
        paste("Failed to initialize dashboard:", e$message),
        type = "error",
        duration = 10
      )
    })
  })

  # =============================================================================
  # PERFORMANCE MONITORING
  # =============================================================================

  # Track page views
  observeEvent(input$main_menu, {
    session_data$page_views <- session_data$page_views + 1
    logger::log_trace("Page view: {input$main_menu}")
  })

  # Monitor long-running queries
  observe({
    invalidateLater(60000)  # Check every minute

    if (session_data$queries_executed > 100) {
      logger::log_warn("High query count in session: {session_data$queries_executed}")
    }

    if (session_data$errors_count > 10) {
      logger::log_warn("High error count in session: {session_data$errors_count}")
    }
  })

  # =============================================================================
  # CACHE MANAGEMENT (OPTIMIZED)
  # =============================================================================

  # Periodic cache refresh - DISABLED for historical data
  # Historical data (1860-1920) doesn't change, so no need for automatic refresh
  # If you need to refresh after data updates, do it manually or on-demand

  # Manual cache refresh button (admin only - optional)
  output$refresh_cache_button <- renderUI({
    if (isTRUE(session$userData$is_admin)) {
      actionButton(
        "refresh_cache",
        "Refresh Cache",
        icon = icon("sync"),
        class = "btn-sm btn-info"
      )
    }
  })

  observeEvent(input$refresh_cache, {
    logger::log_info("Manual cache refresh triggered by admin")
    tryCatch({
      cache$books_summary <- safe_db_query("SELECT * FROM book_sales_summary LIMIT 100")
      cache$last_updated <- Sys.time()
      showNotification("Cache refreshed successfully", type = "message")
    }, error = function(e) {
      logger::log_error("Cache refresh failed: {e$message}")
      showNotification("Cache refresh failed", type = "error")
    })
  })

  # =============================================================================
  # MODULE SERVERS
  # =============================================================================

  # Dashboard module
  dashboardServer("dashboard_module")

  # Book explorer module
  bookExplorerServer("books_module")

  # Sales trends module
  salesTrendsServer("sales_trends_module")

  # Author analysis module
  authorAnalysisServer("authors_module")

  # Author networks module
  authorNetworksServer("networks_module")

  # Royalty analysis module
  royaltyAnalysisServer("royalties_module")

  # Royalty income query module
  royaltyQueryServer("royalty_query_module")

  # Genre analysis module
  genreAnalysisServer("genres_module")

  # =============================================================================
  # NAVIGATION HANDLING
  # =============================================================================

  observeEvent(input$main_menu, {
    tab_name <- input$main_menu
    if (!is.null(tab_name)) {
      logger::log_trace("User navigated to: {tab_name}")
      session_data$page_views <- session_data$page_views + 1
    }
  })

  # =============================================================================
  # ERROR TRACKING
  # =============================================================================

  # Global error handler (optional - for advanced monitoring)
  observe({
    # This is a placeholder for error tracking integration
    # In production, integrate with services like Sentry, Rollbar, etc.
  })

}
