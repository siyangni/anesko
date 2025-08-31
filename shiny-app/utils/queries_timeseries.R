# Time Series Database Query Functions
# Functions for time series retrieval and decade summaries

# Get time series data for specific books
get_book_sales_timeseries <- function(book_ids) {
  if (length(book_ids) == 0) return(data.frame())

  placeholders <- paste0("$", 1:length(book_ids), collapse = ",")
  query <- paste0(
    "\n    SELECT\n      bs.book_id,\n      be.author_surname,\n      be.book_title,\n      bs.year,\n      bs.sales_count\n    FROM book_sales bs\n    JOIN book_entries be ON bs.book_id = be.book_id\n    WHERE bs.book_id IN (", placeholders, ")\n      AND bs.sales_count IS NOT NULL\n    ORDER BY bs.book_id, bs.year\n  ")
  safe_db_query(query, params = as.list(book_ids))
}

# Decade summary
get_decade_summary <- function() {
  query <- "
    SELECT
      (bs.year / 10) * 10 as decade,
      COUNT(DISTINCT bs.book_id) as unique_books,
      COUNT(*) as total_records,
      SUM(bs.sales_count) as total_sales,
      AVG(bs.sales_count) as avg_sales_per_record,
      COUNT(DISTINCT be.author_surname) as unique_authors,
      COUNT(DISTINCT be.publisher) as unique_publishers
    FROM book_sales bs
    JOIN book_entries be ON bs.book_id = be.book_id
    WHERE bs.sales_count IS NOT NULL
    GROUP BY decade
    ORDER BY decade
  "
  safe_db_query(query)
}

# Consolidated time-series with flexible grouping and filters
# Returns columns: year, group_label, total_sales, book_count
get_sales_timeseries_filtered <- function(
  start_year = MIN_YEAR,
  end_year = MAX_YEAR,
  group_by = "gender",
  authors = character(0),
  publishers = character(0),
  genres = character(0),
  bindings = character(0),
  books = character(0),
  include_unknown_gender = TRUE,
  genders = c("Male","Female","Unknown")
) {
  group_expr <- switch(group_by,
    "gender" = "be.gender",
    "author" = "be.author_surname",
    "publisher" = "be.publisher",
    "book" = "be.book_title",
    "genre" = "be.genre",
    "binding" = "be.binding",
    "be.gender"
  )
  label_expr <- paste0("COALESCE(", group_expr, ", 'Unknown')")

  where_clauses <- c(
    "bs.sales_count IS NOT NULL",
    "bs.year BETWEEN $1 AND $2"
  )
  params <- list(start_year, end_year)
  next_idx <- 3

  if (!is.null(genders) && length(genders) > 0) {
    gvals <- genders[!is.na(genders) & nzchar(genders)]
    if (length(gvals) > 0 && length(gvals) < 3) {
      placeholders <- paste0("$", next_idx:(next_idx + length(gvals) - 1), collapse = ",")
      where_clauses <- c(where_clauses, paste0("be.gender IN (", placeholders, ")"))
      params <- c(params, gvals)
      next_idx <- next_idx + length(gvals)
    }
  } else if (!include_unknown_gender) {
    where_clauses <- c(where_clauses, "(be.gender = 'Male' OR be.gender = 'Female')")
  }

  add_in_filter <- function(field, values, case_insensitive = TRUE) {
    non_empty <- values[!is.na(values) & nzchar(values)]
    if (length(non_empty) == 0) return(NULL)
    n <- length(non_empty)
    placeholders <- paste0("$", next_idx:(next_idx + n - 1), collapse = ",")
    if (case_insensitive) {
      clause <- paste0("LOWER(", field, ") IN (", placeholders, ")")
      params <<- c(params, tolower(non_empty))
    } else {
      clause <- paste0(field, " IN (", placeholders, ")")
      params <<- c(params, non_empty)
    }
    next_idx <<- next_idx + n
    where_clauses <<- c(where_clauses, clause)
    NULL
  }

  add_in_filter("be.author_surname", authors, TRUE)
  add_in_filter("be.publisher", publishers, TRUE)
  add_in_filter("be.genre", genres, TRUE)
  add_in_filter("be.binding", bindings, TRUE)
  if (length(books) > 0) {
    non_empty <- books[!is.na(books) & nzchar(books)]
    if (length(non_empty) > 0) {
      n <- length(non_empty)
      placeholders <- paste0("$", next_idx:(next_idx + n - 1), collapse = ",")
      where_clauses <- c(where_clauses, paste0("be.book_id IN (", placeholders, ")"))
      params <- c(params, non_empty)
      next_idx <- next_idx + n
    }
  }

  where_sql <- paste(where_clauses, collapse = " AND ")
  query <- paste0(
    "SELECT\n",
    "  bs.year,\n",
    "  ", label_expr, " AS group_label,\n",
    "  SUM(bs.sales_count) AS total_sales,\n",
    "  COUNT(DISTINCT be.book_id) AS book_count\n",
    "FROM book_sales bs\n",
    "JOIN book_entries be ON bs.book_id = be.book_id\n",
    "WHERE ", where_sql, "\n",
    "GROUP BY bs.year, ", label_expr, "\n",
    "ORDER BY bs.year, ", label_expr, "\n"
  )
  safe_db_query(query, params = params)
}

