# Import Excel Data to PostgreSQL
# This file imports the American Authorship Excel data into the database

library(DBI)
library(RPostgreSQL)
library(readxl)
library(dplyr)
library(tidyr)
library(stringr)

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

# Connect to database
con <- dbConnect(
  RPostgreSQL::PostgreSQL(),
  host = db_config$host,
  dbname = db_config$dbname,
  user = db_config$user,
  password = db_config$password
)

cat("🔗 Connected to database\n")

# Path to your Excel file
excel_file <- "~/anesko/data/original/anesko_db_original.xlsx"

# Check if file exists
if (!file.exists(excel_file)) {
  stop("❌ Excel file not found. Please ensure the file is in the data/ directory")
}

# Read Excel sheets
cat("📖 Reading Excel file...\n")
book_entries <- read_excel(excel_file, sheet = "Book_Entry_Table")
book_sales <- read_excel(excel_file, sheet = "Book_Sales_Table")

cat("📊 Found", nrow(book_entries), "book entries\n")
cat("💰 Found", nrow(book_sales), "sales records\n")

# Clean and prepare book_entries data
cat("\n🧹 Cleaning book entries data...\n")

# Extract publication year from Book ID (e.g., GA1901A -> 1901)
book_entries <- book_entries %>%
  mutate(
    # Extract year from Book ID using regex
    publication_year = as.integer(str_extract(Book_ID, "\\d{4}")),
    
    # Clean up column names to match database
    book_id = Book_ID,
    author_surname = Author_Surname,
    gender = Gender,
    book_title = Book_Title,
    genre = Genre,
    binding = Binding,
    notes = Notes,
    retail_price = as.numeric(Retail_Price),
    
    # Handle royalty rate - convert "SS" and percentages
    royalty_rate = case_when(
      Royalty_Rate == "SS" ~ NA_real_,  # Handle special cases
      grepl("%", Royalty_Rate) ~ as.numeric(gsub("%", "", Royalty_Rate)) / 100,
      TRUE ~ as.numeric(Royalty_Rate)
    ),
    
    contract_terms = Contract_Terms,
    publisher = Publisher
  ) %>%
  select(book_id, author_surname, gender, book_title, genre, binding, 
         notes, retail_price, royalty_rate, contract_terms, publisher, publication_year)

# Check for duplicates
duplicates <- book_entries %>% 
  group_by(book_id) %>% 
  filter(n() > 1)

if (nrow(duplicates) > 0) {
  cat("⚠️  Warning: Found", nrow(duplicates), "duplicate book IDs\n")
  print(duplicates$book_id)
  
  # Keep only first occurrence
  book_entries <- book_entries %>% 
    distinct(book_id, .keep_all = TRUE)
}

# Insert book entries
cat("\n📥 Inserting book entries into database...\n")

# Clear existing data (careful in production!)
dbExecute(con, "TRUNCATE TABLE book_entries CASCADE")

# Insert data
dbWriteTable(con, "book_entries", book_entries, 
             append = TRUE, row.names = FALSE)

cat("✅ Inserted", nrow(book_entries), "book entries\n")

# Clean and prepare book_sales data
cat("\n🧹 Cleaning sales data...\n")

# The sales table has years as columns (1875-1920)
# We need to pivot it to long format
sales_long <- book_sales %>%
  # Assuming first column is Book_ID
  rename(book_id = 1) %>%
  # Pivot all year columns to long format
  pivot_longer(
    cols = matches("^\\d{4}$"),  # Columns that are 4-digit years
    names_to = "year",
    values_to = "sales_count"
  ) %>%
  mutate(
    year = as.integer(year),
    sales_count = as.integer(sales_count)
  ) %>%
  # Remove NA sales (no sales that year)
  filter(!is.na(sales_count))

# Check if there are additional columns for limits and rates
if ("Limits" %in% names(book_sales)) {
  sales_long <- sales_long %>%
    left_join(
      book_sales %>% select(book_id = 1, sales_limit = Limits),
      by = "book_id"
    )
}

if ("Rates" %in% names(book_sales)) {
  sales_long <- sales_long %>%
    left_join(
      book_sales %>% select(book_id = 1, sales_rate = Rates),
      by = "book_id"
    )
}

# Ensure we have the required columns
if (!"sales_limit" %in% names(sales_long)) {
  sales_long$sales_limit <- NA_integer_
}

if (!"sales_rate" %in% names(sales_long)) {
  sales_long$sales_rate <- NA_real_
}

# Select final columns
sales_long <- sales_long %>%
  select(book_id, year, sales_count, sales_limit, sales_rate)

# Check for book_ids that don't exist in book_entries
missing_books <- sales_long %>%
  filter(!book_id %in% book_entries$book_id) %>%
  distinct(book_id)

if (nrow(missing_books) > 0) {
  cat("⚠️  Warning: Found", nrow(missing_books), "book IDs in sales that don't exist in entries\n")
  print(missing_books$book_id)
  
  # Remove sales for non-existent books
  sales_long <- sales_long %>%
    filter(book_id %in% book_entries$book_id)
}

# Insert sales data
cat("\n📥 Inserting sales data into database...\n")

# Clear existing data
dbExecute(con, "TRUNCATE TABLE book_sales CASCADE")

# Insert data in chunks to avoid memory issues
chunk_size <- 1000
n_chunks <- ceiling(nrow(sales_long) / chunk_size)

for (i in 1:n_chunks) {
  start_row <- (i - 1) * chunk_size + 1
  end_row <- min(i * chunk_size, nrow(sales_long))
  
  chunk <- sales_long[start_row:end_row, ]
  
  dbWriteTable(con, "book_sales", chunk, 
               append = TRUE, row.names = FALSE)
  
  cat(".", sep = "")
}

cat("\n✅ Inserted", nrow(sales_long), "sales records\n")

# Verify data import
cat("\n🔍 Verifying data import...\n")

# Check counts
entry_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM book_entries")$count
sales_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM book_sales")$count

cat("📚 Total book entries in database:", entry_count, "\n")
cat("💰 Total sales records in database:", sales_count, "\n")

# Show sample data
cat("\n📋 Sample book entries:\n")
sample_entries <- dbGetQuery(con, "
  SELECT book_id, author_surname, book_title, genre, publication_year 
  FROM book_entries 
  LIMIT 5
")
print(sample_entries)

cat("\n📊 Sales summary by decade:\n")
decade_summary <- dbGetQuery(con, "
  SELECT 
    (year / 10) * 10 as decade,
    COUNT(DISTINCT book_id) as unique_books,
    COUNT(*) as total_records,
    SUM(sales_count) as total_sales
  FROM book_sales
  GROUP BY decade
  ORDER BY decade
")
print(decade_summary)

# Disconnect
dbDisconnect(con)
cat("\n✅ Data import complete!\n")