#!/usr/bin/env Rscript
# Deployment Script for shinyapps.io
# This script automates deployment to Posit's shinyapps.io service

# Load required libraries
if (!requireNamespace("rsconnect", quietly = TRUE)) {
  stop("rsconnect package required. Install with: install.packages('rsconnect')")
}

library(rsconnect)

# =============================================================================
# CONFIGURATION
# =============================================================================

APP_NAME <- "american-authorship-database"
APP_TITLE <- "American Authorship Database (1860-1920)"
APP_DIR <- "shiny-app"

# Account configuration (set via environment variables for security)
ACCOUNT_NAME <- Sys.getenv("SHINYAPPS_ACCOUNT", "")
ACCOUNT_TOKEN <- Sys.getenv("SHINYAPPS_TOKEN", "")
ACCOUNT_SECRET <- Sys.getenv("SHINYAPPS_SECRET", "")

# =============================================================================
# PRE-DEPLOYMENT CHECKS
# =============================================================================

cat("🚀 American Authorship Database - shinyapps.io Deployment\n\n")

# Check 1: Account credentials
if (ACCOUNT_NAME == "" || ACCOUNT_TOKEN == "" || ACCOUNT_SECRET == "") {
  cat("❌ Missing shinyapps.io credentials\n\n")
  cat("Please set environment variables:\n")
  cat("  export SHINYAPPS_ACCOUNT='your-account-name'\n")
  cat("  export SHINYAPPS_TOKEN='your-token'\n")
  cat("  export SHINYAPPS_SECRET='your-secret'\n\n")
  cat("Get credentials from: https://www.shinyapps.io/admin/#/tokens\n")
  stop("Missing credentials")
}

# Check 2: App directory exists
if (!dir.exists(APP_DIR)) {
  stop(sprintf("App directory not found: %s", APP_DIR))
}

# Check 3: Required files exist
required_files <- c(
  file.path(APP_DIR, "app.R"),
  file.path(APP_DIR, "ui.R"),
  file.path(APP_DIR, "server.R"),
  file.path(APP_DIR, "global.R")
)

missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0) {
  cat("❌ Missing required files:\n")
  cat(paste("  -", missing_files, collapse = "\n"), "\n")
  stop("Missing files")
}

cat("✅ Pre-deployment checks passed\n\n")

# =============================================================================
# AUTHENTICATION
# =============================================================================

cat("🔐 Authenticating with shinyapps.io...\n")

tryCatch({
  rsconnect::setAccountInfo(
    name = ACCOUNT_NAME,
    token = ACCOUNT_TOKEN,
    secret = ACCOUNT_SECRET
  )
  cat("✅ Authentication successful\n\n")
}, error = function(e) {
  cat("❌ Authentication failed:", e$message, "\n")
  stop("Authentication error")
})

# =============================================================================
# PACKAGE DEPENDENCIES
# =============================================================================

cat("📦 Checking package dependencies...\n")

# Get packages from DESCRIPTION file
if (file.exists("DESCRIPTION")) {
  deps <- desc::desc_get_deps()
  required_pkgs <- deps$package[deps$type %in% c("Imports", "Depends")]

  cat(sprintf("Found %d required packages\n", length(required_pkgs)))

  # Check if all packages are installed
  missing <- required_pkgs[!(required_pkgs %in% installed.packages()[,"Package"])]

  if (length(missing) > 0) {
    cat("⚠️  Missing packages (will be installed on shinyapps.io):\n")
    cat(paste("  -", missing, collapse = "\n"), "\n")
  }
}

cat("✅ Dependencies checked\n\n")

# =============================================================================
# DEPLOYMENT
# =============================================================================

cat("🚀 Starting deployment to shinyapps.io...\n")
cat(sprintf("   Account: %s\n", ACCOUNT_NAME))
cat(sprintf("   App name: %s\n", APP_NAME))
cat(sprintf("   Directory: %s\n", APP_DIR))
cat("\n")

deploy_start <- Sys.time()

tryCatch({
  rsconnect::deployApp(
    appDir = APP_DIR,
    appName = APP_NAME,
    appTitle = APP_TITLE,
    account = ACCOUNT_NAME,
    forceUpdate = TRUE,
    launch.browser = FALSE,
    logLevel = "verbose"
  )

  deploy_duration <- as.numeric(difftime(Sys.time(), deploy_start, units = "secs"))

  cat("\n")
  cat("✅ Deployment successful!\n")
  cat(sprintf("   Duration: %.0f seconds\n", deploy_duration))
  cat(sprintf("   URL: https://%s.shinyapps.io/%s/\n", ACCOUNT_NAME, APP_NAME))
  cat("\n")

  # Show application info
  app_info <- rsconnect::showProperties(
    appPath = APP_DIR,
    appName = APP_NAME,
    account = ACCOUNT_NAME
  )

  cat("📊 Application Properties:\n")
  cat(sprintf("   Status: %s\n", app_info$status))
  cat(sprintf("   Instance: %s\n", app_info$size))
  cat(sprintf("   Updated: %s\n", app_info$updated_time))

}, error = function(e) {
  cat("\n❌ Deployment failed:\n")
  cat(e$message, "\n\n")

  cat("Common issues:\n")
  cat("  1. Invalid credentials - check your token and secret\n")
  cat("  2. Missing packages - ensure all dependencies are in DESCRIPTION\n")
  cat("  3. Database connection - configure environment variables on shinyapps.io\n")
  cat("  4. File size limits - check if app exceeds size limits\n")

  stop("Deployment error")
})

# =============================================================================
# POST-DEPLOYMENT CONFIGURATION
# =============================================================================

cat("\n📝 Post-deployment checklist:\n\n")

cat("1. Configure environment variables on shinyapps.io:\n")
cat("   - Go to: https://www.shinyapps.io/admin/#/application/%s\n", APP_NAME)
cat("   - Add: DB_HOST, DB_NAME, DB_USER, DB_PASSWORD\n")
cat("   - Add: AUTH_SOURCE=demo (or file/database)\n\n")

cat("2. Configure application settings:\n")
cat("   - Instance size: Select appropriate size based on expected users\n")
cat("   - Idle timeout: Recommended 30-60 minutes\n")
cat("   - Max processes: Recommended 3-5 for production\n\n")

cat("3. Test the application:\n")
cat("   - Visit: https://%s.shinyapps.io/%s/\n", ACCOUNT_NAME, APP_NAME)
cat("   - Verify database connection\n")
cat("   - Test all modules\n\n")

cat("4. Monitor usage:\n")
cat("   - Check metrics: https://www.shinyapps.io/admin/#/dashboard\n")
cat("   - Set up alerts for errors or high usage\n\n")

cat("Done! 🎉\n")
