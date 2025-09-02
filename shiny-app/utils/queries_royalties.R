# Royalty-related Database Query Functions
# Functions to compute royalty income using per-book simple rate or tier structures

# Helper: calculate royalty income for a book based on sales and royalty structure
# total_sales: numeric units sold in the period
# retail_price: numeric price per unit
# royalty_rate: simple royalty rate (0-1) if no tiers
# royalty_tiers: data.frame with columns: lower_limit, upper_limit (NA for open-ended), rate
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

  for (i in seq_len(nrow(royalty_tiers))) {
    tier <- royalty_tiers[i, ]
    tier_lower <- tier$lower_limit
    tier_upper <- if (is.na(tier$upper_limit)) Inf else tier$upper_limit
    tier_rate  <- tier$rate

    if (remaining_sales <= 0) break

    # Sales available in this tier width
    tier_width <- if (is.finite(tier_upper)) (tier_upper - tier_lower + 1) else remaining_sales
    tier_sales <- min(remaining_sales, tier_width)

    if (tier_sales > 0 && !is.na(tier_rate) && tier_rate > 0) {
      total_income <- total_income + (tier_sales * retail_price * tier_rate)
      remaining_sales <- remaining_sales - tier_sales
    }
  }

  return(total_income)
}

# Get royalty income from sales of a book title in a date range.
# If binding_state is NULL, return rows for all bindings; otherwise filter to that binding.
get_royalty_income_by_book_binding_flexible <- function(book_title, binding_state = NULL, start_year, end_year) {
  # When binding_state is NULL, fetch all bindings for the title
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
    sales_data <- safe_db_query(query, params = list(
      paste0("%", book_title, "%"), start_year, end_year
    ))
  } else {
    # Use existing utility for specific binding
    sales_data <- get_book_sales_by_title_binding(book_title, binding_state, start_year, end_year)
  }

  if (is.null(sales_data) || nrow(sales_data) == 0) {
    return(data.frame())
  }

  # For each book row, compute royalty income using simple rate or tiers
  out <- vector("list", nrow(sales_data))
  for (i in seq_len(nrow(sales_data))) {
    book_id <- sales_data$book_id[i]
    total_sales <- sales_data$total_sales[i]

    # Fetch details/tiers
    details <- get_book_details(book_id)
    book_info <- details$book_info
    royalty_tiers <- details$royalty_tiers

    if (!is.null(book_info) && nrow(book_info) > 0) {
      retail_price <- book_info$retail_price[1]
      royalty_rate <- book_info$royalty_rate[1]

      royalty_income <- calculate_royalty_income(
        book_id, total_sales, retail_price, royalty_rate, royalty_tiers
      )

      out[[i]] <- data.frame(
        book_id = book_id,
        book_title = sales_data$book_title[i],
        author_surname = sales_data$author_surname[i],
        binding = sales_data$binding[i],
        total_sales = total_sales,
        retail_price = retail_price,
        royalty_income = royalty_income,
        stringsAsFactors = FALSE
      )
    } else {
      out[[i]] <- NULL
    }
  }

  do.call(rbind, out)
}

# Compute total royalty income for an author in a date range.
# Optionally restrict to a specific author_id when provided.
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

  if (is.null(books_data) || nrow(books_data) == 0) {
    return(data.frame())
  }

  # Get all royalty tiers for all books in one query
  book_ids <- books_data$book_id
  if (length(book_ids) > 0) {
    # Create placeholders for IN clause
    placeholders <- paste0("$", 1:length(book_ids), collapse = ",")
    royalty_query <- paste0("
      SELECT
        book_id,
        tier,
        rate,
        lower_limit,
        upper_limit,
        sliding_scale
      FROM royalty_tiers
      WHERE book_id IN (", placeholders, ")
      ORDER BY book_id, tier
    ")
    royalty_tiers_data <- safe_db_query(royalty_query, params = as.list(book_ids))
  } else {
    royalty_tiers_data <- data.frame()
  }

  # Organize royalty tiers by book_id for faster lookup
  royalty_tiers_by_book <- split(royalty_tiers_data, royalty_tiers_data$book_id)

  results <- vector("list", nrow(books_data))
  total_royalty_income <- 0

  for (i in seq_len(nrow(books_data))) {
    book_id <- books_data$book_id[i]
    total_sales <- books_data$total_sales[i]
    retail_price <- books_data$retail_price[i]
    royalty_rate <- books_data$royalty_rate[i]

    # Get tiers for this book from the pre-fetched data
    royalty_tiers <- if (book_id %in% names(royalty_tiers_by_book)) {
      royalty_tiers_by_book[[as.character(book_id)]]
    } else {
      data.frame()
    }

    royalty_income <- calculate_royalty_income(
      book_id, total_sales, retail_price, royalty_rate, royalty_tiers
    )

    total_royalty_income <- total_royalty_income + royalty_income

    results[[i]] <- data.frame(
      book_id = book_id,
      book_title = books_data$book_title[i],
      author_surname = books_data$author_surname[i],
      total_sales = total_sales,
      retail_price = retail_price,
      royalty_income = royalty_income,
      stringsAsFactors = FALSE
    )
  }

  out <- do.call(rbind, results)
  if (!is.null(out) && nrow(out) > 0) {
    out <- rbind(out, data.frame(
      book_id = "TOTAL",
      book_title = paste("TOTAL FOR", ifelse(is.null(author_id) || !nzchar(author_id), author_surname, author_id)),
      author_surname = author_surname,
      total_sales = sum(out$total_sales, na.rm = TRUE),
      retail_price = NA,
      royalty_income = total_royalty_income,
      stringsAsFactors = FALSE
    ))
  }

  out
}

