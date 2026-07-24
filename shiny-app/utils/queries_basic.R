# Basic Database Query Functions
# Functions for basic data retrieval, search, and filter options

# Get summary statistics
get_summary_stats <- function() {
  query <- "
    SELECT
      (SELECT COUNT(*) FROM book_entries) as total_books,
      (SELECT COUNT(*) FROM book_sales) as total_sales_records,
      (SELECT COUNT(DISTINCT author_surname) FROM book_entries) as unique_authors,
      (SELECT COUNT(DISTINCT publisher) FROM book_entries WHERE publisher IS NOT NULL) as unique_publishers,
      (SELECT MIN(publication_year) FROM book_entries WHERE publication_year IS NOT NULL) as min_year,
      (SELECT MAX(publication_year) FROM book_entries WHERE publication_year IS NOT NULL) as max_year,
      (SELECT SUM(sales_count) FROM book_sales WHERE sales_count IS NOT NULL) as total_copies_sold
  "
  safe_db_query(query)
}

#' Observed publication-year span from the database, plus filter buffer.
#'
#' @param buffer Years of headroom beyond observed min/max (default config)
#' @return list from compute_publication_year_bounds()
get_publication_year_bounds <- function(buffer = NULL) {
  if (is.null(buffer)) {
    buffer <- if (exists("PUBLICATION_YEAR_BUFFER")) {
      as.integer(PUBLICATION_YEAR_BUFFER)
    } else {
      5L
    }
  }

  res <- tryCatch(
    safe_db_query(
      "SELECT MIN(publication_year) AS min_year,
              MAX(publication_year) AS max_year
       FROM book_entries
       WHERE publication_year IS NOT NULL"
    ),
    error = function(e) data.frame(min_year = NA_integer_, max_year = NA_integer_)
  )

  obs_min <- if (!is.null(res) && nrow(res) > 0) res$min_year[1] else NA_integer_
  obs_max <- if (!is.null(res) && nrow(res) > 0) res$max_year[1] else NA_integer_

  compute_publication_year_bounds(
    observed_min = obs_min,
    observed_max = obs_max,
    buffer = buffer
  )
}

#' Refresh global PUBLICATION_YEAR_BOUNDS (call after DB pool is ready).
refresh_publication_year_bounds <- function(buffer = NULL) {
  bounds <- tryCatch(
    get_publication_year_bounds(buffer = buffer),
    error = function(e) {
      warning("Could not load publication year bounds from DB: ", e$message)
      compute_publication_year_bounds(
        observed_min = if (exists("MIN_YEAR")) MIN_YEAR else 1860L,
        observed_max = if (exists("MAX_YEAR")) MAX_YEAR else 1920L,
        buffer = buffer
      )
    }
  )
  assign("PUBLICATION_YEAR_BOUNDS", bounds, envir = .GlobalEnv)
  invisible(bounds)
}

#' Observed sales-year span from book_sales.year, plus filter buffer.
#'
#' @param buffer Years of headroom beyond observed min/max (default SALES_YEAR_BUFFER)
#' @return list from compute_sales_year_bounds()
get_sales_year_bounds <- function(buffer = NULL) {
  if (is.null(buffer)) {
    buffer <- if (exists("SALES_YEAR_BUFFER")) {
      as.integer(SALES_YEAR_BUFFER)
    } else {
      2L
    }
  }

  res <- tryCatch(
    safe_db_query(
      "SELECT MIN(year) AS min_year,
              MAX(year) AS max_year
       FROM book_sales
       WHERE year IS NOT NULL"
    ),
    error = function(e) data.frame(min_year = NA_integer_, max_year = NA_integer_)
  )

  obs_min <- if (!is.null(res) && nrow(res) > 0) res$min_year[1] else NA_integer_
  obs_max <- if (!is.null(res) && nrow(res) > 0) res$max_year[1] else NA_integer_

  compute_sales_year_bounds(
    observed_min = obs_min,
    observed_max = obs_max,
    buffer = buffer
  )
}

