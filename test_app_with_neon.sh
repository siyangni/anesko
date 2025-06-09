#!/bin/bash

# Test Shiny App with Neon PostgreSQL
# This script configures and tests your app with the cloud database

echo "🧪 Testing Shiny App with Neon PostgreSQL"
echo "========================================="
echo ""

# Check if .env file exists
if [ ! -f "shiny-app/.env" ]; then
    echo "❌ Neon configuration not found. Please run ./setup_neon.sh first"
    exit 1
fi

echo "🔧 Step 1: Updating app configuration for cloud database..."

# Update the app configuration to use environment variables
cat > "shiny-app/config/cloud_config.R" << 'EOF'
# Cloud Database Configuration
# This configuration loads database credentials from environment variables

# Load environment variables from .env file if it exists
if (file.exists(".env")) {
  env_vars <- readLines(".env")
  env_vars <- env_vars[!grepl("^#", env_vars) & env_vars != "" & !grepl("^\\s*$", env_vars)]
  
  for (var in env_vars) {
    if (nchar(trimws(var)) > 0 && grepl("=", var)) {
      parts <- strsplit(var, "=", fixed = TRUE)[[1]]
      if (length(parts) >= 2) {
        key <- trimws(parts[1])
        value <- trimws(paste(parts[-1], collapse = "="))
        if (nchar(key) > 0 && nchar(value) > 0) {
          do.call(Sys.setenv, setNames(list(value), key))
        }
      }
    }
  }
}

# Database configuration using environment variables
db_config <- list(
  host = Sys.getenv("DB_HOST", "localhost"),
  dbname = Sys.getenv("DB_NAME", "american_authorship"),
  user = Sys.getenv("DB_USER", "siyang"),
  password = Sys.getenv("DB_PASSWORD", ""),
  port = as.numeric(Sys.getenv("DB_PORT", "5432"))
)

# Validate configuration
if (db_config$host == "localhost" || db_config$password == "") {
  warning("Database configuration may not be properly set for cloud deployment.")
}

cat("🔗 Database configuration loaded:\n")
cat("   Host:", db_config$host, "\n")
cat("   Database:", db_config$dbname, "\n")
cat("   User:", db_config$user, "\n")
cat("   Port:", db_config$port, "\n")
EOF

echo "✅ Created cloud database configuration"

# Update app_config.R to use cloud config
if [ -f "shiny-app/config/app_config.R" ]; then
    # Backup original config
    cp "shiny-app/config/app_config.R" "shiny-app/config/app_config_local_backup.R"
    
    # Update app_config.R to source cloud config
    cat > "shiny-app/config/app_config.R" << 'EOF'
# Application Configuration
# Updated for cloud database deployment

# App metadata
APP_TITLE <- "American Authorship Database (1860-1920)"
APP_VERSION <- "1.0.0"
APP_DESCRIPTION <- "Interactive dashboard for exploring American literary marketplace data"

# Load cloud database configuration
source("config/cloud_config.R")

# Connection pool settings
POOL_SIZE_MIN <- 1
POOL_SIZE_MAX <- 5  # Neon handles more connections than ElephantSQL
POOL_IDLE_TIMEOUT <- 60

# Data refresh settings
CACHE_REFRESH_MINUTES <- 30
DEFAULT_PAGE_SIZE <- 25

# Plot settings
DEFAULT_PLOT_HEIGHT <- 400
DEFAULT_PLOT_WIDTH <- 800

# Date ranges
MIN_YEAR <- 1860
MAX_YEAR <- 1920
DEFAULT_YEAR_RANGE <- c(1880, 1910)

# UI settings
SIDEBAR_WIDTH <- 300
NAVBAR_FIXED <- TRUE

# Feature flags
ENABLE_DOWNLOADS <- TRUE
ENABLE_BOOKMARKS <- TRUE
ENABLE_TOOLTIPS <- TRUE

# Text constants
ABOUT_TEXT <- "
This dashboard provides interactive exploration of the American Authorship Database (1860-1920), 
a comprehensive collection of publishing and sales data from major American publishers during 
the transformative period of the late 19th and early 20th centuries.

**Data Sources:**
- Houghton, Mifflin Co. and predecessors (Harvard University)
- Harper & Brothers (Chadwyck-Healey Microfilm)  
- Scribner Archive (Princeton University)
- J. B. Lippincott Deposit (University of Pennsylvania)

