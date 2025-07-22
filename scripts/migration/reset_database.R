# Reset Database Script
# This script drops all tables and recreates the database schema
# WARNING: This will delete ALL data in the database!

library(DBI)
library(RPostgreSQL)

cat("🔄 Database Reset Script\n")
cat("⚠️  WARNING: This will delete ALL data in the database!\n")
cat("Press Ctrl+C to cancel, or press Enter to continue...\n")
readline()

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

# Connect to database
cat("🔗 Connecting to database...\n")
con <- dbConnect(
  RPostgreSQL::PostgreSQL(),
  host = db_config$host,
  dbname = db_config$dbname,
  user = db_config$user,
  password = db_config$password
)

cat("✅ Connected to database\n")

# List existing tables
existing_tables <- dbGetQuery(con, "
  SELECT tablename 
  FROM pg_tables 
  WHERE schemaname = 'public'
")

if (nrow(existing_tables) > 0) {
  cat("\n📋 Found existing tables:\n")
  for (table in existing_tables$tablename) {
    cat("  -", table, "\n")
  }
} else {
  cat("\n📋 No existing tables found\n")
}

# Drop existing views first (they depend on tables)
cat("\n🗑️  Dropping existing views...\n")
tryCatch({
  dbExecute(con, "DROP VIEW IF EXISTS book_sales_summary CASCADE")
  cat("✅ Dropped view: book_sales_summary\n")
}, error = function(e) {
  cat("⚠️  Note: View book_sales_summary didn't exist or couldn't be dropped\n")
})

# Drop existing tables
cat("\n🗑️  Dropping existing tables...\n")

# Drop in reverse order of dependencies
tables_to_drop <- c("book_sales", "royalty_tiers", "book_entries")

for (table in tables_to_drop) {
  tryCatch({
    dbExecute(con, paste("DROP TABLE IF EXISTS", table, "CASCADE"))
    cat("✅ Dropped table:", table, "\n")
  }, error = function(e) {
    cat("⚠️  Note: Table", table, "didn't exist or couldn't be dropped\n")
  })
}

# Drop functions/triggers
cat("\n🗑️  Dropping functions and triggers...\n")
tryCatch({
  dbExecute(con, "DROP FUNCTION IF EXISTS update_modified_column() CASCADE")
  cat("✅ Dropped function: update_modified_column\n")
}, error = function(e) {
  cat("⚠️  Note: Function update_modified_column didn't exist\n")
})

# Verify tables are dropped
remaining_tables <- dbGetQuery(con, "
  SELECT tablename 
  FROM pg_tables 
  WHERE schemaname = 'public'
")

if (nrow(remaining_tables) == 0) {
  cat("\n✅ All tables successfully dropped\n")
} else {
  cat("\n⚠️  Some tables remain:\n")
  for (table in remaining_tables$tablename) {
    cat("  -", table, "\n")
  }
}

# Ask if user wants to recreate schema
cat("\n🏗️  Do you want to recreate the database schema? (y/n): ")
recreate <- readline()

if (tolower(recreate) %in% c("y", "yes")) {
  cat("\n🏗️  Recreating database schema...\n")
  
  # Disconnect current connection
  dbDisconnect(con)
  
  # Run schema creation script
  tryCatch({
    source("scripts/migration/02_create_schema.R")
    cat("\n✅ Database schema recreated successfully!\n")
    cat("🎯 You can now run the data import with:\n")
    cat("   Rscript scripts/migration/03_import_data.R\n")
    cat("   OR run the full migration:\n")
    cat("   Rscript scripts/migration/00_run_full_migration.R\n")
  }, error = function(e) {
    cat("\n❌ Error recreating schema:\n")
    cat("Error:", e$message, "\n")
    cat("💡 You can manually run: Rscript scripts/migration/02_create_schema.R\n")
  })
} else {
  # Disconnect
  dbDisconnect(con)
  cat("\n✅ Database reset complete (schema not recreated)\n")
  cat("🎯 To recreate the schema, run:\n")
  cat("   Rscript scripts/migration/02_create_schema.R\n")
}

cat("\n🎉 Database reset operation complete!\n")
