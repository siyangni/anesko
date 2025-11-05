# Test Author Network Fixes
# This script tests the fixes for the author network module

library(dplyr)
library(plotly)

cat("🔧 Testing Author Network Fixes\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Load configuration and utilities
source("config/cloud_config.R")
source("utils/database.R")
source("utils/data_processing.R")
source("utils/plotting.R")

# Test 1: Test plotly_empty function
cat("\n📊 Testing plotly_empty function...\n")
tryCatch({
  empty_plot <- plotly_empty("Test message")
  if (!is.null(empty_plot)) {
    cat("✅ plotly_empty function works correctly\n")
  } else {
    cat("❌ plotly_empty function returned NULL\n")
  }
}, error = function(e) {
  cat("❌ plotly_empty function failed:", e$message, "\n")
})

# Test 2: Test create_author_network with empty data
cat("\n🔗 Testing create_author_network with empty data...\n")
tryCatch({
  empty_network <- create_author_network(data.frame())
  if (is.list(empty_network) && "nodes" %in% names(empty_network) && "edges" %in% names(empty_network)) {
    cat("✅ create_author_network handles empty data correctly\n")
  } else {
    cat("❌ create_author_network did not return proper structure\n")
  }
}, error = function(e) {
  cat("❌ create_author_network failed with empty data:", e$message, "\n")
})

# Test 3: Test create_author_network with missing columns
cat("\n🔗 Testing create_author_network with missing columns...\n")
tryCatch({
  bad_data <- data.frame(author_id = 1, author_surname = "Test")
  bad_network <- create_author_network(bad_data)
  if (is.list(bad_network) && nrow(bad_network$nodes) == 0) {
    cat("✅ create_author_network handles missing columns correctly\n")
  } else {
    cat("❌ create_author_network did not handle missing columns properly\n")
  }
}, error = function(e) {
  cat("❌ create_author_network failed with missing columns:", e$message, "\n")
})

# Test 4: Test with real data if available
cat("\n📚 Testing with real database data...\n")
tryCatch({
  # Try to get some real data
  test_query <- "
    SELECT 
      be.author_id,
      be.author_surname,
      be.gender,
      be.publisher,
      be.genre,
      be.publication_year,
      COALESCE(bs.total_sales, 0) as total_sales
    FROM book_entries be
    LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
    WHERE be.author_id IS NOT NULL
      AND be.gender IN ('Male', 'Female')
      AND be.publication_year BETWEEN 1860 AND 1920
    LIMIT 10
  "
  
  test_data <- safe_db_query(test_query)
  
  if (!is.null(test_data) && nrow(test_data) > 0) {
    cat("✅ Retrieved", nrow(test_data), "test records from database\n")
    
    # Test network creation with real data
    network_result <- create_author_network(test_data)
    if (!is.null(network_result) && "nodes" %in% names(network_result)) {
      cat("✅ create_author_network works with real data\n")
      cat("   - Nodes:", nrow(network_result$nodes), "\n")
      cat("   - Edges:", nrow(network_result$edges), "\n")
    } else {
      cat("❌ create_author_network failed with real data\n")
    }
  } else {
    cat("⚠️  No test data available from database\n")
  }
}, error = function(e) {
  cat("❌ Database test failed:", e$message, "\n")
})

cat("\n✅ Author Network fixes testing completed!\n")
