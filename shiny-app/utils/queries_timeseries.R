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
# Returns columns: year (sales year), group_label, total_sales, book_count
#
# sales_start_year / sales_end_year filter book_sales.year (when copies sold).
# Legacy start_year / end_year are aliases for the same sales-year bounds.
# Do NOT pass publication years here.
get_sales_timeseries_filtered <- function(
  sales_start_year = NULL,
  sales_end_year = NULL,
  group_by = "gender",
  authors = character(0),
  publishers = character(0),
  genres = character(0),
  bindings = character(0),
  books = character(0),
  include_unknown_gender = TRUE,
  genders = c("Male", "Female", "Unknown"),
  start_year = NULL,
  end_year = NULL
) {
  sales_range <- resolve_year_range(
    c(
      sales_start_year %||% start_year %||% MIN_YEAR,
      sales_end_year %||% end_year %||% MAX_YEAR
    ),
    default = c(MIN_YEAR, MAX_YEAR)
  )
  sales_start_year <- sales_range$start
  sales_end_year <- sales_range$end
  group_expr <- switch(group_by,
    "gender" = "be.gender",
    "author" = "be.author_surname",
    "publisher" = "be.publisher",
    "book" = "be.book_title",
    "genre" = "be.genre",
    "binding" = "be.binding",
    "be.gender"
  )
  # Gender groups normalize NULL/blank → Unknown; other dims keep COALESCE
  label_expr <- if (identical(group_by, "gender")) {
    gender_display_sql(group_expr)
  } else {
    paste0("COALESCE(", group_expr, ", 'Unknown')")
  }

  # Sales-year filter (book_sales.year — when copies were sold)
  where_clauses <- c(
    "bs.sales_count IS NOT NULL",
    "bs.year BETWEEN $1 AND $2"
  )
  params <- list(sales_start_year, sales_end_year)
  next_idx <- 3L

  # Multi-select genders: empty must not silently mean "all"
  gender_sel <- normalize_gender_filter(genders, mode = "multi")
  gvals <- gender_sel$genders
  if (!isTRUE(include_unknown_gender)) {
    gvals <- setdiff(gvals, "Unknown")
  }
  if (gender_sel$empty || (length(gvals) == 0 && gender_sel$apply)) {
    where_clauses <- c(where_clauses, "FALSE")
  } else {
    gender_sql <- build_gender_sql_filter(gvals, column = "be.gender", param_start = next_idx)
    if (!is.null(gender_sql$clause)) {
      where_clauses <- c(where_clauses, gender_sql$clause)
      params <- c(params, gender_sql$params)
      next_idx <- gender_sql$next_param
    }
  }

  # Optional multi filters: empty / blank / whitespace = no restriction
  add_optional_in <- function(field, values, case_insensitive = TRUE) {
    sel <- normalize_optional_filter(values, mode = "multi")
    if (!sel$apply) return()
    sql <- build_text_in_sql_filter(
      sel$values,
      column = field,
      param_start = next_idx,
      case_insensitive = case_insensitive
    )
    where_clauses <<- c(where_clauses, sql$clause)
    params <<- c(params, sql$params)
    next_idx <<- sql$next_param
  }

  add_optional_in("be.author_surname", authors, TRUE)
  add_optional_in("be.publisher", publishers, TRUE)
  add_optional_in("be.genre", genres, TRUE)
  add_optional_in("be.binding", bindings, TRUE)
  # Book IDs: exact match, optional multi
  book_sel <- normalize_optional_filter(books, mode = "multi")
  if (book_sel$apply) {
    sql <- build_text_in_sql_filter(
      book_sel$values,
      column = "be.book_id",
      param_start = next_idx,
      case_insensitive = FALSE
    )
    where_clauses <- c(where_clauses, sql$clause)
    params <- c(params, sql$params)
    next_idx <- sql$next_param
  }

  where_sql <- paste(where_clauses, collapse = " AND ")
  query <- paste0(
    "SELECT\n",
    "  bs.year AS sales_year,\n",
    "  bs.year,\n",  # keep `year` for existing plot consumers
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
# sales_start_year / sales_end_year filter book_sales.year (not publication year).
get_sales_timeseries_for_dimension <- function(
  dimension,
  values,
  sales_start_year = NULL,
  sales_end_year = NULL,
  authors = character(0),
  publishers = character(0),
  genres = character(0),
  bindings = character(0),
  books = character(0),
  include_unknown_gender = TRUE,
  genders = c("Male", "Female", "Unknown"),
  start_year = NULL,
  end_year = NULL
) {
  if (is.null(values) || length(values) == 0) return(data.frame())

  sales_range <- resolve_year_range(
    c(
      sales_start_year %||% start_year %||% MIN_YEAR,
      sales_end_year %||% end_year %||% MAX_YEAR
    ),
    default = c(MIN_YEAR, MAX_YEAR)
  )
  sales_start_year <- sales_range$start
  sales_end_year <- sales_range$end

  field <- switch(dimension,
    "gender" = "be.gender",
    "author" = "be.author_surname",
    "publisher" = "be.publisher",
    "book" = "be.book_id",
    "genre" = "be.genre",
    "binding" = "be.binding",
    stop("Unsupported dimension: ", dimension)
  )
  label_expr <- if (dimension == "book") {
    "COALESCE(be.book_title, 'Unknown')"
  } else if (dimension == "gender") {
    gender_display_sql(field)
  } else {
    paste0("COALESCE(", field, ", 'Unknown')")
  }

  # Sales-year filter (book_sales.year)
  where_clauses <- c(
    "bs.sales_count IS NOT NULL",
    "bs.year BETWEEN $1 AND $2"
  )
  params <- list(sales_start_year, sales_end_year)
  next_idx <- 3L

  # Multi-select genders: empty must not silently mean "all"
  gender_sel <- normalize_gender_filter(genders, mode = "multi")
  gvals <- gender_sel$genders
  if (!isTRUE(include_unknown_gender)) {
    gvals <- setdiff(gvals, "Unknown")
  }
  if (gender_sel$empty || (length(gvals) == 0 && gender_sel$apply)) {
    where_clauses <- c(where_clauses, "FALSE")
  } else {
    gender_sql <- build_gender_sql_filter(gvals, column = "be.gender", param_start = next_idx)
    if (!is.null(gender_sql$clause)) {
      where_clauses <- c(where_clauses, gender_sql$clause)
      params <- c(params, gender_sql$params)
      next_idx <- gender_sql$next_param
    }
  }

  # Optional multi filters: empty / blank / whitespace = no restriction
  add_optional_in <- function(fld, vals, ci = TRUE) {
    sel <- normalize_optional_filter(vals, mode = "multi")
    if (!sel$apply) return()
    sql <- build_text_in_sql_filter(
      sel$values,
      column = fld,
      param_start = next_idx,
      case_insensitive = ci
    )
    where_clauses <<- c(where_clauses, sql$clause)
    params <<- c(params, sql$params)
    next_idx <<- sql$next_param
  }

  add_optional_in("be.author_surname", authors, TRUE)
  add_optional_in("be.publisher", publishers, TRUE)
  add_optional_in("be.genre", genres, TRUE)
  add_optional_in("be.binding", bindings, TRUE)
  add_optional_in("be.book_id", books, FALSE)

  # Dimension comparison values (required — already guarded above for empty)
  dim_vals <- sanitize_filter_values(values)
  if (length(dim_vals) == 0) return(data.frame())
  n <- length(dim_vals)
  placeholders <- paste0("$", next_idx:(next_idx + n - 1L), collapse = ",")
  where_clauses <- c(where_clauses, paste0(field, " IN (", placeholders, ")"))
  params <- c(params, as.list(dim_vals))

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

