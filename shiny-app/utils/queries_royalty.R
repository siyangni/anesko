# Royalty-related Database Query Functions
# Functions for computing royalty income and fetching royalty-related data

# Helper: Calculate royalty income for a book
calculate_royalty_income <- function(book_id, total_sales, retail_price, royalty_rate, royalty_tiers = NULL) {
  if (is.na(total_sales) || total_sales <= 0 || is.na(retail_price) || retail_price <= 0) {
    return(0)
  }
  if (is.null(royalty_tiers) || nrow(royalty_tiers) == 0) {
    if (is.na(royalty_rate) || royalty_rate <= 0) return(0)
    return(total_sales * retail_price * royalty_rate)
  }
  total_income <- 0
  remaining_sales <- total_sales
  for (i in 1:nrow(royalty_tiers)) {
    tier <- royalty_tiers[i, ]
    tier_lower <- tier$lower_limit
    tier_upper <- if (is.na(tier$upper_limit)) Inf else tier$upper_limit
    tier_rate <- tier$rate
    if (remaining_sales <= 0) break
    tier_sales <- min(remaining_sales, tier_upper - tier_lower + 1)
    if (tier_sales > 0) {
      tier_income <- tier_sales * retail_price * tier_rate
      total_income <- total_income + tier_income
      remaining_sales <- remaining_sales - tier_sales
    }
  }
  total_income
}

# Royalty income by book & binding
get_royalty_income_by_book_binding <- function(book_title, binding_state, start_year, end_year) {
  sales_data <- get_book_sales_by_title_binding(book_title, binding_state, start_year, end_year)
  if (nrow(sales_data) == 0) return(data.frame())
  result <- data.frame()
  for (i in 1:nrow(sales_data)) {
    book_id <- sales_data$book_id[i]
    total_sales <- sales_data$total_sales[i]
    book_details <- get_book_details(book_id)
    book_info <- book_details$book_info
    royalty_tiers <- book_details$royalty_tiers
    if (nrow(book_info) > 0) {
      retail_price <- book_info$retail_price[1]
      royalty_rate <- book_info$royalty_rate[1]
      royalty_income <- calculate_royalty_income(book_id, total_sales, retail_price, royalty_rate, royalty_tiers)
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
  result
}

# Flexible royalty income by book (binding optional)
get_royalty_income_by_book_binding_flexible <- function(book_title, binding_state = NULL, start_year, end_year) {
  if (is.null(binding_state)) {
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
        AND bs.year BETWEEN $2 AND $3
        AND bs.sales_count IS NOT NULL
      GROUP BY be.book_id, be.book_title, be.author_surname, be.binding
      ORDER BY total_sales DESC
    "
    sales_data <- safe_db_query(query, params = list(paste0("%", book_title, "%"), start_year, end_year))
  } else {
    sales_data <- get_book_sales_by_title_binding(book_title, binding_state, start_year, end_year)
  }
  if (is.null(sales_data) || nrow(sales_data) == 0) return(data.frame())

  result <- data.frame()
  for (i in 1:nrow(sales_data)) {
    book_id <- sales_data$book_id[i]
    total_sales <- sales_data$total_sales[i]
    book_details <- get_book_details(book_id)
    book_info <- book_details$book_info
    royalty_tiers <- book_details$royalty_tiers
    if (nrow(book_info) > 0) {
      retail_price <- book_info$retail_price[1]
      royalty_rate <- book_info$royalty_rate[1]
      royalty_income <- calculate_royalty_income(book_id, total_sales, retail_price, royalty_rate, royalty_tiers)
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
  result
}

# Total royalty income by author
get_total_royalty_income_by_author <- function(author_surname, start_year, end_year, author_id = NULL) {
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
    books_data <- safe_db_query(query, params = list(paste0("%", author_surname, "%"), start_year, end_year))
  }
  if (nrow(books_data) == 0) return(data.frame())

  result <- data.frame()
  total_royalty_income <- 0
  for (i in 1:nrow(books_data)) {
    book_id <- books_data$book_id[i]
    total_sales <- books_data$total_sales[i]
    retail_price <- books_data$retail_price[i]
    royalty_rate <- books_data$royalty_rate[i]
    book_details <- get_book_details(book_id)
    royalty_tiers <- book_details$royalty_tiers
    royalty_income <- calculate_royalty_income(book_id, total_sales, retail_price, royalty_rate, royalty_tiers)
    total_royalty_income <- total_royalty_income + royalty_income
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
  result
}

