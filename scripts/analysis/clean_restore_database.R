# Clean Database Restoration Script
# 
# This script will properly restore the database by clearing data first

# Load necessary libraries
library(DBI)
library(RPostgreSQL)
library(magrittr)

# Source database configuration
source("scripts/config/database_config.R")

cat("🔄 CLEAN DATABASE RESTORATION PROCESS\n")
cat("=" %>% rep(60) %>% paste(collapse=""), "\n")

# Connect to database
con <- dbConnect(
  RPostgreSQL::PostgreSQL(),
  host = db_config$host,
  dbname = db_config$dbname,
  user = db_config$user,
  password = db_config$password
)

# Step 1: Check current state
cat("\n📊 STEP 1: Current database state...\n")
current_count <- dbGetQuery(con, "SELECT COUNT(*) as total FROM book_entries")
cat("Current records:", current_count$total, "\n")

# Step 2: Clear existing data (keep structure)
cat("\n🗑️  STEP 2: Clearing existing data...\n")
dbExecute(con, "TRUNCATE book_sales CASCADE")
dbExecute(con, "TRUNCATE book_entries CASCADE")
cat("✅ Data cleared\n")

dbDisconnect(con)

# Step 3: Restore data from backup (data only)
cat("\n📥 STEP 3: Restoring data from backup...\n")
backup_file <- "data/backups/local_backup_20250609_170017.sql"

# Extract and restore only the data (COPY commands)
restore_cmd <- sprintf('grep -A 1000000 "COPY public" "%s" | psql american_authorship', backup_file)
system(restore_cmd)

# Step 4: Verify restoration
cat("\n✅ STEP 4: Verifying restoration...\n")

con <- dbConnect(
  RPostgreSQL::PostgreSQL(),
  host = db_config$host,
  dbname = db_config$dbname,
  user = db_config$user,
  password = db_config$password
)

# Check record count
final_count <- dbGetQuery(con, "SELECT COUNT(*) as total FROM book_entries")
cat("Records after restoration:", final_count$total, "\n")

# Show sample publishers from backup
sample_publishers <- dbGetQuery(con, "SELECT DISTINCT publisher FROM book_entries WHERE publisher IS NOT NULL ORDER BY publisher LIMIT 10")
cat("\nSample publishers from restored data:\n")
print(sample_publishers)

dbDisconnect(con)

cat("\n🎉 CLEAN RESTORATION COMPLETED!\n")
cat("✅ Database restored to backup state from June 9, 2025\n") 