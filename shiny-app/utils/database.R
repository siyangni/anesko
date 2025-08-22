# Database Utility Functions
# Functions for database connection management and common queries

# Create database connection pool
create_db_pool <- function() {
  tryCatch({
    cat("🔧 Creating database connection pool...\n")
    cat("   Host:", db_config$host, "\n")
    cat("   Database:", db_config$dbname, "\n")
    cat("   User:", db_config$user, "\n")

    # Use RPostgreSQL for reliability (works on shinyapps.io)
    pool <- pool::dbPool(
      drv = RPostgreSQL::PostgreSQL(),
      host = db_config$host,
      dbname = db_config$dbname,
      user = db_config$user,
      password = db_config$password,
      port = if(is.null(db_config$port)) 5432 else db_config$port,
      minSize = POOL_SIZE_MIN,
      maxSize = POOL_SIZE_MAX,
      idleTimeout = POOL_IDLE_TIMEOUT * 1000
    )

    cat("✅ Database connection pool created successfully\n")
    return(pool)

  }, error = function(e) {
    cat("💥 Database pool creation failed:", e$message, "\n")
    stop("Failed to create database connection pool: ", e$message)
  })
}

# Safe database query with error handling (simplified for reliability)
safe_db_query <- function(query, params = NULL) {
  tryCatch({
    # Use direct connection instead of pool for reliability
    if (exists("db_config") && !is.null(db_config)) {
      con <- DBI::dbConnect(
        RPostgreSQL::PostgreSQL(),
        host = db_config$host,
        dbname = db_config$dbname,
        user = db_config$user,
        password = db_config$password,
        port = if(is.null(db_config$port)) 5432 else db_config$port
      )

      result <- if (is.null(params)) {
        DBI::dbGetQuery(con, query)
      } else {
        DBI::dbGetQuery(con, query, params = params)
      }

      DBI::dbDisconnect(con)
      return(result)
    } else {
      warning("Database configuration not available")
      return(data.frame())
    }
  }, error = function(e) {
    warning("Database query failed: ", e$message)
    return(data.frame())
  })
}


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

