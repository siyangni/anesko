# Test Original Sliding Scale Data
# This script examines the original Excel data to understand sliding scale values

library(readxl)
library(dplyr)

cat("🔍 Examining Original Sliding Scale Data\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

# Test 1: Check if original Excel file exists and examine sliding scale column
cat("\n📊 Examining original Excel file...\n")
tryCatch({
  excel_path <- "../data/original/anesko_db_original.xlsx"
  
  if (file.exists(excel_path)) {
    cat("✅ Found original Excel file\n")
    
    # Read the book_sales sheet
    book_sales <- read_excel(excel_path, sheet = "book_sales")
    
    cat("📋 Book sales data structure:\n")
    cat("Rows:", nrow(book_sales), "\n")
    cat("Columns:", ncol(book_sales), "\n")
    
    # Check if Sliding Scale column exists
    sliding_scale_cols <- names(book_sales)[grepl("sliding", names(book_sales), ignore.case = TRUE)]
    cat("Sliding scale related columns:", paste(sliding_scale_cols, collapse = ", "), "\n")
    
    if ("Sliding Scale?" %in% names(book_sales)) {
      cat("\n📊 'Sliding Scale?' column analysis:\n")
      
      # Check data types and values
      sliding_values <- book_sales$`Sliding Scale?`
      cat("Data type:", class(sliding_values), "\n")
      cat("Unique values:\n")
      print(table(sliding_values, useNA = "always"))
      
      # Show sample records with different sliding scale values
      cat("\n📋 Sample records by sliding scale value:\n")
      unique_vals <- unique(sliding_values)
      for (val in unique_vals[!is.na(unique_vals)]) {
        sample_records <- book_sales[book_sales$`Sliding Scale?` == val & !is.na(book_sales$`Sliding Scale?`), ]
        if (nrow(sample_records) > 0) {
          cat("\nSliding Scale =", val, "- Sample records (", nrow(sample_records), "total):\n")
          sample_cols <- c("book_ID", "r1", "r2", "r3", "r4", "limit1", "limit2", "limit3", "limit4", "Sliding Scale?")
          available_cols <- intersect(sample_cols, names(sample_records))
          print(head(sample_records[, available_cols], 3))
        }
      }
      
      # Check if there are any TRUE/1 values that indicate sliding scale
      cat("\n🔍 Looking for sliding scale indicators:\n")
      if (any(sliding_values == 1, na.rm = TRUE)) {
        cat("✅ Found records with sliding_scale = 1\n")
        sliding_scale_books <- book_sales[book_sales$`Sliding Scale?` == 1 & !is.na(book_sales$`Sliding Scale?`), ]
        cat("Number of books with sliding scale:", nrow(sliding_scale_books), "\n")
        
        # Show examples
        if (nrow(sliding_scale_books) > 0) {
          cat("Examples of sliding scale books:\n")
          example_cols <- c("book_ID", "r1", "r2", "r3", "r4", "Sliding Scale?")
          available_cols <- intersect(example_cols, names(sliding_scale_books))
          print(head(sliding_scale_books[, available_cols], 5))
        }
      } else if (any(sliding_values == "1", na.rm = TRUE)) {
        cat("✅ Found records with sliding_scale = '1' (string)\n")
      } else if (any(sliding_values == TRUE, na.rm = TRUE)) {
        cat("✅ Found records with sliding_scale = TRUE\n")
      } else {
        cat("⚠️  No sliding scale indicators found (no 1, '1', or TRUE values)\n")
      }
      
    } else {
      cat("❌ 'Sliding Scale?' column not found\n")
      cat("Available columns:\n")
      print(names(book_sales))
    }
    
  } else {
    cat("❌ Original Excel file not found at:", excel_path, "\n")
  }
}, error = function(e) {
  cat("❌ Error reading Excel file:", e$message, "\n")
})

# Test 2: Check the data conversion logic
cat("\n🔧 Testing data conversion logic...\n")
tryCatch({
  # Simulate the conversion from the migration script
  test_values <- c(0, 1, "0", "1", TRUE, FALSE, NA, "", " ")
  
  cat("Testing conversion of various values to logical:\n")
  for (val in test_values) {
    converted <- tryCatch({
      as.logical(as.character(val))
    }, error = function(e) {
      paste("ERROR:", e$message)
    })
    cat("  ", deparse(val), "->", deparse(converted), "\n")
  }
}, error = function(e) {
  cat("❌ Error testing conversion logic:", e$message, "\n")
})

cat("\n🎯 Investigation completed!\n")
cat("💡 This will help determine:\n")
cat("   - What values exist in the original 'Sliding Scale?' column\n")
cat("   - Whether the data conversion logic is working correctly\n")
cat("   - If we need to fix the migration or update the UI\n")
