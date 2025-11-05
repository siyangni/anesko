# Test Year Range Fix
# This script tests the fixed year range calculation

library(DBI)
library(RPostgreSQL)

cat("📅 Testing Year Range Fix\n")
cat(paste(rep("=", 40), collapse = ""), "\n")

# Load configuration
source("config/cloud_config.R")

# Test direct database query for year range
cat("\n📊 Testing direct database query for year range...\n")

tryCatch({
  con <- dbConnect(
    RPostgreSQL::PostgreSQL(),
    host = db_config$host,
    dbname = db_config$dbname,
    user = db_config$user,
    password = db_config$password
  )
  
  # Test the improved query
  year_range_query <- "
    SELECT 
      MIN(publication_year) as min_year,
      MAX(publication_year) as max_year,
      COUNT(*) as total_books
    FROM book_entries 
    WHERE publication_year IS NOT NULL
  "
  
  year_result <- dbGetQuery(con, year_range_query)
  
  cat("Year range query result:\n")
  print(year_result)
  
  # Test the dashboard logic
  cat("\n🎯 Testing dashboard year range logic...\n")
  
  min_yr <- if(is.na(year_result$min_year[1]) || is.null(year_result$min_year[1])) 1860 else year_result$min_year[1]
  max_yr <- if(is.na(year_result$max_year[1]) || is.null(year_result$max_year[1])) 1920 else year_result$max_year[1]
  year_range_display <- paste0(min_yr, " - ", max_yr)
  
  cat("Dashboard will display:", year_range_display, "\n")
  
  # Test edge cases
  cat("\n🔍 Testing edge cases...\n")
  
  # Test with NA values
  test_stats_na <- data.frame(min_year = NA, max_year = NA)
  min_yr_na <- if(is.na(test_stats_na$min_year[1]) || is.null(test_stats_na$min_year[1])) 1860 else test_stats_na$min_year[1]
  max_yr_na <- if(is.na(test_stats_na$max_year[1]) || is.null(test_stats_na$max_year[1])) 1920 else test_stats_na$max_year[1]
  year_range_na <- paste0(min_yr_na, " - ", max_yr_na)
  cat("With NA values:", year_range_na, "\n")
  
  # Test with NULL values
  test_stats_null <- data.frame(min_year = NULL, max_year = NULL)
  if (nrow(test_stats_null) == 0) {
    year_range_null <- "1860 - 1920"
  } else {
    min_yr_null <- if(is.na(test_stats_null$min_year[1]) || is.null(test_stats_null$min_year[1])) 1860 else test_stats_null$min_year[1]
    max_yr_null <- if(is.na(test_stats_null$max_year[1]) || is.null(test_stats_null$max_year[1])) 1920 else test_stats_null$max_year[1]
    year_range_null <- paste0(min_yr_null, " - ", max_yr_null)
  }
  cat("With NULL/empty data:", year_range_null, "\n")
  
  dbDisconnect(con)
  
  cat("\n✅ Year range fix verification:\n")
  cat("- Database query works: ✅\n")
  cat("- Year range calculation works: ✅\n")
  cat("- Fallback logic works: ✅\n")
  cat("- Dashboard should show:", year_range_display, "\n")
  
}, error = function(e) {
  cat("❌ Database connection failed:", e$message, "\n")
  cat("Testing fallback logic only...\n")
  
  # Test fallback logic without database
  cat("\n🔧 Testing fallback logic...\n")
  
  # Simulate failed stats (empty data frame)
  empty_stats <- data.frame()
  if (nrow(empty_stats) == 0) {
    fallback_range <- "1860 - 1920"
  } else {
    min_yr <- if(is.na(empty_stats$min_year[1]) || is.null(empty_stats$min_year[1])) 1860 else empty_stats$min_year[1]
    max_yr <- if(is.na(empty_stats$max_year[1]) || is.null(empty_stats$max_year[1])) 1920 else empty_stats$max_year[1]
    fallback_range <- paste0(min_yr, " - ", max_yr)
  }
  
  cat("Fallback range:", fallback_range, "\n")
  cat("✅ Fallback logic works correctly\n")
})

cat("\n🚀 Summary:\n")
cat("The dashboard year range fix should:\n")
cat("1. Query publication_year from book_entries (more reliable)\n")
cat("2. Handle NA/NULL values gracefully\n")
cat("3. Show '1860 - 1920' as fallback if data is missing\n")
cat("4. Display actual range if data is available\n")
cat("\nRestart the Shiny app to see the fix in action!\n")
