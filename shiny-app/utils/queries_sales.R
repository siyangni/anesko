# Sales Analysis Database Query Functions
# Functions for sales performance analysis, publisher data, and top books

# Get sales data by sales year and genre.
# year_start/year_end (and sales_*) filter book_sales.year, not publication year.
get_sales_by_year_genre <- function(sales_start_year = NULL, sales_end_year = NULL,
                                    year_start = NULL, year_end = NULL) {
  sales_range <- resolve_year_range(
    c(
      sales_start_year %||% year_start %||% MIN_YEAR,
      sales_end_year %||% year_end %||% MAX_YEAR
    ),
    default = c(MIN_YEAR, MAX_YEAR)
  )
  query <- "
    SELECT
      bs.year AS sales_year,
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
  safe_db_query(query, params = list(sales_range$start, sales_range$end))
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

# Get top selling books filtered by publication year (catalog metadata).
get_top_books <- function(limit = 20,
                          publication_start_year = NULL,
                          publication_end_year = NULL,
                          min_year = NULL,
                          max_year = NULL) {
  # Default to full observed publication span (catalog), not a narrow sales window
  pub_default <- tryCatch(
    publication_default_range(),
    error = function(e) c(MIN_YEAR, MAX_YEAR)
  )
  pub_range <- resolve_year_range(
    c(
      publication_start_year %||% min_year %||% pub_default[[1]],
      publication_end_year %||% max_year %||% pub_default[[2]]
    ),
    default = pub_default
  )
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
  safe_db_query(query, params = list(pub_range$start, pub_range$end, limit))
}

# Shared WHERE for title + optional binding sales queries.
# Year bounds are sales years (book_sales.year), never publication years.
# Empty / blank binding_state means all bindings (optional filter semantics).
.build_title_binding_sales_where <- function(book_title,
                                             binding_state = NULL,
                                             sales_start_year = NULL,
                                             sales_end_year = NULL,
                                             start_year = NULL,
                                             end_year = NULL) {
  sales_range <- resolve_year_range(
    c(
      sales_start_year %||% start_year %||% MIN_YEAR,
      sales_end_year %||% end_year %||% MAX_YEAR
    ),
    default = c(MIN_YEAR, MAX_YEAR)
  )
  where_conditions <- c(
    "LOWER(be.book_title) LIKE LOWER($1)",
    "bs.year BETWEEN $2 AND $3",
    "bs.sales_count IS NOT NULL"
  )
  params <- list(
    paste0("%", book_title %||% "", "%"),
    sales_range$start,
    sales_range$end
  )
  next_param <- 4L

  binding_appended <- append_optional_text_filter(
    binding_state, "be.binding", where_conditions, params, next_param,
    mode = "single", match = "like"
  )

  list(
    where_clause = paste(binding_appended$where_conditions, collapse = " AND "),
    params = binding_appended$params,
    next_param = binding_appended$next_param,
    sales_range = sales_range
  )
}

# Get sales of binding state edition of book title within sales years.
# Empty / blank binding_state means all bindings (optional filter).
# sales_start_year / sales_end_year filter book_sales.year (not publication year).
# start_year / end_year are legacy aliases for sales years.
get_book_sales_by_title_binding <- function(book_title,
                                            binding_state = NULL,
                                            sales_start_year = NULL,
                                            sales_end_year = NULL,
                                            start_year = NULL,
                                            end_year = NULL) {
  built <- .build_title_binding_sales_where(
    book_title, binding_state,
    sales_start_year = sales_start_year,
    sales_end_year = sales_end_year,
    start_year = start_year,
    end_year = end_year
  )

  query <- paste0("
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
    WHERE ", built$where_clause, "
    GROUP BY be.book_id, be.book_title, be.author_surname, be.binding
    ORDER BY total_sales DESC
  ")
  safe_db_query(query, params = built$params)
}

# Shared WHERE builder for genre / binding / gender analysis queries.
# Year bounds are sales years (book_sales.year), never publication years.
.build_genre_binding_gender_where <- function(binding_state = NULL,
                                             genre = NULL,
                                             gender = NULL,
                                             sales_start_year = NULL,
                                             sales_end_year = NULL,
                                             start_year = NULL,
                                             end_year = NULL) {
  sales_range <- resolve_year_range(
    c(
      sales_start_year %||% start_year %||% MIN_YEAR,
      sales_end_year %||% end_year %||% MAX_YEAR
    ),
    default = c(MIN_YEAR, MAX_YEAR)
  )
  where_conditions <- c("bs.year BETWEEN $1 AND $2", "bs.sales_count IS NOT NULL")
  params <- list(sales_range$start, sales_range$end)
  next_param <- 3L

  # Optional single-select: "" / NULL / whitespace = all
  binding_appended <- append_optional_text_filter(
    binding_state, "be.binding", where_conditions, params, next_param,
    mode = "single", match = "like"
  )
  where_conditions <- binding_appended$where_conditions
  params <- binding_appended$params
  next_param <- binding_appended$next_param

  genre_appended <- append_optional_text_filter(
    genre, "be.genre", where_conditions, params, next_param,
    mode = "single", match = "like"
  )
  where_conditions <- genre_appended$where_conditions
  params <- genre_appended$params
  next_param <- genre_appended$next_param

  gender_sel <- normalize_gender_filter(gender, mode = "single")
  if (gender_sel$apply) {
    gender_sql <- build_gender_sql_filter(
      gender_sel$genders,
      column = "be.gender",
      param_start = next_param
    )
    if (!is.null(gender_sql$clause)) {
      where_conditions <- c(where_conditions, gender_sql$clause)
      params <- c(params, gender_sql$params)
      next_param <- gender_sql$next_param
    }
  }

  list(
    where_clause = paste(where_conditions, collapse = " AND "),
    params = params,
    next_param = next_param
  )
}

# Get average sales by binding/genre/gender within sales-year range
get_average_sales_by_binding_genre_gender <- function(binding_state = NULL,
                                                     genre = NULL,
                                                     gender = NULL,
                                                     start_year = NULL,
                                                     end_year = NULL,
                                                     sales_start_year = NULL,
                                                     sales_end_year = NULL) {
  built <- .build_genre_binding_gender_where(
    binding_state, genre, gender,
    sales_start_year = sales_start_year %||% start_year,
    sales_end_year = sales_end_year %||% end_year
  )
  gender_expr <- gender_display_sql("be.gender")

  query <- paste0("
    SELECT
      be.binding,
      be.genre,
      ", gender_expr, " AS gender,
      COUNT(DISTINCT be.book_id) as book_count,
      AVG(bs.sales_count) as avg_sales_per_year,
      SUM(bs.sales_count) / COUNT(DISTINCT be.book_id) as avg_total_sales_per_book
    FROM book_entries be
    JOIN book_sales bs ON be.book_id = bs.book_id
    WHERE ", built$where_clause, "
    GROUP BY be.binding, be.genre, ", gender_expr, "
    ORDER BY avg_total_sales_per_book DESC
  ")

  safe_db_query(query, params = built$params)
}

# Get total sales by binding/genre/gender within sales-year range
get_total_sales_by_binding_genre_gender <- function(binding_state = NULL,
                                                   genre = NULL,
                                                   gender = NULL,
                                                   start_year = NULL,
                                                   end_year = NULL,
                                                   sales_start_year = NULL,
                                                   sales_end_year = NULL) {
  built <- .build_genre_binding_gender_where(
    binding_state, genre, gender,
    sales_start_year = sales_start_year %||% start_year,
    sales_end_year = sales_end_year %||% end_year
  )
  gender_expr <- gender_display_sql("be.gender")

  query <- paste0("
    SELECT
      be.binding,
      be.genre,
      ", gender_expr, " AS gender,
      COUNT(DISTINCT be.book_id) as book_count,
      SUM(bs.sales_count) as total_sales
    FROM book_entries be
    JOIN book_sales bs ON be.book_id = bs.book_id
    WHERE ", built$where_clause, "
    GROUP BY be.binding, be.genre, ", gender_expr, "
    ORDER BY total_sales DESC
  ")

  safe_db_query(query, params = built$params)
}

# Get per-book total sales for a genre/binding within sales-year range
get_total_sales_per_book_by_genre_binding <- function(binding_state = NULL,
                                                     genre = NULL,
                                                     start_year = NULL,
                                                     end_year = NULL,
                                                     sales_start_year = NULL,
                                                     sales_end_year = NULL) {
  built <- .build_genre_binding_gender_where(
    binding_state, genre, gender = NULL,
    sales_start_year = sales_start_year %||% start_year,
    sales_end_year = sales_end_year %||% end_year
  )

  query <- paste0("
    SELECT
      be.book_id,
      be.book_title,
      SUM(bs.sales_count) AS total_sales
    FROM book_entries be
    JOIN book_sales bs ON be.book_id = bs.book_id
    WHERE ", built$where_clause, "
    GROUP BY be.book_id, be.book_title
    ORDER BY total_sales DESC
  ")

  safe_db_query(query, params = built$params)
}

# Get average sales by book title and binding within sales-year range.
# Empty / blank binding_state means all bindings.
get_average_sales_by_book_binding <- function(book_title,
                                              binding_state = NULL,
                                              sales_start_year = NULL,
                                              sales_end_year = NULL,
                                              start_year = NULL,
                                              end_year = NULL) {
  built <- .build_title_binding_sales_where(
    book_title, binding_state,
    sales_start_year = sales_start_year,
    sales_end_year = sales_end_year,
    start_year = start_year,
    end_year = end_year
  )

  query <- paste0("
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
    WHERE ", built$where_clause, "
    GROUP BY be.book_id, be.book_title, be.author_surname, be.binding
    ORDER BY avg_sales_per_year DESC
  ")
  safe_db_query(query, params = built$params)
}
