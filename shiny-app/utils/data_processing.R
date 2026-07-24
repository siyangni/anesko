# Data Processing Utility Functions
# Functions for data transformation, aggregation, and preparation
# Updated for new PostgreSQL database schema with author_id and proper NULLs

# NULL coalescing operator used throughout the application
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
}

# Format numeric values for compact display
format_number <- function(x, suffix = "") {
  if (is.null(x) || length(x) == 0) return("N/A")

  if (length(x) > 1) {
    return(sapply(x, format_number, suffix = suffix))
  }

  # bit64::integer64 from RPostgres BIGINT — coerce before is.numeric checks
  if (inherits(x, "integer64")) {
    x <- as.numeric(x)
  }

  if (is.na(x) || !is.numeric(x)) return("N/A")

  x <- as.numeric(x)
  if (is.na(x) || is.infinite(x)) return("N/A")
  if (x < 0) return("N/A")

  if (x >= FORMAT_MILLION_THRESHOLD) {
    paste0(round(x / FORMAT_MILLION_THRESHOLD, 1), "M", suffix)
  } else if (x >= FORMAT_THOUSAND_THRESHOLD) {
    paste0(round(x / FORMAT_THOUSAND_THRESHOLD, 1), "K", suffix)
  } else {
    paste0(formatC(x, format = "d", big.mark = ","), suffix)
  }
}

# Clean and standardize genre codes (updated for new database values)
clean_genre <- function(genre) {
  # Handle vectors properly
  if (is.null(genre)) return("Other")

  # New database already has cleaned genre values:
  # Novel, Poetry, Drama, Essay/Other Non-Fiction, etc.
  # Just handle NULLs and return as-is
  ifelse(is.na(genre) | is.null(genre), "Other", genre)
}

# Canonical gender labels used in UI filters and display
CANONICAL_GENDERS <- c("Male", "Female", "Unknown")
KNOWN_GENDERS <- c("Male", "Female")

# Clean and standardize gender for display / in-memory use.
# Blank, whitespace-only, NA, and unrecognized codes become "Unknown".
# DB stores unknown as NULL; UI/display uses the string "Unknown".
clean_gender <- function(gender) {
  if (is.null(gender)) {
    return(character(0))
  }

  g <- as.character(gender)
  trimmed <- trimws(g)
  blank <- is.na(trimmed) | !nzchar(trimmed)

  out <- rep("Unknown", length(trimmed))
  if (all(blank)) {
    return(out)
  }

  # Case-insensitive match against known labels / single-letter codes
  lower <- tolower(trimmed)
  out[!blank & lower %in% c("m", "male")] <- "Male"
  out[!blank & lower %in% c("f", "female")] <- "Female"
  out[!blank & lower %in% c("u", "unknown", "other", "n/a", "na", "none")] <- "Unknown"
  # Any other non-blank unrecognized value stays Unknown (already set)

  out
}

#' Normalize a UI gender filter into a query-ready selection.
#'
#' Single-select mode (selectInput with "" = "All Authors"):
#'   NULL / "" / whitespace → no filter (all genders), empty = FALSE
#' Multi-select mode (checkboxGroupInput):
#'   NULL / character(0) → empty selection (no rows), NOT silently "all"
#'
#' @param gender_filter Raw UI value (character vector, NULL, or "")
#' @param mode "multi" (checkboxes) or "single" (dropdown)
#' @return list(apply, genders, empty)
#'   apply: TRUE if a gender WHERE clause should be applied
#'   genders: canonical values when apply is TRUE (may be empty)
#'   empty: TRUE when multi-select has nothing checked
normalize_gender_filter <- function(gender_filter, mode = c("multi", "single")) {
  mode <- match.arg(mode)

  if (mode == "single") {
    if (is.null(gender_filter) || length(gender_filter) == 0) {
      return(list(apply = FALSE, genders = character(0), empty = FALSE))
    }
    raw <- trimws(as.character(gender_filter[[1]]))
    if (is.na(raw) || !nzchar(raw)) {
      # Explicit "All Authors" / "Compare Both" choice
      return(list(apply = FALSE, genders = character(0), empty = FALSE))
    }
    g <- unique(clean_gender(raw))
    g <- g[g %in% CANONICAL_GENDERS]
    if (length(g) == 0) {
      return(list(apply = FALSE, genders = character(0), empty = FALSE))
    }
    return(list(apply = TRUE, genders = g, empty = FALSE))
  }

  # multi: empty must not mean "all"
  if (is.null(gender_filter) || length(gender_filter) == 0) {
    return(list(apply = TRUE, genders = character(0), empty = TRUE))
  }
  cleaned <- unique(clean_gender(gender_filter))
  cleaned <- cleaned[cleaned %in% CANONICAL_GENDERS]
  if (length(cleaned) == 0) {
    return(list(apply = TRUE, genders = character(0), empty = TRUE))
  }
  list(apply = TRUE, genders = cleaned, empty = FALSE)
}

