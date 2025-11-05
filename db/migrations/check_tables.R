# Quick script to check database tables and examine sample data
library(DBI)
library(RPostgreSQL)

# Load database configuration
if (Sys.getenv("DB_USER") != "" && Sys.getenv("DB_PASSWORD") != "") {
  cat("🔐 Using environment variables for database connection...\n")
  db_config <- list(
    host = ifelse(Sys.getenv("DB_HOST") != "", Sys.getenv("DB_HOST"), "localhost"),
    dbname = ifelse(Sys.getenv("DB_NAME") != "", Sys.getenv("DB_NAME"), "american_authorship"),
    user = Sys.getenv("DB_USER"),
    password = Sys.getenv("DB_PASSWORD")
  )
} else {
  cat("📁 Using config file for database connection...\n")
  source("scripts/config/database_config.R")
}

con <- dbConnect(
  RPostgreSQL::PostgreSQL(),
  host = db_config$host,
  dbname = db_config$dbname,
  user = db_config$user,
  password = db_config$password
)

cat("🔗 Connected to database\n")

# List all tables
cat("\n📋 Tables in database:\n")
tables <- dbListTables(con)
print(tables)

# Function to examine a table
examine_table <- function(table_name, sample_rows = 5) {
  cat("\n", rep("=", 60), "\n")
  cat("📊 EXAMINING TABLE:", toupper(table_name), "\n")
  cat(rep("=", 60), "\n")

  # Get row count
  count_query <- paste("SELECT COUNT(*) as count FROM", table_name)
  row_count <- dbGetQuery(con, count_query)$count
  cat("� Total rows:", row_count, "\n")

  if (row_count == 0) {
    cat("⚠️  Table is empty\n")
    return()
  }

  # Get table structure
  cat("\n🏗️  Table structure:\n")
  fields <- dbListFields(con, table_name)
  cat("Columns:", paste(fields, collapse = ", "), "\n")

  # Show sample rows
  cat("\n📋 Sample rows (first", min(sample_rows, row_count), "rows):\n")
  sample_query <- paste("SELECT * FROM", table_name, "LIMIT", sample_rows)
  sample_data <- dbGetQuery(con, sample_query)
  print(sample_data)

  # Show some basic stats for numeric columns
  if (table_name == "book_entries") {
    cat("\n📊 Quick stats:\n")
    stats <- dbGetQuery(con, "
      SELECT
        COUNT(DISTINCT author_surname) as unique_authors,
        COUNT(DISTINCT publisher) as unique_publishers,
        COUNT(DISTINCT genre) as unique_genres,
        MIN(publication_year) as earliest_year,
        MAX(publication_year) as latest_year
      FROM book_entries
    ")
    print(stats)

    # Add detailed column tabulations for book_entries
    cat("\n📊 DETAILED COLUMN TABULATIONS:\n")

    # Tabulate gender
    cat("\n🚻 Gender distribution:\n")
    gender_tab <- dbGetQuery(con, "
      SELECT gender, COUNT(*) as count
      FROM book_entries
      GROUP BY gender
      ORDER BY count DESC
    ")
    print(gender_tab)

    # Tabulate genre
    cat("\n📚 Genre distribution:\n")
    genre_tab <- dbGetQuery(con, "
      SELECT genre, COUNT(*) as count
      FROM book_entries
      GROUP BY genre
      ORDER BY count DESC
    ")
    print(genre_tab)

    # Tabulate binding
    cat("\n📖 Binding distribution:\n")
    binding_tab <- dbGetQuery(con, "
      SELECT binding, COUNT(*) as count
      FROM book_entries
      GROUP BY binding
      ORDER BY count DESC
    ")
    print(binding_tab)

    # Tabulate top publishers
    cat("\n🏢 Top 10 Publishers:\n")
    publisher_tab <- dbGetQuery(con, "
      SELECT publisher, COUNT(*) as count
      FROM book_entries
      GROUP BY publisher
      ORDER BY count DESC
      LIMIT 10
    ")
    print(publisher_tab)

    # Tabulate top authors
    cat("\n✍️  Top 10 Authors:\n")
    author_tab <- dbGetQuery(con, "
      SELECT author_surname, COUNT(*) as count
      FROM book_entries
      GROUP BY author_surname
      ORDER BY count DESC
      LIMIT 10
    ")
    print(author_tab)

    # Publication year distribution by decade
    cat("\n📅 Publication years by decade:\n")
    decade_tab <- dbGetQuery(con, "
      SELECT
        FLOOR(publication_year / 10) * 10 as decade_start,
        COUNT(*) as count
      FROM book_entries
      WHERE publication_year IS NOT NULL
      GROUP BY FLOOR(publication_year / 10) * 10
      ORDER BY decade_start
    ")
    print(decade_tab)

  } else if (table_name == "book_sales") {
    cat("\n📊 Sales stats:\n")
    stats <- dbGetQuery(con, "
      SELECT
        COUNT(DISTINCT book_id) as unique_books,
        MIN(year) as earliest_year,
        MAX(year) as latest_year,
        SUM(sales_count) as total_sales,
        AVG(sales_count) as avg_sales_per_record
      FROM book_sales
    ")
    print(stats)

    # Add detailed tabulations for book_sales
    cat("\n📊 SALES DATA TABULATIONS:\n")

    # Sales by decade
    cat("\n📅 Sales by decade:\n")
    sales_decade_tab <- dbGetQuery(con, "
      SELECT
        FLOOR(year / 10) * 10 as decade_start,
        COUNT(*) as total_records,
        COUNT(DISTINCT book_id) as unique_books,
        SUM(sales_count) as total_sales
      FROM book_sales
      GROUP BY FLOOR(year / 10) * 10
      ORDER BY decade_start
    ")
    print(sales_decade_tab)

    # Top selling books
    cat("\n📈 Top 10 selling books (by total sales):\n")
    top_books_tab <- dbGetQuery(con, "
      SELECT
        book_id,
        SUM(sales_count) as total_sales,
        COUNT(*) as years_with_sales,
        MIN(year) as first_year,
        MAX(year) as last_year
      FROM book_sales
      WHERE sales_count > 0
      GROUP BY book_id
      ORDER BY total_sales DESC
      LIMIT 10
    ")
    print(top_books_tab)

  } else if (table_name == "royalty_tiers") {
    cat("\n📊 Royalty stats:\n")
    stats <- dbGetQuery(con, "
      SELECT
        COUNT(DISTINCT book_id) as unique_books,
        COUNT(DISTINCT tier) as unique_tiers,
        MIN(rate) as min_rate,
        MAX(rate) as max_rate,
        AVG(rate) as avg_rate,
        COUNT(CASE WHEN sliding_scale = TRUE THEN 1 END) as sliding_scale_count
      FROM royalty_tiers
    ")
    print(stats)

    # Add detailed tabulations for royalty_tiers
    cat("\n📊 ROYALTY TIERS TABULATIONS:\n")

    # Royalty rates distribution
    cat("\n💰 Royalty rates distribution:\n")
    rates_tab <- dbGetQuery(con, "
      SELECT
        rate,
        COUNT(*) as count,
        COUNT(DISTINCT book_id) as unique_books
      FROM royalty_tiers
      GROUP BY rate
      ORDER BY rate
    ")
    print(rates_tab)

    # Tier distribution
    cat("\n📊 Tier distribution:\n")
    tier_tab <- dbGetQuery(con, "
      SELECT
        tier,
        COUNT(*) as count,
        AVG(rate) as avg_rate,
        MIN(rate) as min_rate,
        MAX(rate) as max_rate
      FROM royalty_tiers
      GROUP BY tier
      ORDER BY tier
    ")
    print(tier_tab)

    # Sliding scale distribution
    cat("\n⚖️  Sliding scale distribution:\n")
    sliding_tab <- dbGetQuery(con, "
      SELECT
        sliding_scale,
        COUNT(*) as count,
        COUNT(DISTINCT book_id) as unique_books
      FROM royalty_tiers
      GROUP BY sliding_scale
      ORDER BY sliding_scale
    ")
    print(sliding_tab)

  }
}

# Examine each table
main_tables <- c("book_entries", "book_sales", "royalty_tiers")

for (table in main_tables) {
  if (table %in% tables) {
    examine_table(table, sample_rows = 3)
  } else {
    cat("\n⚠️  Table", table, "not found in database\n")
  }
}

# Check for any other tables
other_tables <- setdiff(tables, main_tables)
if (length(other_tables) > 0) {
  cat("\n🔍 Other tables found:\n")
  for (table in other_tables) {
    examine_table(table, sample_rows = 2)
  }
}

# Check views
cat("\n👁️  Checking for views:\n")
views <- dbGetQuery(con, "
  SELECT viewname
  FROM pg_views
  WHERE schemaname = 'public'
")

if (nrow(views) > 0) {
  cat("Found views:\n")
  for (view in views$viewname) {
    cat("  -", view, "\n")
    # Show sample from view
    sample_query <- paste("SELECT * FROM", view, "LIMIT 2")
    sample_data <- dbGetQuery(con, sample_query)
    print(sample_data)
  }
} else {
  cat("No views found\n")
}

dbDisconnect(con)
cat("\n✅ Database examination completed!\n")