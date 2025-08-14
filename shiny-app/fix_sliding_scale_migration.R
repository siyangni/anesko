# Fix Sliding Scale Migration
# This script re-runs the royalty tiers migration with the corrected sliding scale conversion

library(DBI)
library(RPostgreSQL)
library(dplyr)

cat("🔧 Fixing Sliding Scale Migration\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Load database configuration
source("../scripts/config/database_config.R")

# Connect to database
con <- dbConnect(
  RPostgreSQL::PostgreSQL(),
  host = db_config$host,
  dbname = db_config$dbname,
  user = db_config$user,
  password = db_config$password
)

cat("✅ Connected to database\n")

# Step 1: Check current sliding scale data
cat("\n📊 Checking current sliding scale data in database...\n")
current_data <- dbGetQuery(con, "
  SELECT 
    sliding_scale,
    COUNT(*) as count
  FROM royalty_tiers 
  GROUP BY sliding_scale
  ORDER BY sliding_scale
")
print(current_data)

# Step 2: Read the cleaned royalty tiers data with proper conversion
cat("\n📖 Reading cleaned royalty tiers data with fixed conversion...\n")
royalty_tiers_file <- "../data/cleaned/royalty_tiers_cleaned.csv"

if (file.exists(royalty_tiers_file)) {
  cat("✅ Found royalty tiers file\n")
  
  royalty_tiers_data <- read.csv(royalty_tiers_file, stringsAsFactors = FALSE)
  cat("📊 Original data rows:", nrow(royalty_tiers_data), "\n")
  
  # Check original sliding scale values
  cat("📋 Original sliding scale values:\n")
  print(table(royalty_tiers_data$sliding_scale, useNA = "always"))
  
  # Get valid book_ids from book_entries table
  valid_book_ids <- dbGetQuery(con, "SELECT DISTINCT book_id FROM book_entries")$book_id
  cat("📋 Found", length(valid_book_ids), "valid book IDs in book_entries\n")

  # Apply the corrected conversion logic
  royalty_data <- royalty_tiers_data %>%
    mutate(
      # Ensure proper data types
      book_id = as.character(book_ID),
      tier = as.integer(tier),
      rate = as.numeric(rate),
      lower_limit = as.integer(lower_limit),
      # Handle large upper_limit values properly
      upper_limit = case_when(
        is.infinite(upper_limit) ~ NA_integer_,
        upper_limit > 2147483647 ~ NA_integer_,  # Max integer value
        TRUE ~ as.integer(upper_limit)
      ),
      # Fix sliding_scale conversion: properly handle 0/1 values
      sliding_scale = case_when(
        sliding_scale == 0 | sliding_scale == "0" ~ FALSE,
        sliding_scale == 1 | sliding_scale == "1" ~ TRUE,
        is.na(sliding_scale) ~ NA,
        TRUE ~ NA
      )
    ) %>%
    select(book_id, tier, rate, lower_limit, upper_limit, sliding_scale) %>%
    # Remove any rows with missing book_id or invalid tiers
    filter(!is.na(book_id) & book_id != "" & !is.na(tier) & !is.na(rate)) %>%
    # Only keep records for books that exist in book_entries
    filter(book_id %in% valid_book_ids)
  
  cat("📊 Processed data rows:", nrow(royalty_data), "\n")
  cat("📋 Corrected sliding scale values:\n")
  print(table(royalty_data$sliding_scale, useNA = "always"))
  
  # Step 3: Update the database
  cat("\n🔄 Updating database with corrected sliding scale values...\n")
  
  # Clear existing royalty tiers data
  dbExecute(con, "DELETE FROM royalty_tiers")
  cat("✅ Cleared existing royalty tiers data\n")
  
  # Insert corrected data
  if (nrow(royalty_data) > 0) {
    chunk_size <- 1000
    n_chunks <- ceiling(nrow(royalty_data) / chunk_size)
    
    for (i in 1:n_chunks) {
      start_row <- (i - 1) * chunk_size + 1
      end_row <- min(i * chunk_size, nrow(royalty_data))
      
      chunk <- royalty_data[start_row:end_row, ]
      
      dbWriteTable(con, "royalty_tiers", chunk,
                   append = TRUE, row.names = FALSE)
      
      cat(".", sep = "")
    }
    
    cat("\n✅ Inserted", nrow(royalty_data), "corrected royalty tier records\n")
  } else {
    cat("❌ No royalty tier data to insert\n")
  }
  
  # Step 4: Verify the fix
  cat("\n🔍 Verifying the fix...\n")
  updated_data <- dbGetQuery(con, "
    SELECT 
      sliding_scale,
      COUNT(*) as count,
      COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage
    FROM royalty_tiers 
    GROUP BY sliding_scale
    ORDER BY sliding_scale
  ")
  
  cat("📊 Updated sliding scale data:\n")
  print(updated_data)
  
  # Check for sliding scale records
  sliding_scale_count <- dbGetQuery(con, "
    SELECT COUNT(*) as count
    FROM royalty_tiers 
    WHERE sliding_scale = TRUE
  ")
  
  cat("✅ Books with sliding scale royalty structures:", sliding_scale_count$count, "\n")
  
} else {
  cat("❌ Royalty tiers file not found:", royalty_tiers_file, "\n")
  cat("💡 Please run scripts/cleaning/pre_migration_cleaning.R first\n")
}

# Close database connection
dbDisconnect(con)

cat("\n🎉 Sliding scale migration fix completed!\n")
cat("💡 The 'Sliding Scale Only' filter should now work correctly in the Shiny app.\n")
