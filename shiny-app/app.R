#install.packages(c("shiny", "shinydashboard", "DBI", "RPostgreSQL", 
#                  "pool", "dplyr", "ggplot2", "plotly", "DT"))

# American Authorship Database Dashboard
# Main application entry point

# Function to check if all required packages are available
check_dependencies <- function() {
  required_packages <- c("shiny", "shinydashboard", "DBI", "RPostgreSQL", 
                        "pool", "dplyr", "ggplot2", "plotly", "DT")
  
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

# Launch the application with error handling
cat("🚀 Starting American Authorship Database Dashboard...\n")

tryCatch({
  shinyApp(ui = ui, server = server)
}, error = function(e) {
  cat("❌ Failed to start Shiny app:", e$message, "\n")
  cat("\n🔍 Troubleshooting tips:\n")
  cat("1. Ensure PostgreSQL is running: sudo service postgresql start\n")
  cat("2. Check database credentials in config/app_config.R\n")
  cat("3. Verify database 'american_authorship' exists and is accessible\n")
  cat("4. Check console for additional error messages\n")
  stop(e)
})

# Alternative command to run from the project root:
# shiny::runApp("shiny-app/")
