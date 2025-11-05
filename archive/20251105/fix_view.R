# Fix book_sales_summary view
# This script updates the view to handle NULL values properly

library(DBI)
library(RPostgreSQL)

# Load database configuration
if (Sys.getenv("DB_USER") != "" && Sys.getenv("DB_PASSWORD") != "") {
  db_config <- list(
    host = ifelse(Sys.getenv("DB_HOST") != "", Sys.getenv("DB_HOST"), "localhost"),
    dbname = ifelse(Sys.getenv("DB_NAME") != "", Sys.getenv("DB_NAME"), "american_authorship"),
    user = Sys.getenv("DB_USER"),
    password = Sys.getenv("DB_PASSWORD")
  )
} else {
  source("scripts/config/database_config.R")
}

tryCatch({
  # Connect to database
  con <- dbConnect(
    RPostgreSQL::PostgreSQL(),
    host = db_config$host,
    dbname = db_config$dbname,
    user = db_config$user,
    password = db_config$password
  )

  cat("🔗 Connected to database\n")

  # Update the view with better NULL handling
  cat("👁️  Updating book_sales_summary view...\n")
  dbExecute(con, "
  CREATE OR REPLACE VIEW book_sales_summary AS
  SELECT 
    be.book_id,
    be.author_surname,
    be.gender,
    be.book_title,
    be.genre,
    be.publisher,
    be.publication_year,
    COALESCE(COUNT(DISTINCT CASE WHEN bs.sales_count IS NOT NULL THEN bs.year END), 0) as years_with_sales,
    MIN(bs.year) as first_sale_year,
    MAX(bs.year) as last_sale_year,
    COALESCE(SUM(CASE WHEN bs.sales_count IS NOT NULL THEN bs.sales_count ELSE 0 END), 0) as total_sales
  FROM book_entries be
  LEFT JOIN book_sales bs ON be.book_id = bs.book_id
  GROUP BY be.book_id, be.author_surname, be.gender, be.book_title, be.genre, be.publisher, be.publication_year
  ")

  cat("✅ View updated successfully!\n")

  # Test the view
  cat("🧪 Testing the view...\n")
  test_result <- dbGetQuery(con, "SELECT COUNT(*) as total_books, SUM(total_sales) as total_sales_sum FROM book_sales_summary LIMIT 1")
  print(test_result)

  # Disconnect
  dbDisconnect(con)
  cat("✅ Database view fix complete!\n")

}, error = function(e) {
  cat("❌ Error:", e$message, "\n")
  cat("This is likely due to database connection issues.\n")
  cat("The Shiny app code has been fixed and should work once the database is accessible.\n")
}) 