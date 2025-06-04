# Main Server for American Authorship Dashboard

server <- function(input, output, session) {
  
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
  
  # Module servers
  dashboardServer("dashboard_module")
  bookExplorerServer("books_module")
  salesAnalysisServer("sales_module")
  authorAnalysisServer("authors_module")
  genreAnalysisServer("genres_module")
  
  # Handle navigation
  observeEvent(input$main_menu, {
    tab_name <- input$main_menu
    if (!is.null(tab_name)) {
      # Optional: Add analytics or logging here
      cat("User navigated to:", tab_name, "\n")
    }
  })
  
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
  
} 