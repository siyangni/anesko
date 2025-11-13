# American Authorship Database - Authenticated Version
# This version includes authentication using shinymanager
#
# To enable authentication:
# 1. Rename this file to app.R (backup the original first)
# 2. Install shinymanager: install.packages("shinymanager")
# 3. Configure users in config/auth_config.R
# 4. Set environment variable: AUTH_ENABLED=true
#
# For production, also set:
# - AUTH_SOURCE=file or database
# - AUTH_SESSION_TIMEOUT=60 (minutes)
# - Create secure user credentials

# Check dependencies
check_dependencies <- function() {
  required_packages <- c("shiny", "shinydashboard", "shinymanager",
                        "DBI", "RPostgreSQL", "pool", "dplyr",
                        "ggplot2", "plotly", "DT")

  missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]

  if(length(missing_packages) > 0) {
    stop("Missing required packages: ", paste(missing_packages, collapse = ", "),
         "\nPlease install them with: install.packages(c('",
         paste(missing_packages, collapse = "', '"), "'))")
  }
}

# Check dependencies first
tryCatch({
  check_dependencies()
  cat("✅ All required packages are available\n")
}, error = function(e) {
  cat("❌ Dependency check failed:", e$message, "\n")
  stop(e)
})

# Load authentication configuration
source("config/auth_config.R")

# Source all components with error handling
tryCatch({
  source("global.R")
  cat("✅ Global configuration loaded\n")
}, error = function(e) {
  cat("❌ Failed to load global.R:", e$message, "\n")
  stop("Please check your database configuration and ensure PostgreSQL is running")
})

tryCatch({
  source("ui.R")
  cat("✅ UI components loaded\n")
}, error = function(e) {
  cat("❌ Failed to load ui.R:", e$message, "\n")
  stop(e)
})

tryCatch({
  source("server.R")
  cat("✅ Server logic loaded\n")
}, error = function(e) {
  cat("❌ Failed to load server.R:", e$message, "\n")
  stop(e)
})

# =============================================================================
# WRAP UI WITH AUTHENTICATION
# =============================================================================

library(shinymanager)

# Get credentials (from database, file, or demo)
credentials <- get_credentials(pool = if(exists("pool")) pool else NULL)

# Wrap the UI with secure_app
ui_secure <- shinymanager::secure_app(
  ui,
  enable_admin = TRUE,  # Enable admin panel for user management
  language = "en",
  background_image = NULL,  # Optional: add background image path
  choose_language = FALSE
)

# =============================================================================
# WRAP SERVER WITH AUTHENTICATION
# =============================================================================

server_secure <- function(input, output, session) {

  # Call the authentication module
  res_auth <- shinymanager::secure_server(
    check_credentials = shinymanager::check_credentials(credentials)
  )

  # Get authenticated user info
  user_info <- reactive({
    reactiveValuesToList(res_auth)
  })

  # Log authentication event
  observe({
    if (!is.null(user_info()$user)) {
      log_auth_event(
        event = "login_success",
        username = user_info()$user,
        ip_address = session$clientData$url_hostname,
        details = paste("Session:", session$token)
      )
    }
  })

  # Session timeout warning
  observe({
    invalidateLater(AUTH_SESSION_TIMEOUT * 60 * 1000)  # Convert minutes to milliseconds

    # Show warning 5 minutes before timeout
    if (AUTH_SESSION_TIMEOUT > 5) {
      showNotification(
        paste("Your session will expire in", AUTH_SESSION_TIMEOUT, "minutes due to inactivity"),
        type = "warning",
        duration = 10
      )
    }
  })

  # Log logout
  session$onSessionEnded(function() {
    if (!is.null(user_info()$user)) {
      log_auth_event(
        event = "logout",
        username = user_info()$user,
        ip_address = session$clientData$url_hostname,
        details = paste("Session ended:", session$token)
      )
    }
  })

  # Call the original server function
  server(input, output, session)

  # Make user info available globally (optional)
  output$user_info_display <- renderText({
    if (!is.null(user_info()$user)) {
      paste("Logged in as:", user_info()$user)
    } else {
      ""
    }
  })
}

# =============================================================================
# LAUNCH APPLICATION
# =============================================================================

cat("🚀 Starting American Authorship Database Dashboard (Authenticated)...\n")
cat("   Users loaded:", nrow(credentials), "\n")
cat("   Session timeout:", AUTH_SESSION_TIMEOUT, "minutes\n")

tryCatch({
  shinyApp(ui = ui_secure, server = server_secure)
}, error = function(e) {
  cat("❌ Failed to start Shiny app:", e$message, "\n")
  cat("\n🔍 Troubleshooting tips:\n")
  cat("1. Ensure PostgreSQL is running: sudo service postgresql start\n")
  cat("2. Check database credentials in config/app_config.R\n")
  cat("3. Verify database 'american_authorship' exists and is accessible\n")
  cat("4. Check console for additional error messages\n")
  cat("5. Ensure shinymanager package is installed: install.packages('shinymanager')\n")
  stop(e)
})
