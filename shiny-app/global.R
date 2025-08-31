# Global setup for American Authorship Shiny Dashboard
# This file loads libraries, sets up database connections, and defines global functions

# Load required libraries
library(shiny)
library(shinydashboard)
library(shinydashboardPlus)
library(DT)
library(plotly)
library(ggplot2)
library(dplyr)
library(lubridate)
library(DBI)
library(RPostgreSQL)
library(pool)

# Try to load RPostgres if available (optional for better SSL support)
tryCatch({
  library(RPostgres)
}, error = function(e) {
  # RPostgres not available, will use RPostgreSQL only
})
library(shinyWidgets)
library(waiter)
library(fresh)
library(htmltools)
library(scales)
library(tidyr)
library(stringr)

# Load configuration
source("config/app_config.R")

# Load utility functions
source("utils/database.R")
source("utils/data_processing.R")
source("utils/plotting.R")

# Load modules
source("modules/dashboard_module.R")
source("modules/book_explorer_module.R")
# Replaced placeholder Sales Analysis with Sales Trends module
source("modules/sales_trends_module.R")
# Keep legacy sales analysis available (not wired into UI) for reference
source("modules/sales_analysis_module.R")
source("modules/author_analysis_module.R")
source("modules/author_networks_module.R")  # NEW
source("modules/royalty_analysis_module.R")  # NEW
source("modules/royalty_query_module.R")  # NEW - Dedicated royalty income query
source("modules/genre_analysis_module.R")

# Initialize database connection pool for better performance
# Use a more robust approach to handle pool creation and management
initialize_db_pool <- function() {
  tryCatch({
    # Check if pool exists and is valid
    if (exists("pool", envir = .GlobalEnv) && !is.null(pool)) {
      # Test if pool is still valid
      test_result <- tryCatch({
        pool::dbGetQuery(pool, "SELECT 1 as test")
      }, error = function(e) NULL)

      if (!is.null(test_result) && nrow(test_result) == 1) {
        return(pool)  # Pool is working, return it
      } else {
        # Pool is invalid, close it safely
        tryCatch(pool::poolClose(pool), error = function(e) NULL)
      }
    }

    # Create new pool
    new_pool <- create_db_pool()
    assign("pool", new_pool, envir = .GlobalEnv)
    return(new_pool)
  }, error = function(e) {
    warning("Failed to initialize database pool: ", e$message)
    return(NULL)
  })
}

# Initialize the pool
pool <- initialize_db_pool()

# Global data cache (will be populated on app start)
cache <- reactiveValues(
  books_summary = NULL,
  genre_summary = NULL,
  decade_summary = NULL,
  author_summary = NULL,
  last_updated = Sys.time()
)

# Custom theme for the app (toned-down, accessible palette)
app_theme <- fresh::create_theme(
  fresh::adminlte_color(
    light_blue = "#2a4365",  # muted blue
    blue       = "#1e3a5f",
    navy       = "#1f2937",  # slate
    teal       = "#0f766e",  # dark teal (AA on white)
    green      = "#166534",  # dark green
    olive      = "#6b7280",  # neutral gray
    lime       = "#047857",  # emerald
    orange     = "#9a3412",  # burnt orange
    red        = "#7f1d1d",  # deep red
    fuchsia    = "#6d28d9"   # deep purple
  ),
  fresh::adminlte_sidebar(
    dark_bg       = "#1f2937", # dark slate
    dark_hover_bg = "#111827",
    dark_color    = "#e5e7eb"  # light gray text
  ),
  fresh::adminlte_global(
    content_bg = "#f7fafc"     # light gray content background
  )
)

# Global constants
GENRE_COLORS <- c(
  "F" = "#e74c3c",    # Fiction - Red
  "N" = "#3498db",    # Non-fiction - Blue
  "P" = "#9b59b6",    # Poetry - Purple
  "D" = "#f39c12",    # Drama - Orange
  "J" = "#27ae60",    # Juvenile - Green
  "S" = "#1abc9c",    # Short stories - Teal
  "B" = "#95a5a6",    # Biography - Gray
  "Other" = "#7f8c8d" # Other - Dark gray
)

GENDER_COLORS <- c(
  "M" = "#3498db",    # Male - Blue
  "F" = "#e74c3c"     # Female - Red
)

# Ambient pie chart colors (muted, accessible)
PIE_COLORS <- c(
  "#2a4365",  # deep muted blue
  "#0f766e",  # dark teal
  "#6d28d9",  # deep purple
  "#9a3412",  # burnt orange
  "#166534",  # dark green
  "#374151",  # slate
  "#2563eb",  # indigo
  "#7c3aed"   # violet
)

# Ambient palette for charts (bar/line/fill/colors)
AMBIENT_COLORS <- c(
  "#2a4365", "#0f766e", "#6d28d9", "#9a3412",
  "#166534", "#374151", "#2563eb", "#7c3aed",
  "#1e3a5f", "#115e59", "#4c1d95"
)



# Define %||% operator for NULL coalescing
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
}

# Helper function to format numbers
format_number <- function(x, suffix = "") {
  if (is.null(x) || length(x) == 0) return("N/A")

  # Handle vectors
  if (length(x) > 1) {
    return(sapply(x, format_number, suffix = suffix))
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

# Helper function to create value boxes with consistent styling
create_value_box <- function(value, subtitle, icon, color = "blue", width = 12) {
  # Handle both numeric and string values
  formatted_value <- if(is.numeric(value)) {
    format_number(value)
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

# Error handling function
safe_query <- function(query_func, default_value = NULL, error_message = "Data unavailable") {
  tryCatch({
    query_func()
  }, error = function(e) {
    showNotification(
      paste("Error:", error_message),
      type = "error",
      duration = 5
    )
    return(default_value)
  })
}

# Loading spinner options
waiter_options <- list(
  html = spin_fading_circles(),
  color = "rgba(0,0,0,0.5)"
)