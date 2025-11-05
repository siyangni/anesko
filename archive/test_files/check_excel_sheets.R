# Check Excel Sheets and Fix Sliding Scale Conversion
library(readxl)
library(dplyr)

cat("🔍 Checking Excel File Structure\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

excel_path <- "../data/original/anesko_db_original.xlsx"

if (file.exists(excel_path)) {
  cat("✅ Found Excel file\n")
  
  # List all sheets
  sheets <- excel_sheets(excel_path)
  cat("📋 Available sheets:\n")
  for (i in seq_along(sheets)) {
    cat("  ", i, ":", sheets[i], "\n")
  }
  
  # Try to find the sheet with sales data
  for (sheet_name in sheets) {
    cat("\n📊 Examining sheet:", sheet_name, "\n")
    tryCatch({
      data <- read_excel(excel_path, sheet = sheet_name, n_max = 5)
      cat("  Columns:", paste(names(data), collapse = ", "), "\n")
      
      # Check if this sheet has sliding scale data
      if ("Sliding Scale?" %in% names(data)) {
        cat("  ✅ Found 'Sliding Scale?' column in", sheet_name, "\n")
        
        # Read full data to analyze sliding scale
        full_data <- read_excel(excel_path, sheet = sheet_name)
        sliding_values <- full_data$`Sliding Scale?`
        
        cat("  📊 Sliding Scale values:\n")
        print(table(sliding_values, useNA = "always"))
        
        # Test proper conversion logic
        cat("\n  🔧 Testing proper conversion logic:\n")
        
        # Proper conversion: convert 0/1 to FALSE/TRUE
        proper_conversion <- case_when(
          sliding_values == 0 | sliding_values == "0" ~ FALSE,
          sliding_values == 1 | sliding_values == "1" ~ TRUE,
          is.na(sliding_values) ~ NA,
          TRUE ~ NA
        )
        
        cat("  Original values -> Proper conversion:\n")
        conversion_table <- table(
          Original = sliding_values, 
          Converted = proper_conversion, 
          useNA = "always"
        )
        print(conversion_table)
        
        # Count how many would be TRUE vs FALSE
        cat("\n  📊 Conversion summary:\n")
        cat("    FALSE (no sliding scale):", sum(proper_conversion == FALSE, na.rm = TRUE), "\n")
        cat("    TRUE (has sliding scale):", sum(proper_conversion == TRUE, na.rm = TRUE), "\n")
        cat("    NA (unknown):", sum(is.na(proper_conversion)), "\n")
        
        break
      }
    }, error = function(e) {
      cat("  ❌ Error reading sheet:", e$message, "\n")
    })
  }
} else {
  cat("❌ Excel file not found\n")
}
