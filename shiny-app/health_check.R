# Health Check Endpoint for American Authorship Database
# This provides a simple HTTP endpoint for monitoring systems

#' Create a health check endpoint for the Shiny application
#'
#' This endpoint can be queried by load balancers, monitoring systems,
#' or orchestration platforms (Kubernetes, Docker Swarm) to verify
#' that the application is running and healthy.
#'
#' Usage:
#'   Add to server.R:
#'   source("health_check.R")
#'   setup_health_check(session, pool)
#'
#' Test:
#'   curl http://localhost:3838/health
#'
#' @param session Shiny session object
#' @param db_pool Database connection pool (optional)
setup_health_check <- function(session, db_pool = NULL) {

  # Create health check handler
  session$registerDataObj(
    name = "health",
    data = NULL,
    func = function(data, req) {

      # Health check response
      health_status <- list(
        status = "healthy",
        timestamp = as.character(Sys.time()),
        checks = list()
      )

      # Check 1: Application is running
      health_status$checks$application <- list(
        status = "pass",
        message = "Application is running"
      )

      # Check 2: Database connectivity (if pool provided)
      if (!is.null(db_pool)) {
        db_check <- tryCatch({
          result <- pool::dbGetQuery(db_pool, "SELECT 1 as health_check")
          if (nrow(result) == 1 && result$health_check == 1) {
            list(status = "pass", message = "Database is responsive")
          } else {
            list(status = "fail", message = "Database query returned unexpected result")
          }
        }, error = function(e) {
          list(status = "fail", message = paste("Database error:", e$message))
        })

        health_status$checks$database <- db_check

        # Update overall status if database check failed
        if (db_check$status == "fail") {
          health_status$status <- "unhealthy"
        }
      }

      # Check 3: Memory usage (warn if > 80%)
      mem_info <- gc(verbose = FALSE, full = TRUE)
      mem_used_mb <- sum(mem_info[, 2])  # Total memory used
      mem_available <- mem_used_mb / 0.8  # Estimate available (rough)

      if (mem_used_mb > mem_available * 0.8) {
        health_status$checks$memory <- list(
          status = "warn",
          message = sprintf("High memory usage: %.0f MB", mem_used_mb)
        )
        health_status$status <- "degraded"
      } else {
        health_status$checks$memory <- list(
          status = "pass",
          message = sprintf("Memory usage normal: %.0f MB", mem_used_mb)
        )
      }

      # Return JSON response
      list(
        status = ifelse(health_status$status == "healthy", 200L, 503L),
        headers = list("Content-Type" = "application/json"),
        body = jsonlite::toJSON(health_status, auto_unbox = TRUE, pretty = TRUE)
      )
    }
  )
}

#' Create readiness check endpoint
#'
#' Readiness check indicates if the application is ready to serve requests.
#' Different from health check - health indicates if app should be restarted,
#' readiness indicates if app should receive traffic.
#'
#' @param session Shiny session object
#' @param db_pool Database connection pool
setup_readiness_check <- function(session, db_pool = NULL) {

  session$registerDataObj(
    name = "ready",
    data = NULL,
    func = function(data, req) {

      ready <- TRUE
      checks <- list()

      # Check 1: Database connection must be available
      if (!is.null(db_pool)) {
        db_ready <- tryCatch({
          result <- pool::dbGetQuery(db_pool, "SELECT COUNT(*) as count FROM book_entries LIMIT 1")
          nrow(result) == 1
        }, error = function(e) FALSE)

        checks$database <- list(
          ready = db_ready,
          message = ifelse(db_ready, "Database ready", "Database not ready")
        )

        if (!db_ready) ready <- FALSE
      }

      # Check 2: Required cache loaded
      if (exists("cache", envir = .GlobalEnv)) {
        cache_ready <- !is.null(get("cache", envir = .GlobalEnv)$books_summary)
        checks$cache <- list(
          ready = cache_ready,
          message = ifelse(cache_ready, "Cache initialized", "Cache not ready")
        )
        if (!cache_ready) ready <- FALSE
      }

      response <- list(
        ready = ready,
        timestamp = as.character(Sys.time()),
        checks = checks
      )

      list(
        status = ifelse(ready, 200L, 503L),
        headers = list("Content-Type" = "application/json"),
        body = jsonlite::toJSON(response, auto_unbox = TRUE, pretty = TRUE)
      )
    }
  )
}

#' Create liveness check endpoint
#'
#' Liveness check is a simple ping to verify the process is alive.
#' Should always return 200 if the process is running.
#'
#' @param session Shiny session object
setup_liveness_check <- function(session) {
  session$registerDataObj(
    name = "alive",
    data = NULL,
    func = function(data, req) {
      list(
        status = 200L,
        headers = list("Content-Type" = "application/json"),
        body = '{"alive": true}'
      )
    }
  )
}