#' SQL expression that normalizes stored gender for display / grouping.
#' Maps NULL and blank/whitespace to 'Unknown'.
gender_display_sql <- function(column = "be.gender") {
  paste0("COALESCE(NULLIF(BTRIM(", column, "), ''), 'Unknown')")
}

#' Build a parameterized SQL WHERE fragment for gender filtering.
#'
#' Unknown in the UI maps to NULL or blank values in the database
#' (schema CHECK allows only 'Male', 'Female', or NULL).
#'
#' @param genders Canonical gender values (Male / Female / Unknown)
#' @param column SQL column reference
#' @param param_start Next $n parameter index
#' @return list(clause, params, next_param)
#'   Empty genders → clause "FALSE" (match nothing; never silent "all")
build_gender_sql_filter <- function(genders, column = "be.gender", param_start = 1L) {
  param_start <- as.integer(param_start)
  genders <- unique(clean_gender(genders))
  genders <- genders[genders %in% CANONICAL_GENDERS]

  if (length(genders) == 0) {
    return(list(clause = "FALSE", params = list(), next_param = param_start))
  }

  # All canonical genders selected → no filter needed
  if (setequal(genders, CANONICAL_GENDERS)) {
    return(list(clause = NULL, params = list(), next_param = param_start))
  }

  known <- intersect(genders, KNOWN_GENDERS)
  include_unknown <- "Unknown" %in% genders

  parts <- character(0)
  params <- list()
  idx <- param_start

  if (length(known) > 0) {
    placeholders <- paste0("$", idx:(idx + length(known) - 1L), collapse = ",")
    parts <- c(parts, paste0(column, " IN (", placeholders, ")"))
    params <- c(params, as.list(known))
    idx <- idx + length(known)
  }

  if (include_unknown) {
    parts <- c(parts, paste0("(", column, " IS NULL OR BTRIM(", column, ") = '')"))
  }

  list(
    clause = paste0("(", paste(parts, collapse = " OR "), ")"),
    params = params,
    next_param = idx
  )
}

# Calculate royalty rate statistics
calculate_royalty_stats <- function(data) {
  data %>%
    filter(!is.na(royalty_rate) & royalty_rate > 0) %>%
    summarise(
      mean_royalty = mean(royalty_rate, na.rm = TRUE),
      median_royalty = median(royalty_rate, na.rm = TRUE),
      min_royalty = min(royalty_rate, na.rm = TRUE),
      max_royalty = max(royalty_rate, na.rm = TRUE),
      q25_royalty = quantile(royalty_rate, 0.25, na.rm = TRUE),
      q75_royalty = quantile(royalty_rate, 0.75, na.rm = TRUE),
      .groups = "drop"
    )
}

# Create age cohorts for books
create_age_cohorts <- function(publication_years) {
  cut(publication_years, 
      breaks = c(1859, 1869, 1879, 1889, 1899, 1909, 1920),
      labels = c("1860s", "1870s", "1880s", "1890s", "1900s", "1910s"),
      include.lowest = TRUE)
}

# Calculate sales velocity (sales per year)
calculate_sales_velocity <- function(data) {
  data %>%
    mutate(
      sales_velocity = ifelse(years_with_sales > 0, 
                             total_sales / years_with_sales, 
                             0)
    )
}

