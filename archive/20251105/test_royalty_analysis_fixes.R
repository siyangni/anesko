# Test Royalty Analysis Fixes
# This script tests the fixes for the royalty analysis module

library(dplyr)
library(DT)

cat("🔧 Testing Royalty Analysis Fixes\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Load configuration and utilities
source("config/cloud_config.R")
source("utils/database.R")
source("utils/data_processing.R")

# Test 1: Test analyze_royalty_patterns with empty data
cat("\n📊 Testing analyze_royalty_patterns with empty data...\n")
tryCatch({
  empty_result <- analyze_royalty_patterns(data.frame())
  if (is.data.frame(empty_result) && nrow(empty_result) == 0) {
    cat("✅ analyze_royalty_patterns handles empty data correctly\n")
  } else {
    cat("❌ analyze_royalty_patterns did not handle empty data properly\n")
  }
}, error = function(e) {
  cat("❌ analyze_royalty_patterns failed with empty data:", e$message, "\n")
})

# Test 2: Test analyze_royalty_patterns with missing columns
cat("\n📊 Testing analyze_royalty_patterns with missing columns...\n")
tryCatch({
  bad_data <- data.frame(tier = 1, book_id = "test")
  bad_result <- analyze_royalty_patterns(bad_data)
  if (is.data.frame(bad_result) && nrow(bad_result) == 0) {
    cat("✅ analyze_royalty_patterns handles missing columns correctly\n")
  } else {
    cat("❌ analyze_royalty_patterns did not handle missing columns properly\n")
  }
}, error = function(e) {
  cat("❌ analyze_royalty_patterns failed with missing columns:", e$message, "\n")
})

# Test 3: Test with real royalty data if available
cat("\n📚 Testing with real royalty database data...\n")
tryCatch({
  # Try to get some real royalty data
  test_query <- "
    SELECT 
      rt.*,
      be.book_title,
      be.author_surname,
      be.author_id,
      be.publisher,
      be.genre,
      be.publication_year,
      be.retail_price,
      COALESCE(bs.total_sales, 0) as total_sales
    FROM royalty_tiers rt
    JOIN book_entries be ON rt.book_id = be.book_id
    LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
    WHERE be.publication_year BETWEEN 1860 AND 1920
    LIMIT 20
  "
  
  test_data <- safe_db_query(test_query)
  
  if (!is.null(test_data) && nrow(test_data) > 0) {
    cat("✅ Retrieved", nrow(test_data), "royalty records from database\n")
    cat("📋 Columns:", paste(names(test_data), collapse = ", "), "\n")
    
    # Test analyze_royalty_patterns with real data
    analysis_result <- analyze_royalty_patterns(test_data)
    if (!is.null(analysis_result) && nrow(analysis_result) > 0) {
      cat("✅ analyze_royalty_patterns works with real data\n")
      cat("   - Tiers analyzed:", nrow(analysis_result), "\n")
      cat("   - Columns in result:", paste(names(analysis_result), collapse = ", "), "\n")
      
      # Test if we can format the data like the module does
      tryCatch({
        formatted_result <- analysis_result %>%
          select(
            Tier = tier,
            `Book Count` = book_count,
            `Avg Rate` = avg_rate,
            `Min Rate` = min_rate,
            `Max Rate` = max_rate,
            `Sliding Scale %` = sliding_scale_pct
          ) %>%
          mutate(
            `Avg Rate` = paste0(round(`Avg Rate` * 100, 1), "%"),
            `Rate Range` = paste0(round(`Min Rate` * 100, 1), "% - ", round(`Max Rate` * 100, 1), "%"),
            `Sliding Scale %` = paste0(round(`Sliding Scale %`, 1), "%")
          ) %>%
          select(Tier, `Book Count`, `Avg Rate`, `Rate Range`, `Sliding Scale %`)
        
        cat("✅ Data formatting works correctly\n")
        cat("📊 Sample formatted data:\n")
        print(head(formatted_result, 3))
        
      }, error = function(e) {
        cat("❌ Data formatting failed:", e$message, "\n")
      })
      
    } else {
      cat("❌ analyze_royalty_patterns failed with real data\n")
    }
  } else {
    cat("⚠️  No royalty data available from database\n")
  }
}, error = function(e) {
  cat("❌ Database test failed:", e$message, "\n")
})

# Test 4: Test the improved query logic
cat("\n🔍 Testing improved query parameter handling...\n")
tryCatch({
  # Test with publisher filter
  publishers <- c("Harper & Brothers", "Houghton Mifflin")
  publisher_placeholders <- paste0("$", 3:(2 + length(publishers)), collapse = ",")
  test_query <- paste0("
    SELECT COUNT(*) as count
    FROM royalty_tiers rt
    JOIN book_entries be ON rt.book_id = be.book_id
    WHERE be.publication_year BETWEEN $1 AND $2
      AND be.publisher IN (", publisher_placeholders, ")
  ")
  
  params <- c(list(1860, 1920), as.list(publishers))
  
  result <- safe_db_query(test_query, params = params)
  if (!is.null(result) && nrow(result) > 0) {
    cat("✅ Improved query parameter handling works\n")
    cat("   - Found", result$count, "records with publisher filter\n")
  } else {
    cat("⚠️  Query returned no results\n")
  }
}, error = function(e) {
  cat("❌ Query parameter test failed:", e$message, "\n")
})

cat("\n✅ Royalty Analysis fixes testing completed!\n")
cat("\n💡 The '[object Object]' error should now be resolved with proper error handling.\n")
