#!/bin/bash

# Data Migration Script for Neon PostgreSQL
# This script migrates your local PostgreSQL data to Neon

echo "📊 Data Migration to Neon PostgreSQL"
echo "==================================="
echo ""

# Check if .env file exists
if [ ! -f "shiny-app/.env" ]; then
    echo "❌ Configuration file not found. Please run ./setup_neon.sh first"
    exit 1
fi

# Load environment variables
source shiny-app/.env

echo "🔍 Migration checklist:"
echo "[ ] Local PostgreSQL database is running"
echo "[ ] Neon credentials configured" 
echo "[ ] Connection to Neon tested"
echo ""

read -p "Are you ready to proceed with migration? (y/n): " proceed

if [ "$proceed" != "y" ]; then
    echo "ℹ️  Migration cancelled. Run this script again when ready."
    exit 0
fi

echo ""
echo "📦 Step 1: Creating local database backup..."

# Create backup directory
mkdir -p data/backups

# Create timestamp for backup
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="data/backups/local_backup_$TIMESTAMP.sql"

# Export local database
if pg_dump -h localhost -U siyang american_authorship > "$BACKUP_FILE" 2>/dev/null; then
    echo "✅ Local backup created: $BACKUP_FILE"
else
    echo "❌ Local backup failed. Please ensure:"
    echo "   - PostgreSQL is running: sudo service postgresql start"
    echo "   - Database 'american_authorship' exists"
    echo "   - User 'siyang' has access"
    
    read -p "Try alternative backup method? (y/n): " alt_method
    
    if [ "$alt_method" = "y" ]; then
        echo "🔧 Trying alternative backup..."
        
        # Try with password prompt
        echo "Please enter your PostgreSQL password for user 'siyang':"
        pg_dump -h localhost -U siyang -W american_authorship > "$BACKUP_FILE"
        
        if [ $? -eq 0 ]; then
            echo "✅ Alternative backup successful"
        else
            echo "❌ Backup failed. Please check your PostgreSQL setup."
            exit 1
        fi
    else
        exit 1
    fi
fi

echo ""
echo "🔄 Step 2: Importing data to Neon..."

# Import to Neon with SSL
echo "📤 Uploading data (this may take a few minutes)..."

if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "\conninfo" 2>/dev/null; then
    echo "✅ Neon connection verified"
    
    # Import data
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" < "$BACKUP_FILE" 2>/dev/null; then
        echo "✅ Data import successful!"
    else
        echo "⚠️  Import encountered issues. Trying with verbose output..."
        
        # Try with verbose output to see what's happening
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 < "$BACKUP_FILE"
        
        if [ $? -eq 0 ]; then
            echo "✅ Data import completed with warnings"
        else
            echo "❌ Data import failed. This might be due to:"
            echo "   - Connection issues"
            echo "   - Permission issues"
            echo "   - Storage quota (Neon free tier: 500MB)"
            echo ""
            echo "🔧 Trying selective import (essential tables only)..."
            
            # Create a minimal backup with just essential data
            echo "📊 Creating minimal dataset..."
            
            # Create minimal SQL file with optimized schema
            cat > "data/backups/minimal_neon_$TIMESTAMP.sql" << 'EOF'
-- Minimal American Authorship Database for Neon PostgreSQL
-- Optimized for 500MB storage limit

