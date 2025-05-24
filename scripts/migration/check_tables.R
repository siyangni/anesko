# Quick script to check database tables
library(DBI)
library(RPostgreSQL)

# Use environment variables for connection
db_config <- list(
  host = "localhost",
  dbname = "american_authorship", 
  user = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASSWORD")
)

con <- dbConnect(
  RPostgreSQL::PostgreSQL(),
  host = db_config$host,
  dbname = db_config$dbname,
  user = db_config$user,
  password = db_config$password
)

# List all tables
cat("📋 Tables in database:\n")
tables <- dbListTables(con)
print(tables)

# If book_entries exists, show its structure
if ("book_entries" %in% tables) {
  cat("\n📚 book_entries table structure:\n")
  fields <- dbListFields(con, "book_entries")
  print(fields)
  
  # Show table info
  cat("\n📊 Table info:\n")
  info <- dbGetQuery(con, "
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns 
    WHERE table_name = 'book_entries'
    ORDER BY ordinal_position
  ")
  print(info)
}

dbDisconnect(con)
cat("✅ Database check completed!\n") 