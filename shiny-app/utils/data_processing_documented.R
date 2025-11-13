# Documented Utility Functions for Data Processing
# This file contains helper functions with comprehensive roxygen2 documentation

#' Format numbers for display with K/M suffixes
#'
#' Converts large numbers into human-readable format with K (thousand) and M (million) suffixes.
#' Handles NULL, NA, and negative values gracefully by returning "N/A".
#'
#' @param x Numeric value or vector to format
#' @param suffix Optional suffix to append (e.g., "$" for currency)
#' @return Character string or vector with formatted numbers
#' @export
#' @examples
#' format_number(1500)  # Returns "1.5K"
#' format_number(1500000)  # Returns "1.5M"
#' format_number(c(1000, 2000, 3000))  # Returns c("1K", "2K", "3K")
#' format_number(1500, suffix = "$")  # Returns "1.5K$"
format_number_documented <- function(x, suffix = "") {
  if (is.null(x) || length(x) == 0) return("N/A")

  # Handle vectors
  if (length(x) > 1) {
    return(sapply(x, format_number_documented, suffix = suffix))
  }

  # Check for NA, NULL, or non-numeric values
  if (is.na(x) || !is.numeric(x)) return("N/A")

  # Convert to numeric if it's not already
  x <- as.numeric(x)
  if (is.na(x) || is.infinite(x)) return("N/A")

  # Handle negative numbers
  if (x < 0) return("N/A")

  if (x >= 1000000) {
    paste0(round(x / 1000000, 1), "M", suffix)
  } else if (x >= 1000) {
    paste0(round(x / 1000, 1), "K", suffix)
  } else {
    paste0(formatC(x, format = "d", big.mark = ","), suffix)
  }
}

#' Create a consistently styled value box for dashboard
#'
#' Wrapper around shinydashboard::valueBox with consistent formatting
#' for numeric and string values.
#'
#' @param value Numeric or character value to display
#' @param subtitle Descriptive text below the value
#' @param icon Icon name (without "icon()" wrapper)
#' @param color Box color: "blue", "green", "yellow", "red", etc.
#' @param width Box width in Bootstrap grid units (1-12)
#' @return A shinydashboard valueBox object
#' @export
#' @examples
#' create_value_box_documented(1500, "Total Books", "book", "blue")
#' create_value_box_documented("1860-1920", "Date Range", "calendar", "green")
create_value_box_documented <- function(value, subtitle, icon, color = "blue", width = 12) {
  # Handle both numeric and string values
  formatted_value <- if(is.numeric(value)) {
    format_number_documented(value)
  } else {
    as.character(value)  # Keep strings as-is (like year ranges)
  }

  valueBox(
    value = formatted_value,
    subtitle = subtitle,
    icon = icon(icon),
    color = color,
    width = width
  )
}

#' Safely execute database queries with error handling
#'
#' Wraps database queries with comprehensive error handling and logging.
#' Returns default value on error and optionally shows user notifications.
#'
#' @param query_func Function that executes the query
#' @param default_value Value to return if query fails (default: NULL)
#' @param error_message User-friendly error message
#' @param context Additional context for logging (e.g., "Author Analysis")
#' @param show_notification Whether to show Shiny notification on error
#' @return Query result on success, default_value on error
#' @export
#' @examples
#' \dontrun{
#' safe_query(
#'   query_func = function() dbGetQuery(pool, "SELECT * FROM books"),
#'   default_value = data.frame(),
#'   error_message = "Failed to load books",
#'   context = "Dashboard"
#' )
#' }
safe_query_documented <- function(query_func, default_value = NULL,
                                  error_message = "Data unavailable",
                                  context = "", show_notification = TRUE) {
  tryCatch({
    result <- query_func()

    # Check if result is empty and provide context-specific feedback
    if (!is.null(result) && is.data.frame(result) && nrow(result) == 0 &&
        show_notification && context != "") {
      showNotification(
        paste("No data found for", context,
              "- try adjusting your filters or date range"),
        type = "warning",
        duration = 8
      )
    }

    return(result)
  }, error = function(e) {
    # Log error for debugging
    if (requireNamespace("logger", quietly = TRUE)) {
      logger::log_error("Database query error in {context}: {e$message}")
    } else {
      cat("Database query error:", e$message, "\n")
    }

    if (show_notification) {
      showNotification(
        paste("Error:", error_message,
              "- Please try different parameters or contact support"),
        type = "error",
        duration = 10
      )
    }
    return(default_value)
  })
}

