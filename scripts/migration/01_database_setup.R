# Database Setup and Configuration
# This file sets up PostgreSQL database for the American Authorship project

# Test database connection
library(DBI)
library(RPostgreSQL)

# Database configuration (TEMPLATE - do not commit actual credentials)
# Create your actual database config file (not tracked by git)
# Create database config file with template values
cat('db_config <- list(
  host = "localhost",
  dbname = "american_authorship",
  user = "your_username",  # Replace with your actual username
  password = "your_password"  # Replace with your actual password
)
', file = "scripts/config/database_config.R")

cat("\n📝 Instructions for setting up database credentials:\n")
cat("1. Edit scripts/config/database_config.R with your actual credentials, OR\n")
cat("2. Set environment variables: DB_USER, DB_PASSWORD, DB_HOST, DB_NAME\n")
cat("   Example: export DB_USER=siyang DB_PASSWORD=yourpassword\n\n")

# Test connection - try environment variables first, then config file
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

tryCatch({
  con <- dbConnect(
    RPostgreSQL::PostgreSQL(),
    host = db_config$host,
    dbname = db_config$dbname,
    user = db_config$user,
    password = db_config$password
  )
  
  # Test connection with a simple query instead of dbIsValid()
  result <- dbGetQuery(con, "SELECT 1 as test")
  if (!is.null(result) && nrow(result) == 1) {
    cat("✅ Database connection successful!\n")
  } else {
    cat("❌ Database connection test failed!\n")
  }
  
  dbDisconnect(con)
}, error = function(e) {
  cat("❌ Database connection failed!\n")
  cat("Error:", e$message, "\n")
})

# Exit R
quit()

# Save the actual configuration in a file that's gitignored:
# scripts/config/database_config.R (not tracked by git)
