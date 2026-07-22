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
cat("🌐 Open: http://127.0.0.1:3838\n\n")

# Safe browser launcher for headless / conda / minimal terminal envs.
# Avoids: Error in utils::browseURL(appUrl): 'browser' must be a non-empty character string
.safe_launch_browser <- function(url) {
  cat("\n🚀 Shiny app running at:\n   ", url, "\n\n")
  browser_opt <- getOption("browser")
  if (is.function(browser_opt)) {
    try(browser_opt(url), silent = TRUE)
    return(invisible(NULL))
  }
  if (is.character(browser_opt) && nzchar(browser_opt)) {
    try(utils::browseURL(url), silent = TRUE)
    return(invisible(NULL))
  }
  xdg <- Sys.which("xdg-open")
  if (nzchar(xdg)) {
    try(system2(xdg, url, wait = FALSE, stdout = FALSE, stderr = FALSE), silent = TRUE)
  }
  invisible(NULL)
}

tryCatch({
  # Host/port MUST be set on shinyApp(options=...), not via options() at the
  # top of this file. runApp() evaluates getOption("shiny.port") BEFORE sourcing
  # app.R, so options(shiny.port=3838) here would be too late and Shiny would
  # pick a random port (e.g. 4296). App-level options are applied after source.
  # See shiny::.setupShinyApp: if (missing(port)) port <- findVal("port", port)
  shinyApp(
    ui = ui,
    server = server,
    options = list(
      host = "127.0.0.1",
      port = 3838,
      launch.browser = .safe_launch_browser
    )
  )
}, error = function(e) {
  cat("❌ Failed to start Shiny app:", e$message, "\n")
  cat("\n🔍 Troubleshooting tips:\n")
  cat("1. Free port 3838 if something else is bound to it\n")
  cat("2. Ensure the database is reachable (Neon or local)\n")
  cat("3. From project root:  shiny::runApp(\"shiny-app/\")\n")
  cat("   or from shiny-app/:  shiny::runApp()\n")
  stop(e)
})

# Alternative command to run from the project root:
# shiny::runApp("shiny-app/")
