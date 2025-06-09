# Cloud Database Configuration
# This configuration loads database credentials from environment variables

# Load environment variables from .env file if it exists
if (file.exists(".env")) {
  env_vars <- readLines(".env")
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

# Database configuration using environment variables
db_config <- list(
  host = Sys.getenv("DB_HOST", "localhost"),
  dbname = Sys.getenv("DB_NAME", "american_authorship"),
  user = Sys.getenv("DB_USER", "siyang"),
  password = Sys.getenv("DB_PASSWORD", ""),
  port = as.numeric(Sys.getenv("DB_PORT", "5432"))
)

# Validate configuration
if (db_config$host == "localhost" || db_config$password == "") {
  warning("Database configuration may not be properly set for cloud deployment.")
}

cat("🔗 Database configuration loaded:\n")
cat("   Host:", db_config$host, "\n")
cat("   Database:", db_config$dbname, "\n")
cat("   User:", db_config$user, "\n")
cat("   Port:", db_config$port, "\n")
