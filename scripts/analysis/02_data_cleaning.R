# Data Cleaning and Exploration
# 
# This script performs initial data cleaning and exploration of the migrated data

# Load necessary libraries
library(pacman)
p_load(DBI, RPostgreSQL, tidyverse, janitor, skimr, here)

# Source database configuration
source("scripts/config/database_config.R")

# Connect to database
con <- dbConnect(
  RPostgreSQL::PostgreSQL(),
  host = db_config$host,
  dbname = db_config$dbname,
  user = db_config$user,
  password = db_config$password
)

# List all tables
  tables <- dbListTables(con)
  
  for (i in seq_along(tables)) {
    table_name <- tables[i]
    cat(sprintf("%d. %s\n", i, table_name))
  }

# Get table structure
  cat("\n\n📋 TABLE STRUCTURES:\n")
  cat("=" %>% rep(50) %>% paste(collapse=""), "\n")
  
  for (table_name in tables) {
    cat("\nTable:", table_name, "\n")
    cat("=" %>% rep(50) %>% paste(collapse=""), "\n")

    # Get column information
    columns <- dbListFields(con, table_name)
    cat("Columns:", paste(columns, collapse=", "), "\n")

    # Get sample data
    cat("Sample data:\n")
    sample_data <- dbGetQuery(con, sprintf("SELECT * FROM %s LIMIT 5", table_name))
    print(sample_data)
  }

# ==========================================
# UNIQUE VALUES ANALYSIS
# ==========================================

cat("\n\n🔍 UNIQUE VALUES ANALYSIS:\n")
cat("=" %>% rep(60) %>% paste(collapse=""), "\n")

# Create output directory if it doesn't exist
if (!dir.exists("outputs/reports")) {
  dir.create("outputs/reports", recursive = TRUE)
}

# Open file to write results
output_file <- "outputs/reports/unique_values_analysis.txt"
sink(output_file)