-- Create tables with constraints
CREATE TABLE IF NOT EXISTS book_entries (
  book_id VARCHAR(50) PRIMARY KEY,
  author_surname VARCHAR(255),
  gender CHAR(1) CHECK (gender IN ('M', 'F')),
  book_title TEXT,
  genre VARCHAR(100),
  binding VARCHAR(50),
  notes TEXT,
  retail_price DECIMAL(10,2),
  royalty_rate DECIMAL(5,4),
  contract_terms TEXT,
  publisher VARCHAR(255),
  publication_year INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS book_sales (
  sale_id SERIAL PRIMARY KEY,
  book_id VARCHAR(50) REFERENCES book_entries(book_id) ON DELETE CASCADE,
  year INTEGER NOT NULL,
  sales_count INTEGER,
  sales_limit INTEGER,
  sales_rate DECIMAL(10,2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT unique_book_year UNIQUE (book_id, year)
);

-- Create efficient indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_author_surname ON book_entries(author_surname);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_genre ON book_entries(genre);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_gender ON book_entries(gender);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_publisher ON book_entries(publisher);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_publication_year ON book_entries(publication_year);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_book_year ON book_sales(book_id, year);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sales_year ON book_sales(year);

-- Create materialized view for better performance
CREATE MATERIALIZED VIEW IF NOT EXISTS book_sales_summary AS
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
GROUP BY be.book_id, be.author_surname, be.gender, be.book_title, be.genre, be.publisher, be.publication_year;

-- Create index on materialized view
CREATE INDEX IF NOT EXISTS idx_summary_total_sales ON book_sales_summary(total_sales);

EOF

            # Try to import minimal schema
            echo "📤 Attempting optimized import..."
            PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" < "data/backups/minimal_neon_$TIMESTAMP.sql"
            
            if [ $? -eq 0 ]; then
                echo "✅ Minimal schema created successfully"
                echo "ℹ️  You may need to populate data manually due to size or complexity"
            fi
        fi
    fi
else
    echo "❌ Failed to connect to Neon. Please check your credentials."
    exit 1
fi

echo ""
echo "🧪 Step 3: Verifying migration..."

# Test the migrated database
cat > "verify_neon_migration.R" << 'EOF'
# Verify Neon Migration
library(DBI)
library(RPostgreSQL)

# Load environment variables
if (file.exists("shiny-app/.env")) {
  env_vars <- readLines("shiny-app/.env")
  env_vars <- env_vars[!grepl("^#", env_vars) & env_vars != "" & !grepl("^\\s*$", env_vars)]
  
  for (var in env_vars) {
    if (nchar(trimws(var)) > 0 && grepl("=", var)) {
      parts <- strsplit(var, "=", fixed = TRUE)[[1]]
      if (length(parts) >= 2) {
        key <- trimws(parts[1])
        value <- trimws(paste(parts[-1], collapse = "="))
        if (nchar(key) > 0 && nchar(value) > 0) {
          do.call(Sys.setenv, setNames(list(value), key))
        }
      }
    }
  }
}

tryCatch({
  con <- dbConnect(
    RPostgreSQL::PostgreSQL(),
    host = Sys.getenv("DB_HOST"),
    dbname = Sys.getenv("DB_NAME"),
    user = Sys.getenv("DB_USER"),
    password = Sys.getenv("DB_PASSWORD"),
    port = as.numeric(Sys.getenv("DB_PORT", "5432"))
  )
  
  # Check tables
  tables <- dbListTables(con)
  cat("📋 Tables found:", length(tables), "\n")
  cat("   ", paste(tables, collapse = ", "), "\n\n")
  
  # Check data counts
  if ("book_entries" %in% tables) {
    book_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM book_entries")$count
    cat("📚 Books:", book_count, "\n")
  }
  
  if ("book_sales" %in% tables) {
    sales_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM book_sales")$count
    cat("💰 Sales records:", sales_count, "\n")
  }
  
  if ("book_sales_summary" %in% tables) {
    summary_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM book_sales_summary")$count
    cat("📊 Summary records:", summary_count, "\n")
  }
  
  # Check database size
  size_result <- dbGetQuery(con, "
    SELECT pg_size_pretty(pg_database_size(current_database())) as size
  ")
  cat("💾 Database size:", size_result$size, "\n")
  
  dbDisconnect(con)
  cat("\n✅ Migration verification complete!\n")
  
}, error = function(e) {
  cat("❌ Verification failed:", e$message, "\n")
})
EOF

Rscript verify_neon_migration.R

echo ""
echo "🎉 Migration process complete!"
echo ""
echo "📝 Next steps:"
echo "1. Update your Shiny app configuration for cloud database"
echo "2. Test app locally with Neon"
echo "3. Deploy to ShinyApps.io"
echo ""
echo "Run: ./test_app_with_neon.sh" 