# Prepare time series data for plotting
prepare_timeseries <- function(sales_data, aggregate_by = "year") {
  if (nrow(sales_data) == 0) return(data.frame())
  
  switch(aggregate_by,
    "year" = sales_data %>%
      group_by(year) %>%
      summarise(
        total_sales = sum(sales_count, na.rm = TRUE),
        books_sold = n_distinct(book_id),
        avg_sales_per_book = mean(sales_count, na.rm = TRUE),
        .groups = "drop"
      ),
    
    "decade" = sales_data %>%
      mutate(decade = (year %/% 10) * 10) %>%
      group_by(decade) %>%
      summarise(
        total_sales = sum(sales_count, na.rm = TRUE),
        books_sold = n_distinct(book_id),
        avg_sales_per_book = mean(sales_count, na.rm = TRUE),
        years_span = n_distinct(year),
        .groups = "drop"
      ),
    
    sales_data
  )
}

# Create summary statistics for numeric columns
create_numeric_summary <- function(data, column) {
  if (!column %in% names(data)) return(NULL)
  
  values <- data[[column]]
  values <- values[!is.na(values) & is.finite(values)]
  
  if (length(values) == 0) return(NULL)
  
  list(
    count = length(values),
    mean = mean(values),
    median = median(values),
    sd = sd(values),
    min = min(values),
    max = max(values),
    q25 = quantile(values, 0.25),
    q75 = quantile(values, 0.75),
    missing = sum(is.na(data[[column]]))
  )
}

# Calculate market concentration (Herfindahl-Hirschman Index)
calculate_market_concentration <- function(data, group_var) {
  if (!group_var %in% names(data)) return(NULL)
  
  market_shares <- data %>%
    filter(!is.na(.data[[group_var]])) %>%
    group_by(.data[[group_var]]) %>%
    summarise(total = sum(total_sales, na.rm = TRUE), .groups = "drop") %>%
    mutate(
      market_share = total / sum(total),
      hhi_component = market_share^2
    )
  
  list(
    hhi = sum(market_shares$hhi_component),
    market_shares = market_shares %>%
      arrange(desc(market_share)) %>%
      mutate(
        market_share_pct = market_share * 100,
        cumulative_share = cumsum(market_share_pct)
      )
  )
}

# Prepare data for correlation analysis
prepare_correlation_data <- function(data) {
  numeric_cols <- data %>%
    select_if(is.numeric) %>%
    select(-contains("id")) %>%  # Remove ID columns
    names()
  
  if (length(numeric_cols) < 2) return(NULL)
  
  cor_data <- data[numeric_cols]
  cor_data <- cor_data[complete.cases(cor_data), ]
  
  if (nrow(cor_data) < 10) return(NULL)  # Need minimum observations
  
  list(
    data = cor_data,
    correlation_matrix = cor(cor_data, use = "complete.obs"),
    variables = numeric_cols
  )
}

# Create binned data for distribution analysis
create_distribution_bins <- function(values, n_bins = 20) {
  if (length(values) == 0 || all(is.na(values))) return(NULL)
  
  values <- values[!is.na(values) & is.finite(values)]
  
  if (length(unique(values)) < 3) return(NULL)
  
  # Create bins
  breaks <- pretty(values, n = n_bins)
  bins <- cut(values, breaks = breaks, include.lowest = TRUE)
  
  # Create histogram data
  hist_data <- data.frame(
    bin = as.character(bins),
    count = as.numeric(table(bins))
  ) %>%
    filter(!is.na(bin))
  
  # Add bin centers for plotting
  hist_data$bin_center <- breaks[-length(breaks)] + diff(breaks) / 2
  
  hist_data
}

# Identify outliers using IQR method
identify_outliers <- function(values, multiplier = 1.5) {
  if (length(values) == 0 || all(is.na(values))) return(logical(0))
  
  q1 <- quantile(values, 0.25, na.rm = TRUE)
  q3 <- quantile(values, 0.75, na.rm = TRUE)
  iqr <- q3 - q1
  
  lower_bound <- q1 - multiplier * iqr
  upper_bound <- q3 + multiplier * iqr
  
  values < lower_bound | values > upper_bound
}

