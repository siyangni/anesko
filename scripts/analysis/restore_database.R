# Database Restoration Script
# 
# This script will restore the database from the backup file
# SAFETY: It will create a backup of current state first

# Load necessary libraries
library(DBI)
library(RPostgreSQL)
library(magrittr)

# Source database configuration
source("scripts/config/database_config.R")

cat("🔄 DATABASE RESTORATION PROCESS\n")
cat("=" %>% rep(60) %>% paste(collapse=""), "\n")

# Step 1: Check current database state
cat("\n📊 STEP 1: Checking current database state...\n")

con <- dbConnect(
  RPostgreSQL::PostgreSQL(),
  host = db_config$host,
  dbname = db_config$dbname,
  user = db_config$user,
  password = db_config$password
)

# Show current publishers
current_publishers <- dbGetQuery(con, "SELECT publisher, COUNT(*) as count FROM book_entries WHERE publisher IS NOT NULL GROUP BY publisher ORDER BY publisher")
cat("Current publishers in database:\n")
print(current_publishers)

# Get total record count
total_records <- dbGetQuery(con, "SELECT COUNT(*) as total FROM book_entries")
cat("\nTotal records in book_entries:", total_records$total, "\n")

dbDisconnect(con)

# Step 2: Create backup of current state
cat("\n💾 STEP 2: Creating backup of current state...\n")
current_time <- format(Sys.time(), "%Y%m%d_%H%M%S")
current_backup_file <- paste0("data/backups/pre_restore_backup_", current_time, ".sql")

backup_cmd <- sprintf('pg_dump -h localhost -U siyang american_authorship > "%s"', current_backup_file)
system(backup_cmd)

if (file.exists(current_backup_file) && file.size(current_backup_file) > 1000) {
  cat("✅ Current database backed up to:", current_backup_file, "\n")
} else {
  cat("❌ Backup failed! Stopping restoration process.\n")
  stop("Backup failed - restoration aborted for safety")
}

# Step 3: Restore from backup
cat("\n🔄 STEP 3: Restoring from backup...\n")
backup_file <- "data/backups/local_backup_20250609_170017.sql"

if (!file.exists(backup_file)) {
  stop("Backup file not found: ", backup_file)
}

cat("Restoring from:", backup_file, "\n")
cat("Database will be restored to the state from June 9, 2025 17:00:17\n")

# Restore the database
restore_cmd <- sprintf('psql american_authorship < "%s"', backup_file)
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

# Show restored publishers
restored_publishers <- dbGetQuery(con, "SELECT publisher, COUNT(*) as count FROM book_entries WHERE publisher IS NOT NULL GROUP BY publisher ORDER BY publisher")
cat("Publishers after restoration:\n")
print(restored_publishers)

# Get total record count after restoration
total_after <- dbGetQuery(con, "SELECT COUNT(*) as total FROM book_entries")
cat("\nTotal records after restoration:", total_after$total, "\n")

dbDisconnect(con)

cat("\n🎉 DATABASE RESTORATION COMPLETED!\n")
cat("=" %>% rep(60) %>% paste(collapse=""), "\n")
cat("✅ Your database has been restored to the backup state\n")
cat("💾 Your previous state was saved to:", current_backup_file, "\n")
cat("📅 Database is now at state from: June 9, 2025 17:00:17\n") 