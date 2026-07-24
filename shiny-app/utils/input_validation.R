# Input Validation Utilities
# Security functions to prevent SQL injection and validate user inputs

# Whitelist of allowed SQL column names for grouping
ALLOWED_GROUP_BY_FIELDS <- c(
  "gender" = "be.gender",
  "author" = "be.author_surname",
  "publisher" = "be.publisher",
  "book" = "be.book_title",
  "genre" = "be.genre",
  "binding" = "be.binding"
)

#' Validate and sanitize group_by parameter
#'
#' This function validates that the group_by parameter is one of the
#' allowed values and returns the corresponding SQL expression.
#' This prevents SQL injection attacks.
#'
#' @param group_by Character string indicating grouping dimension
#' @return Character string with validated SQL expression
#' @throws error if invalid group_by value
validate_group_by <- function(group_by) {
  # Validate input exists
  if (is.null(group_by) || length(group_by) == 0 || !is.character(group_by)) {
    stop("Invalid group_by parameter: must be a character string")
  }

  # Normalize to lowercase
  group_by <- tolower(trimws(group_by))

  # Check against whitelist
  if (!group_by %in% names(ALLOWED_GROUP_BY_FIELDS)) {
    stop(sprintf(
      "Invalid group_by value: '%s'. Allowed values: %s",
      group_by,
      paste(names(ALLOWED_GROUP_BY_FIELDS), collapse = ", ")
    ))
  }

  # Return validated SQL expression
  ALLOWED_GROUP_BY_FIELDS[[group_by]]
}

#' Validate year parameter
#'
#' Ensures year is within valid range for the dataset
#'
#' @param year Numeric year value
#' @param param_name Parameter name for error messages
#' @return Validated year as integer
validate_year <- function(year, param_name = "year") {
  if (is.null(year) || !is.numeric(year)) {
    stop(sprintf("%s must be numeric", param_name))
  }

  year <- as.integer(year)

  # Use constants from app_config.R
  if (year < INPUT_MIN_YEAR || year > INPUT_MAX_YEAR) {
    stop(sprintf("%s must be between %d and %d", param_name, INPUT_MIN_YEAR, INPUT_MAX_YEAR))
  }

  # Warn if outside dataset range but allow it
  if (year < MIN_YEAR || year > MAX_YEAR) {
    warning(sprintf("%s (%d) is outside dataset range (%d-%d)",
                    param_name, year, MIN_YEAR, MAX_YEAR))
  }

  year
}

#' Validate year range
#'
#' Ensures start_year < end_year and both are valid
#'
#' @param start_year Numeric start year
#' @param end_year Numeric end year
#' @return List with validated start_year and end_year
validate_year_range <- function(start_year, end_year) {
  start_year <- validate_year(start_year, "start_year")
  end_year <- validate_year(end_year, "end_year")

  if (start_year >= end_year) {
    stop(sprintf(
      "start_year (%d) must be less than end_year (%d)",
      start_year, end_year
    ))
  }

  list(start_year = start_year, end_year = end_year)
}

#' Sanitize string input for database queries
#'
#' Normalizes and bounds user-supplied text.
#' Note: This is a defense-in-depth measure; always use parameterized queries!
#'
#' @param input Character vector to sanitize
#' @param max_length Maximum allowed length (default: 200)
#' @return Sanitized character vector
sanitize_string_input <- function(input, max_length = 200) {
  if (is.null(input) || length(input) == 0) {
    return(character(0))
  }

  # Convert to character
  input <- as.character(input)

  # Truncate to maximum length
  input <- substr(input, 1, max_length)

  # Trim whitespace
  input <- trimws(input)

  # Remove empty strings
  input <- input[nzchar(input)]

  input
}

#' Validate dimension parameter for comparison queries
#'
#' @param dimension Character string indicating comparison dimension
#' @return Validated dimension string
validate_dimension <- function(dimension) {
  allowed_dimensions <- c("book", "author", "publisher", "genre", "binding", "gender")

  if (is.null(dimension) || !is.character(dimension) || length(dimension) != 1) {
    stop("Dimension must be a single character string")
  }

  dimension <- tolower(trimws(dimension))

  if (!dimension %in% allowed_dimensions) {
    stop(sprintf(
      "Invalid dimension: '%s'. Allowed: %s",
      dimension,
      paste(allowed_dimensions, collapse = ", ")
    ))
  }

  dimension
}

