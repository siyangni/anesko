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

# Safe browser launcher for headless / conda / minimal terminal envs.
# Avoids: Error in utils::browseURL(appUrl): 'browser' must be a non-empty character string
.safe_launch_browser <- function(url) {
  cat("\n🚀 Shiny app running at:\n   ", url, "\n")
  cat("   Press Ctrl+C in this terminal to stop and free the port.\n\n")
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

# NOTE: If server.R exists in this directory, shiny::runApp("shiny-app/") uses
# global.R/ui.R/server.R and IGNORES this file. Port defaults for that path are
# set in .Rprofile (options(shiny.port)). This app.R path is only used when
# server.R is absent, or when this file is sourced/run directly.
#
# Prefer 3838 when free; otherwise bind any free port so restarts never fail
# with "address already in use". Host/port MUST be set on shinyApp(options=...),
# not via options() at the top of this file — runApp() reads getOption("shiny.port")
# BEFORE sourcing app.R. App-level options are applied after source only when
# runApp()'s port argument is missing.
.find_shiny_port <- function(preferred = 3838L, host = "127.0.0.1") {
  preferred <- as.integer(preferred)
  can_bind <- function(port) {
    srv <- tryCatch(
      httpuv::startServer(host, port, list(call = function(req) NULL), quiet = TRUE),
      error = function(e) NULL
    )
    if (is.null(srv)) {
      return(FALSE)
    }
    try(httpuv::stopServer(srv), silent = TRUE)
    TRUE
  }

  if (can_bind(preferred)) {
    cat("🌐 Preferred port", preferred, "is free\n")
    return(preferred)
  }

  free_port <- httpuv::randomPort(min = 3000L, max = 8999L, host = host)
  cat("⚠️  Port", preferred, "is in use; using free port", free_port, "instead\n")
  as.integer(free_port)
}

tryCatch({
  app_host <- "127.0.0.1"
  app_port <- .find_shiny_port(preferred = 3838L, host = app_host)
  cat("🌐 Will listen on: http://", app_host, ":", app_port, "\n\n", sep = "")

  shinyApp(
    ui = ui,
    server = server,
    options = list(
      host = app_host,
      port = app_port,
      launch.browser = .safe_launch_browser
    )
  )
}, error = function(e) {
  cat("❌ Failed to start Shiny app:", e$message, "\n")
  cat("\n🔍 Troubleshooting tips:\n")
  cat("1. Stop any leftover Shiny/R process still holding a port\n")
  cat("   e.g.  ss -tlnp | grep R   or   fuser -k 3838/tcp\n")
  cat("2. Ensure the database is reachable (Neon or local)\n")
  cat("3. From project root:  shiny::runApp(\"shiny-app/\")\n")
  cat("   or from shiny-app/:  shiny::runApp()\n")
  cat("4. Do not pass a fixed port=... unless you need one; the app\n")
  cat("   auto-selects a free port (prefers 3838).\n")
  stop(e)
})

# Alternative command to run from the project root:
# shiny::runApp("shiny-app/")
