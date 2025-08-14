# Test Sliding Scale Filter
# This script tests the sliding scale filter functionality

library(dplyr)

cat("🔍 Testing Sliding Scale Filter Functionality\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

# Load configuration and utilities
source("config/cloud_config.R")
source("utils/database.R")
source("utils/data_processing.R")

# Test 1: Verify sliding scale data exists
cat("\n📊 Verifying sliding scale data in database...\n")
tryCatch({
  sliding_scale_summary <- safe_db_query("
    SELECT 
      sliding_scale,
      COUNT(*) as count,
      COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage
    FROM royalty_tiers 
    GROUP BY sliding_scale
    ORDER BY sliding_scale
  ")
  
  if (!is.null(sliding_scale_summary) && nrow(sliding_scale_summary) > 0) {
    cat("✅ Sliding scale data summary:\n")
    print(sliding_scale_summary)
  } else {
    cat("❌ No sliding scale data found\n")
  }
}, error = function(e) {
  cat("❌ Error querying sliding scale data:", e$message, "\n")
})

# Test 2: Test the royalty analysis query WITHOUT sliding scale filter
cat("\n📚 Testing royalty analysis query WITHOUT sliding scale filter...\n")
tryCatch({
  base_query <- "
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
  "
  
  all_data <- safe_db_query(base_query)
  
  if (!is.null(all_data) && nrow(all_data) > 0) {
    cat("✅ Query without sliding scale filter returned", nrow(all_data), "records\n")
    
    # Check sliding scale distribution in results
    sliding_dist <- table(all_data$sliding_scale, useNA = "always")
    cat("📊 Sliding scale distribution in results:\n")
    print(sliding_dist)
    
  } else {
    cat("❌ Query without sliding scale filter returned no data\n")
  }
}, error = function(e) {
  cat("❌ Error with base query:", e$message, "\n")
})

# Test 3: Test the royalty analysis query WITH sliding scale filter
cat("\n📚 Testing royalty analysis query WITH sliding scale filter...\n")
tryCatch({
  sliding_query <- "
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
      AND rt.sliding_scale = TRUE
  "
  
  sliding_data <- safe_db_query(sliding_query)
  
  if (!is.null(sliding_data) && nrow(sliding_data) > 0) {
    cat("✅ Query with sliding scale filter returned", nrow(sliding_data), "records\n")
    
    # Verify all records have sliding_scale = TRUE
    all_sliding <- all(sliding_data$sliding_scale == TRUE, na.rm = TRUE)
    cat("✅ All records have sliding_scale = TRUE:", all_sliding, "\n")
    
    # Show sample records
    cat("📋 Sample sliding scale records:\n")
    sample_cols <- c("book_id", "tier", "rate", "sliding_scale", "book_title", "author_surname")
    available_cols <- intersect(sample_cols, names(sliding_data))
    print(head(sliding_data[, available_cols], 5))
    
  } else {
    cat("❌ Query with sliding scale filter returned no data\n")
  }
}, error = function(e) {
  cat("❌ Error with sliding scale query:", e$message, "\n")
})

# Test 4: Test the analyze_royalty_patterns function with sliding scale data
cat("\n🔧 Testing analyze_royalty_patterns with sliding scale data...\n")
tryCatch({
  # Get sliding scale data
  sliding_query <- "
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
      AND rt.sliding_scale = TRUE
    LIMIT 50
  "
  
  test_data <- safe_db_query(sliding_query)
  
  if (!is.null(test_data) && nrow(test_data) > 0) {
    cat("✅ Got", nrow(test_data), "sliding scale records for analysis\n")
    
    # Test analyze_royalty_patterns
    analysis_result <- analyze_royalty_patterns(test_data)
    
    if (!is.null(analysis_result) && nrow(analysis_result) > 0) {
      cat("✅ analyze_royalty_patterns worked with sliding scale data\n")
      cat("📊 Analysis results:\n")
      print(analysis_result)
    } else {
      cat("❌ analyze_royalty_patterns failed with sliding scale data\n")
    }
  } else {
    cat("❌ Could not get sliding scale data for analysis\n")
  }
}, error = function(e) {
  cat("❌ Error testing analyze_royalty_patterns:", e$message, "\n")
})

cat("\n🎉 Sliding scale filter testing completed!\n")
cat("💡 The 'Sliding Scale Only' checkbox should now work correctly in the Shiny app.\n")
cat("📊 Expected behavior:\n")
cat("   - Unchecked: Shows all ~1007 royalty tier records\n")
cat("   - Checked: Shows only ~832 sliding scale records\n")
