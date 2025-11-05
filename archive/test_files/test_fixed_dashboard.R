# Test Fixed Dashboard Genre Logic
library(dplyr)

cat("🎭 Testing Fixed Dashboard Genre Logic\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Load configuration and utilities
source("config/cloud_config.R")
source("utils/database.R")

# Test the exact fixed dashboard logic
cat("\n📊 Testing fixed dashboard reactive logic...\n")

# Simulate the fixed genre_data reactive
genre_data_result <- tryCatch({
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
  warning("Failed to load genre data: ", e$message)
  data.frame(genre = character(0), total_sales = numeric(0))
})

if (nrow(genre_data_result) > 0) {
  cat("✅ genre_data reactive simulation successful\n")
  cat("Raw genre data:\n")
  print(genre_data_result)
  
  # Simulate the fixed renderPlotly logic
  cat("\n📊 Testing fixed renderPlotly logic...\n")
  
  data <- genre_data_result  # This is what genre_data() returns
  
  if (is.null(data) || nrow(data) == 0) {
    cat("❌ Data is null or empty - would show empty plot\n")
  } else {
    cat("✅ Data is valid - applying plot transformation\n")
    
    # Apply the FIXED plot_data transformation
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
    
    cat("Final plot_data for dashboard:\n")
    print(plot_data)
    
    # Verify the fixes
    cat("\n🎯 Verification of fixes:\n")
    
    # Check Essay consolidation
    essay_entries <- plot_data %>% filter(grepl("Essay", genre_display))
    cat("Essay entries:", nrow(essay_entries), "(should be 1)\n")
    if (nrow(essay_entries) > 0) {
      cat("  Essay category:", essay_entries$genre_display[1], 
          "with", essay_entries$book_count[1], "books and", 
          scales::comma(essay_entries$total_sales[1]), "sales\n")
    }
    
    # Check J mapping
    j_entries <- plot_data %>% filter(genre_display == "J")
    children_entries <- plot_data %>% filter(genre_display == "Children's Literature/Juvenile")
    cat("'J' entries remaining:", nrow(j_entries), "(should be 0)\n")
    cat("'Children's Literature/Juvenile' entries:", nrow(children_entries), "(should be 1)\n")
    if (nrow(children_entries) > 0) {
      cat("  Children's category with", children_entries$book_count[1], "books and", 
          scales::comma(children_entries$total_sales[1]), "sales\n")
    }
    
    # Check total categories
    cat("Total genre categories:", nrow(plot_data), "(should be 8 or fewer)\n")
    
    # Show what the dashboard will display
    cat("\n📊 Dashboard will show these genres:\n")
    for (i in 1:nrow(plot_data)) {
      cat(i, ". ", plot_data$genre_display[i], " - ", 
          scales::comma(plot_data$total_sales[i]), " sales (", 
          plot_data$book_count[i], " books)\n", sep = "")
    }
    
    if (nrow(essay_entries) == 1 && nrow(j_entries) == 0 && nrow(children_entries) == 1) {
      cat("\n✅ ALL FIXES WORKING CORRECTLY!\n")
      cat("The dashboard should now show consolidated genre categories.\n")
    } else {
      cat("\n❌ Some fixes not working correctly\n")
    }
  }
  
} else {
  cat("❌ genre_data reactive simulation failed\n")
}

cat("\n🚀 Next Steps:\n")
cat("1. Restart the Shiny application\n")
cat("2. The dashboard should now show consolidated genres\n")
cat("3. No more 'Essay' + 'Essay/Other Non-Fiction' duplication\n")
cat("4. No more 'J' single-letter code visible\n")
cat("5. 'Children's Literature/Juvenile' should include former 'J' entries\n")
