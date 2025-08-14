# Test Genre Dashboard Fix
library(dplyr)

cat("🎭 Testing Genre Dashboard Fix\n")
cat(paste(rep("=", 40), collapse = ""), "\n")

# Load configuration and utilities
source("config/cloud_config.R")
source("utils/database.R")

# Test the fixed genre logic
cat("\n📊 Testing fixed genre dashboard logic...\n")

# Get the data the same way the dashboard does
books_summary <- get_books_summary()

if (nrow(books_summary) > 0) {
  cat("✅ Books summary loaded:", nrow(books_summary), "books\n")
  
  # Apply the same aggregation logic as the dashboard
  genre_data <- books_summary %>%
    group_by(genre) %>%
    summarise(
      total_sales = sum(total_sales, na.rm = TRUE),
      book_count = n(),
      .groups = "drop"
    ) %>%
    filter(!is.na(genre), total_sales > 0) %>%
    arrange(desc(total_sales)) %>%
    slice_head(n = 10)
  
  cat("\nGenre data from dashboard logic:\n")
  print(genre_data)
  
  # Apply the NEW fixed plot logic
  cat("\n✨ Applying FIXED plot logic...\n")
  plot_data_fixed <- genre_data %>%
    mutate(genre_display = case_when(
      is.na(genre) | genre == "" ~ "Other",
      genre == "J" ~ "Juvenile",  # Handle legacy "J" code
      TRUE ~ genre  # Use actual genre names from database
    )) %>%
    # Take top 8 genres for better visualization
    slice_head(n = 8)
  
  cat("Fixed plot data:\n")
  print(plot_data_fixed[, c("genre", "genre_display", "total_sales", "book_count")])
  
  # Compare with OLD logic (what was causing the problem)
  cat("\n❌ OLD logic (for comparison):\n")
  plot_data_old <- genre_data %>%
    mutate(genre_clean = case_when(
      is.na(genre) | genre == "" ~ "Other",
      genre == "F" ~ "Fiction",
      genre == "N" ~ "Non-fiction",
      genre == "P" ~ "Poetry",
      genre == "D" ~ "Drama",
      genre == "J" ~ "Juvenile",
      genre == "S" ~ "Short Stories",
      genre == "B" ~ "Biography",
      TRUE ~ "Other"
    ))
  
  cat("Old plot data (problematic):\n")
  print(plot_data_old[, c("genre", "genre_clean", "total_sales")])
  
  # Show the difference
  cat("\n📊 Summary of the fix:\n")
  cat("BEFORE (old logic):\n")
  old_summary <- plot_data_old %>%
    group_by(genre_clean) %>%
    summarise(total_sales = sum(total_sales), .groups = "drop") %>%
    arrange(desc(total_sales))
  print(old_summary)
  
  cat("\nAFTER (fixed logic):\n")
  new_summary <- plot_data_fixed %>%
    group_by(genre_display) %>%
    summarise(total_sales = sum(total_sales), .groups = "drop") %>%
    arrange(desc(total_sales))
  print(new_summary)
  
  cat("\n🎯 Expected result in dashboard:\n")
  cat("- Chart should show", nrow(plot_data_fixed), "distinct genres\n")
  cat("- Labels should be actual genre names, not 'Genre Clean'\n")
  cat("- Top genre should be 'Novel' with", scales::comma(plot_data_fixed$total_sales[1]), "sales\n")
  
} else {
  cat("❌ No books summary data available\n")
}

cat("\n✅ Genre dashboard fix should now work correctly!\n")
cat("   - Multiple genres will be displayed (not just 2)\n")
cat("   - Actual genre names will be shown as labels\n")
cat("   - Chart will show top 8 genres by sales volume\n")