#' Refresh global SALES_YEAR_BOUNDS (call after DB pool is ready).
refresh_sales_year_bounds <- function(buffer = NULL) {
  bounds <- tryCatch(
    get_sales_year_bounds(buffer = buffer),
    error = function(e) {
      warning("Could not load sales year bounds from DB: ", e$message)
      compute_sales_year_bounds(
        observed_min = if (exists("MIN_YEAR")) MIN_YEAR else 1860L,
        observed_max = if (exists("MAX_YEAR")) MAX_YEAR else 1920L,
        buffer = buffer
      )
    }
  )
  assign("SALES_YEAR_BOUNDS", bounds, envir = .GlobalEnv)
  invisible(bounds)
}

#' Refresh both publication and sales year bound caches.
refresh_year_bounds <- function() {
  list(
    publication = refresh_publication_year_bounds(),
    sales = refresh_sales_year_bounds()
  )
}

# Get books with sales summary
get_books_summary <- function() {
  query <- "
    SELECT
      be.*,
      COALESCE(bs.total_sales, 0) as total_sales,
      COALESCE(bs.years_with_sales, 0) as years_with_sales,
      bs.first_sale_year,
      bs.last_sale_year
    FROM book_entries be
    LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
    ORDER BY be.publication_year DESC, be.author_surname
  "
  safe_db_query(query)
}

