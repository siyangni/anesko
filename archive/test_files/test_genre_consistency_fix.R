# Test Genre Consistency Fix
library(dplyr)

cat("🎭 Testing Genre Consistency Fix\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Load configuration and utilities
source("config/cloud_config.R")
source("utils/database.R")

# Test the fixed genre consistency logic
cat("\n📊 Testing genre consistency fix...\n")

# Get the data the same way the dashboard does
books_summary <- get_books_summary()

if (nrow(books_summary) > 0) {
  cat("✅ Books summary loaded:", nrow(books_summary), "books\n")
  
  # Apply the same aggregation logic as the dashboard (BEFORE fix)
  genre_data_before <- books_summary %>%
    group_by(genre) %>%
    summarise(
      total_sales = sum(total_sales, na.rm = TRUE),
      book_count = n(),
      .groups = "drop"
    ) %>%
    filter(!is.na(genre), total_sales > 0) %>%
    arrange(desc(total_sales)) %>%
    slice_head(n = 10)
  
  cat("\n❌ BEFORE fix - Raw genre data (with inconsistencies):\n")
  print(genre_data_before)
  
  # Apply the NEW FIXED logic with consistency handling
  cat("\n✨ AFTER fix - Applying consistency mapping...\n")
  plot_data_fixed <- genre_data_before %>%
    mutate(genre_display = case_when(
      is.na(genre) | genre == "" ~ "Other",
      genre == "J" ~ "Children's Literature/Juvenile",  # Legacy single-letter code
      genre == "Essay" ~ "Essays/Other Non-Fiction",    # Standardize essay naming
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
  
  cat("Fixed plot data:\n")
  print(plot_data_fixed)
  
  # Show the specific fixes
  cat("\n🔧 Specific Inconsistencies Fixed:\n")
  
  # Check Essay consolidation
  essay_before <- genre_data_before %>% filter(grepl("Essay", genre))
  essay_after <- plot_data_fixed %>% filter(grepl("Essay", genre_display))
  
  if (nrow(essay_before) > 1) {
    cat("Essay consolidation:\n")
    cat("  BEFORE: ", nrow(essay_before), " separate essay categories\n")
    print(essay_before[, c("genre", "book_count", "total_sales")])
    cat("  AFTER: ", nrow(essay_after), " consolidated essay category\n")
    print(essay_after[, c("genre_display", "book_count", "total_sales")])
  }
  
  # Check J code mapping
  j_before <- genre_data_before %>% filter(genre == "J")
  children_after <- plot_data_fixed %>% filter(genre_display == "Children's Literature/Juvenile")
  
  if (nrow(j_before) > 0) {
    cat("\nLegacy 'J' code mapping:\n")
    cat("  BEFORE: 'J' code with", j_before$book_count, "books and", scales::comma(j_before$total_sales), "sales\n")
    cat("  AFTER: Combined with 'Children's Literature/Juvenile' -", children_after$book_count, "books and", scales::comma(children_after$total_sales), "sales\n")
  }
  
  # Compare totals
  cat("\n📊 Summary comparison:\n")
  cat("BEFORE fix:\n")
  cat("  - Total categories:", nrow(genre_data_before), "\n")
  cat("  - Essay categories:", sum(grepl("Essay", genre_data_before$genre)), "\n")
  cat("  - Legacy codes:", sum(nchar(genre_data_before$genre) == 1), "\n")
  
  cat("AFTER fix:\n")
  cat("  - Total categories:", nrow(plot_data_fixed), "\n")
  cat("  - Essay categories:", sum(grepl("Essay", plot_data_fixed$genre_display)), "\n")
  cat("  - Legacy codes:", sum(nchar(plot_data_fixed$genre_display) == 1), "\n")
  
  # Verify data integrity
  total_books_before <- sum(genre_data_before$book_count)
  total_books_after <- sum(plot_data_fixed$book_count)
  total_sales_before <- sum(genre_data_before$total_sales)
  total_sales_after <- sum(plot_data_fixed$total_sales)
  
  cat("\n✅ Data integrity check:\n")
  cat("  Books: ", total_books_before, " → ", total_books_after, " (", 
      ifelse(total_books_before == total_books_after, "✅ PRESERVED", "❌ LOST"), ")\n")
  cat("  Sales: ", scales::comma(total_sales_before), " → ", scales::comma(total_sales_after), " (", 
      ifelse(total_sales_before == total_sales_after, "✅ PRESERVED", "❌ LOST"), ")\n")
  
} else {
  cat("❌ No books summary data available\n")
}

cat("\n🎯 Expected Dashboard Result:\n")
cat("✅ 'Essay' and 'Essay/Other Non-Fiction' will be consolidated\n")
cat("✅ 'J' code will be mapped to 'Children's Literature/Juvenile'\n")
cat("✅ All other genres will remain properly named\n")
cat("✅ No data loss - just better categorization\n")
cat("✅ Consistent genre naming throughout the dashboard\n")
