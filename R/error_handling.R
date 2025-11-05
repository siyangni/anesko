# Enhanced Error Handling Utilities
# Functions for better user feedback and error management in the Shiny app

# Enhanced safe_query function with detailed feedback
safe_query_enhanced <- function(query_func, default_value = NULL, 
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
    cat("Database query error:", e$message, "\n")
    
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

# Function to validate analysis parameters before running queries
validate_analysis_params <- function(genre_filter, binding_filter, gender_filter, 
                                   start_year, end_year, 
                                   analysis_type = "distribution") {
  issues <- character(0)
  suggestions <- character(0)
  
  # Check date range
  if (is.null(start_year) || is.null(end_year) || start_year >= end_year) {
    issues <- c(issues, "Invalid date range")
    suggestions <- c(suggestions, 
                    "Select a valid date range (start year must be before end year)")
  }
  
  # Check if date range is too narrow
  if (!is.null(start_year) && !is.null(end_year) && 
      (end_year - start_year) < 5) {
    suggestions <- c(suggestions, 
                    "Consider expanding your date range for more comprehensive results")
  }
  
  # For period comparison, need sufficient range
  if (analysis_type == "period_comparison" && !is.null(start_year) && 
      !is.null(end_year)) {
    if ((end_year - start_year) < 10) {
      issues <- c(issues, "Period comparison requires at least 10 years of data")
      suggestions <- c(suggestions, 
                      paste("Expand your date range to at least 10 years",
                            "for meaningful period comparison"))
    }
  }
  
  return(list(
    valid = length(issues) == 0,
    issues = issues,
    suggestions = suggestions
  ))
}

# Function to check data availability for given parameters
check_data_availability <- function(genre_filter, binding_filter, gender_filter, 
                                  start_year, end_year) {
  tryCatch({
    # Quick count query to check if any data exists
    where_conditions <- c("bs.year BETWEEN $1 AND $2", "bs.sales_count IS NOT NULL")
    params <- list(start_year, end_year)
    param_count <- 2
    
    if (!is.null(binding_filter) && binding_filter != "") {
      param_count <- param_count + 1
      where_conditions <- c(where_conditions, 
                           paste0("LOWER(be.binding) LIKE LOWER($", param_count, ")"))
      params <- c(params, list(paste0("%", binding_filter, "%")))
    }
    
    if (!is.null(genre_filter) && genre_filter != "") {
      param_count <- param_count + 1
      where_conditions <- c(where_conditions, 
                           paste0("LOWER(be.genre) LIKE LOWER($", param_count, ")"))
      params <- c(params, list(paste0("%", genre_filter, "%")))
    }
    
    if (!is.null(gender_filter) && gender_filter != "") {
      param_count <- param_count + 1
      where_conditions <- c(where_conditions, 
                           paste0("LOWER(be.gender) LIKE LOWER($", param_count, ")"))
      params <- c(params, list(paste0("%", gender_filter, "%")))
    }
    
    where_clause <- paste(where_conditions, collapse = " AND ")
    
    query <- paste0("
      SELECT COUNT(*) as record_count
      FROM book_entries be
      JOIN book_sales bs ON be.book_id = bs.book_id
      WHERE ", where_clause)
    
    result <- safe_db_query(query, params = params)
    
    if (nrow(result) > 0 && result$record_count[1] > 0) {
      return(list(available = TRUE, count = result$record_count[1]))
    } else {
      return(list(available = FALSE, count = 0))
    }
    
  }, error = function(e) {
    return(list(available = FALSE, count = 0, error = e$message))
  })
}

# Function to generate helpful suggestions when no data is found
generate_data_suggestions <- function(genre_filter, binding_filter, gender_filter, 
                                    start_year, end_year) {
  suggestions <- character(0)
  
  if (!is.null(genre_filter) && genre_filter != "") {
    suggestions <- c(suggestions, 
                    "Try selecting 'All Genres' or a different genre")
  }
  
  if (!is.null(binding_filter) && binding_filter != "") {
    suggestions <- c(suggestions, 
                    "Try selecting 'All Binding Types' or a different binding")
  }
  
  if (!is.null(gender_filter) && gender_filter != "") {
    suggestions <- c(suggestions, 
                    "Try selecting 'All Authors' or a different gender")
  }
  
  if (!is.null(start_year) && !is.null(end_year) && 
      (end_year - start_year) < 20) {
    suggestions <- c(suggestions, 
                    "Try expanding your date range to include more years")
  }
  
  return(suggestions)
}

# Function to create context string for error messages
create_context_string <- function(genre_filter, binding_filter, gender_filter, 
                                start_year, end_year) {
  context_parts <- character(0)
  
  if (!is.null(genre_filter) && genre_filter != "") {
    context_parts <- c(context_parts, paste("genre:", genre_filter))
  }
  
  if (!is.null(binding_filter) && binding_filter != "") {
    context_parts <- c(context_parts, paste("binding:", binding_filter))
  }
  
  if (!is.null(gender_filter) && gender_filter != "") {
    context_parts <- c(context_parts, paste("gender:", gender_filter))
  }
  
  if (!is.null(start_year) && !is.null(end_year)) {
    context_parts <- c(context_parts, paste("years:", start_year, "-", end_year))
  }
  
  return(paste(context_parts, collapse = ", "))
}

# Function to create enhanced empty plot messages
create_empty_plot_message <- function(base_message, genre_filter, binding_filter, 
                                    gender_filter, start_year, end_year) {
  message_parts <- c(base_message)
  
  # Add context-specific suggestions
  if (!is.null(genre_filter) && genre_filter != "") {
    message_parts <- c(message_parts, 
                      "Try selecting 'All Genres' or a different genre")
  }
  
  if (!is.null(binding_filter) && binding_filter != "") {
    message_parts <- c(message_parts, 
                      "Try selecting 'All Binding Types' or a different binding")
  }
  
  if (!is.null(gender_filter) && gender_filter != "") {
    message_parts <- c(message_parts, 
                      "Try selecting 'All Authors' or a different gender")
  }
  
  if (!is.null(start_year) && !is.null(end_year) && 
      (end_year - start_year) < 10) {
    message_parts <- c(message_parts, 
                      "Try expanding your date range to include more years")
  }
  
  message_parts <- c(message_parts, 
                    "Click 'Run Analysis' after adjusting your parameters")
  
  return(paste(message_parts, collapse = "\n"))
}

# Function to create informative summary when no data is available
create_no_data_summary <- function() {
  div(
    class = "alert alert-info",
    style = paste("margin: 20px 0; padding: 15px;", 
                  "background-color: #d9edf7;", 
                  "border: 1px solid #bce8f1;", 
                  "border-radius: 4px;"),
    h4("No Analysis Results", 
       style = "margin-top: 0; color: #31708f;"),
    p("Click 'Run Analysis' to generate results with your selected parameters.", 
      style = "margin-bottom: 10px; color: #31708f;"),
    tags$ul(
      tags$li("Try selecting different genres, binding types, or author genders"),
      tags$li("Expand your date range to include more years"),
      tags$li("Switch between 'Total Sales' and 'Average Sales' metrics"),
      tags$li("Consider using 'All Genres' or 'All Authors' for broader analysis"),
      style = "color: #31708f; margin-bottom: 0;"
    )
  )
}
