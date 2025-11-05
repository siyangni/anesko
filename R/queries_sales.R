# Sales Analysis Database Query Functions
# Functions for sales performance analysis, publisher data, and top books

# Get sales data by year and genre
get_sales_by_year_genre <- function(year_start = 1860, year_end = 1920) {
  query <- "
    SELECT
      bs.year,
      be.genre,
      SUM(bs.sales_count) as total_sales,
      COUNT(DISTINCT be.book_id) as unique_books,
      AVG(bs.sales_count) as avg_sales_per_book
    FROM book_sales bs
    JOIN book_entries be ON bs.book_id = be.book_id
    WHERE bs.year BETWEEN $1 AND $2
      AND bs.sales_count IS NOT NULL
      AND be.genre IS NOT NULL
    GROUP BY bs.year, be.genre
    ORDER BY bs.year, be.genre
  "
  safe_db_query(query, params = list(year_start, year_end))
}

# Get publisher performance
get_publisher_performance <- function(min_books = 5) {
  query <- "
    SELECT
      be.publisher,
      COUNT(*) as book_count,
      COALESCE(SUM(bs.total_sales), 0) as total_sales,
      COALESCE(AVG(bs.total_sales), 0) as avg_sales_per_book,
      MIN(be.publication_year) as first_publication,
      MAX(be.publication_year) as last_publication
    FROM book_entries be
    LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
    WHERE be.publisher IS NOT NULL
    GROUP BY be.publisher
    HAVING COUNT(*) >= $1
    ORDER BY total_sales DESC
  "
  safe_db_query(query, params = list(min_books))
}

# Get top selling books
get_top_books <- function(limit = 20, min_year = MIN_YEAR, max_year = MAX_YEAR) {
  query <- "
    SELECT
      be.book_id,
      be.author_surname,
      be.book_title,
      be.genre,
      be.publisher,
      be.publication_year,
      be.retail_price,
      bs.total_sales,
      bs.years_with_sales,
      bs.first_sale_year,
      bs.last_sale_year
    FROM book_entries be
    JOIN book_sales_summary bs ON be.book_id = bs.book_id
    WHERE be.publication_year BETWEEN $1 AND $2
      AND bs.total_sales > 0
    ORDER BY bs.total_sales DESC
    LIMIT $3
  "
  safe_db_query(query, params = list(min_year, max_year, limit))
}

# Get sales of binding state edition of book title in date range
get_book_sales_by_title_binding <- function(book_title, binding_state, start_year, end_year) {
  query <- "
    SELECT
      be.book_id,
      be.book_title,
      be.author_surname,
      be.binding,
      SUM(bs.sales_count) as total_sales,
      COUNT(bs.year) as years_with_sales,
      MIN(bs.year) as first_sale_year,
      MAX(bs.year) as last_sale_year
    FROM book_entries be
    JOIN book_sales bs ON be.book_id = bs.book_id
    WHERE LOWER(be.book_title) LIKE LOWER($1)
      AND LOWER(be.binding) LIKE LOWER($2)
      AND bs.year BETWEEN $3 AND $4
      AND bs.sales_count IS NOT NULL
    GROUP BY be.book_id, be.book_title, be.author_surname, be.binding
    ORDER BY total_sales DESC
  "
  safe_db_query(query, params = list(
    paste0("%", book_title, "%"),
    paste0("%", binding_state, "%"),
    start_year,
    end_year
  ))
}

