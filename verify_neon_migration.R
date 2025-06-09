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
