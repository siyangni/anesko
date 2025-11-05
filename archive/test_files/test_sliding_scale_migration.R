# Test Sliding Scale Migration Issue
# This script investigates the sliding scale data conversion issue

library(dplyr)

cat("🔍 Investigating Sliding Scale Migration Issue\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

# Load configuration and utilities
source("config/cloud_config.R")
source("utils/database.R")

# Test 1: Check the original data source to see if sliding scale data exists
cat("\n📊 Checking if original sliding scale data exists...\n")
tryCatch({
  # Check if we can find the cleaned data files
  if (file.exists("../data/cleaned/royalty_tiers.csv")) {
    cat("✅ Found royalty_tiers.csv file\n")
    
    # Read the CSV to see what sliding scale data looks like
    royalty_csv <- read.csv("../data/cleaned/royalty_tiers.csv", stringsAsFactors = FALSE)
    
    cat("📋 CSV file structure:\n")
    cat("Columns:", paste(names(royalty_csv), collapse = ", "), "\n")
    cat("Total rows:", nrow(royalty_csv), "\n")
    
    if ("sliding_scale" %in% names(royalty_csv)) {
      cat("\n📊 Sliding scale values in CSV:\n")
      sliding_scale_summary <- table(royalty_csv$sliding_scale, useNA = "always")
      print(sliding_scale_summary)
      
      # Show sample records with different sliding scale values
      cat("\n📋 Sample records by sliding scale value:\n")
      for (val in unique(royalty_csv$sliding_scale)) {
        if (!is.na(val)) {
          sample_records <- royalty_csv[royalty_csv$sliding_scale == val & !is.na(royalty_csv$sliding_scale), ]
          if (nrow(sample_records) > 0) {
            cat("Sliding scale =", val, "- Sample records:\n")
            print(head(sample_records[, c("book_ID", "tier", "rate", "sliding_scale")], 3))
          }
        }
      }
    } else {
      cat("❌ No sliding_scale column found in CSV\n")
    }
    
  } else {
    cat("⚠️  royalty_tiers.csv file not found\n")
  }
}, error = function(e) {
  cat("❌ Error reading CSV file:", e$message, "\n")
})

# Test 2: Check the data conversion logic from the migration script
cat("\n🔧 Testing data conversion logic...\n")
tryCatch({
  # Simulate the conversion logic from 03_import_data.R
  if (file.exists("../data/cleaned/royalty_tiers.csv")) {
    test_data <- read.csv("../data/cleaned/royalty_tiers.csv", stringsAsFactors = FALSE)
    
    if (nrow(test_data) > 0) {
      cat("📋 Original data types:\n")
      str(test_data[, c("book_ID", "tier", "rate", "sliding_scale")])
      
      # Apply the same conversion logic as in the migration script
      converted_data <- test_data %>%
        mutate(
          book_id = as.character(book_ID),
          tier = as.integer(tier),
          rate = as.numeric(rate),
          sliding_scale = as.logical(as.character(sliding_scale))  # This is the key conversion
        ) %>%
        select(book_id, tier, rate, sliding_scale) %>%
        filter(!is.na(book_id) & book_id != "" & !is.na(tier) & !is.na(rate))
      
      cat("\n📋 After conversion:\n")
      cat("Converted rows:", nrow(converted_data), "\n")
      
      if ("sliding_scale" %in% names(converted_data)) {
        cat("Sliding scale values after conversion:\n")
        sliding_scale_converted <- table(converted_data$sliding_scale, useNA = "always")
        print(sliding_scale_converted)
        
        # Show the conversion process for a few examples
        cat("\n🔍 Conversion examples:\n")
        sample_indices <- head(which(!is.na(test_data$sliding_scale)), 5)
        if (length(sample_indices) > 0) {
          for (i in sample_indices) {
            original_val <- test_data$sliding_scale[i]
            converted_val <- as.logical(as.character(original_val))
            cat("Original:", original_val, "->", "Converted:", converted_val, "\n")
          }
        }
      }
    }
  }
}, error = function(e) {
  cat("❌ Error testing conversion logic:", e$message, "\n")
})

# Test 3: Check what values might be causing the conversion to fail
cat("\n🔍 Investigating conversion issues...\n")
tryCatch({
  if (file.exists("../data/cleaned/royalty_tiers.csv")) {
    test_data <- read.csv("../data/cleaned/royalty_tiers.csv", stringsAsFactors = FALSE)
    
    if ("sliding_scale" %in% names(test_data)) {
      # Check unique values and their types
      unique_vals <- unique(test_data$sliding_scale)
      cat("Unique sliding_scale values:\n")
      for (val in unique_vals) {
        cat("Value:", val, "- Type:", class(val), "- Is NA:", is.na(val), "\n")
        
        # Test conversion
        converted <- tryCatch({
          as.logical(as.character(val))
        }, error = function(e) {
          paste("ERROR:", e$message)
        })
        cat("  Converts to:", converted, "\n")
      }
      
      # Check for problematic values
      problematic <- test_data[!test_data$sliding_scale %in% c(0, 1, TRUE, FALSE, NA), ]
      if (nrow(problematic) > 0) {
        cat("\n⚠️  Found problematic sliding_scale values:\n")
        print(unique(problematic$sliding_scale))
      }
    }
  }
}, error = function(e) {
  cat("❌ Error investigating conversion issues:", e$message, "\n")
})

cat("\n🎯 Investigation Summary:\n")
cat("- Check if sliding scale data exists in source files\n")
cat("- Verify data conversion logic is working correctly\n")
cat("- Identify why all values are NULL in database\n")
cat("\n✅ Sliding scale migration investigation completed!\n")
