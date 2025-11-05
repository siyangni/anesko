# Debug Reactive Issue in Dashboard
# This script tests if the reactive function is working correctly

library(dplyr)

cat("🔍 Debugging Reactive Issue in Dashboard\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Load configuration and utilities
source("config/cloud_config.R")
source("utils/database.R")

# Test 1: Test the safe_query function directly
cat("\n📊 Testing safe_query function...\n")

# Test the exact same function call as in the reactive
safe_query_result <- tryCatch({
  safe_query(function() {
    get_books_summary() %>%
      group_by(genre) %>%
      summarise(
        total_sales = sum(total_sales, na.rm = TRUE),
        book_count = n(),
        .groups = "drop"
      ) %>%
      filter(!is.na(genre), total_sales > 0) %>%
      arrange(desc(total_sales)) %>%
      slice_head(n = 10)
  },
  default_value = data.frame(genre = character(0), total_sales = numeric(0)),
  error_message = "Failed to load genre data")
}, error = function(e) {
  cat("❌ Error in safe_query:", e$message, "\n")
  return(NULL)
})

if (!is.null(safe_query_result) && nrow(safe_query_result) > 0) {
  cat("✅ safe_query working correctly\n")
  cat("safe_query result:\n")
  print(safe_query_result)
} else {
  cat("❌ safe_query failed or returned empty data\n")
  print(safe_query_result)
}

# Test 2: Check if safe_query function exists and works
cat("\n🔧 Testing safe_query function definition...\n")

if (exists("safe_query")) {
  cat("✅ safe_query function exists\n")
  
  # Test with a simple query
  simple_test <- tryCatch({
    safe_query(function() {
      data.frame(test = 1:3, value = c("a", "b", "c"))
    },
    default_value = data.frame(),
    error_message = "Test failed")
  }, error = function(e) {
    cat("❌ Simple safe_query test failed:", e$message, "\n")
    return(NULL)
  })
  
  if (!is.null(simple_test) && nrow(simple_test) > 0) {
    cat("✅ safe_query basic functionality works\n")
  } else {
    cat("❌ safe_query basic functionality broken\n")
  }
  
} else {
  cat("❌ safe_query function not found\n")
}

# Test 3: Check the exact dashboard reactive logic
cat("\n📋 Testing exact dashboard reactive logic...\n")

# Simulate the reactive environment
if (!is.null(safe_query_result) && nrow(safe_query_result) > 0) {
  
  # This is exactly what should happen in the renderPlotly
  cat("Simulating renderPlotly logic...\n")
  
  data <- safe_query_result  # This is genre_data()
  
  cat("Data received by renderPlotly:\n")
  print(data)
  
  if (is.null(data) || nrow(data) == 0) {
    cat("❌ Data is null or empty - would return empty plot\n")
  } else {
    cat("✅ Data is valid - proceeding with plot logic\n")
    
    # Apply the exact plot_data transformation
    plot_data <- data %>%
      mutate(genre_display = case_when(
        is.na(genre) | genre == "" ~ "Other",
        genre == "J" ~ "Children's Literature/Juvenile",  # Legacy single-letter code
        genre == "Essay" ~ "Essay/Other Non-Fiction",     # Standardize essay naming (match existing)
        TRUE ~ genre  # Use actual genre names from database
      )) %>%
      # Re-aggregate after standardization to combine inconsistent categories
      group_by(genre_display) %>%
      summarise(
        total_sales = sum(total_sales, na.rm = TRUE),
        book_count = sum(book_count, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      arrange(desc(total_sales)) %>%
      # Take top 8 genres for better visualization
      slice_head(n = 8)
    
    cat("Final plot_data that should be used:\n")
    print(plot_data)
    
    # Check the specific fixes
    essay_count <- sum(grepl("Essay", plot_data$genre_display))
    j_count <- sum(plot_data$genre_display == "J")
    children_count <- sum(plot_data$genre_display == "Children's Literature/Juvenile")
    
    cat("\n🎯 Fix verification:\n")
    cat("Essay entries:", essay_count, "(should be 1)\n")
    cat("'J' entries:", j_count, "(should be 0)\n") 
    cat("Children's Literature entries:", children_count, "(should be 1)\n")
    
    if (essay_count == 1 && j_count == 0 && children_count == 1) {
      cat("✅ All fixes working correctly in simulation\n")
    } else {
      cat("❌ Fixes not working in simulation\n")
    }
  }
}

# Test 4: Check if there might be a different genre_data source
cat("\n🔍 Checking for alternative data sources...\n")

# Check if there are other functions that might be providing genre data
other_genre_functions <- c("get_genre_analysis", "get_genre_data", "get_genre_summary")

for (func_name in other_genre_functions) {
  if (exists(func_name)) {
    cat("⚠️  Found alternative function:", func_name, "\n")
  }
}

# Test 5: Check if the dashboard module is using a different path
cat("\n📄 Checking dashboard module for alternative code paths...\n")

# Read the dashboard module file to check for any conditional logic
dashboard_content <- readLines("modules/dashboard_module.R")
genre_lines <- grep("genre", dashboard_content, ignore.case = TRUE)

cat("Lines mentioning 'genre' in dashboard module:\n")
for (line_num in genre_lines) {
  cat("Line", line_num, ":", dashboard_content[line_num], "\n")
}

cat("\n💡 Debugging Summary:\n")
cat("If safe_query works but dashboard doesn't show fixes:\n")
cat("1. Check Shiny console for reactive errors\n")
cat("2. Check if browser dev tools show JavaScript errors\n")
cat("3. Verify the dashboard is actually using the updated module\n")
cat("4. Check if there's a different reactive invalidation issue\n")