cat("UNIQUE VALUES ANALYSIS\n")
cat("Generated on:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("=" %>% rep(60) %>% paste(collapse=""), "\n\n")

for (table_name in tables) {
  cat("TABLE:", toupper(table_name), "\n")
  cat("=" %>% rep(40) %>% paste(collapse=""), "\n")
  
  # Get all columns for this table
  columns <- dbListFields(con, table_name)
  
  for (column_name in columns) {
    cat("\nColumn:", column_name, "\n")
    cat("-" %>% rep(30) %>% paste(collapse=""), "\n")
    
    # Get unique values for this column
    query <- sprintf("SELECT DISTINCT %s FROM %s WHERE %s IS NOT NULL ORDER BY %s", 
                     column_name, table_name, column_name, column_name)
    
    tryCatch({
      unique_values <- dbGetQuery(con, query)
      
      if (nrow(unique_values) > 0) {
        # Count total unique values
        cat("Total unique values:", nrow(unique_values), "\n")
        
        # Show all unique values (limit display if too many)
        if (nrow(unique_values) <= 50) {
          cat("Unique values:\n")
          for (i in 1:nrow(unique_values)) {
            value <- unique_values[i, 1]
            if (is.na(value)) {
              cat(sprintf("  %d. <NA>\n", i))
            } else {
              cat(sprintf("  %d. %s\n", i, value))
            }
          }
        } else {
          cat("First 25 unique values:\n")
          for (i in 1:25) {
            value <- unique_values[i, 1]
            if (is.na(value)) {
              cat(sprintf("  %d. <NA>\n", i))
            } else {
              cat(sprintf("  %d. %s\n", i, value))
            }
          }
          cat(sprintf("  ... and %d more values\n", nrow(unique_values) - 25))
          
          cat("\nLast 25 unique values:\n")
          start_idx <- max(1, nrow(unique_values) - 24)
          for (i in start_idx:nrow(unique_values)) {
            value <- unique_values[i, 1]
            if (is.na(value)) {
              cat(sprintf("  %d. <NA>\n", i))
            } else {
              cat(sprintf("  %d. %s\n", i, value))
            }
          }
        }
      } else {
        cat("No unique values found (all values are NULL)\n")
      }
      
      # Check for NULL values
      null_query <- sprintf("SELECT COUNT(*) as null_count FROM %s WHERE %s IS NULL", 
                           table_name, column_name)
      null_count <- dbGetQuery(con, null_query)$null_count
      if (null_count > 0) {
        cat("NULL values:", null_count, "\n")
      }
      
    }, error = function(e) {
      cat("Error analyzing column:", e$message, "\n")
    })
    
    cat("\n")
  }
  
  cat("\n" %>% rep(3) %>% paste(collapse=""))
}

# Close the output file
sink()

# Also display summary to console
cat("\n📊 UNIQUE VALUES SUMMARY:\n")
cat("=" %>% rep(50) %>% paste(collapse=""), "\n")

for (table_name in tables) {
  cat("\nTable:", table_name, "\n")
  columns <- dbListFields(con, table_name)
  
  for (column_name in columns) {
    # Get count of unique values
    query <- sprintf("SELECT COUNT(DISTINCT %s) as unique_count FROM %s WHERE %s IS NOT NULL", 
                     column_name, table_name, column_name)
    
    tryCatch({
      unique_count <- dbGetQuery(con, query)$unique_count
      
      # Get null count
      null_query <- sprintf("SELECT COUNT(*) as null_count FROM %s WHERE %s IS NULL", 
                           table_name, column_name)
      null_count <- dbGetQuery(con, null_query)$null_count
      
      cat(sprintf("  %s: %d unique values", column_name, unique_count))
      if (null_count > 0) {
        cat(sprintf(" (%d nulls)", null_count))
      }
      cat("\n")
      
    }, error = function(e) {
      cat(sprintf("  %s: Error - %s\n", column_name, e$message))
    })
  }
}

cat(sprintf("\n📁 Detailed analysis saved to: %s\n", output_file))

# List all publishers in the table book_entries
publishers <- dbGetQuery(con, "SELECT DISTINCT publisher FROM book_entries")
print(publishers)

# ==========================================
# PUBLISHER NAME STANDARDIZATION
# ==========================================

cat("\n\n🔧 STANDARDIZING PUBLISHER NAMES:\n")
cat("=" %>% rep(50) %>% paste(collapse=""), "\n")

# Harper variations -> "Harper and Brothers"
cat("\nStandardizing Harper publishers...\n")
dbExecute(con, "UPDATE book_entries SET publisher = 'Harper and Brothers' WHERE publisher = 'Harper & Brothers'")
dbExecute(con, "UPDATE book_entries SET publisher = 'Harper and Brothers' WHERE publisher = 'Harper &Brothers'")
dbExecute(con, "UPDATE book_entries SET publisher = 'Harper and Brothers' WHERE publisher = 'Harper and Bros.'")

# Houghton variations -> "Houghton-Mifflin"
cat("Standardizing Houghton publishers...\n")
dbExecute(con, "UPDATE book_entries SET publisher = 'Houghton-Mifflin' WHERE publisher = 'Hougton, Mifflin'")
dbExecute(con, "UPDATE book_entries SET publisher = 'Houghton-Mifflin' WHERE publisher = 'Houghton, Mifflin'")
dbExecute(con, "UPDATE book_entries SET publisher = 'Houghton-Mifflin' WHERE publisher = 'Houghton Mifflin'")
dbExecute(con, "UPDATE book_entries SET publisher = 'Houghton-Mifflin' WHERE publisher = 'Houhgton, Mifflin'")

# Hougthon -> Houghton
dbExecute(con, "UPDATE book_entries SET publisher = 'Houghton' WHERE publisher = 'Hougthon'")

# Osgood standardization
cat("Standardizing Osgood publishers...\n")
dbExecute(con, "UPDATE book_entries SET publisher = 'Osgood-McIlvaine' WHERE publisher = 'Osgood, McIlvaine'")

# Fields standardization
cat("Standardizing Fields publishers...\n")
dbExecute(con, "UPDATE book_entries SET publisher = 'Fields-Osgood' WHERE publisher = 'Fields, Osgood'")

cat("\n✅ Publisher standardization completed!\n")

# Verify the changes by checking distinct publishers again
cat("\n📊 UPDATED PUBLISHER LIST:\n")
cat("=" %>% rep(50) %>% paste(collapse=""), "\n")
updated_publishers <- dbGetQuery(con, "SELECT DISTINCT publisher FROM book_entries ORDER BY publisher")
print(updated_publishers)

# Always close connection
dbDisconnect(con)