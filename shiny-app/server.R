# Main Server for American Authorship Dashboard

server <- function(input, output, session) {

  # Create reactive cache for data (FIXED: moved from global.R for proper scope)
  cache <- reactiveValues(
    books_summary = NULL,
    genre_summary = NULL,
    decade_summary = NULL,
    author_summary = NULL,
    last_updated = Sys.time()
  )

  # Show loading screen on startup
  waiter <- waiter::Waiter$new(
    html = tagList(
      h3("Loading American Authorship Database..."),
      waiter::spin_fading_circles()
    ),
    color = "rgba(33, 37, 41, 0.85)"
  )
  
  waiter$show()
  
  # Initialize database connection and cache
  observe({
    tryCatch({
      # Ensure we have a valid database pool
      if (is.null(pool)) {
        pool <<- initialize_db_pool()
      }
      
      if (is.null(pool)) {
        showNotification("Database connection failed - pool could not be created", type = "error", duration = 10)
        waiter$hide()
        return()
      }
      
      # Test database connection
      test_query <- safe_db_query("SELECT 1 as test")
      if (is.null(test_query) || nrow(test_query) == 0) {
        showNotification("Database connection failed - unable to execute test query", type = "error", duration = 10)
        waiter$hide()
        return()
      }
      
      # Pre-load summary data for better performance
      cache$books_summary <- safe_db_query("SELECT * FROM book_sales_summary LIMIT 100")
      cache$last_updated <- Sys.time()
      
      # Hide loading screen after initialization
      waiter$hide()
      
      showNotification("Dashboard loaded successfully!", type = "message", duration = 3)
      
    }, error = function(e) {
      waiter$hide()
      showNotification(
        paste("Failed to initialize dashboard:", e$message), 
        type = "error", 
        duration = 10
      )
    })
  })

  # ---------------------------------------------------------------------------
  # Browser history: sync sidebar tabs with ?tab= for Back/Forward + deep links
  # Client logic lives in www/browser_history.js (pushState / popstate).
  # ---------------------------------------------------------------------------
  nav_state <- reactiveValues(
    # TRUE while applying a tab change that came from the browser (not a click)
    syncing_from_url = FALSE,
    last_tab = NULL
  )

  select_main_tab <- function(tab, from_browser = FALSE) {
    if (!is_valid_tab(tab)) {
      tab <- DEFAULT_TAB
    }
    if (isTRUE(from_browser)) {
      nav_state$syncing_from_url <- TRUE
    }
    nav_state$last_tab <- tab
    shinydashboard::updateTabItems(
      session = session,
      inputId = "main_menu",
      selected = tab
    )
    if (isTRUE(from_browser)) {
      session$onFlushed(function() {
        nav_state$syncing_from_url <- FALSE
      }, once = TRUE)
    }
  }

  # Deep link / Back / Forward → select the matching sidebar tab
  observeEvent(input$browser_nav_tab, {
    nav <- input$browser_nav_tab
    if (is.null(nav)) {
      return()
    }

    tab <- if (is.list(nav) || (is.vector(nav) && !is.null(names(nav)))) {
      nav[["tab"]]
    } else {
      nav
    }
    if (is.null(tab) || !nzchar(as.character(tab)[1])) {
      return()
    }
    tab <- as.character(tab)[1]
    if (!is_valid_tab(tab)) {
      tab <- DEFAULT_TAB
    }

    current <- isolate(input$main_menu)
    source <- if (is.list(nav)) nav[["source"]] else NULL

    # Already on this tab — still mark last_tab so click handler can no-op
    if (!is.null(current) && identical(tab, current)) {
      nav_state$last_tab <- tab
      cat("History/nav echo (already on tab):", tab,
          if (!is.null(source)) paste0(" [", source, "]") else "", "\n")
      return()
    }

    select_main_tab(tab, from_browser = TRUE)
    cat("User navigated to (via URL/history):", tab,
        if (!is.null(source)) paste0(" [", source, "]") else "", "\n")
  }, ignoreNULL = TRUE)

  # Sidebar click / programmatic updateTabItems → ask browser to push history
  observeEvent(input$main_menu, {
    tab <- input$main_menu
    if (!is_valid_tab(tab)) {
      return()
    }

    # Applied from Back/Forward/deep link — do not push another entry
    if (isTRUE(isolate(nav_state$syncing_from_url))) {
      nav_state$last_tab <- tab
      return()
    }

    prev <- isolate(nav_state$last_tab)
    # First paint / echo of the same tab: replace URL, don't grow history
    mode <- if (is.null(prev)) "replace" else "push"

    if (identical(tab, prev)) {
      return()
    }

    nav_state$last_tab <- tab
    session$sendCustomMessage(
      "anesko_nav_history",
      list(tab = tab, mode = mode)
    )
    cat("User navigated to:", tab, " (history mode:", mode, ")\n")
  }, ignoreNULL = TRUE)

  observeEvent(input[["dashboard_module-navigate_to"]], {
    target_tab <- input[["dashboard_module-navigate_to"]]

    if (is.null(target_tab) || !nzchar(target_tab)) {
      return()
    }
    if (!is_valid_tab(target_tab)) {
      return()
    }

    shinydashboard::updateTabItems(
      session = session,
      inputId = "main_menu",
      selected = target_tab
    )
  }, ignoreNULL = TRUE)

  observeEvent(input[["dashboard_module-go_sales_trends"]], {
    shinydashboard::updateTabItems(
      session = session,
      inputId = "main_menu",
      selected = "sales_trends"
    )
  }, ignoreNULL = TRUE)
  
  # Removed the problematic session cleanup code that was closing the shared pool
  # The pool should persist across sessions for better performance
  
  # Periodic cache refresh (optional)
  observe({
    invalidateLater(CACHE_REFRESH_MINUTES * 60 * 1000)  # Convert to milliseconds
    
    # Only refresh if cache is older than threshold
    if (!is.null(cache$last_updated) && 
        difftime(Sys.time(), cache$last_updated, units = "mins") > CACHE_REFRESH_MINUTES) {
      
      tryCatch({
        # Ensure pool is still valid before refreshing
        if (!is.null(pool)) {
          # Refresh cached data
          cache$books_summary <- safe_db_query("SELECT * FROM book_sales_summary LIMIT 100")
          cache$last_updated <- Sys.time()
          
          showNotification("Data refreshed", type = "message", duration = 2)
        }
      }, error = function(e) {
        cat("Cache refresh failed:", e$message, "\n")
        # Try to reinitialize pool if cache refresh fails
        pool <<- initialize_db_pool()
      })
    }
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

  # Author networks module (NEW)
  authorNetworksServer("networks_module")

  # Royalty analysis module (NEW)
  royaltyAnalysisServer("royalties_module")

  # Royalty income query module (NEW)
  royaltyQueryServer("royalty_query_module")

  # Genre analysis module
  genreAnalysisServer("genres_module")

}