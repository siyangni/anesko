# Test App Loading Script
# This tests that all components can be loaded without running the full server

cat("🧪 Testing Shiny app components...\n\n")

# Test 1: Check dependencies
cat("📦 Test 1: Checking dependencies...\n")
required_packages <- c("shiny", "shinydashboard", "DBI", "RPostgreSQL", 
                      "pool", "dplyr", "ggplot2", "plotly", "DT")

missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]

if(length(missing_packages) > 0) {
  cat("❌ Missing packages:", paste(missing_packages, collapse = ", "), "\n")
} else {
  cat("✅ All required packages available\n")
}

# Test 2: Load global configuration
cat("\n🌐 Test 2: Loading global configuration...\n")
tryCatch({
  source("global.R")
  cat("✅ Global configuration loaded successfully\n")
  
  # Check if pool was created
  if (exists("pool") && !is.null(pool)) {
    cat("✅ Database pool created\n")
  } else {
    cat("❌ Database pool not created\n")
  }
}, error = function(e) {
  cat("❌ Global configuration failed:", e$message, "\n")
})

# Test 3: Load UI
cat("\n🎨 Test 3: Loading UI components...\n")
tryCatch({
  source("ui.R")
  cat("✅ UI components loaded successfully\n")
}, error = function(e) {
  cat("❌ UI loading failed:", e$message, "\n")
})

# Test 4: Load server logic
cat("\n⚙️  Test 4: Loading server logic...\n")
tryCatch({
  source("server.R")
  cat("✅ Server logic loaded successfully\n")
}, error = function(e) {
  cat("❌ Server loading failed:", e$message, "\n")
})

# Test 5: Test a database query
cat("\n📊 Test 5: Testing database connectivity...\n")
tryCatch({
  if (exists("safe_db_query") && exists("pool") && !is.null(pool)) {
    test_result <- safe_db_query("SELECT COUNT(*) as count FROM book_entries")
    if (nrow(test_result) > 0) {
      cat("✅ Database query successful - found", test_result$count, "books\n")
    } else {
      cat("❌ Database query returned no results\n")
    }
  } else {
    cat("❌ Database query function or pool not available\n")
  }
}, error = function(e) {
  cat("❌ Database query failed:", e$message, "\n")
})

cat("\n🎯 Component testing complete!\n")
cat("If all tests passed, the app should work when launched.\n") 