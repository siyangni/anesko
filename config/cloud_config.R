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
# Check if we're in a cloud environment first (prioritize environment variables)
db_host <- Sys.getenv("DB_HOST", "")
db_name <- Sys.getenv("DB_NAME", "")
db_user <- Sys.getenv("DB_USER", "")
db_password <- Sys.getenv("DB_PASSWORD", "")

config_loaded <- FALSE

# If environment variables are set, use them (cloud deployment)
if (db_host != "" && db_password != "") {
  cat("🌐 Using environment variables for database config (cloud mode)\n")
  db_config <- list(
    host = db_host,
    dbname = db_name,
    user = db_user,
    password = db_password,
    port = as.numeric(Sys.getenv("DB_PORT", "5432")),
    sslmode = Sys.getenv("DB_SSL_MODE", "require")
  )
  config_loaded <- TRUE
} else {
  # Fallback to local config file for development
  config_paths <- c(
    "../../scripts/config/database_config.R",
    "../scripts/config/database_config.R",
    "scripts/config/database_config.R"
  )

  for (config_path in config_paths) {
    if (file.exists(config_path)) {
      source(config_path)
      cat("📁 Using local database config from", config_path, "\n")
      config_loaded <- TRUE
      break
    }
  }
}

if (!config_loaded) {
  # Require environment variables for production deployment
  db_host <- Sys.getenv("DB_HOST", "")
  db_name <- Sys.getenv("DB_NAME", "")
  db_user <- Sys.getenv("DB_USER", "")
  db_password <- Sys.getenv("DB_PASSWORD", "")

  # Fail clearly if environment variables are not set
  if (db_host == "" || db_password == "") {
    stop("Database configuration not found. Please set DB_HOST, DB_NAME, DB_USER, and DB_PASSWORD environment variables.")
  }

  cat("🌐 Using environment variables for database config\n")
  db_config <- list(
    host = db_host,
    dbname = db_name,
    user = db_user,
    password = db_password,
    port = as.numeric(Sys.getenv("DB_PORT", "5432")),
    sslmode = Sys.getenv("DB_SSL_MODE", "require")
  )
  config_loaded <- TRUE
}

# Validate configuration
if (db_config$host == "localhost" || db_config$password == "") {
  warning("Database configuration may not be properly set for cloud deployment.")
}

cat("🔗 Database configuration loaded:\n")
cat("   Host:", db_config$host, "\n")
cat("   Database:", db_config$dbname, "\n")
cat("   User:", db_config$user, "\n")
cat("   Port:", db_config$port, "\n")