#' NULL-coalescing operator
#'
#' Returns the first non-NULL, non-NA, non-empty value.
#' Useful for providing default values.
#'
#' @param x First value to check
#' @param y Default value if x is NULL/NA/empty
#' @return x if valid, otherwise y
#' @export
#' @examples
#' NULL %||% "default"  # Returns "default"
#' "value" %||% "default"  # Returns "value"
#' NA %||% "default"  # Returns "default"
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
}

#' Calculate percentage with proper formatting
#'
#' Calculates percentage and formats with specified decimal places.
#' Handles division by zero gracefully.
#'
#' @param numerator Numerator value
#' @param denominator Denominator value
#' @param digits Number of decimal places (default: 1)
#' @param include_symbol Whether to include % symbol
#' @return Formatted percentage string
#' @export
#' @examples
#' calculate_percentage(25, 100)  # Returns "25.0%"
#' calculate_percentage(1, 3, digits = 2)  # Returns "33.33%"
#' calculate_percentage(5, 0)  # Returns "N/A" (handles division by zero)
calculate_percentage <- function(numerator, denominator, digits = 1, include_symbol = TRUE) {
  if (is.null(denominator) || is.na(denominator) || denominator == 0) {
    return("N/A")
  }

  if (is.null(numerator) || is.na(numerator)) {
    return("N/A")
  }

  pct <- (numerator / denominator) * 100
  formatted <- format(round(pct, digits), nsmall = digits)

  if (include_symbol) {
    paste0(formatted, "%")
  } else {
    formatted
  }
}

#' Format currency values
#'
#' Formats numeric values as currency with $ symbol and commas.
#'
#' @param value Numeric value to format
#' @param currency_symbol Currency symbol (default: "$")
#' @param digits Number of decimal places (default: 2)
#' @return Formatted currency string
#' @export
#' @examples
#' format_currency(1234.56)  # Returns "$1,234.56"
#' format_currency(1000000)  # Returns "$1,000,000.00"
format_currency <- function(value, currency_symbol = "$", digits = 2) {
  if (is.null(value) || is.na(value) || !is.numeric(value)) {
    return("N/A")
  }

  if (value < 0) {
    return(paste0("-", currency_symbol, formatC(abs(value), format = "f", digits = digits, big.mark = ",")))
  }

  paste0(currency_symbol, formatC(value, format = "f", digits = digits, big.mark = ","))
}

#' Format date ranges
#'
#' Creates formatted date range strings for display.
#'
#' @param start_date Start date (Date or character)
#' @param end_date End date (Date or character)
#' @param separator Separator between dates (default: " - ")
#' @return Formatted date range string
#' @export
#' @examples
#' format_date_range("1860", "1920")  # Returns "1860 - 1920"
#' format_date_range(1860, 1920, " to ")  # Returns "1860 to 1920"
format_date_range <- function(start_date, end_date, separator = " - ") {
  if (is.null(start_date) || is.null(end_date)) {
    return("N/A")
  }

  paste0(start_date, separator, end_date)
}

#' Truncate text with ellipsis
#'
#' Truncates long text strings and adds ellipsis if needed.
#'
#' @param text Text to truncate
#' @param max_length Maximum length before truncation
#' @param ellipsis Ellipsis string (default: "...")
#' @return Truncated text string
#' @export
#' @examples
#' truncate_text("This is a very long title", 10)  # Returns "This is a..."
truncate_text <- function(text, max_length, ellipsis = "...") {
  if (is.null(text) || is.na(text)) {
    return("")
  }

  text <- as.character(text)

  if (nchar(text) <= max_length) {
    return(text)
  }

  paste0(substr(text, 1, max_length - nchar(ellipsis)), ellipsis)
}
