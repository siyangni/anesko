# Test Script for Fixed Filter Issues
# This script tests all the fixes we've implemented

library(DBI)
library(RPostgreSQL)
library(dplyr)

cat("🧪 Testing All Filter Fixes\n")
cat(paste(rep("=", 40), collapse = ""), "\n")

# Load configuration and utilities
source("config/cloud_config.R")
source("utils/database.R")

# Test 1: Gender Analysis (Dashboard Issue)
cat("\n👥 Testing Gender Analysis (Dashboard Fix)...\n")
gender_result <- get_gender_analysis()

if (!is.null(gender_result) && nrow(gender_result) > 0) {
  cat("✅ Gender analysis working!\n")
  print(gender_result)
  
  # Test the gender label mapping that was fixed
  plot_data <- gender_result %>%
    mutate(gender_label = case_when(
      gender == "Male" ~ "Male Authors",
      gender == "Female" ~ "Female Authors",
      is.na(gender) ~ "Unknown",
      TRUE ~ paste(gender, "Authors")
    ))
  
  cat("Gender labels:", paste(plot_data$gender_label, collapse = ", "), "\n")
} else {
  cat("❌ Gender analysis still failing\n")
}

# Test 2: Filter Options (Book Explorer Issue)
cat("\n🔍 Testing Filter Options...\n")
filter_opts <- get_filter_options()

if (!is.null(filter_opts)) {
  cat("✅ Filter options working!\n")
  cat("- Genres:", nrow(filter_opts$genres), "\n")
  cat("- Publishers:", nrow(filter_opts$publishers), "\n")
  cat("- Genders:", nrow(filter_opts$genders), "\n")
  
  if (nrow(filter_opts$genders) > 0) {
    cat("- Available genders:", paste(filter_opts$genders$gender, collapse = ", "), "\n")
  }
} else {
  cat("❌ Filter options still failing\n")
}

# Test 3: Search Books Function (Book Explorer Issue)
cat("\n📚 Testing Search Books Function...\n")

# Test basic search
all_books <- tryCatch({
  search_books()
}, error = function(e) {
  cat("❌ Basic search failed:", e$message, "\n")
  NULL
})

if (!is.null(all_books) && nrow(all_books) > 0) {
  cat("✅ Basic search working:", nrow(all_books), "books\n")
  
  # Test gender filter (the main issue)
  male_books <- tryCatch({
    search_books(gender_filter = c("Male"))
  }, error = function(e) {
    cat("❌ Male gender filter failed:", e$message, "\n")
    NULL
  })
  
  if (!is.null(male_books) && nrow(male_books) > 0) {
    cat("✅ Male gender filter working:", nrow(male_books), "books\n")
    unique_genders <- unique(male_books$gender)
    cat("  Genders in results:", paste(unique_genders, collapse = ", "), "\n")
  } else {
    cat("❌ Male gender filter not working\n")
  }
  
  # Test female filter
  female_books <- tryCatch({
    search_books(gender_filter = c("Female"))
  }, error = function(e) {
    cat("❌ Female gender filter failed:", e$message, "\n")
    NULL
  })
  
  if (!is.null(female_books) && nrow(female_books) > 0) {
    cat("✅ Female gender filter working:", nrow(female_books), "books\n")
  } else {
    cat("❌ Female gender filter not working\n")
  }
  
  # Test genre filter
  novel_books <- tryCatch({
    search_books(genre_filter = c("Novel"))
  }, error = function(e) {
    cat("❌ Novel genre filter failed:", e$message, "\n")
    NULL
  })
  
  if (!is.null(novel_books) && nrow(novel_books) > 0) {
    cat("✅ Novel genre filter working:", nrow(novel_books), "books\n")
    unique_genres <- unique(novel_books$genre)
    cat("  Genres in results:", paste(unique_genres, collapse = ", "), "\n")
  } else {
    cat("❌ Novel genre filter not working\n")
  }
  
  # Test combined filters
  combined <- tryCatch({
    search_books(gender_filter = c("Female"), genre_filter = c("Novel"))
  }, error = function(e) {
    cat("❌ Combined filter failed:", e$message, "\n")
    NULL
  })
  
  if (!is.null(combined) && nrow(combined) > 0) {
    cat("✅ Combined filters working:", nrow(combined), "books\n")
  } else {
    cat("❌ Combined filters not working\n")
  }
  
} else {
  cat("❌ Basic search not working\n")
}

# Test 4: Verify Data Quality
cat("\n🔍 Testing Data Quality...\n")

if (!is.null(all_books) && nrow(all_books) > 0) {
  # Check gender values
  gender_values <- unique(all_books$gender)
  cat("Gender values in data:", paste(gender_values, collapse = ", "), "\n")
  
  # Check genre values
  genre_values <- unique(all_books$genre)
  cat("Sample genre values:", paste(head(genre_values, 5), collapse = ", "), "\n")
  
  # Check for NULLs
  null_genders <- sum(is.na(all_books$gender))
  null_genres <- sum(is.na(all_books$genre))
  cat("NULL genders:", null_genders, ", NULL genres:", null_genres, "\n")
}

cat("\n📋 Summary of Fixes:\n")
cat("✅ Fixed gender analysis to use 'Male'/'Female' instead of 'M'/'F'\n")
cat("✅ Fixed book explorer gender filter to use 'Male'/'Female'\n")
cat("✅ Fixed database utility functions to work without pool\n")
cat("✅ Fixed search_books function to use explicit year ranges\n")
cat("✅ Updated reset filters to use correct gender values\n")

cat("\n🚀 The Shiny app should now work correctly!\n")
cat("   Both gender analysis and book filtering should be functional.\n")
