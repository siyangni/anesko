# Authentication Configuration for American Authorship Database
# Using shinymanager for simple but secure authentication

# SECURITY NOTE: This is a basic authentication system suitable for:
# - Internal academic use
# - Small teams (< 50 users)
# - Non-sensitive historical data
#
# For production with sensitive data, consider:
# - OAuth2 (Auth0, Okta)
# - LDAP/Active Directory integration
# - Multi-factor authentication (MFA)

# =============================================================================
# USER DATABASE
# =============================================================================

# Option 1: Simple credentials (for development/demo)
# NEVER use this in production with real passwords!
create_demo_credentials <- function() {
  data.frame(
    user = c("admin", "researcher", "viewer"),
    password = c(
      # These are hashed with bcrypt
      "$2a$10$VcfBD4N2Fg5UuHLPKJbPQeFZWwF7x.1D5dTfQ2Rg4Hqm6S8LD/fey",  # "admin123"
      "$2a$10$h0NYMDd3Ag/rHqrK7yOVk.7ZLqYMK3OyEPwJPJvW8qJUzN1x4dMXe",  # "research"
      "$2a$10$kpHBHUxHLPT3t1Q7FYLa5.rNxVLfW9mQ8uZr0KrHxKs6M7tLUVpGC"   # "view"
    ),
    admin = c(TRUE, FALSE, FALSE),
    start = rep(as.Date("2024-01-01"), 3),
    expire = rep(as.Date("2025-12-31"), 3),
    stringsAsFactors = FALSE
  )
}

# Option 2: Load from secure source (recommended for production)
load_credentials_from_file <- function(credentials_file = "config/users.rds") {
  if (file.exists(credentials_file)) {
    readRDS(credentials_file)
  } else {
    warning(sprintf("Credentials file not found: %s. Using demo credentials.", credentials_file))
    create_demo_credentials()
  }
}

# Option 3: Load from database (best for production)
load_credentials_from_database <- function(pool) {
  tryCatch({
    DBI::dbGetQuery(pool, "
      SELECT
        username as user,
        password_hash as password,
        is_admin as admin,
        account_start as start,
        account_expire as expire
      FROM app_users
      WHERE active = TRUE
    ")
  }, error = function(e) {
    warning("Could not load users from database: ", e$message)
    create_demo_credentials()
  })
}

# =============================================================================
# AUTHENTICATION SETUP
# =============================================================================

# Determine which credentials source to use
get_credentials <- function(pool = NULL) {
  # Priority order:
  # 1. Database (if pool provided and users table exists)
  # 2. Secure file (users.rds)
  # 3. Demo credentials (fallback)

  auth_source <- Sys.getenv("AUTH_SOURCE", "demo")

  if (!is.null(pool) && auth_source == "database") {
    return(load_credentials_from_database(pool))
  } else if (auth_source == "file") {
    return(load_credentials_from_file())
  } else {
    cat("⚠️  Using demo credentials. Set AUTH_SOURCE=file or database for production\n")
    return(create_demo_credentials())
  }
}

# =============================================================================
# PASSWORD HASHING UTILITIES
# =============================================================================

#' Hash a password using bcrypt
#'
#' @param password Plain text password
#' @return Bcrypt hashed password
hash_password <- function(password) {
  if (!requireNamespace("bcrypt", quietly = TRUE)) {
    stop("bcrypt package required for password hashing")
  }
  bcrypt::hashpw(password)
}

#' Create new user credentials
#'
#' Helper function to create new user entries
#'
#' @param username Username
#' @param password Plain text password (will be hashed)
#' @param is_admin Whether user has admin privileges
#' @param expire_date Account expiration date
#' @return Single-row data frame with user credentials
create_user <- function(username, password, is_admin = FALSE, expire_date = Sys.Date() + 365) {
  data.frame(
    user = username,
    password = hash_password(password),
    admin = is_admin,
    start = Sys.Date(),
    expire = expire_date,
    stringsAsFactors = FALSE
  )
}

# =============================================================================
# SESSION LOGGING
# =============================================================================

#' Log authentication events
#'
#' Records login attempts, successes, and failures for security auditing
#'
#' @param event Event type ("login_success", "login_failure", "logout")
#' @param username Username attempting authentication
#' @param ip_address IP address of client
#' @param details Additional details about the event
log_auth_event <- function(event, username, ip_address = "unknown", details = "") {
  timestamp <- Sys.time()

  # Log to file
  log_dir <- "logs/auth"
  if (!dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE)
  }

  log_file <- file.path(log_dir, paste0("auth_", format(Sys.Date(), "%Y%m"), ".log"))

  log_entry <- sprintf(
    "[%s] %s | User: %s | IP: %s | %s\n",
    timestamp, event, username, ip_address, details
  )

  cat(log_entry, file = log_file, append = TRUE)

  # Also log to console in development
  if (Sys.getenv("R_ENV", "development") == "development") {
    cat(log_entry)
  }
}

# =============================================================================
# CONFIGURATION OPTIONS
# =============================================================================

# Customize shinymanager appearance
auth_ui_config <- list(
  # Application title
  title = "American Authorship Database (1860-1920)",

  # Language
  language = "en",

  # Logo (optional)
  logo = NULL,  # Set to path like "www/logo.png" if available

  # Background image (optional)
  background_image = NULL,

  # Cookie expiration (in days)
  cookie_expiration = 7,

  # Additional CSS (optional)
  additional_class = "auth-custom"
)

# Session timeout (in minutes)
AUTH_SESSION_TIMEOUT <- as.integer(Sys.getenv("AUTH_SESSION_TIMEOUT", "60"))

# Maximum failed login attempts before lockout
MAX_FAILED_ATTEMPTS <- as.integer(Sys.getenv("MAX_FAILED_ATTEMPTS", "5"))

# Lockout duration (in minutes)
LOCKOUT_DURATION <- as.integer(Sys.getenv("LOCKOUT_DURATION", "30"))
