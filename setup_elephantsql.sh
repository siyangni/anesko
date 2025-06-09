#!/bin/bash

# ElephantSQL Setup Helper Script
# This script helps you configure your app to use ElephantSQL

echo "🐘 ElephantSQL Configuration Helper"
echo "=================================="
echo ""

echo "📋 After creating your ElephantSQL instance, please provide the connection details:"
echo ""

# Collect connection details
read -p "Server/Host (e.g., bubble.db.elephantsql.com): " DB_HOST
read -p "User & Default database (your instance name): " DB_NAME_AND_USER
read -s -p "Password: " DB_PASSWORD
echo ""

# Validate inputs
if [ -z "$DB_HOST" ] || [ -z "$DB_NAME_AND_USER" ] || [ -z "$DB_PASSWORD" ]; then
    echo "❌ All fields are required. Please run the script again."
    exit 1
fi

echo ""
echo "✅ Creating configuration files..."

# Create .env file for the Shiny app
cat > "shiny-app/.env" << EOF
# ElephantSQL Configuration for American Authorship Database
# Generated on $(date)

DB_HOST=$DB_HOST
DB_NAME=$DB_NAME_AND_USER
DB_USER=$DB_NAME_AND_USER
DB_PASSWORD=$DB_PASSWORD
DB_PORT=5432
EOF

echo "✅ Created shiny-app/.env file"

# Update .gitignore to ensure .env is not committed
if ! grep -q "\.env" .gitignore; then
    echo "" >> .gitignore
    echo "# Environment variables" >> .gitignore
    echo ".env" >> .gitignore
    echo "shiny-app/.env" >> .gitignore
fi

echo "✅ Updated .gitignore to protect credentials"

# Create a test connection script
cat > "test_elephantsql_connection.R" << 'EOF'
# Test ElephantSQL Connection
# Run this to verify your cloud database connection works

library(DBI)
library(RPostgreSQL)

# Load environment variables
if (file.exists("shiny-app/.env")) {
  env_vars <- readLines("shiny-app/.env")
  env_vars <- env_vars[!grepl("^#", env_vars) & env_vars != ""]
  
  for (var in env_vars) {
    if (var != "") {
      parts <- strsplit(var, "=")[[1]]
      if (length(parts) == 2) {
        Sys.setenv(setNames(parts[2], parts[1]))
      }
    }
  }
}

# Test connection
cat("🔗 Testing ElephantSQL connection...\n")

tryCatch({
  con <- dbConnect(
    RPostgreSQL::PostgreSQL(),
    host = Sys.getenv("DB_HOST"),
    dbname = Sys.getenv("DB_NAME"),
    user = Sys.getenv("DB_USER"),
    password = Sys.getenv("DB_PASSWORD"),
    port = as.numeric(Sys.getenv("DB_PORT", "5432"))
  )
  
  # Test query
  result <- dbGetQuery(con, "SELECT version()")
  cat("✅ Connection successful!\n")
  cat("📊 PostgreSQL version:", result$version, "\n")
  
  # Check if tables exist
  tables <- dbListTables(con)
  if (length(tables) > 0) {
    cat("📋 Found tables:", paste(tables, collapse = ", "), "\n")
  } else {
    cat("📋 No tables found - ready for data migration\n")
  }
  
  dbDisconnect(con)
  cat("🎉 ElephantSQL setup successful!\n")
  
}, error = function(e) {
  cat("❌ Connection failed:", e$message, "\n")
  cat("🔍 Please check your credentials and try again\n")
})
EOF

echo "✅ Created connection test script"

echo ""
echo "🔍 Testing connection to ElephantSQL..."
Rscript test_elephantsql_connection.R

echo ""
echo "📚 Configuration complete! Your credentials are stored in:"
echo "   - shiny-app/.env (protected by .gitignore)"
echo ""
echo "📝 Next steps:"
echo "1. If connection test passed, proceed to data migration"
echo "2. If connection failed, double-check your ElephantSQL credentials"
echo "3. Run: ./migrate_to_elephantsql.sh" 