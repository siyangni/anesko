# Test Fixed Query for Author Networks
library(dplyr)

cat("🔧 Testing Fixed PostgreSQL Query\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Load configuration and utilities
source("config/cloud_config.R")
source("utils/database.R")

# Test the fixed query logic
cat("\n🔍 Testing fixed query logic...\n")

gender_filter <- c("Male", "Female")
year_range <- c(1860, 1920)

# Create gender filter clause
gender_placeholders <- paste0("$", 3:(2 + length(gender_filter)), collapse = ",")
author_query <- paste0("
  SELECT 
    be.author_id,
    be.author_surname,
    be.gender,
    be.publisher,
    be.genre,
    be.publication_year,
    COALESCE(bs.total_sales, 0) as total_sales
  FROM book_entries be
  LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
  WHERE be.author_id IS NOT NULL
    AND be.gender IN (", gender_placeholders, ")
    AND be.publication_year BETWEEN $1 AND $2
  LIMIT 10
")

# Create parameter list with year range first, then gender values
params <- c(list(year_range[1], year_range[2]), as.list(gender_filter))

cat("📝 Query:\n", author_query, "\n")
cat("📋 Parameters:\n")
print(params)

tryCatch({
  book_data <- safe_db_query(author_query, params = params)
  
  if (!is.null(book_data) && nrow(book_data) > 0) {
    cat("✅ Query successful! Retrieved", nrow(book_data), "records\n")
    cat("📊 Sample data:\n")
    print(head(book_data, 3))
  } else {
    cat("⚠️  Query returned no data\n")
  }
}, error = function(e) {
  cat("❌ Query failed:", e$message, "\n")
})

cat("\n✅ Query testing completed!\n")
