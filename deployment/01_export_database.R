# Database Export Script for Cloud Migration
# This script exports the current PostgreSQL database for migration to NeonDB

library(DBI)
library(RPostgreSQL)
library(dplyr)

cat("🚀 Starting Database Export for Cloud Migration\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

# Load local database configuration
source("../scripts/config/database_config.R")

# Connect to local database
cat("📡 Connecting to local database...\n")
con <- tryCatch({
  dbConnect(
    RPostgreSQL::PostgreSQL(),
    host = db_config$host,
    dbname = db_config$dbname,
    user = db_config$user,
    password = db_config$password
  )
}, error = function(e) {
  stop("❌ Failed to connect to local database: ", e$message)
})

cat("✅ Connected to local database\n")

# Create export directory
export_dir <- "database_export"
if (!dir.exists(export_dir)) {
  dir.create(export_dir, recursive = TRUE)
}

# Export 1: Database Schema
cat("\n📋 Exporting database schema...\n")
schema_file <- file.path(export_dir, "database_schema.sql")

# Get all table creation statements
tables <- dbGetQuery(con, "
  SELECT table_name 
  FROM information_schema.tables 
  WHERE table_schema = 'public' 
  ORDER BY table_name
")

schema_sql <- c(
  "-- American Authorship Database Schema",
  "-- Generated for NeonDB migration",
  paste("-- Export Date:", Sys.time()),
  "",
  "-- Drop existing tables if they exist",
  "DROP TABLE IF EXISTS book_sales CASCADE;",
  "DROP TABLE IF EXISTS royalty_tiers CASCADE;",
  "DROP TABLE IF EXISTS book_entries CASCADE;",
  "DROP TABLE IF EXISTS book_sales_summary CASCADE;",
  ""
)

# Export table schemas
for (table_name in tables$table_name) {
  cat("  Exporting schema for:", table_name, "\n")
  
  # Get CREATE TABLE statement
  create_stmt <- dbGetQuery(con, paste0("
    SELECT 
      'CREATE TABLE ' || schemaname || '.' || tablename || ' (' ||
      array_to_string(
        array_agg(
          column_name || ' ' || data_type ||
          CASE 
            WHEN character_maximum_length IS NOT NULL 
            THEN '(' || character_maximum_length || ')'
            WHEN numeric_precision IS NOT NULL AND numeric_scale IS NOT NULL
            THEN '(' || numeric_precision || ',' || numeric_scale || ')'
            ELSE ''
          END ||
          CASE WHEN is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END
        ), ', '
      ) || ');' as create_statement
    FROM information_schema.columns c
    JOIN pg_tables t ON c.table_name = t.tablename
    WHERE c.table_name = '", table_name, "'
    GROUP BY schemaname, tablename
  "))
  
  if (nrow(create_stmt) > 0) {
    schema_sql <- c(schema_sql, "", paste("-- Table:", table_name), create_stmt$create_statement)
  }
}

# Add indexes and constraints
cat("  Exporting indexes and constraints...\n")
indexes <- dbGetQuery(con, "
  SELECT indexname, indexdef 
  FROM pg_indexes 
  WHERE schemaname = 'public'
  ORDER BY indexname
")

if (nrow(indexes) > 0) {
  schema_sql <- c(schema_sql, "", "-- Indexes")
  for (i in 1:nrow(indexes)) {
    schema_sql <- c(schema_sql, paste(indexes$indexdef[i], ";"))
  }
}

# Write schema file
writeLines(schema_sql, schema_file)
cat("✅ Schema exported to:", schema_file, "\n")

# Export 2: Data
cat("\n📊 Exporting table data...\n")
data_file <- file.path(export_dir, "database_data.sql")

data_sql <- c(
  "-- American Authorship Database Data",
  "-- Generated for NeonDB migration",
  paste("-- Export Date:", Sys.time()),
  ""
)

# Export data for each table
for (table_name in tables$table_name) {
  cat("  Exporting data for:", table_name, "\n")
  
  # Get row count
  row_count <- dbGetQuery(con, paste("SELECT COUNT(*) as count FROM", table_name))$count
  cat("    Rows:", row_count, "\n")
  
  if (row_count > 0) {
    # Get column names
    columns <- dbGetQuery(con, paste0("
      SELECT column_name, data_type
      FROM information_schema.columns 
      WHERE table_name = '", table_name, "'
      ORDER BY ordinal_position
    "))
    
    # Export data in chunks
    chunk_size <- 1000
    n_chunks <- ceiling(row_count / chunk_size)
    
    data_sql <- c(data_sql, paste("-- Data for table:", table_name))
    
    for (chunk in 1:n_chunks) {
      offset <- (chunk - 1) * chunk_size
      
      chunk_data <- dbGetQuery(con, paste0("
        SELECT * FROM ", table_name, " 
        ORDER BY ", columns$column_name[1], "
        LIMIT ", chunk_size, " OFFSET ", offset
      ))
      
      if (nrow(chunk_data) > 0) {
        # Generate INSERT statements
        for (row in 1:nrow(chunk_data)) {
          values <- sapply(chunk_data[row, ], function(x) {
            if (is.na(x)) {
              "NULL"
            } else if (is.character(x)) {
              paste0("'", gsub("'", "''", x), "'")
            } else if (is.logical(x)) {
              if (x) "TRUE" else "FALSE"
            } else {
              as.character(x)
            }
          })
          
          insert_stmt <- paste0(
            "INSERT INTO ", table_name, " (",
            paste(names(chunk_data), collapse = ", "),
            ") VALUES (",
            paste(values, collapse = ", "),
            ");"
          )
          
          data_sql <- c(data_sql, insert_stmt)
        }
      }
      
      cat("    Chunk", chunk, "of", n_chunks, "completed\n")
    }
    
    data_sql <- c(data_sql, "")
  }
}

# Write data file
writeLines(data_sql, data_file)
cat("✅ Data exported to:", data_file, "\n")

# Export 3: Complete backup using pg_dump (if available)
cat("\n💾 Creating complete backup with pg_dump...\n")
backup_file <- file.path(export_dir, "database_full_backup.sql")

pg_dump_cmd <- paste0(
  "pg_dump -h ", db_config$host,
  " -U ", db_config$user,
  " -d ", db_config$dbname,
  " --no-password",
  " > ", backup_file
)

# Set PGPASSWORD environment variable
Sys.setenv(PGPASSWORD = db_config$password)

backup_result <- tryCatch({
  system(pg_dump_cmd, intern = TRUE)
  TRUE
}, error = function(e) {
  cat("⚠️  pg_dump not available or failed:", e$message, "\n")
  FALSE
})

if (backup_result && file.exists(backup_file)) {
  cat("✅ Complete backup created:", backup_file, "\n")
} else {
  cat("⚠️  Complete backup not created (pg_dump may not be available)\n")
}

# Export summary
cat("\n📈 Export Summary:\n")
for (table_name in tables$table_name) {
  row_count <- dbGetQuery(con, paste("SELECT COUNT(*) as count FROM", table_name))$count
  cat("  ", table_name, ":", row_count, "rows\n")
}

# Close connection
dbDisconnect(con)

cat("\n🎉 Database export completed successfully!\n")
cat("📁 Export files created in:", export_dir, "\n")
cat("   - database_schema.sql (table structures)\n")
cat("   - database_data.sql (all data)\n")
if (file.exists(backup_file)) {
  cat("   - database_full_backup.sql (complete backup)\n")
}

cat("\n💡 Next steps:\n")
cat("   1. Set up your NeonDB instance\n")
cat("   2. Run 02_import_to_neondb.R to import the data\n")
cat("   3. Verify the migration with 03_verify_neondb.R\n")