# Create success metrics for books
calculate_success_metrics <- function(data) {
  data %>%
    mutate(
      # Sales performance
      sales_category = case_when(
        total_sales == 0 ~ "No Sales",
        total_sales < 1000 ~ "Low Sales (<1K)",
        total_sales < 5000 ~ "Moderate Sales (1K-5K)",
        total_sales < 20000 ~ "Good Sales (5K-20K)",
        TRUE ~ "High Sales (20K+)"
      ),
      
      # Longevity
      longevity_category = case_when(
        years_with_sales == 0 ~ "No Sales Period",
        years_with_sales <= 2 ~ "Short Run (≤2 years)",
        years_with_sales <= 5 ~ "Medium Run (3-5 years)",
        years_with_sales <= 10 ~ "Long Run (6-10 years)",
        TRUE ~ "Very Long Run (10+ years)"
      ),
      
      # Price category
      price_category = case_when(
        is.na(retail_price) ~ "Unknown Price",
        retail_price < 1.00 ~ "Low Price (<$1)",
        retail_price < 2.00 ~ "Moderate Price ($1-2)",
        retail_price < 4.00 ~ "High Price ($2-4)",
        TRUE ~ "Premium Price ($4+)"
      )
    )
}

# Aggregate data by time period
aggregate_by_period <- function(data, period = "year", date_col = "year") {
  if (!date_col %in% names(data)) return(data)
  
  switch(period,
    "year" = data,
    
    "decade" = data %>%
      mutate(period = (!!sym(date_col) %/% 10) * 10) %>%
      group_by(period) %>%
      summarise(
        total_sales = sum(total_sales, na.rm = TRUE),
        unique_books = n_distinct(book_id),
        unique_authors = n_distinct(author_surname, na.rm = TRUE),
        avg_sales = mean(total_sales, na.rm = TRUE),
        .groups = "drop"
      ),
    
    "5year" = data %>%
      mutate(period = (!!sym(date_col) %/% 5) * 5) %>%
      group_by(period) %>%
      summarise(
        total_sales = sum(total_sales, na.rm = TRUE),
        unique_books = n_distinct(book_id),
        unique_authors = n_distinct(author_surname, na.rm = TRUE),
        avg_sales = mean(total_sales, na.rm = TRUE),
        .groups = "drop"
      )
  )
}

# =============================================================================
# NEW FUNCTIONS FOR ENHANCED DATABASE FEATURES
# =============================================================================

# Process author data using new author_id field
process_author_data <- function(author_data) {
  if (nrow(author_data) == 0) return(data.frame())

  author_data %>%
    mutate(
      # Career span
      career_span = last_publication - first_publication + 1,

      # Productivity metrics
      books_per_year = ifelse(career_span > 0, book_count / career_span, book_count),

      # Success categories
      author_category = case_when(
        book_count == 1 ~ "Single Publication",
        book_count <= 3 ~ "Occasional Author (2-3 books)",
        book_count <= 10 ~ "Regular Author (4-10 books)",
        TRUE ~ "Prolific Author (10+ books)"
      ),

      # Sales performance
      sales_performance = case_when(
        total_sales == 0 ~ "No Sales",
        total_sales < 5000 ~ "Low Sales",
        total_sales < 20000 ~ "Moderate Sales",
        total_sales < 100000 ~ "High Sales",
        TRUE ~ "Bestselling Author"
      )
    )
}

