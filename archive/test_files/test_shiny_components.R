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