**Principal Investigator:** Dr. Michael Anesko (Penn State University)
"

METHODOLOGY_TEXT <- "
**Data Collection:**
All data has been hand-transcribed from original publisher archives, including sales records, 
royalty statements, and contract information.

**Coverage:**
- 630+ book entries with comprehensive metadata
- 63 years of sales data (1858-1920)
- Focus on major publishers and commercially successful works

**Validation:**
Data has been cross-referenced across multiple sources where possible to ensure accuracy.
"
EOF

    echo "✅ Updated app configuration for cloud database"
fi

echo ""
echo "🧪 Step 2: Testing app components..."

# Test database connection
cat > "test_shiny_components.R" << 'EOF'
# Test Shiny App Components with Neon PostgreSQL
setwd("shiny-app")

# Test 1: Load configuration
cat("📋 Test 1: Loading configuration...\n")
tryCatch({
  source("config/app_config.R")
  cat("✅ Configuration loaded successfully\n")
  cat("   Using database:", db_config$host, "\n")
}, error = function(e) {
  cat("❌ Configuration error:", e$message, "\n")
  quit(status = 1)
})

# Test 2: Load required packages
cat("\n📦 Test 2: Loading packages...\n")
required_packages <- c("shiny", "shinydashboard", "DBI", "RPostgreSQL", "pool", "dplyr", "ggplot2", "plotly", "DT")
missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]

if(length(missing_packages) > 0) {
  cat("❌ Missing packages:", paste(missing_packages, collapse = ", "), "\n")
  cat("Installing missing packages...\n")
  install.packages(missing_packages)
}
cat("✅ All packages available\n")

# Test 3: Load global.R
cat("\n🌐 Test 3: Loading global.R...\n")
tryCatch({
  source("global.R")
  cat("✅ Global configuration loaded\n")
}, error = function(e) {
  cat("❌ Global loading error:", e$message, "\n")
  quit(status = 1)
})

# Test 4: Test database connection
cat("\n🔗 Test 4: Testing database connection...\n")
tryCatch({
  if (exists("pool") && !is.null(pool)) {
    # Test a simple query
    result <- pool::dbGetQuery(pool, "SELECT COUNT(*) as count FROM book_entries")
    cat("✅ Database connection successful\n")
    cat("   Found", result$count, "books in database\n")
    
    # Test view
    summary_result <- pool::dbGetQuery(pool, "SELECT COUNT(*) as count FROM book_sales_summary LIMIT 1")
    cat("   Summary view accessible:", summary_result$count, "records\n")
    
  } else {
    cat("❌ Database pool not created\n")
  }
}, error = function(e) {
  cat("❌ Database connection error:", e$message, "\n")
})

# Test 5: Test utility functions
cat("\n⚙️  Test 5: Testing utility functions...\n")
tryCatch({
  # Test safe_db_query function
  test_result <- safe_db_query("SELECT 1 as test")
  if (!is.null(test_result) && nrow(test_result) > 0) {
    cat("✅ Database utilities working\n")
  } else {
    cat("⚠️  Database utilities may have issues\n")
  }
}, error = function(e) {
  cat("❌ Utility function error:", e$message, "\n")
})

cat("\n🎉 Component testing complete!\n")
cat("\nIf all tests passed, your app should work with Neon PostgreSQL.\n")
EOF

cd shiny-app && Rscript ../test_shiny_components.R
cd ..

echo ""
echo "🚀 Step 3: Starting app for local testing..."
echo ""
echo "📍 The app will start on http://localhost:3838"
echo "📍 Press Ctrl+C to stop the app when done testing"
echo ""

read -p "Start the app now? (y/n): " start_app

if [ "$start_app" = "y" ]; then
    echo "🎬 Starting Shiny app with Neon PostgreSQL..."
    echo ""
    
    cd shiny-app
    R -e "shiny::runApp(port = 3838, host = '0.0.0.0')"
    cd ..
else
    echo "ℹ️  To test manually, run:"
    echo "   cd shiny-app"
    echo "   R -e \"shiny::runApp()\""
fi

echo ""
echo "📝 Next steps after testing:"
echo "1. If app works correctly, proceed to ShinyApps.io deployment"
echo "2. If there are issues, check the troubleshooting guide"
echo "3. Run: ./deploy_to_shinyapps.sh" 