# Test Sliding Scale Data Investigation
# This script investigates sliding scale royalty data in the database

library(dplyr)

cat("🔍 Investigating Sliding Scale Royalty Data\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

# Load configuration and utilities
source("config/cloud_config.R")
source("utils/database.R")

# Test 1: Check if sliding_scale column exists and what values it contains
cat("\n📊 Examining sliding_scale column in royalty_tiers table...\n")
tryCatch({
  sliding_scale_check <- safe_db_query("
    SELECT 
      sliding_scale,
      COUNT(*) as count,
      COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage
    FROM royalty_tiers 
    GROUP BY sliding_scale
    ORDER BY sliding_scale
  ")
  
  if (!is.null(sliding_scale_check) && nrow(sliding_scale_check) > 0) {
    cat("✅ sliding_scale column data:\n")
    print(sliding_scale_check)
  } else {
    cat("❌ No data found in sliding_scale column\n")
  }
}, error = function(e) {
  cat("❌ Error checking sliding_scale column:", e$message, "\n")
})

# Test 2: Check data types and sample values
cat("\n🔍 Examining sliding_scale data types and sample values...\n")
tryCatch({
  sample_data <- safe_db_query("
    SELECT 
      tier_id,
      book_id,
      tier,
      rate,
      sliding_scale,
      CASE 
        WHEN sliding_scale = TRUE THEN 'TRUE'
        WHEN sliding_scale = FALSE THEN 'FALSE'
        WHEN sliding_scale IS NULL THEN 'NULL'
        ELSE 'OTHER: ' || sliding_scale::text
      END as sliding_scale_display
    FROM royalty_tiers 
    LIMIT 10
  ")
  
  if (!is.null(sample_data) && nrow(sample_data) > 0) {
    cat("✅ Sample sliding_scale values:\n")
    print(sample_data[, c("tier_id", "book_id", "tier", "sliding_scale", "sliding_scale_display")])
  } else {
    cat("❌ No sample data found\n")
  }
}, error = function(e) {
  cat("❌ Error getting sample data:", e$message, "\n")
})

# Test 3: Test the exact filter condition used in the module
cat("\n🔧 Testing the exact sliding scale filter condition...\n")
tryCatch({
  filter_test <- safe_db_query("
    SELECT 
      COUNT(*) as total_records,
      COUNT(CASE WHEN sliding_scale = TRUE THEN 1 END) as sliding_scale_true,
      COUNT(CASE WHEN sliding_scale = FALSE THEN 1 END) as sliding_scale_false,
      COUNT(CASE WHEN sliding_scale IS NULL THEN 1 END) as sliding_scale_null
    FROM royalty_tiers rt
    JOIN book_entries be ON rt.book_id = be.book_id
    WHERE be.publication_year BETWEEN 1860 AND 1920
  ")
  
  if (!is.null(filter_test) && nrow(filter_test) > 0) {
    cat("✅ Filter condition results:\n")
    print(filter_test)
    
    if (filter_test$sliding_scale_true > 0) {
      cat("✅ Found", filter_test$sliding_scale_true, "records with sliding_scale = TRUE\n")
    } else {
      cat("⚠️  No records found with sliding_scale = TRUE\n")
    }
  }
}, error = function(e) {
  cat("❌ Error testing filter condition:", e$message, "\n")
})

# Test 4: Test the complete query used in the module with sliding scale filter
cat("\n📋 Testing complete module query with sliding scale filter...\n")
tryCatch({
  module_query <- "
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
    WHERE be.publication_year BETWEEN $1 AND $2
      AND rt.sliding_scale = TRUE
  "
  
  module_result <- safe_db_query(module_query, params = list(1860, 1920))
  
  if (!is.null(module_result) && nrow(module_result) > 0) {
    cat("✅ Module query with sliding scale filter returned", nrow(module_result), "records\n")
    cat("📊 Sample results:\n")
    print(head(module_result[, c("book_id", "tier", "rate", "sliding_scale", "book_title", "author_surname")], 5))
  } else {
    cat("⚠️  Module query with sliding scale filter returned no results\n")
  }
}, error = function(e) {
  cat("❌ Error testing module query:", e$message, "\n")
})

# Test 5: Check if there are any books with multiple tiers (which might indicate sliding scales)
cat("\n📚 Checking for books with multiple royalty tiers...\n")
tryCatch({
  multi_tier_check <- safe_db_query("
    SELECT 
      rt.book_id,
      be.book_title,
      be.author_surname,
      COUNT(rt.tier) as tier_count,
      STRING_AGG(rt.tier::text, ', ' ORDER BY rt.tier) as tiers,
      STRING_AGG(rt.rate::text, ', ' ORDER BY rt.tier) as rates,
      BOOL_OR(rt.sliding_scale) as has_sliding_scale
    FROM royalty_tiers rt
    JOIN book_entries be ON rt.book_id = be.book_id
    WHERE be.publication_year BETWEEN 1860 AND 1920
    GROUP BY rt.book_id, be.book_title, be.author_surname
    HAVING COUNT(rt.tier) > 1
    ORDER BY tier_count DESC, rt.book_id
    LIMIT 10
  ")
  
  if (!is.null(multi_tier_check) && nrow(multi_tier_check) > 0) {
    cat("✅ Found", nrow(multi_tier_check), "books with multiple tiers (showing first 10):\n")
    print(multi_tier_check)
  } else {
    cat("⚠️  No books found with multiple tiers\n")
  }
}, error = function(e) {
  cat("❌ Error checking multi-tier books:", e$message, "\n")
})

cat("\n🎯 Investigation Summary:\n")
cat("- Check if sliding_scale column contains TRUE values\n")
cat("- Verify the filter logic is working correctly\n")
cat("- Determine if 'no results' is expected behavior\n")
cat("\n✅ Sliding scale investigation completed!\n")