# Search books
# Search books.
# year_range / publication_year_range filters book_entries.publication_year
# (when the book was published), NOT sales years.
search_books <- function(search_term = "", genre_filter = NULL,
                        gender_filter = c("Male", "Female", "Unknown"),
                        publication_year_range = NULL,
                        year_range = NULL,
                        publisher_filter = NULL) {
  # Prefer explicit publication_year_range; year_range kept as legacy alias.
  # Default to full observed publication span (not sales-year constants).
  pub_default <- tryCatch(
    publication_default_range(),
    error = function(e) c(MIN_YEAR, MAX_YEAR)
  )
  pub_range <- resolve_year_range(
    publication_year_range %||% year_range,
    default = pub_default
  )

  where_conditions <- c("1=1")  # Base condition
  params <- list()
  param_counter <- 1

  # Add search term filter
  if (!is.null(search_term) && search_term != "") {
    where_conditions <- c(where_conditions,
                         paste0("(LOWER(be.book_title) LIKE LOWER($", param_counter, ") OR ",
                               "LOWER(be.author_surname) LIKE LOWER($", param_counter + 1, "))"))
    params <- c(params, paste0("%", search_term, "%"), paste0("%", search_term, "%"))
    param_counter <- param_counter + 2
  }

  # Optional multi filters: empty / blank / whitespace = no restriction (all)
  genre_appended <- append_optional_text_filter(
    genre_filter, "be.genre", where_conditions, params, param_counter,
    mode = "multi", match = "in"
  )
  where_conditions <- genre_appended$where_conditions
  params <- genre_appended$params
  param_counter <- genre_appended$next_param

  # Gender filter (multi-select: empty = no matches, not silent "all")
  gender_sel <- normalize_gender_filter(gender_filter, mode = "multi")
  if (gender_sel$apply) {
    gender_sql <- build_gender_sql_filter(
      gender_sel$genders,
      column = "be.gender",
      param_start = param_counter
    )
    if (!is.null(gender_sql$clause)) {
      where_conditions <- c(where_conditions, gender_sql$clause)
      params <- c(params, gender_sql$params)
      param_counter <- gender_sql$next_param
    }
  }

  # Publication-year filter (catalog metadata — not sales years)
  where_conditions <- c(where_conditions,
                       paste0("be.publication_year BETWEEN $", param_counter, " AND $", param_counter + 1))
  params <- c(params, pub_range$start, pub_range$end)
  param_counter <- param_counter + 2

  # Optional multi publisher filter: empty / blank / whitespace = all
  pub_appended <- append_optional_text_filter(
    publisher_filter, "be.publisher", where_conditions, params, param_counter,
    mode = "multi", match = "in"
  )
  where_conditions <- pub_appended$where_conditions
  params <- pub_appended$params
  param_counter <- pub_appended$next_param

  where_clause <- paste(where_conditions, collapse = " AND ")

  query <- paste0("
    SELECT
      be.book_id,
      be.author_surname,
      be.gender,
      be.book_title,
      be.genre,
      be.binding,
      be.publisher,
      be.publication_year,
      be.retail_price,
      be.royalty_rate,
      COALESCE(bs.total_sales, 0) as total_sales,
      COALESCE(bs.years_with_sales, 0) as years_with_sales
    FROM book_entries be
    LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
    WHERE ", where_clause, "
    ORDER BY be.publication_year DESC, be.author_surname, be.book_title
  ")

  safe_db_query(query, params = params)
}

# Get unique values for filters (updated for new schema)
# Period availability: years = publication span; sales_years = sales span.
# Prefer publication_* / sales_* helpers for UI limits; this list is for
# dropdown option population and lightweight diagnostics.
get_filter_options <- function() {
  list(
    genres = safe_db_query("SELECT DISTINCT genre FROM book_entries WHERE genre IS NOT NULL ORDER BY genre"),
    publishers = safe_db_query("SELECT DISTINCT publisher FROM book_entries WHERE publisher IS NOT NULL ORDER BY publisher"),
    # Include Unknown for NULL/blank stored genders so UI filters stay consistent
    genders = safe_db_query(paste0(
      "SELECT DISTINCT ", gender_display_sql("gender"), " AS gender ",
      "FROM book_entries ORDER BY gender"
    )),
    years = safe_db_query(
      "SELECT MIN(publication_year) as min_year, MAX(publication_year) as max_year
       FROM book_entries WHERE publication_year IS NOT NULL"
    ),
    sales_years = safe_db_query(
      "SELECT MIN(year) as min_year, MAX(year) as max_year
       FROM book_sales WHERE year IS NOT NULL"
    ),
    author_ids = safe_db_query("SELECT DISTINCT author_id FROM book_entries WHERE author_id IS NOT NULL ORDER BY author_id"),
    book_titles = safe_db_query("SELECT DISTINCT book_title FROM book_entries WHERE book_title IS NOT NULL ORDER BY book_title"),
    binding_states = safe_db_query("SELECT DISTINCT binding FROM book_entries WHERE binding IS NOT NULL ORDER BY binding")
  )
}

# Get unique book titles for dropdown
get_book_titles <- function() {
  safe_db_query("SELECT DISTINCT book_title FROM book_entries WHERE book_title IS NOT NULL ORDER BY book_title")
}


# Get unique book titles with their first publication year
get_book_titles_with_year <- function() {
  query <- "
    SELECT
      book_title,
      MIN(publication_year) AS first_publication_year
    FROM book_entries
    WHERE book_title IS NOT NULL
    GROUP BY book_title
    ORDER BY book_title
  "
  safe_db_query(query)
}

# Get unique author surnames for dropdown
get_author_surnames <- function() {
  safe_db_query("SELECT DISTINCT author_surname FROM book_entries WHERE author_surname IS NOT NULL ORDER BY author_surname")
}

#' Author surnames with book counts for selectize / dropdown labels.
#'
#' Single source of truth for author-name pickers (author analysis, royalty query).
#' book_count uses COUNT(DISTINCT book_id) so multi-row editions do not inflate totals.
#'
#' @param limit Max surnames to return (default 200)
#' @return data.frame(author_surname, book_count, total_sales)
get_author_surname_options <- function(limit = 200L) {
  limit <- as.integer(limit)[1]
  if (is.na(limit) || limit < 1L) {
    limit <- 200L
  }
  query <- "
    SELECT
      be.author_surname,
      COUNT(DISTINCT be.book_id) AS book_count,
      COALESCE(SUM(bs.total_sales), 0) AS total_sales
    FROM book_entries be
    LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
    WHERE be.author_surname IS NOT NULL
    GROUP BY be.author_surname
    HAVING COUNT(DISTINCT be.book_id) >= 1
    ORDER BY be.author_surname
    LIMIT $1
  "
  safe_db_query(query, params = list(limit))
}

#' Author IDs for a given surname (for optional Author ID pickers).
#'
#' book_count uses COUNT(DISTINCT book_id) consistently across analyses.
#'
#' @param surname Exact author_surname match
#' @return data.frame(author_id, author_surname, book_count)
get_author_ids_by_surname <- function(surname) {
  if (is.null(surname) || !nzchar(as.character(surname)[1])) {
    return(data.frame(
      author_id = character(0),
      author_surname = character(0),
      book_count = integer(0)
    ))
  }
  query <- "
    SELECT
      be.author_id,
      be.author_surname,
      COUNT(DISTINCT be.book_id) AS book_count
    FROM book_entries be
    WHERE be.author_surname = $1
      AND be.author_id IS NOT NULL
    GROUP BY be.author_id, be.author_surname
    ORDER BY book_count DESC, be.author_id
  "
  safe_db_query(query, params = list(as.character(surname)[1]))
}

#' Named choices for an author-surname selectize input.
#'
#' @param limit Max surnames
#' @return named character vector (labels → values), or character(0)
author_surname_select_choices <- function(limit = 200L) {
  df <- get_author_surname_options(limit = limit)
  if (is.null(df) || nrow(df) == 0) {
    return(character(0))
  }
  labels <- paste0(
    df$author_surname, " (", df$book_count,
    ifelse(df$book_count == 1, " book", " books"), ")"
  )
  stats::setNames(df$author_surname, labels)
}

#' Named choices for an author-id selectize given a surname.
#'
#' @param surname Exact author_surname
#' @return named character vector (labels → cleaned author_id), or character(0)
author_id_select_choices <- function(surname) {
  id_df <- get_author_ids_by_surname(surname)
  if (is.null(id_df) || nrow(id_df) == 0) {
    return(character(0))
  }
  labels <- paste0(
    format_author_label(id_df$author_id, id_df$author_surname),
    " (", id_df$book_count,
    ifelse(id_df$book_count == 1, " book)", " books)")
  )
  stats::setNames(clean_author_id(id_df$author_id), labels)
}

#' Author career overview books filtered by publication year.
#'
#' Publication-year filter (catalog metadata), not sales years.
#' Optional author_id exact match; otherwise surname substring match.
#'
#' @param author_surname Surname (or fragment) for LIKE match when author_id empty
#' @param author_id Optional exact author_id; empty/NULL → surname match only
#' @param publication_start_year Start of publication year range
#' @param publication_end_year End of publication year range
#' @return data.frame of books with lifetime sales summary columns
get_author_overview_books <- function(author_surname,
                                      author_id = NULL,
                                      publication_start_year = NULL,
                                      publication_end_year = NULL) {
  pub_default <- tryCatch(
    publication_default_range(),
    error = function(e) c(MIN_YEAR, MAX_YEAR)
  )
  pub_range <- resolve_year_range(
    c(
      publication_start_year %||% pub_default[[1]],
      publication_end_year %||% pub_default[[2]]
    ),
    default = pub_default
  )

  author_id_param <- if (is.null(author_id) || !nzchar(as.character(author_id)[1])) {
    ""
  } else {
    as.character(author_id)[1]
  }
  author_name_param <- if (is.null(author_surname) || !nzchar(as.character(author_surname)[1])) {
    ""
  } else {
    paste0("%", as.character(author_surname)[1], "%")
  }

  query <- "
    SELECT
      be.book_id,
      be.book_title,
      be.author_surname,
      be.genre,
      be.binding,
      be.publication_year,
      be.retail_price,
      be.royalty_rate,
      COALESCE(bs.total_sales, 0) as total_sales,
      COALESCE(bs.years_with_sales, 0) as years_with_sales,
      bs.first_sale_year,
      bs.last_sale_year
    FROM book_entries be
    LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
    WHERE (
      CASE WHEN $1 <> '' THEN be.author_id = $1 ELSE TRUE END
    ) AND (
      CASE WHEN $2 <> '' THEN LOWER(be.author_surname) LIKE LOWER($2) ELSE TRUE END
    )
      AND be.publication_year BETWEEN $3 AND $4
    ORDER BY be.publication_year, be.book_title
  "
  safe_db_query(query, params = list(
    author_id_param,
    author_name_param,
    pub_range$start,
    pub_range$end
  ))
}

# Get unique binding states for dropdown
get_binding_states <- function() {
  safe_db_query("SELECT DISTINCT binding FROM book_entries WHERE binding IS NOT NULL ORDER BY binding")
}

# Get author gender analysis (updated for new schema)
# Unknown = NULL/blank gender in DB; always included for consistent reporting
get_gender_analysis <- function() {
  gender_expr <- gender_display_sql("be.gender")
  query <- paste0("
    SELECT
      ", gender_expr, " AS gender,
      COUNT(*) as book_count,
      COALESCE(SUM(bs.total_sales), 0) as total_sales,
      COALESCE(AVG(bs.total_sales), 0) as avg_sales_per_book,
      COUNT(DISTINCT be.author_surname) as unique_authors,
      COUNT(DISTINCT be.author_id) as unique_author_ids
    FROM book_entries be
    LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
    GROUP BY ", gender_expr, "
    ORDER BY gender
  ")
  safe_db_query(query)
}

# Get author analysis using new author_id field
get_author_analysis <- function() {
  query <- "
    SELECT
      be.author_id,
      be.author_surname,
      be.gender,
      COUNT(*) as book_count,
      MIN(be.publication_year) as first_publication,
      MAX(be.publication_year) as last_publication,
      COALESCE(SUM(bs.total_sales), 0) as total_sales,
      COALESCE(AVG(bs.total_sales), 0) as avg_sales_per_book,
      COALESCE(AVG(be.retail_price), 0) as avg_retail_price,
      COALESCE(AVG(be.royalty_rate), 0) as avg_royalty_rate
    FROM book_entries be
    LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
    WHERE be.author_id IS NOT NULL
    GROUP BY be.author_id, be.author_surname, be.gender
    HAVING COUNT(*) >= 2  -- Authors with multiple books
    ORDER BY total_sales DESC
  "
  safe_db_query(query)
}

# Get books by specific author using author_id
get_books_by_author <- function(author_id) {
  query <- "
    SELECT
      be.book_id,
      be.book_title,
      be.genre,
      be.binding,
      be.publisher,
      be.publication_year,
      be.retail_price,
      be.royalty_rate,
      COALESCE(bs.total_sales, 0) as total_sales,
      COALESCE(bs.years_with_sales, 0) as years_with_sales,
      bs.first_sale_year,
      bs.last_sale_year
    FROM book_entries be
    LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
    WHERE be.author_id = $1
    ORDER BY be.publication_year
  "
  safe_db_query(query, params = list(author_id))
}

# Get comprehensive book details with royalty tiers
get_book_details <- function(book_id) {
  # Get basic book info
  book_query <- "
    SELECT
      be.*,
      COALESCE(bs.total_sales, 0) as total_sales,
      COALESCE(bs.years_with_sales, 0) as years_with_sales,
      bs.first_sale_year,
      bs.last_sale_year
    FROM book_entries be
    LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
    WHERE be.book_id = $1
  "

  # Get royalty tiers
  royalty_query <- "
    SELECT
      tier,
      rate,
      lower_limit,
      upper_limit,
      sliding_scale
    FROM royalty_tiers
    WHERE book_id = $1
    ORDER BY tier
  "

  # Get sales time series
  sales_query <- "
    SELECT
      year,
      sales_count
    FROM book_sales
    WHERE book_id = $1
      AND sales_count IS NOT NULL
    ORDER BY year
  "

  list(
    book_info = safe_db_query(book_query, params = list(book_id)),
    royalty_tiers = safe_db_query(royalty_query, params = list(book_id)),
    sales_timeseries = safe_db_query(sales_query, params = list(book_id))
  )
}
