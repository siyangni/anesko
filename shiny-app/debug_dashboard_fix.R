# Debug Dashboard Genre Fix
# This script tests why the dashboard fix isn't working

library(dplyr)

cat("🔍 Debugging Dashboard Genre Fix\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Load configuration and utilities
source("config/cloud_config.R")
source("utils/database.R")

# Test 1: Verify the exact same logic as the dashboard
cat("\n📊 Testing exact dashboard logic...\n")

# Step 1: Get genre_data (same as dashboard reactive)
cat("Step 1: Getting genre_data (dashboard reactive equivalent)...\n")
genre_data <- tryCatch({
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
}, error = function(e) {
  cat("❌ Error in genre_data step:", e$message, "\n")
  return(NULL)
})

if (!is.null(genre_data) && nrow(genre_data) > 0) {
  cat("✅ genre_data loaded successfully\n")
  cat("Raw genre_data:\n")
  print(genre_data)
  
  # Step 2: Apply the exact same plot_data logic as dashboard
  cat("\nStep 2: Applying exact dashboard plot_data logic...\n")
  plot_data <- tryCatch({
    genre_data %>%
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
  }, error = function(e) {
    cat("❌ Error in plot_data step:", e$message, "\n")
    return(NULL)
  })
  
  if (!is.null(plot_data) && nrow(plot_data) > 0) {
    cat("✅ plot_data created successfully\n")
    cat("Final plot_data:\n")
    print(plot_data)
    
    # Check specific fixes
    cat("\n🔍 Checking specific fixes:\n")
    
    # Check if Essay consolidation worked
    essay_entries <- plot_data %>% filter(grepl("Essay", genre_display))
    cat("Essay entries in final data:", nrow(essay_entries), "\n")
    if (nrow(essay_entries) > 0) {
      print(essay_entries)
    }
    
    # Check if J mapping worked
    j_entries <- plot_data %>% filter(genre_display == "J")
    children_entries <- plot_data %>% filter(genre_display == "Children's Literature/Juvenile")
    cat("'J' entries remaining:", nrow(j_entries), "\n")
    cat("'Children's Literature/Juvenile' entries:", nrow(children_entries), "\n")
    if (nrow(children_entries) > 0) {
      print(children_entries)
    }
    
  } else {
    cat("❌ plot_data creation failed\n")
  }
  
} else {
  cat("❌ genre_data creation failed\n")
}

# Test 2: Check if there are any issues with the dashboard module loading
cat("\n📋 Testing dashboard module loading...\n")

# Try to source the dashboard module
dashboard_load_result <- tryCatch({
  source("modules/dashboard_module.R")
  cat("✅ Dashboard module loaded successfully\n")
  TRUE
}, error = function(e) {
  cat("❌ Error loading dashboard module:", e$message, "\n")
  FALSE
})

# Test 3: Check for any syntax errors in the specific function
if (dashboard_load_result) {
  cat("\n🔧 Testing dashboard function availability...\n")
  
  # Check if the functions exist
  if (exists("dashboardUI")) {
    cat("✅ dashboardUI function exists\n")
  } else {
    cat("❌ dashboardUI function not found\n")
  }
  
  if (exists("dashboardServer")) {
    cat("✅ dashboardServer function exists\n")
  } else {
    cat("❌ dashboardServer function not found\n")
  }
}

# Test 4: Check for potential caching issues
cat("\n💾 Checking for potential caching issues...\n")

# Check if there's any global cache variable
if (exists("cache", envir = .GlobalEnv)) {
  cat("⚠️  Global cache variable found - this might be causing issues\n")
  cache_info <- get("cache", envir = .GlobalEnv)
  if (is.list(cache_info) && "last_updated" %in% names(cache_info)) {
    cat("Cache last updated:", cache_info$last_updated, "\n")
  }
} else {
  cat("✅ No global cache variable found\n")
}

# Test 5: Simulate the exact create_bar_plot call
cat("\n📊 Testing create_bar_plot call...\n")

if (!is.null(plot_data) && nrow(plot_data) > 0) {
  # Load plotting utilities
  plot_load_result <- tryCatch({
    source("utils/plotting.R")
    cat("✅ Plotting utilities loaded\n")
    TRUE
  }, error = function(e) {
    cat("❌ Error loading plotting utilities:", e$message, "\n")
    FALSE
  })
  
  if (plot_load_result) {
    # Try the exact create_bar_plot call from dashboard
    plot_result <- tryCatch({
      create_bar_plot(
        data = plot_data,
        x_col = "genre_display",
        y_col = "total_sales",
        title = "Sales by Genre",
        orientation = "horizontal"
      )
      cat("✅ create_bar_plot executed successfully\n")
      TRUE
    }, error = function(e) {
      cat("❌ Error in create_bar_plot:", e$message, "\n")
      FALSE
    })
  }
}

cat("\n📋 Debug Summary:\n")
cat("1. Check if genre_data logic works: ", ifelse(exists("genre_data") && !is.null(genre_data), "✅", "❌"), "\n")
cat("2. Check if plot_data logic works: ", ifelse(exists("plot_data") && !is.null(plot_data), "✅", "❌"), "\n")
cat("3. Check if dashboard module loads: ", ifelse(exists("dashboard_load_result") && dashboard_load_result, "✅", "❌"), "\n")
cat("4. Check if plotting works: ", ifelse(exists("plot_result") && plot_result, "✅", "❌"), "\n")

cat("\n💡 Recommendations:\n")
cat("- If all tests pass, the issue might be browser caching\n")
cat("- If plot_data test fails, there's a logic error\n")
cat("- If module loading fails, there's a syntax error\n")
cat("- Try hard refresh (Ctrl+F5) in browser\n")
cat("- Check Shiny application console for errors\n")