# Create author network data for relationship analysis
create_author_network <- function(book_data) {
  # Handle empty input
  if (is.null(book_data) || nrow(book_data) == 0) {
    return(list(nodes = data.frame(), edges = data.frame()))
  }

  # Validate required columns
  required_cols <- c("author_id", "author_surname", "gender", "publisher", "publication_year", "total_sales")
  missing_cols <- setdiff(required_cols, names(book_data))
  if (length(missing_cols) > 0) {
    warning("Missing required columns in book_data: ", paste(missing_cols, collapse = ", "))
    return(list(nodes = data.frame(), edges = data.frame()))
  }

  # Create nodes (authors) with error handling
  tryCatch({
    nodes <- book_data %>%
      mutate(gender = clean_gender(gender)) %>%
      group_by(author_id, author_surname, gender) %>%
      summarise(
        book_count = n(),
        total_sales = sum(total_sales, na.rm = TRUE),
        avg_year = mean(publication_year, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(
        # Ensure node_size is always positive and reasonable
        node_size = pmax(3, pmin(20, log10(total_sales + 1) * 2)),
        node_color = case_when(
          gender == "Male" ~ "#1f77b4",
          gender == "Female" ~ "#ff7f0e",
          gender == "Unknown" ~ "#7f7f7f",
          TRUE ~ "#2ca02c"
        )
      )

    # Handle case where no nodes were created
    if (nrow(nodes) == 0) {
      return(list(nodes = data.frame(), edges = data.frame()))
    }

    # Create edges (shared publishers or similar publication years)
    edges <- tryCatch({
      book_data %>%
        select(author_id, publisher, publication_year) %>%
        filter(!is.na(publisher), !is.na(publication_year)) %>%
        inner_join(., ., by = "publisher", suffix = c("_1", "_2"), relationship = "many-to-many") %>%
        filter(
          author_id_1 != author_id_2,
          abs(publication_year_1 - publication_year_2) <= 5
        ) %>%
        group_by(author_id_1, author_id_2) %>%
        summarise(
          shared_publishers = n_distinct(publisher),
          weight = shared_publishers,
          .groups = "drop"
        ) %>%
        filter(weight > 0)
    }, error = function(e) {
      warning("Error creating network edges: ", e$message)
      data.frame()
    })

    # Ensure edges is a data.frame even if empty
    if (is.null(edges)) {
      edges <- data.frame()
    }

    return(list(nodes = nodes, edges = edges))

  }, error = function(e) {
    warning("Error creating author network: ", e$message)
    return(list(nodes = data.frame(), edges = data.frame()))
  })
}

# Analyze royalty tier patterns with enhanced error handling
analyze_royalty_patterns <- function(royalty_data) {
  # Validate input
  if (is.null(royalty_data) || nrow(royalty_data) == 0) {
    return(data.frame())
  }

  # Check for required columns
  required_cols <- c("tier", "book_id", "rate", "sliding_scale")
  missing_cols <- setdiff(required_cols, names(royalty_data))
  if (length(missing_cols) > 0) {
    warning("Missing required columns in royalty_data: ", paste(missing_cols, collapse = ", "))
    return(data.frame())
  }

  tryCatch({
    result <- royalty_data %>%
      # Filter out invalid data
      filter(!is.na(tier), !is.na(book_id), !is.na(rate)) %>%
      group_by(tier) %>%
      summarise(
        book_count = n_distinct(book_id),
        avg_rate = mean(rate, na.rm = TRUE),
        median_rate = median(rate, na.rm = TRUE),
        min_rate = min(rate, na.rm = TRUE),
        max_rate = max(rate, na.rm = TRUE),
        avg_lower_limit = mean(lower_limit, na.rm = TRUE),
        avg_upper_limit = mean(upper_limit, na.rm = TRUE),
        sliding_scale_pct = mean(as.numeric(sliding_scale), na.rm = TRUE) * 100,
        .groups = "drop"
      ) %>%
      mutate(
        # Ensure all numeric values are valid
        avg_rate = ifelse(is.na(avg_rate) | is.infinite(avg_rate), 0, avg_rate),
        median_rate = ifelse(is.na(median_rate) | is.infinite(median_rate), 0, median_rate),
        min_rate = ifelse(is.na(min_rate) | is.infinite(min_rate), 0, min_rate),
        max_rate = ifelse(is.na(max_rate) | is.infinite(max_rate), 0, max_rate),
        sliding_scale_pct = ifelse(is.na(sliding_scale_pct) | is.infinite(sliding_scale_pct), 0, sliding_scale_pct),

        # Add tier descriptions
        tier_description = case_when(
          tier == 1 ~ "Initial Tier",
          tier == 2 ~ "Second Tier",
          tier == 3 ~ "Third Tier",
          tier == 4 ~ "Final Tier",
          TRUE ~ paste("Tier", tier)
        )
      ) %>%
      # Ensure we have valid tiers
      filter(!is.na(tier), book_count > 0)

    return(result)

  }, error = function(e) {
    warning("Error in analyze_royalty_patterns: ", e$message)
    return(data.frame())
  })
}

# Create publication timeline with enhanced features
create_enhanced_timeline <- function(book_data) {
  if (nrow(book_data) == 0) return(data.frame())

  book_data %>%
    group_by(publication_year, gender, genre) %>%
    summarise(
      book_count = n(),
      total_sales = sum(total_sales, na.rm = TRUE),
      avg_price = mean(retail_price, na.rm = TRUE),
      unique_authors = n_distinct(author_id),
      unique_publishers = n_distinct(publisher),
      .groups = "drop"
    ) %>%
    filter(!is.na(publication_year))
}

# Calculate market share analysis
calculate_market_share <- function(data, group_by_col) {
  if (!group_by_col %in% names(data) || nrow(data) == 0) return(data.frame())

  data %>%
    group_by(!!sym(group_by_col)) %>%
    summarise(
      total_sales = sum(total_sales, na.rm = TRUE),
      book_count = n(),
      unique_authors = n_distinct(author_id),
      .groups = "drop"
    ) %>%
    mutate(
      market_share = total_sales / sum(total_sales, na.rm = TRUE),
      market_share_pct = market_share * 100,
      cumulative_share = cumsum(market_share_pct)
    ) %>%
    arrange(desc(market_share))
}

# Handle NULL values in data for visualization
clean_data_for_viz <- function(data) {
  data %>%
    mutate(
      across(where(is.character), ~ ifelse(is.na(.x), "Unknown", .x)),
      across(where(is.numeric), ~ ifelse(is.na(.x), 0, .x))
    )
}

# =============================================================================
# CATALOG-STYLE TITLE FORMATTING
# Reposition leading articles (A, An, The) to the end for list/table display.
# Database values stay unchanged; use these helpers only for UI presentation.
# =============================================================================

#' Format book titles in library catalog style
#'
#' Moves a leading English article ("A", "An", "The") to the end of the title:
#' e.g. "A Boy's Town" -> "Boy's Town, A". Mid-title articles are left alone.
#' Only matches article + whitespace (so "Ann Boyd" / "Theatricals" are unchanged).
#'
#' @param titles Character vector of book titles (may include NA).
#' @return Character vector of the same length with catalog-style display forms.
format_title_catalog_style <- function(titles) {
  if (is.null(titles)) {
    return(character(0))
  }

  # Coerce factors etc.; preserve length including NAs
  titles <- as.character(titles)
  out <- titles

  # Leading article + at least one non-space character in the remainder
  article_re <- "^(A|An|The)\\s+(.+)$"
  matches <- grepl(article_re, titles, ignore.case = TRUE, perl = TRUE)

  if (any(matches, na.rm = TRUE)) {
    idx <- which(matches)
    for (i in idx) {
      m <- regexec(article_re, titles[[i]], ignore.case = TRUE, perl = TRUE)
      parts <- regmatches(titles[[i]], m)[[1]]
      if (length(parts) >= 3) {
        article_raw <- parts[[2]]
        remainder <- trimws(parts[[3]])
        if (!nzchar(remainder)) {
          next
        }
        article_norm <- switch(
          tolower(article_raw),
          "a" = "A",
          "an" = "An",
          "the" = "The",
          article_raw
        )
        out[[i]] <- paste0(remainder, ", ", article_norm)
      }
    }
  }

  out
}

#' Build named selectize choices for book titles in catalog style
#'
#' Labels use catalog form (articles at end) and are sorted alphabetically by
#' that label. Values remain the original stored titles for database lookups.
#'
#' @param titles Character vector of original book titles.
#' @param labels Optional precomputed display labels (same length as titles).
#'   If NULL, labels are produced via format_title_catalog_style(titles).
#'   When provided, empty/NA titles (and their labels) are dropped together
#'   before deduplication by original title.
#' @return Named character vector: names = display labels, values = original titles.
make_title_choices <- function(titles, labels = NULL) {
  if (is.null(titles) || length(titles) == 0) {
    return(stats::setNames(character(0), character(0)))
  }

  titles <- as.character(titles)
  if (is.null(labels)) {
    labels <- format_title_catalog_style(titles)
  } else {
    labels <- as.character(labels)
    if (length(labels) != length(titles)) {
      stop("make_title_choices: labels must be the same length as titles")
    }
  }

  keep <- !is.na(titles) & nzchar(trimws(titles))
  titles <- titles[keep]
  labels <- labels[keep]

  if (length(titles) == 0) {
    return(stats::setNames(character(0), character(0)))
  }

  # Deduplicate by original title, keep first label
  dedup <- !duplicated(titles)
  titles <- titles[dedup]
  labels <- labels[dedup]

  ord <- order(labels, titles, na.last = TRUE)
  stats::setNames(titles[ord], labels[ord])
}
