# Cloud Database Configuration Template
# Copy this file to cloud_config.R and fill in your credentials
# NEVER commit cloud_config.R with real credentials!

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
# BEST PRACTICE: Set these as environment variables, not hardcoded
# SECURITY: Supports Docker secrets via _FILE environment variables
db_host <- Sys.getenv("DB_HOST", "")
db_name <- Sys.getenv("DB_NAME", "")
db_user <- Sys.getenv("DB_USER", "")

# Support Docker secrets pattern: check for DB_PASSWORD_FILE first
db_password_file <- Sys.getenv("DB_PASSWORD_FILE", "")
if (db_password_file != "" && file.exists(db_password_file)) {
  # Read password from Docker secret file
  db_password <- trimws(readLines(db_password_file, warn = FALSE, n = 1))
  cat("🔐 Loaded database password from Docker secret file\n")
} else {
  # Fallback to environment variable (for non-Docker deployments)
  db_password <- Sys.getenv("DB_PASSWORD", "")
  if (db_password != "") {
    cat("⚠️  Using DB_PASSWORD from environment (consider using secrets file)\n")
  }
}

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
  stop("Database configuration not found. Please set environment variables or create database_config.R")
}

# Validate configuration
if (is.null(db_config$host) || db_config$host == "" || is.null(db_config$password) || db_config$password == "") {
  stop("Database configuration incomplete. Required: host, dbname, user, password")
}

cat("🔗 Database configuration loaded:\n")
cat("   Host:", db_config$host, "\n")
cat("   Database:", db_config$dbname, "\n")
cat("   User:", db_config$user, "\n")
cat("   Port:", db_config$port, "\n")
