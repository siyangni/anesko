# Test the compute_distribution function to verify the fix
library(dplyr)

cat("🔧 Testing compute_distribution function fix\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Load configuration and utilities
source("config/cloud_config.R")
source("utils/database.R")
source("utils/queries_sales.R")
source("utils/error_handling.R")

# Mock showNotification for testing
showNotification <- function(message, type = "message", duration = 5) {
  cat("NOTIFICATION [", type, "]:", message, "\n")
}

# Define the compute_distribution function (extracted from module)
compute_distribution <- function(base_df, params) {
  if (is.null(base_df) || nrow(base_df) == 0) {
    showNotification(
      "No data available for the selected parameters. Try adjusting your filters, date range, or analysis type.",
      type = "warning",
      duration = 8
    )
    return(data.frame())
  }

  primary <- params$primary_breakdown %||% "genre"  # 'genre' or 'binding'
  split <- params$secondary_split %||% ""
  normalize <- params$normalize %||% "absolute"
  top_n <- params$top_n %||% 10
  sort_by <- params$sort_by %||% "value"
  metric <- params$metric_type %||% "total"  # 'total' or 'average'

  # Determine value column with better error messages
  if (metric == "average") {
    value_col <- "avg_total_sales_per_book"
    # Ensure column exists (from average query)
    if (!(value_col %in% names(base_df))) {
      showNotification(
        "Data format error: Average sales data not available. Try switching to 'Total Sales' metric.",
        type = "error",
        duration = 8
      )
      return(data.frame())
    }
  } else {
    value_col <- "total_sales"
    if (!(value_col %in% names(base_df))) {
      showNotification(
        "Data format error: Total sales data not available. Please contact support.",
        type = "error",
        duration = 8
      )
      return(data.frame())
    }
  }

  # Columns to keep
  keep_cols <- c("genre", "binding", "gender", "book_count", value_col)
  df <- base_df[, intersect(keep_cols, names(base_df)), drop = FALSE]

  # Aggregate by chosen breakdown
  if (split == "") {
    # Group by primary only
    if (primary == "genre") {
      # Check if required columns exist
      if (!("genre" %in% names(df))) {
        showNotification("Data format error: 'genre' column missing from results", 
                       type = "error", duration = 8)
        return(data.frame())
      }
      
      agg <- aggregate(df[[value_col]] ~ genre, df, sum)
      names(agg)[2] <- value_col  # Fix column name directly
      
      if ("book_count" %in% names(df)) {
        bc <- aggregate(book_count ~ genre, df, sum)
        out <- merge(agg, bc, by = "genre", all = TRUE)
      } else {
        out <- agg
        out$book_count <- 1  # Fallback
      }
      
      # Safely select existing columns
      available_cols <- intersect(c("genre", value_col, "book_count"), names(out))
      out <- out[, available_cols, drop = FALSE]
      
    } else {
      # Check if required columns exist
      if (!("binding" %in% names(df))) {
        showNotification("Data format error: 'binding' column missing from results", 
                       type = "error", duration = 8)
        return(data.frame())
      }
      
      agg <- aggregate(df[[value_col]] ~ binding, df, sum)
      names(agg)[2] <- value_col  # Fix column name directly
      
      if ("book_count" %in% names(df)) {
        bc <- aggregate(book_count ~ binding, df, sum)
        out <- merge(agg, bc, by = "binding", all = TRUE)
      } else {
        out <- agg
        out$book_count <- 1  # Fallback
      }
      
      # Safely select existing columns
      available_cols <- intersect(c("binding", value_col, "book_count"), names(out))
      out <- out[, available_cols, drop = FALSE]
    }
  } else {
    return(data.frame(Error = "Split functionality not tested in this script"))
  }

  # Sort and limit
  if (sort_by == "value") {
    out <- out[order(-out[[value_col]]), ]
  }
  out <- head(out, top_n)

  return(out)
}

# Test 1: Get test data
cat("\n📊 Getting test data...\n")
base_data <- get_total_sales_by_binding_genre_gender(NULL, NULL, NULL, 1860, 1920)
cat("Base data columns:", paste(names(base_data), collapse = ", "), "\n")
cat("Base data rows:", nrow(base_data), "\n")

if (nrow(base_data) > 0) {
  cat("Sample data:\n")
  print(head(base_data, 3))
}

# Test 2: Test compute_distribution with genre breakdown
cat("\n🧮 Testing compute_distribution with genre breakdown...\n")
params_genre <- list(
  primary_breakdown = "genre",
  secondary_split = "",
  normalize = "absolute",
  show_cumulative = FALSE,
  top_n = 5,
  sort_by = "value",
  metric_type = "total"
)

result_genre <- compute_distribution(base_data, params_genre)
cat("Result columns:", paste(names(result_genre), collapse = ", "), "\n")
cat("Result rows:", nrow(result_genre), "\n")

if (nrow(result_genre) > 0) {
  cat("Genre breakdown results:\n")
  print(result_genre)
} else {
  cat("❌ No results returned for genre breakdown\n")
}

# Test 3: Test compute_distribution with binding breakdown
cat("\n🧮 Testing compute_distribution with binding breakdown...\n")
params_binding <- list(
  primary_breakdown = "binding",
  secondary_split = "",
  normalize = "absolute",
  show_cumulative = FALSE,
  top_n = 5,
  sort_by = "value",
  metric_type = "total"
)

result_binding <- compute_distribution(base_data, params_binding)
cat("Result columns:", paste(names(result_binding), collapse = ", "), "\n")
cat("Result rows:", nrow(result_binding), "\n")

if (nrow(result_binding) > 0) {
  cat("Binding breakdown results:\n")
  print(result_binding)
} else {
  cat("❌ No results returned for binding breakdown\n")
}

# Test 4: Test with average metric
cat("\n🧮 Testing with average metric...\n")
base_data_avg <- get_average_sales_by_binding_genre_gender(NULL, NULL, NULL, 1860, 1920)
cat("Average data columns:", paste(names(base_data_avg), collapse = ", "), "\n")

params_avg <- list(
  primary_breakdown = "genre",
  secondary_split = "",
  normalize = "absolute",
  show_cumulative = FALSE,
  top_n = 3,
  sort_by = "value",
  metric_type = "average"
)

result_avg <- compute_distribution(base_data_avg, params_avg)
cat("Average result columns:", paste(names(result_avg), collapse = ", "), "\n")
cat("Average result rows:", nrow(result_avg), "\n")

if (nrow(result_avg) > 0) {
  cat("Average breakdown results:\n")
  print(result_avg)
} else {
  cat("❌ No results returned for average breakdown\n")
}

cat("\n🎯 compute_distribution function test completed!\n")
cat("If all tests passed, the column selection error should be fixed.\n")
