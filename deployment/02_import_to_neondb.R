# NeonDB Import Script
# This script imports the exported database to NeonDB

library(DBI)
library(RPostgreSQL)
library(dplyr)

cat("🌐 Starting NeonDB Import Process\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

# NeonDB Configuration
# IMPORTANT: Update these with your actual NeonDB credentials
neondb_config <- list(
  host = Sys.getenv("NEONDB_HOST", "your-neondb-host.neon.tech"),
  dbname = Sys.getenv("NEONDB_NAME", "neondb"),
  user = Sys.getenv("NEONDB_USER", "neondb_owner"),
  password = Sys.getenv("NEONDB_PASSWORD", "your-password"),
  port = as.numeric(Sys.getenv("NEONDB_PORT", "5432"))
)

# Validate NeonDB configuration
if (neondb_config$host == "your-neondb-host.neon.tech" || 
    neondb_config$password == "your-password") {
  cat("❌ Please update NeonDB configuration in this script or set environment variables:\n")
  cat("   NEONDB_HOST=your-host.neon.tech\n")
  cat("   NEONDB_NAME=neondb\n")
  cat("   NEONDB_USER=neondb_owner\n")
  cat("   NEONDB_PASSWORD=your-password\n")
  cat("   NEONDB_PORT=5432\n")
  stop("NeonDB configuration required")
}

cat("🔗 NeonDB Configuration:\n")
cat("   Host:", neondb_config$host, "\n")
cat("   Database:", neondb_config$dbname, "\n")
cat("   User:", neondb_config$user, "\n")
cat("   Port:", neondb_config$port, "\n")

# Connect to NeonDB
cat("\n📡 Connecting to NeonDB...\n")
neon_con <- tryCatch({
  dbConnect(
    RPostgreSQL::PostgreSQL(),
    host = neondb_config$host,
    dbname = neondb_config$dbname,
    user = neondb_config$user,
    password = neondb_config$password,
    port = neondb_config$port
  )
}, error = function(e) {
  stop("❌ Failed to connect to NeonDB: ", e$message, 
       "\nPlease check your credentials and network connection.")
})

cat("✅ Connected to NeonDB successfully\n")

# Check export files
export_dir <- "database_export"
schema_file <- file.path(export_dir, "database_schema.sql")
data_file <- file.path(export_dir, "database_data.sql")

if (!file.exists(schema_file)) {
  stop("❌ Schema file not found. Please run 01_export_database.R first.")
}

if (!file.exists(data_file)) {
  stop("❌ Data file not found. Please run 01_export_database.R first.")
}

# Import Schema
cat("\n📋 Importing database schema...\n")
tryCatch({
  schema_sql <- readLines(schema_file)
  
  # Filter out comments and empty lines for execution
  executable_lines <- schema_sql[
    !grepl("^--", schema_sql) & 
    !grepl("^\\s*$", schema_sql)
  ]
  
  # Execute schema creation
  for (line in executable_lines) {
    if (nchar(trimws(line)) > 0) {
      dbExecute(neon_con, line)
    }
  }
  
  cat("✅ Schema imported successfully\n")
}, error = function(e) {
  cat("❌ Schema import failed:", e$message, "\n")
  cat("💡 Trying alternative approach...\n")
  
  # Alternative: Create tables manually
  tryCatch({
    # Create book_entries table
    dbExecute(neon_con, "
      CREATE TABLE IF NOT EXISTS book_entries (
        book_id VARCHAR(50) PRIMARY KEY,
        author_surname VARCHAR(255),
        gender CHAR(1),
        book_title TEXT,
        genre VARCHAR(100),
        binding VARCHAR(50),
        notes TEXT,
        retail_price DECIMAL(10,2),
        royalty_rate DECIMAL(5,4),
        contract_terms TEXT,
        publisher VARCHAR(255),
        publication_year INTEGER,
        author_id VARCHAR(10),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ")
    
    # Create royalty_tiers table
    dbExecute(neon_con, "
      CREATE TABLE IF NOT EXISTS royalty_tiers (
        tier_id SERIAL PRIMARY KEY,
        book_id VARCHAR(50) REFERENCES book_entries(book_id) ON DELETE CASCADE,
        tier INTEGER NOT NULL,
        rate DECIMAL(10,4) NOT NULL,
        lower_limit INTEGER NOT NULL,
        upper_limit INTEGER,
        sliding_scale BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT unique_book_tier UNIQUE (book_id, tier)
      )
    ")
    
    # Create book_sales table
    dbExecute(neon_con, "
      CREATE TABLE IF NOT EXISTS book_sales (
        sale_id SERIAL PRIMARY KEY,
        book_id VARCHAR(50) REFERENCES book_entries(book_id) ON DELETE CASCADE,
        year INTEGER NOT NULL,
        sales_count INTEGER NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT unique_book_year UNIQUE (book_id, year)
      )
    ")
    
    # Create book_sales_summary table
    dbExecute(neon_con, "
      CREATE TABLE IF NOT EXISTS book_sales_summary (
        book_id VARCHAR(50) PRIMARY KEY REFERENCES book_entries(book_id) ON DELETE CASCADE,
        total_sales INTEGER NOT NULL DEFAULT 0,
        first_sale_year INTEGER,
        last_sale_year INTEGER,
        peak_sales_year INTEGER,
        peak_sales_count INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ")
    
    cat("✅ Tables created manually\n")
  }, error = function(e2) {
    stop("❌ Failed to create tables: ", e2$message)
  })
})

# Import Data
cat("\n📊 Importing data...\n")
tryCatch({
  data_sql <- readLines(data_file)
  
  # Filter INSERT statements
  insert_statements <- data_sql[grepl("^INSERT INTO", data_sql)]
  
  cat("   Found", length(insert_statements), "INSERT statements\n")
  
  # Execute in batches
  batch_size <- 100
  n_batches <- ceiling(length(insert_statements) / batch_size)
  
  for (batch in 1:n_batches) {
    start_idx <- (batch - 1) * batch_size + 1
    end_idx <- min(batch * batch_size, length(insert_statements))
    
    batch_statements <- insert_statements[start_idx:end_idx]
    
    for (stmt in batch_statements) {
      tryCatch({
        dbExecute(neon_con, stmt)
      }, error = function(e) {
        cat("⚠️  Failed to execute:", substr(stmt, 1, 100), "...\n")
        cat("   Error:", e$message, "\n")
      })
    }
    
    cat("   Batch", batch, "of", n_batches, "completed\n")
  }
  
  cat("✅ Data import completed\n")
}, error = function(e) {
  cat("❌ Data import failed:", e$message, "\n")
  cat("💡 You may need to import data manually or check the data file format\n")
})

# Verify Import
cat("\n🔍 Verifying import...\n")
tables <- c("book_entries", "royalty_tiers", "book_sales", "book_sales_summary")

import_summary <- data.frame(
  table = character(),
  rows = integer(),
  status = character(),
  stringsAsFactors = FALSE
)

for (table in tables) {
  tryCatch({
    count_result <- dbGetQuery(neon_con, paste("SELECT COUNT(*) as count FROM", table))
    row_count <- count_result$count
    status <- if (row_count > 0) "✅ OK" else "⚠️  Empty"
    
    import_summary <- rbind(import_summary, data.frame(
      table = table,
      rows = row_count,
      status = status,
      stringsAsFactors = FALSE
    ))
    
    cat("  ", table, ":", row_count, "rows\n")
  }, error = function(e) {
    import_summary <<- rbind(import_summary, data.frame(
      table = table,
      rows = 0,
      status = "❌ Error",
      stringsAsFactors = FALSE
    ))
    cat("  ", table, ": Error -", e$message, "\n")
  })
}

# Test a sample query
cat("\n🧪 Testing sample queries...\n")
tryCatch({
  sample_books <- dbGetQuery(neon_con, "
    SELECT book_id, book_title, author_surname, publication_year 
    FROM book_entries 
    LIMIT 5
  ")
  
  if (nrow(sample_books) > 0) {
    cat("✅ Sample query successful:\n")
    print(sample_books)
  } else {
    cat("⚠️  Sample query returned no results\n")
  }
}, error = function(e) {
  cat("❌ Sample query failed:", e$message, "\n")
})

# Close connection
dbDisconnect(neon_con)

# Summary
cat("\n📈 Import Summary:\n")
print(import_summary)

total_rows <- sum(import_summary$rows)
successful_tables <- sum(import_summary$status == "✅ OK")

cat("\n🎉 NeonDB Import Completed!\n")
cat("   Total rows imported:", total_rows, "\n")
cat("   Successful tables:", successful_tables, "of", length(tables), "\n")

if (successful_tables == length(tables) && total_rows > 0) {
  cat("✅ Import appears successful!\n")
  cat("\n💡 Next steps:\n")
  cat("   1. Run 03_verify_neondb.R to verify data integrity\n")
  cat("   2. Update your application configuration\n")
  cat("   3. Test the application with NeonDB\n")
} else {
  cat("⚠️  Import may have issues. Please check the logs above.\n")
  cat("\n💡 Troubleshooting:\n")
  cat("   1. Verify NeonDB credentials\n")
  cat("   2. Check network connectivity\n")
  cat("   3. Review error messages above\n")
  cat("   4. Consider manual data import if needed\n")
}
