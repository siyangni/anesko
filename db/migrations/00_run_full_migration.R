# Full Migration Script
# This script runs the complete data migration process:
# 1. Data cleaning (pre_migration_cleaning.R)
# 2. Database setup (01_database_setup.R)
# 3. Schema creation (02_create_schema.R)
# 4. Data import (03_import_data.R)

cat("🚀 Starting full migration process...\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Step 1: Run data cleaning
cat("\n📋 Step 1: Running data cleaning...\n")
cat("Running scripts/cleaning/pre_migration_cleaning.R\n")

tryCatch({
  source("scripts/cleaning/pre_migration_cleaning.R")
  cat("✅ Data cleaning completed successfully\n")
}, error = function(e) {
  cat("❌ Data cleaning failed:\n")
  cat("Error:", e$message, "\n")
  stop("Migration aborted due to data cleaning failure")
})

# Step 2: Database setup
cat("\n🔧 Step 2: Setting up database connection...\n")
cat("Running scripts/migration/01_database_setup.R\n")

tryCatch({
  source("scripts/migration/01_database_setup.R")
  cat("✅ Database setup completed successfully\n")
}, error = function(e) {
  cat("❌ Database setup failed:\n")
  cat("Error:", e$message, "\n")
  stop("Migration aborted due to database setup failure")
})

# Step 3: Schema creation
cat("\n🏗️  Step 3: Creating database schema...\n")
cat("Running scripts/migration/02_create_schema.R\n")

tryCatch({
  source("scripts/migration/02_create_schema.R")
  cat("✅ Schema creation completed successfully\n")
}, error = function(e) {
  cat("❌ Schema creation failed:\n")
  cat("Error:", e$message, "\n")
  stop("Migration aborted due to schema creation failure")
})

# Step 4: Data import
cat("\n📥 Step 4: Importing cleaned data...\n")
cat("Running scripts/migration/03_import_data.R\n")

tryCatch({
  source("scripts/migration/03_import_data.R")
  cat("✅ Data import completed successfully\n")
}, error = function(e) {
  cat("❌ Data import failed:\n")
  cat("Error:", e$message, "\n")
  stop("Migration aborted due to data import failure")
})

# Final summary
cat("\n🎉 MIGRATION COMPLETE! 🎉\n")
cat(paste(rep("=", 50), collapse = ""), "\n")
cat("All steps completed successfully:\n")
cat("✅ Data cleaning\n")
cat("✅ Database setup\n") 
cat("✅ Schema creation\n")
cat("✅ Data import\n")
cat("\nYour American Authorship database is ready to use!\n")