# Get time series data for specific books
get_book_sales_timeseries <- function(book_ids) {
  if (length(book_ids) == 0) return(data.frame())

  # Create placeholder string for IN clause
  placeholders <- paste0("$", 1:length(book_ids), collapse = ",")

  query <- paste0("
    SELECT
      bs.book_id,
      be.author_surname,
      be.book_title,
      bs.year,
      bs.sales_count
    FROM book_sales bs
    JOIN book_entries be ON bs.book_id = be.book_id
    WHERE bs.book_id IN (", placeholders, ")
      AND bs.sales_count IS NOT NULL
    ORDER BY bs.book_id, bs.year
  ")

  safe_db_query(query, params = as.list(book_ids))
}

# Get decade summary
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


# Get unique author surnames for dropdown
get_author_surnames <- function() {
  safe_db_query("SELECT DISTINCT author_surname FROM book_entries WHERE author_surname IS NOT NULL ORDER BY author_surname")
}

# Get unique binding states for dropdown
get_binding_states <- function() {
  safe_db_query("SELECT DISTINCT binding FROM book_entries WHERE binding IS NOT NULL ORDER BY binding")
}

# NEW FUNCTIONS FOR ENHANCED DATABASE FEATURES

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

# Get royalty tier analysis
get_royalty_analysis <- function() {
  query <- "
    SELECT
      rt.tier,
      COUNT(*) as tier_count,
      AVG(rt.rate) as avg_rate,
      MIN(rt.rate) as min_rate,
      MAX(rt.rate) as max_rate,
      COUNT(DISTINCT rt.book_id) as unique_books,
      AVG(rt.lower_limit) as avg_lower_limit,
      AVG(rt.upper_limit) as avg_upper_limit
    FROM royalty_tiers rt
    GROUP BY rt.tier
    ORDER BY rt.tier
  "
  safe_db_query(query)
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

# =============================================================================
# NEW ANALYTICS FUNCTIONS FOR SALES ANALYSIS MODULE
# =============================================================================

# Function 1: Get sales of binding state edition of book title in date range
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
  # Map grouping to SQL expressions
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

  # Gender filter (explicit list overrides include_unknown_gender)
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

  # Helper to add IN filters
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

  # Apply optional filters
  add_in_filter("be.author_surname", authors, case_insensitive = TRUE)
  add_in_filter("be.publisher", publishers, case_insensitive = TRUE)
  add_in_filter("be.genre", genres, case_insensitive = TRUE)
  add_in_filter("be.binding", bindings, case_insensitive = TRUE)
  # Books filter by ID (case-sensitive assumed)
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
# dimension: one of 'book','author','publisher','genre','binding','gender'
# values: character vector of item values (book uses book_id)
# Returns: year, group_label, total_sales, book_count
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

  # Map dimension to field and values field
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

  # Explicit gender selection or include/exclude unknown
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

  # Base filters (excluding the dimension being compared; caller should pass empty for that dim if needed)
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

  # Now add the comparison values for the selected dimension
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

# Function 2: Get average sales by binding state/genre and gender in date range
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

# Function 3: Get total sales by binding state/genre and gender in date range
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

# Function 3a: Get per-book total sales for a given genre/binding in a date range (for significance tests)
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

  query <- paste0(
    "\n    SELECT\n      be.book_id,\n      be.book_title,\n      SUM(bs.sales_count) AS total_sales\n    FROM book_entries be\n    JOIN book_sales bs ON be.book_id = bs.book_id\n    WHERE ", where_clause, "\n    GROUP BY be.book_id, be.book_title\n    ORDER BY total_sales DESC\n  ")

  safe_db_query(query, params = params)
}


# Helper function to calculate royalty income for a book based on sales and royalty structure
calculate_royalty_income <- function(book_id, total_sales, retail_price, royalty_rate, royalty_tiers = NULL) {
  if (is.na(total_sales) || total_sales <= 0 || is.na(retail_price) || retail_price <= 0) {
    return(0)
  }

  # If no complex royalty tiers, use simple calculation
  if (is.null(royalty_tiers) || nrow(royalty_tiers) == 0) {
    if (is.na(royalty_rate) || royalty_rate <= 0) {
      return(0)
    }
    return(total_sales * retail_price * royalty_rate)
  }

  # Complex royalty calculation with tiers
  total_income <- 0
  remaining_sales <- total_sales

  for (i in 1:nrow(royalty_tiers)) {
    tier <- royalty_tiers[i, ]
    tier_lower <- tier$lower_limit
    tier_upper <- if (is.na(tier$upper_limit)) Inf else tier$upper_limit
    tier_rate <- tier$rate

    if (remaining_sales <= 0) break

    # Calculate sales in this tier
    tier_sales <- min(remaining_sales, tier_upper - tier_lower + 1)
    if (tier_sales > 0) {
      tier_income <- tier_sales * retail_price * tier_rate
      total_income <- total_income + tier_income
      remaining_sales <- remaining_sales - tier_sales
    }
  }

  return(total_income)
}

# Function 4: Get royalty income from sale of binding state/book title in date range
get_royalty_income_by_book_binding <- function(book_title, binding_state, start_year, end_year) {
  # First get the sales data
  sales_data <- get_book_sales_by_title_binding(book_title, binding_state, start_year, end_year)

  if (nrow(sales_data) == 0) {
    return(data.frame())
  }

  # Get book details with royalty information
  result <- data.frame()

  for (i in 1:nrow(sales_data)) {
    book_id <- sales_data$book_id[i]
    total_sales <- sales_data$total_sales[i]

    # Get book details
    book_details <- get_book_details(book_id)
    book_info <- book_details$book_info
    royalty_tiers <- book_details$royalty_tiers

    if (nrow(book_info) > 0) {
      retail_price <- book_info$retail_price[1]
      royalty_rate <- book_info$royalty_rate[1]

      # Calculate royalty income
      royalty_income <- calculate_royalty_income(
        book_id, total_sales, retail_price, royalty_rate, royalty_tiers
      )

      # Add to result
      result <- rbind(result, data.frame(
        book_id = book_id,
        book_title = sales_data$book_title[i],
        author_surname = sales_data$author_surname[i],
        binding = sales_data$binding[i],
        total_sales = total_sales,
        retail_price = retail_price,
        royalty_income = royalty_income,
        stringsAsFactors = FALSE
      ))
    }
  }

  return(result)
}

# Function 5: Get total royalty income from author's books in date range
get_total_royalty_income_by_author <- function(author_surname, start_year, end_year, author_id = NULL) {
  # Build query dynamically to optionally filter by author_id when provided
  if (!is.null(author_id) && nzchar(author_id)) {
    query <- "
      SELECT
        be.book_id,
        be.book_title,
        be.author_surname,
        be.author_id,
        be.retail_price,
        be.royalty_rate,
        SUM(bs.sales_count) as total_sales
      FROM book_entries be
      JOIN book_sales bs ON be.book_id = bs.book_id
      WHERE be.author_id = $1
        AND bs.year BETWEEN $2 AND $3
        AND bs.sales_count IS NOT NULL
      GROUP BY be.book_id, be.book_title, be.author_surname, be.author_id, be.retail_price, be.royalty_rate
      ORDER BY be.book_title
    "
    books_data <- safe_db_query(query, params = list(author_id, start_year, end_year))
  } else {
    query <- "
      SELECT
        be.book_id,
        be.book_title,
        be.author_surname,
        be.author_id,
        be.retail_price,
        be.royalty_rate,
        SUM(bs.sales_count) as total_sales
      FROM book_entries be
      JOIN book_sales bs ON be.book_id = bs.book_id
      WHERE LOWER(be.author_surname) LIKE LOWER($1)
        AND bs.year BETWEEN $2 AND $3
        AND bs.sales_count IS NOT NULL
      GROUP BY be.book_id, be.book_title, be.author_surname, be.author_id, be.retail_price, be.royalty_rate
      ORDER BY be.book_title
    "
    books_data <- safe_db_query(query, params = list(
      paste0("%", author_surname, "%"), start_year, end_year
    ))
  }

  if (nrow(books_data) == 0) {
    return(data.frame())
  }

  # Calculate royalty income for each book
  result <- data.frame()
  total_royalty_income <- 0

  for (i in 1:nrow(books_data)) {
    book_id <- books_data$book_id[i]
    total_sales <- books_data$total_sales[i]
    retail_price <- books_data$retail_price[i]
    royalty_rate <- books_data$royalty_rate[i]

    # Get royalty tiers for this book
    book_details <- get_book_details(book_id)
    royalty_tiers <- book_details$royalty_tiers

    # Calculate royalty income
    royalty_income <- calculate_royalty_income(
      book_id, total_sales, retail_price, royalty_rate, royalty_tiers
    )

    total_royalty_income <- total_royalty_income + royalty_income

    # Add to result
    result <- rbind(result, data.frame(
      book_id = book_id,
      book_title = books_data$book_title[i],
      author_surname = books_data$author_surname[i],
      total_sales = total_sales,
      retail_price = retail_price,
      royalty_income = royalty_income,
      stringsAsFactors = FALSE
    ))
  }

  # Add summary row
  if (nrow(result) > 0) {
    result <- rbind(result, data.frame(
      book_id = "TOTAL",
      book_title = paste("TOTAL FOR", author_surname),
      author_surname = author_surname,
      total_sales = sum(result$total_sales, na.rm = TRUE),
      retail_price = NA,
      royalty_income = total_royalty_income,
      stringsAsFactors = FALSE
    ))
  }

  return(result)
}

# Function 6: Get average sales by book title and binding state in date range
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