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
search_books <- function(search_term = "", genre_filter = NULL, gender_filter = NULL,
                        year_range = c(1860, 1920), publisher_filter = NULL) {

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

  # Add genre filter
  if (!is.null(genre_filter) && length(genre_filter) > 0) {
    genre_placeholders <- paste0("$", param_counter:(param_counter + length(genre_filter) - 1), collapse = ",")
    where_conditions <- c(where_conditions, paste0("be.genre IN (", genre_placeholders, ")"))
    params <- c(params, as.list(genre_filter))
    param_counter <- param_counter + length(genre_filter)
  }

  # Add gender filter
  if (!is.null(gender_filter) && length(gender_filter) > 0) {
    gender_placeholders <- paste0("$", param_counter:(param_counter + length(gender_filter) - 1), collapse = ",")
    where_conditions <- c(where_conditions, paste0("be.gender IN (", gender_placeholders, ")"))
    params <- c(params, as.list(gender_filter))
    param_counter <- param_counter + length(gender_filter)
  }

  # Add year range filter
  where_conditions <- c(where_conditions,
                       paste0("be.publication_year BETWEEN $", param_counter, " AND $", param_counter + 1))
  params <- c(params, year_range[1], year_range[2])
  param_counter <- param_counter + 2

  # Add publisher filter
  if (!is.null(publisher_filter) && length(publisher_filter) > 0) {
    pub_placeholders <- paste0("$", param_counter:(param_counter + length(publisher_filter) - 1), collapse = ",")
    where_conditions <- c(where_conditions, paste0("be.publisher IN (", pub_placeholders, ")"))
    params <- c(params, as.list(publisher_filter))
  }

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
get_filter_options <- function() {
  list(
    genres = safe_db_query("SELECT DISTINCT genre FROM book_entries WHERE genre IS NOT NULL ORDER BY genre"),
    publishers = safe_db_query("SELECT DISTINCT publisher FROM book_entries WHERE publisher IS NOT NULL ORDER BY publisher"),
    genders = safe_db_query("SELECT DISTINCT gender FROM book_entries WHERE gender IS NOT NULL ORDER BY gender"),
    years = safe_db_query("SELECT MIN(publication_year) as min_year, MAX(publication_year) as max_year FROM book_entries"),
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

# Get unique binding states for dropdown
get_binding_states <- function() {
  safe_db_query("SELECT DISTINCT binding FROM book_entries WHERE binding IS NOT NULL ORDER BY binding")
}

# Get author gender analysis (updated for new schema)
get_gender_analysis <- function() {
  query <- "
    SELECT
      be.gender,
      COUNT(*) as book_count,
      COALESCE(SUM(bs.total_sales), 0) as total_sales,
      COALESCE(AVG(bs.total_sales), 0) as avg_sales_per_book,
      COUNT(DISTINCT be.author_surname) as unique_authors,
      COUNT(DISTINCT be.author_id) as unique_author_ids
    FROM book_entries be
    LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
    WHERE be.gender IN ('Male', 'Female')
    GROUP BY be.gender
  "
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
