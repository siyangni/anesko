#!/usr/bin/env Rscript

# =============================================================================
# Shiny App Deployment Script to shinyapps.io
# =============================================================================
# 
# This script deploys the R Shiny application to shinyapps.io using the
# provided credentials. It includes error handling, dependency checking,
# and deployment verification.
#
# Usage: Rscript deploy_shiny.R [app_directory] [app_name]
# 
# Prerequisites:
# - R with rsconnect package installed
# - Shiny app files in the specified directory
# - Network connectivity to shinyapps.io
# 
# Author: Generated for anesko project
# Date: Sys.Date()
# =============================================================================

# Load required libraries
suppressPackageStartupMessages({
  if (!require(rsconnect, quietly = TRUE)) {
    stop("rsconnect package is required. Install with: install.packages('rsconnect')")
  }
})

# Color output functions for console
cat_info <- function(msg) {
  cat("\033[34m[INFO]\033[0m", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "-", msg, "\n")
}

cat_success <- function(msg) {
  cat("\033[32m[SUCCESS]\033[0m", msg, "\n")
}

cat_warning <- function(msg) {
  cat("\033[33m[WARNING]\033[0m", msg, "\n")
}

cat_error <- function(msg) {
  cat("\033[31m[ERROR]\033[0m", msg, "\n")
}

# Function to check if required environment variables are set
check_env_vars <- function() {
  cat_info("Checking required environment variables...")

  required_vars <- c("SHINY_ACCOUNT_NAME", "SHINY_TOKEN", "SHINY_SECRET")
  missing_vars <- c()

  for (var in required_vars) {
    if (Sys.getenv(var) == "") {
      missing_vars <- c(missing_vars, var)
    }
  }

  if (length(missing_vars) > 0) {
    cat_error(paste("Missing required environment variables:", paste(missing_vars, collapse = ", ")))
    cat("Please set these environment variables before running this script.\n")
    cat("You can use the .env.template file as a reference:\n")
    cat("  1. Copy .env.template to .env: cp scripts/deployment/.env.template scripts/deployment/.env\n")
    cat("  2. Edit .env with your actual credentials\n")
    cat("  3. Source the environment: source scripts/deployment/.env\n")
    cat("\n")
    stop("Missing required environment variables")
  }

  cat_success("All required environment variables are set")
}

# Function to check if required packages are installed
check_dependencies <- function() {
  cat_info("Checking required packages...")

  required_packages <- c("rsconnect", "shiny")
  missing_packages <- c()

  for (pkg in required_packages) {
    if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
      missing_packages <- c(missing_packages, pkg)
    }
  }

  if (length(missing_packages) > 0) {
    cat_error(paste("Missing required packages:", paste(missing_packages, collapse = ", ")))
    cat("Install missing packages with:")
    cat("install.packages(c(", paste0("'", missing_packages, "'", collapse = ", "), "))\n")
    stop("Missing required packages")
  }

  cat_success("All required packages are installed")
}

# Function to setup shinyapps.io account
setup_account <- function() {
  cat_info("Setting up shinyapps.io account credentials...")

  # Get credentials from environment variables
  account_name <- Sys.getenv("SHINY_ACCOUNT_NAME")
  token <- Sys.getenv("SHINY_TOKEN")
  secret <- Sys.getenv("SHINY_SECRET")

  tryCatch({
    rsconnect::setAccountInfo(
      name = account_name,
      token = token,
      secret = secret
    )
    cat_success(paste("Account credentials configured successfully for:", account_name))
  }, error = function(e) {
    cat_error(paste("Failed to set account credentials:", e$message))
    stop("Account setup failed")
  })
}

# Function to validate app directory
validate_app_directory <- function(app_dir) {
  cat_info(paste("Validating app directory:", app_dir))
  
  if (!dir.exists(app_dir)) {
    cat_error(paste("App directory does not exist:", app_dir))
    stop("Invalid app directory")
  }
  
  # Check for required Shiny files
  required_files <- c("app.R", "ui.R", "server.R")
  found_files <- c()
  
  for (file in required_files) {
    if (file.exists(file.path(app_dir, file))) {
      found_files <- c(found_files, file)
    }
  }
  
  if (length(found_files) == 0) {
    cat_error("No Shiny app files found (app.R, ui.R, or server.R)")
    stop("Invalid Shiny app directory")
  }
  
  cat_success(paste("Found Shiny files:", paste(found_files, collapse = ", ")))
  return(found_files)
}

