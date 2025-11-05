# Test Neon PostgreSQL Connection
# Run this to verify your cloud database connection works

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
        value <- trimws(paste(parts[-1], collapse = "="))  # Handle values with = signs
        if (nchar(key) > 0 && nchar(value) > 0) {
          do.call(Sys.setenv, setNames(list(value), key))
        }
      }
    }
  }
}

# Test connection
cat("🔗 Testing Neon PostgreSQL connection...\n")

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
  
  # Test database size
  size_result <- dbGetQuery(con, "
    SELECT pg_size_pretty(pg_database_size(current_database())) as size
  ")
  cat("💾 Database size:", size_result$size, "\n")
  
  dbDisconnect(con)
  cat("🎉 Neon setup successful!\n")
  
}, error = function(e) {
  cat("❌ Connection failed:", e$message, "\n")
  cat("🔍 Please check your credentials and try again\n")
  cat("💡 Make sure to use SSL connection (sslmode=require)\n")
})
