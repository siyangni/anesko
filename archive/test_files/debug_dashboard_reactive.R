# Debug Dashboard Reactive Functions
# This script simulates the exact dashboard reactive logic to find the issue

library(dplyr)

cat("🔍 Debugging Dashboard Reactive Functions\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Load all required components
source("config/cloud_config.R")
source("utils/database.R")

# Test 1: Test get_summary_stats function directly
cat("\n📊 Testing get_summary_stats function...\n")

summary_result <- tryCatch({
  get_summary_stats()
}, error = function(e) {
  cat("❌ get_summary_stats failed:", e$message, "\n")
  return(NULL)
})

if (!is.null(summary_result) && nrow(summary_result) > 0) {
  cat("✅ get_summary_stats returned data:\n")
  print(summary_result)
  cat("\nColumn types:\n")
  print(sapply(summary_result, class))
  cat("\nmin_year:", summary_result$min_year, "(class:", class(summary_result$min_year), ")\n")
  cat("max_year:", summary_result$max_year, "(class:", class(summary_result$max_year), ")\n")
  cat("Is min_year NA?", is.na(summary_result$min_year), "\n")
  cat("Is max_year NA?", is.na(summary_result$max_year), "\n")
} else {
  cat("❌ get_summary_stats failed or returned no data\n")
  summary_result <- data.frame(
    total_books = 0, total_sales_records = 0, unique_authors = 0,
    unique_publishers = 0, min_year = 1860, max_year = 1920,
    total_copies_sold = 0
  )
  cat("Using fallback data:\n")
  print(summary_result)
}

# Test 2: Simulate the exact dashboard reactive logic
cat("\n🎯 Simulating dashboard reactive logic...\n")

# This is exactly what the dashboard reactive does
stats_reactive_result <- tryCatch({
  get_summary_stats()
}, error = function(e) {
  warning("Failed to load summary statistics: ", e$message)
  data.frame(
    total_books = 0, total_sales_records = 0, unique_authors = 0,
    unique_publishers = 0, min_year = 1860, max_year = 1920,
    total_copies_sold = 0
  )
})

cat("Reactive result:\n")
print(stats_reactive_result)

# Test 3: Simulate the exact value box calculation
cat("\n📅 Simulating year range value box calculation...\n")

stats <- stats_reactive_result  # This is what stats() returns in the dashboard

# This is the exact logic from the dashboard
year_range_value <- {
  min_yr <- if(is.na(stats$min_year[1]) || is.null(stats$min_year[1])) 1860 else stats$min_year[1]
  max_yr <- if(is.na(stats$max_year[1]) || is.null(stats$max_year[1])) 1920 else stats$max_year[1]
  paste0(min_yr, " - ", max_yr)
}

cat("Year range value that should appear in dashboard:", year_range_value, "\n")

# Test 4: Check for potential issues with data frame structure
cat("\n🔍 Checking data frame structure issues...\n")

cat("Number of rows in stats:", nrow(stats), "\n")
cat("Number of columns in stats:", ncol(stats), "\n")
cat("Column names:", paste(colnames(stats), collapse = ", "), "\n")

if (nrow(stats) == 0) {
  cat("❌ ISSUE FOUND: stats data frame is empty!\n")
  cat("This would cause stats$min_year[1] to be NA\n")
} else if (!"min_year" %in% colnames(stats)) {
  cat("❌ ISSUE FOUND: min_year column missing from stats!\n")
} else if (!"max_year" %in% colnames(stats)) {
  cat("❌ ISSUE FOUND: max_year column missing from stats!\n")
} else {
  cat("✅ Data frame structure looks correct\n")
}

# Test 5: Check if the issue is with indexing
cat("\n🔢 Testing indexing issues...\n")

if (nrow(stats) > 0) {
  cat("stats$min_year:", stats$min_year, "\n")
  cat("stats$min_year[1]:", stats$min_year[1], "\n")
  cat("stats$max_year:", stats$max_year, "\n")
  cat("stats$max_year[1]:", stats$max_year[1], "\n")
  
  # Test the exact conditions
  cat("is.na(stats$min_year[1]):", is.na(stats$min_year[1]), "\n")
  cat("is.null(stats$min_year[1]):", is.null(stats$min_year[1]), "\n")
  cat("is.na(stats$max_year[1]):", is.na(stats$max_year[1]), "\n")
  cat("is.null(stats$max_year[1]):", is.null(stats$max_year[1]), "\n")
} else {
  cat("Cannot test indexing - data frame is empty\n")
}

# Test 6: Alternative approach - check if we need to handle empty data frames differently
cat("\n🛠️ Testing alternative approaches...\n")

# Alternative 1: Check for empty data frame first
if (nrow(stats) == 0 || is.null(stats) || all(is.na(stats))) {
  alt_year_range_1 <- "1860 - 1920"
  cat("Alternative 1 (empty check first):", alt_year_range_1, "\n")
} else {
  min_yr <- if(is.na(stats$min_year[1]) || is.null(stats$min_year[1])) 1860 else stats$min_year[1]
  max_yr <- if(is.na(stats$max_year[1]) || is.null(stats$max_year[1])) 1920 else stats$max_year[1]
  alt_year_range_1 <- paste0(min_yr, " - ", max_yr)
  cat("Alternative 1 (with data):", alt_year_range_1, "\n")
}

# Alternative 2: Use safer indexing
safe_min_year <- if(length(stats$min_year) > 0 && !is.na(stats$min_year[1])) stats$min_year[1] else 1860
safe_max_year <- if(length(stats$max_year) > 0 && !is.na(stats$max_year[1])) stats$max_year[1] else 1920
alt_year_range_2 <- paste0(safe_min_year, " - ", safe_max_year)
cat("Alternative 2 (safer indexing):", alt_year_range_2, "\n")

cat("\n💡 Debugging Summary:\n")
cat("If get_summary_stats works but dashboard shows NA:\n")
cat("1. Check if reactive function is actually being called\n")
cat("2. Check if there are JavaScript errors in browser console\n")
cat("3. Check if the value box rendering is failing\n")
cat("4. The issue might be in the UI rendering, not the data\n")

cat("\n🔧 Recommended fix based on findings:\n")
if (nrow(stats) == 0) {
  cat("- The reactive is returning empty data - fix the database query\n")
} else if (year_range_value == "1860 - 1920") {
  cat("- Data is NA - the database query needs improvement\n")
} else {
  cat("- Data looks correct - the issue might be in UI rendering\n")
  cat("- Try the safer indexing approach (Alternative 2)\n")
}
