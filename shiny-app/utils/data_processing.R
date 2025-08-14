# Data Processing Utility Functions
# Functions for data transformation, aggregation, and preparation
# Updated for new PostgreSQL database schema with author_id and proper NULLs

# Clean and standardize genre codes (updated for new database values)
clean_genre <- function(genre) {
  # Handle vectors properly
  if (is.null(genre)) return("Other")

  # New database already has cleaned genre values:
  # Novel, Poetry, Drama, Essay/Other Non-Fiction, etc.
  # Just handle NULLs and return as-is
  ifelse(is.na(genre) | is.null(genre), "Other", genre)
}

# Clean and standardize gender (updated for new database values)
clean_gender <- function(gender) {
  # New database already has "Male"/"Female" values, just handle NULLs
  ifelse(is.na(gender) | is.null(gender), "Unknown", gender)
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