# Function to check app dependencies
check_app_dependencies <- function(app_dir) {
  cat_info("Checking app dependencies...")
  
  # Look for common dependency files
  dep_files <- c("renv.lock", "DESCRIPTION", "requirements.R")
  found_dep_files <- c()
  
  for (file in dep_files) {
    if (file.exists(file.path(app_dir, file))) {
      found_dep_files <- c(found_dep_files, file)
    }
  }
  
  if (length(found_dep_files) > 0) {
    cat_info(paste("Found dependency files:", paste(found_dep_files, collapse = ", ")))
  } else {
    cat_warning("No dependency files found. Make sure all required packages are installed.")
  }
}

# Function to deploy the app
deploy_app <- function(app_dir, app_name = NULL) {
  cat_info("Starting deployment to shinyapps.io...")
  
  # If no app name provided, use directory name
  if (is.null(app_name)) {
    app_name <- basename(normalizePath(app_dir))
  }
  
  cat_info(paste("App name:", app_name))
  cat_info(paste("App directory:", app_dir))
  
  tryCatch({
    # Deploy the application
    rsconnect::deployApp(
      appDir = app_dir,
      appName = app_name,
      account = Sys.getenv("SHINY_ACCOUNT_NAME"),
      forceUpdate = TRUE,
      launch.browser = FALSE
    )
    
    cat_success("Deployment completed successfully!")
    
    # Get app URL
    app_url <- paste0("https://", Sys.getenv("SHINY_ACCOUNT_NAME"), ".shinyapps.io/", app_name)
    cat_success(paste("App URL:", app_url))
    
    return(app_url)
    
  }, error = function(e) {
    cat_error(paste("Deployment failed:", e$message))
    stop("Deployment failed")
  })
}

# Function to show deployment status
show_deployment_status <- function() {
  cat_info("Checking deployment status...")
  
  tryCatch({
    apps <- rsconnect::applications()
    if (nrow(apps) > 0) {
      cat_success("Current deployed applications:")
      print(apps[, c("name", "url", "status")])
    } else {
      cat_info("No applications currently deployed")
    }
  }, error = function(e) {
    cat_warning(paste("Could not retrieve deployment status:", e$message))
  })
}

# Function to show help
show_help <- function() {
  cat("Shiny App Deployment Script\n")
  cat("===========================\n\n")
  cat("Usage: Rscript deploy_shiny.R [COMMAND] [OPTIONS]\n\n")
  cat("Commands:\n")
  cat("  deploy [app_dir] [app_name]  Deploy Shiny app (default)\n")
  cat("  status                       Show deployment status\n")
  cat("  help                         Show this help message\n\n")
  cat("Options:\n")
  cat("  app_dir    Path to Shiny app directory (default: current directory)\n")
  cat("  app_name   Name for the deployed app (default: directory name)\n\n")
  cat("Examples:\n")
  cat("  Rscript deploy_shiny.R                    # Deploy current directory\n")
  cat("  Rscript deploy_shiny.R deploy ./my_app    # Deploy specific directory\n")
  cat("  Rscript deploy_shiny.R deploy ./my_app my_custom_name\n")
  cat("  Rscript deploy_shiny.R status             # Check deployment status\n")
}

# Main function
main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  
  # Parse command line arguments
  command <- if (length(args) >= 1) args[1] else "deploy"
  
  if (command %in% c("help", "-h", "--help")) {
    show_help()
    return()
  }
  
  cat_info("Starting Shiny deployment script...")

  # Check environment variables
  check_env_vars()

  # Check dependencies
  check_dependencies()

  # Setup account
  setup_account()
  
  if (command == "status") {
    show_deployment_status()
    return()
  }
  
  if (command == "deploy" || length(args) == 0) {
    # Get app directory and name
    app_dir <- if (length(args) >= 2) args[2] else "."
    app_name <- if (length(args) >= 3) args[3] else NULL
    
    # Validate and deploy
    validate_app_directory(app_dir)
    check_app_dependencies(app_dir)
    app_url <- deploy_app(app_dir, app_name)
    
    cat_success("Deployment process completed!")
    cat_info("You can now access your app at the provided URL.")
    
  } else {
    cat_error(paste("Unknown command:", command))
    cat("Use 'Rscript deploy_shiny.R help' for usage information.")
    quit(status = 1)
  }
}

# Run main function if script is executed directly
if (!interactive()) {
  main()
}
