# Test Author Network Application
# This script tests the author network module in isolation

library(shiny)
library(shinydashboard)
library(DT)
library(plotly)
library(ggplot2)
library(dplyr)
library(scales)

cat("🚀 Testing Author Network Module\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Load all required components
source("config/cloud_config.R")
source("utils/database.R")
source("utils/data_processing.R")
source("utils/plotting.R")
source("modules/author_networks_module.R")

# Test the module functions directly
cat("\n📊 Testing module functions...\n")

# Simulate input values
test_inputs <- list(
  gender_filter = c("Male", "Female"),
  year_range = c(1860, 1920),
  min_books = 2
)

# Test the data query logic
cat("\n🔍 Testing data query logic...\n")
tryCatch({
  author_query <- "
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
      AND be.gender = ANY($1)
      AND be.publication_year BETWEEN $2 AND $3
    LIMIT 20
  "
  
  book_data <- safe_db_query(
    author_query, 
    params = list(
      test_inputs$gender_filter,
      test_inputs$year_range[1],
      test_inputs$year_range[2]
    )
  )
  
  if (!is.null(book_data) && nrow(book_data) > 0) {
    cat("✅ Query returned", nrow(book_data), "records\n")
    
    # Test filtering logic
    author_counts <- book_data %>%
      group_by(author_id) %>%
      summarise(book_count = n(), .groups = "drop") %>%
      filter(book_count >= test_inputs$min_books)
    
    cat("✅ Found", nrow(author_counts), "authors with >=", test_inputs$min_books, "books\n")
    
    if (nrow(author_counts) > 0) {
      filtered_data <- book_data %>%
        filter(author_id %in% author_counts$author_id)
      
      cat("✅ Filtered data has", nrow(filtered_data), "records\n")
      
      # Test network creation
      network_result <- create_author_network(filtered_data)
      
      if (!is.null(network_result)) {
        cat("✅ Network created successfully\n")
        cat("   - Nodes:", nrow(network_result$nodes), "\n")
        cat("   - Edges:", nrow(network_result$edges), "\n")
        
        # Test if we can create a plot
        if (nrow(network_result$nodes) > 0) {
          cat("✅ Network has data for visualization\n")
        } else {
          cat("⚠️  Network has no nodes for visualization\n")
        }
      } else {
        cat("❌ Network creation failed\n")
      }
    } else {
      cat("⚠️  No authors meet the minimum book criteria\n")
    }
  } else {
    cat("⚠️  No data returned from query\n")
  }
}, error = function(e) {
  cat("❌ Data query test failed:", e$message, "\n")
})

cat("\n✅ Author Network module testing completed!\n")
cat("\n💡 To test the full application, run the Shiny app and navigate to the Author Networks tab.\n")
cat("   The errors should now be resolved with proper error messages displayed.\n")