# Time series for selected values of a given dimension (compare mode)
get_sales_timeseries_for_dimension <- function(
  dimension,
  values,
  start_year = MIN_YEAR,
  end_year = MAX_YEAR,
  authors = character(0),
  publishers = character(0),
  genres = character(0),
  bindings = character(0),
  books = character(0),
  include_unknown_gender = TRUE,
  genders = c("Male","Female","Unknown")
) {
  if (is.null(values) || length(values) == 0) return(data.frame())

  field <- switch(dimension,
    "gender" = "be.gender",
    "author" = "be.author_surname",
    "publisher" = "be.publisher",
    "book" = "be.book_id",
    "genre" = "be.genre",
    "binding" = "be.binding",
    stop("Unsupported dimension: ", dimension)
  )
  label_expr <- if (dimension == "book") "COALESCE(be.book_title, 'Unknown')" else paste0("COALESCE(", field, ", 'Unknown')")

  where_clauses <- c(
    "bs.sales_count IS NOT NULL",
    "bs.year BETWEEN $1 AND $2"
  )
  params <- list(start_year, end_year)
  next_idx <- 3

  if (!is.null(genders) && length(genders) > 0) {
    gvals <- genders[!is.na(genders) & nzchar(genders)]
    if (length(gvals) > 0 && length(gvals) < 3) {
      placeholders <- paste0("$", next_idx:(next_idx + length(gvals) - 1), collapse = ",")
      where_clauses <- c(where_clauses, paste0("be.gender IN (", placeholders, ")"))
      params <- c(params, gvals)
      next_idx <- next_idx + length(gvals)
    }
  } else if (!include_unknown_gender) {
    where_clauses <- c(where_clauses, "(be.gender = 'Male' OR be.gender = 'Female')")
  }

  add_in <- function(fld, vals, ci = TRUE) {
    vv <- vals[!is.na(vals) & nzchar(vals)]
    if (length(vv) == 0) return()
    n <- length(vv)
    placeholders <- paste0("$", next_idx:(next_idx + n - 1), collapse = ",")
    if (ci) {
      where_clauses <<- c(where_clauses, paste0("LOWER(", fld, ") IN (", placeholders, ")"))
      params <<- c(params, tolower(vv))
    } else {
      where_clauses <<- c(where_clauses, paste0(fld, " IN (", placeholders, ")"))
      params <<- c(params, vv)
    }
    next_idx <<- next_idx + n
  }

  add_in("be.author_surname", authors, TRUE)
  add_in("be.publisher", publishers, TRUE)
  add_in("be.genre", genres, TRUE)
  add_in("be.binding", bindings, TRUE)
  add_in("be.book_id", books, FALSE)

  vv <- values[!is.na(values) & nzchar(values)]
  n <- length(vv)
  placeholders <- paste0("$", next_idx:(next_idx + n - 1), collapse = ",")
  where_clauses <- c(where_clauses, paste0(field, " IN (", placeholders, ")"))
  params <- c(params, vv)

  where_sql <- paste(where_clauses, collapse = " AND ")
  query <- paste0(
    "SELECT\n",
    "  bs.year,\n",
    "  ", label_expr, " AS group_label,\n",
    "  SUM(bs.sales_count) AS total_sales,\n",
    "  COUNT(DISTINCT be.book_id) AS book_count\n",
    "FROM book_sales bs\n",
    "JOIN book_entries be ON bs.book_id = be.book_id\n",
    "WHERE ", where_sql, "\n",
    "GROUP BY bs.year, ", label_expr, "\n",
    "ORDER BY bs.year, ", label_expr, "\n"
  )
  safe_db_query(query, params = params)
}

