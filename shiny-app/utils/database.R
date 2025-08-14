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
    author_ids = safe_db_query("SELECT DISTINCT author_id FROM book_entries WHERE author_id IS NOT NULL ORDER BY author_id")
  )
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