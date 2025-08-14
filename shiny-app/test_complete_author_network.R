# Complete Test of Author Network Fixes
# This script tests the entire author network workflow

library(dplyr)
library(plotly)
library(scales)

cat("🚀 Complete Author Network Test\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Load all required components
source("config/cloud_config.R")
source("utils/database.R")
source("utils/data_processing.R")
source("utils/plotting.R")

# Test complete workflow
cat("\n🔄 Testing complete workflow...\n")

# Simulate the reactive logic from the module
test_network_data <- function() {
  # Simulate input values
  gender_filter <- c("Male", "Female")
  year_range <- c(1860, 1920)
  min_books <- 2
  
  # Ensure we have valid inputs (this is the new validation logic)
  if (is.null(gender_filter) || length(gender_filter) == 0) {
    gender_filter <- c("Male", "Female")
  }
  
  if (is.null(year_range) || length(year_range) != 2) {
    year_range <- c(1860, 1920)
  }
  
  if (is.null(min_books) || !is.numeric(min_books)) {
    min_books <- 2
  }
  
  cat("📋 Using filters:\n")
  cat("   - Gender:", paste(gender_filter, collapse = ", "), "\n")
  cat("   - Year range:", year_range[1], "-", year_range[2], "\n")
  cat("   - Min books:", min_books, "\n")
  
  # Get author data with filters (using the fixed query)
  gender_placeholders <- paste0("$", 3:(2 + length(gender_filter)), collapse = ",")
  author_query <- paste0("
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
      AND be.gender IN (", gender_placeholders, ")
      AND be.publication_year BETWEEN $1 AND $2
  ")
  
  params <- c(list(year_range[1], year_range[2]), as.list(gender_filter))
  
  book_data <- safe_db_query(author_query, params = params)
  
  # Handle empty query results (new error handling)
  if (is.null(book_data) || nrow(book_data) == 0) {
    return(list(
      nodes = data.frame(),
      edges = data.frame(),
      message = "No books found matching the selected criteria."
    ))
  }
  
  cat("✅ Retrieved", nrow(book_data), "book records\n")
  
  # Filter authors with minimum books
  author_counts <- book_data %>%
    group_by(author_id) %>%
    summarise(book_count = n(), .groups = "drop") %>%
    filter(book_count >= min_books)
  
  if (nrow(author_counts) == 0) {
    return(list(
      nodes = data.frame(),
      edges = data.frame(),
      message = paste("No authors found with at least", min_books, "books in the selected criteria.")
    ))
  }
  
  cat("✅ Found", nrow(author_counts), "authors with >=", min_books, "books\n")
  
  filtered_data <- book_data %>%
    filter(author_id %in% author_counts$author_id)
  
  cat("✅ Filtered to", nrow(filtered_data), "records for network creation\n")
  
  # Create network based on type (using the improved function)
  network_result <- create_author_network(filtered_data)
  
  # Add success message if we have data (new feature)
  if (!is.null(network_result) && nrow(network_result$nodes) > 0) {
    network_result$message <- paste("Network created with", nrow(network_result$nodes), "authors and", nrow(network_result$edges), "connections.")
  } else {
    network_result$message <- "No network connections found between authors with the selected criteria."
  }
  
  return(network_result)
}

# Test the complete workflow
tryCatch({
  net_data <- test_network_data()
  
  if (!is.null(net_data)) {
    cat("✅ Network data created successfully\n")
    cat("📊 Results:\n")
    cat("   - Nodes:", nrow(net_data$nodes), "\n")
    cat("   - Edges:", nrow(net_data$edges), "\n")
    cat("   - Message:", net_data$message, "\n")
    
    # Test plotly_empty function
    if (nrow(net_data$nodes) == 0) {
      cat("\n📈 Testing plotly_empty function...\n")
      empty_plot <- plotly_empty(net_data$message)
      if (!is.null(empty_plot)) {
        cat("✅ plotly_empty works correctly for empty data\n")
      }
    } else {
      cat("\n📈 Testing network visualization...\n")
      # Test if we can create the network plot
      nodes <- net_data$nodes
      required_cols <- c("author_id", "author_surname", "gender", "book_count", "total_sales", "node_size")
      missing_cols <- setdiff(required_cols, names(nodes))
      
      if (length(missing_cols) == 0) {
        cat("✅ All required columns present for visualization\n")
      } else {
        cat("❌ Missing columns:", paste(missing_cols, collapse = ", "), "\n")
      }
    }
  } else {
    cat("❌ Network data creation failed\n")
  }
}, error = function(e) {
  cat("❌ Complete workflow test failed:", e$message, "\n")
})

cat("\n🎉 Complete author network test finished!\n")
cat("💡 The fixes should resolve the 'argument is of length zero' errors.\n")
