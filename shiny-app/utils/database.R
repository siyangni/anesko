# Database Utility Functions
# Functions for database connection management and common queries
# SECURITY: All queries use parameterized statements to prevent SQL injection

# Load input validation utilities
tryCatch({
  source("utils/input_validation.R", local = TRUE)
}, error = function(e) {
  # Validation functions will be loaded on-demand if this fails
  NULL
})

# Create database connection pool
create_db_pool <- function() {
  tryCatch({
    cat("🔧 Creating database connection pool...\n")
    cat("   Host:", db_config$host, "\n")
    cat("   Database:", db_config$dbname, "\n")
    cat("   User:", db_config$user, "\n")

    # Use RPostgreSQL for reliability (works on shinyapps.io)
    pool <- pool::dbPool(
      drv = RPostgreSQL::PostgreSQL(),
      host = db_config$host,
      dbname = db_config$dbname,
      user = db_config$user,
      password = db_config$password,
      port = if(is.null(db_config$port)) 5432 else db_config$port,
      minSize = POOL_SIZE_MIN,
      maxSize = POOL_SIZE_MAX,
      idleTimeout = POOL_IDLE_TIMEOUT * 1000
    )

    cat("✅ Database connection pool created successfully\n")
    return(pool)

  }, error = function(e) {
    cat("💥 Database pool creation failed:", e$message, "\n")
    stop("Failed to create database connection pool: ", e$message)
  })
}

# Safe database query with error handling using connection pool
# FIXED: Now properly uses the pool for performance and reliability
safe_db_query <- function(query, params = NULL) {
  # Check if pool exists and is valid
  if (!exists("pool", envir = .GlobalEnv) || is.null(pool)) {
    warning("Database pool not initialized. Attempting to initialize...")
    pool <<- tryCatch(
      create_db_pool(),
      error = function(e) {
        warning("Failed to create pool: ", e$message)
        return(NULL)
      }
    )
  }

  if (is.null(pool)) {
    warning("Database pool unavailable")
    return(data.frame())
  }

  tryCatch({
    result <- if (is.null(params)) {
      pool::dbGetQuery(pool, query)
    } else {
      pool::dbGetQuery(pool, query, params = params)
    }
    return(result)
  }, error = function(e) {
    warning("Database query failed: ", e$message)
    # Don't return empty data frame immediately - might be transient error
    # Try one reconnection attempt
    tryCatch({
      pool::poolClose(pool)
      pool <<- create_db_pool()
      result <- if (is.null(params)) {
        pool::dbGetQuery(pool, query)
      } else {
        pool::dbGetQuery(pool, query, params = params)
      }
      return(result)
    }, error = function(e2) {
      warning("Query failed after reconnection: ", e2$message)
      return(data.frame())
    })
  })
}

# NOTE: All query functions have been refactored to utils/queries_*.R files:
# - queries_basic.R: Basic summary stats, books, filters
# - queries_sales.R: Sales analysis and aggregations
# - queries_timeseries.R: Time series data and trends
# - queries_royalties.R: Royalty calculations and author income
#
# These modules properly use the connection pool via safe_db_query()
# No legacy code remains in this file.
