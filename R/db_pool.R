# R/db_pool.R
# Unified database connection pool management using {config} package

#' Create database connection pool
#'
#' Creates a connection pool to PostgreSQL using configuration from config.yml
#' Configuration is selected based on R_CONFIG_ACTIVE environment variable
#'
#' @return A pool object from the pool package
#' @export
get_db_pool <- function() {
  # Load configuration
  cfg <- config::get("db")

  # Validate required configuration
  if (is.null(cfg$host) || cfg$host == "") {
    stop("Database host not configured. Please set DB_HOST environment variable.")
  }
  if (is.null(cfg$password) || cfg$password == "") {
    stop("Database password not configured. Please set DB_PASSWORD environment variable.")
  }

  # Try RPostgres first (better performance and SSL support), fall back to RPostgreSQL
  drv <- NULL
  if (requireNamespace("RPostgres", quietly = TRUE)) {
    drv <- RPostgres::Postgres()
    cat("📦 Using RPostgres driver\n")
  } else if (requireNamespace("RPostgreSQL", quietly = TRUE)) {
    drv <- RPostgreSQL::PostgreSQL()
    cat("📦 Using RPostgreSQL driver\n")
  } else {
    stop("No PostgreSQL driver found. Please install RPostgres or RPostgreSQL package.")
  }

  # Create connection pool
  pool <- pool::dbPool(
    drv      = drv,
    host     = cfg$host,
    port     = cfg$port,
    dbname   = cfg$dbname,
    user     = cfg$user,
    password = cfg$password,
    sslmode  = cfg$sslmode
  )

  cat("✅ Database pool created:\n")
  cat("   Host:", cfg$host, "\n")
  cat("   Database:", cfg$dbname, "\n")
  cat("   User:", cfg$user, "\n")

  return(pool)
}