#' Validate gender filter values against canonical labels
#'
#' Accepts Male/Female/Unknown (case-insensitive codes M/F/U).
#' Blank/whitespace-only values are treated as Unknown when non-empty
#' input is provided. Empty input returns character(0) when allow_empty
#' is TRUE — callers must not treat that as "all genders".
#'
#' Depends on clean_gender() from data_processing.R in the running app.
#'
#' @param values Character vector of gender filter values
#' @param allow_empty If TRUE, empty input is valid and returns character(0)
#' @return Canonical gender character vector
validate_gender <- function(values, allow_empty = TRUE) {
  if (is.null(values) || length(values) == 0) {
    if (isTRUE(allow_empty)) {
      return(character(0))
    }
    stop("Gender filter must include at least one value")
  }

  # Single explicit "all" sentinel used by selectInput choices ("")
  if (length(values) == 1L) {
    raw <- trimws(as.character(values[[1]]))
    if (is.na(raw) || !nzchar(raw)) {
      if (isTRUE(allow_empty)) {
        return(character(0))
      }
      stop("Gender filter must include at least one value")
    }
  }

  if (!exists("clean_gender", mode = "function")) {
    stop("clean_gender() is required; source data_processing.R first")
  }

  cleaned <- unique(clean_gender(values))
  cleaned <- cleaned[cleaned %in% c("Male", "Female", "Unknown")]

  if (length(cleaned) == 0 && !isTRUE(allow_empty)) {
    stop("Gender filter must be one of: Male, Female, Unknown")
  }

  cleaned
}

#' Validate and sanitize filter values
#'
#' Ensures filter values are safe for use in parameterized queries
#'
#' @param values Character vector of filter values
#' @param field_name Name of field being filtered (for error messages)
#' @param max_values Maximum number of values allowed (default: 100)
#' @return Sanitized character vector
validate_filter_values <- function(values, field_name = "filter", max_values = MAX_FILTER_VALUES) {
  if (is.null(values) || length(values) == 0) {
    return(character(0))
  }

  # Sanitize each value
  values <- sanitize_string_input(values)

  # Check max values (use constant from app_config.R)
  if (length(values) > max_values) {
    warning(sprintf(
      "%s has %d values, limiting to first %d",
      field_name, length(values), max_values
    ))
    values <- head(values, max_values)
  }

  values
}

#' Validate limit parameter for query results
#'
#' @param limit Numeric limit value
#' @param max_limit Maximum allowed limit (default: 10000)
#' @return Validated limit as integer
validate_limit <- function(limit, max_limit = MAX_QUERY_LIMIT) {
  if (is.null(limit)) {
    return(as.integer(DEFAULT_QUERY_LIMIT))  # Use constant from app_config.R
  }

  if (!is.numeric(limit) || limit < 1) {
    stop("Limit must be a positive number")
  }

  limit <- as.integer(limit)

  # Use constant from app_config.R
  if (limit > max_limit) {
    warning(sprintf(
      "Limit %d exceeds maximum %d, using %d",
      limit, max_limit, max_limit
    ))
    limit <- max_limit
  }

  limit
}

#' Log potentially suspicious query parameters
#'
#' Logs query parameters for security auditing
#'
#' @param function_name Name of the calling function
#' @param params List of parameters
log_query_parameters <- function(function_name, params) {
  # This function can be extended to write to a security log
  # For now, it just validates that logging is possible

  if (!exists("logger_initialized") || !logger_initialized) {
    # Logger not available, skip
    return(invisible(NULL))
  }

  # Log with logger package if available
  if (requireNamespace("logger", quietly = TRUE)) {
    logger::log_trace(
      "Query: {function_name}",
      function_name = function_name
    )
  }
}