# Get average sales by binding state/genre and gender in date range
get_average_sales_by_binding_genre_gender <- function(binding_state = NULL, genre = NULL, gender = NULL, start_year, end_year) {
  where_conditions <- c("bs.year BETWEEN $1 AND $2", "bs.sales_count IS NOT NULL")
  params <- list(start_year, end_year)
  param_count <- 2

  if (!is.null(binding_state) && binding_state != "") {
    param_count <- param_count + 1
    where_conditions <- c(where_conditions, paste0("LOWER(be.binding) LIKE LOWER($", param_count, ")"))
    params <- c(params, list(paste0("%", binding_state, "%")))
  }

  if (!is.null(genre) && genre != "") {
    param_count <- param_count + 1
    where_conditions <- c(where_conditions, paste0("LOWER(be.genre) LIKE LOWER($", param_count, ")"))
    params <- c(params, list(paste0("%", genre, "%")))
  }

  if (!is.null(gender) && gender != "") {
    param_count <- param_count + 1
    where_conditions <- c(where_conditions, paste0("be.gender = $", param_count))
    params <- c(params, list(gender))
  }

  where_clause <- paste(where_conditions, collapse = " AND ")

  query <- paste0("
    SELECT
      be.binding,
      be.genre,
      be.gender,
      COUNT(DISTINCT be.book_id) as book_count,
      AVG(bs.sales_count) as avg_sales_per_year,
      SUM(bs.sales_count) / COUNT(DISTINCT be.book_id) as avg_total_sales_per_book
    FROM book_entries be
    JOIN book_sales bs ON be.book_id = bs.book_id
    WHERE ", where_clause, "
    GROUP BY be.binding, be.genre, be.gender
    ORDER BY avg_total_sales_per_book DESC
  ")

  safe_db_query(query, params = params)
}

# Get total sales by binding state/genre and gender in date range
get_total_sales_by_binding_genre_gender <- function(binding_state = NULL, genre = NULL, gender = NULL, start_year, end_year) {
  where_conditions <- c("bs.year BETWEEN $1 AND $2", "bs.sales_count IS NOT NULL")
  params <- list(start_year, end_year)
  param_count <- 2

  if (!is.null(binding_state) && binding_state != "") {
    param_count <- param_count + 1
    where_conditions <- c(where_conditions, paste0("LOWER(be.binding) LIKE LOWER($", param_count, ")"))
    params <- c(params, list(paste0("%", binding_state, "%")))
  }

  if (!is.null(genre) && genre != "") {
    param_count <- param_count + 1
    where_conditions <- c(where_conditions, paste0("LOWER(be.genre) LIKE LOWER($", param_count, ")"))
    params <- c(params, list(paste0("%", genre, "%")))
  }

  if (!is.null(gender) && gender != "") {
    param_count <- param_count + 1
    where_conditions <- c(where_conditions, paste0("be.gender = $", param_count))
    params <- c(params, list(gender))
  }

  where_clause <- paste(where_conditions, collapse = " AND ")

  query <- paste0("
    SELECT
      be.binding,
      be.genre,
      be.gender,
      COUNT(DISTINCT be.book_id) as book_count,
      SUM(bs.sales_count) as total_sales
    FROM book_entries be
    JOIN book_sales bs ON be.book_id = bs.book_id
    WHERE ", where_clause, "
    GROUP BY be.binding, be.genre, be.gender
    ORDER BY total_sales DESC
  ")

  safe_db_query(query, params = params)
}

# Get per-book total sales for a given genre/binding in a date range (for significance tests)
get_total_sales_per_book_by_genre_binding <- function(binding_state = NULL, genre = NULL, start_year, end_year) {
  where_conditions <- c("bs.year BETWEEN $1 AND $2", "bs.sales_count IS NOT NULL")
  params <- list(start_year, end_year)
  param_count <- 2

  if (!is.null(binding_state) && binding_state != "") {
    param_count <- param_count + 1
    where_conditions <- c(where_conditions, paste0("LOWER(be.binding) LIKE LOWER($", param_count, ")"))
    params <- c(params, list(paste0("%", binding_state, "%")))
  }

  if (!is.null(genre) && genre != "") {
    param_count <- param_count + 1
    where_conditions <- c(where_conditions, paste0("LOWER(be.genre) LIKE LOWER($", param_count, ")"))
    params <- c(params, list(paste0("%", genre, "%")))
  }

  where_clause <- paste(where_conditions, collapse = " AND ")

  query <- paste0("
    SELECT
      be.book_id,
      be.book_title,
      SUM(bs.sales_count) AS total_sales
    FROM book_entries be
    JOIN book_sales bs ON be.book_id = bs.book_id
    WHERE ", where_clause, "
    GROUP BY be.book_id, be.book_title
    ORDER BY total_sales DESC
  ")

  safe_db_query(query, params = params)
}

# Get average sales by book title and binding state in date range
get_average_sales_by_book_binding <- function(book_title, binding_state, start_year, end_year) {
  query <- "
    SELECT
      be.book_id,
      be.book_title,
      be.author_surname,
      be.binding,
      AVG(bs.sales_count) as avg_sales_per_year,
      COUNT(bs.year) as years_with_sales,
      SUM(bs.sales_count) as total_sales,
      MIN(bs.year) as first_sale_year,
      MAX(bs.year) as last_sale_year
    FROM book_entries be
    JOIN book_sales bs ON be.book_id = bs.book_id
    WHERE LOWER(be.book_title) LIKE LOWER($1)
      AND LOWER(be.binding) LIKE LOWER($2)
      AND bs.year BETWEEN $3 AND $4
      AND bs.sales_count IS NOT NULL
    GROUP BY be.book_id, be.book_title, be.author_surname, be.binding
    ORDER BY avg_sales_per_year DESC
  "
  safe_db_query(query, params = list(
    paste0("%", book_title, "%"),
    paste0("%", binding_state, "%"),
    start_year,
    end_year
  ))
}
