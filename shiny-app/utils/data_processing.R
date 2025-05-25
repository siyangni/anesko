# Data Processing Utility Functions
# Functions for data transformation, aggregation, and preparation

# Clean and standardize genre codes
clean_genre <- function(genre) {
  # Handle vectors properly
  if (is.null(genre)) return("Other")
  
  # Standard mappings
  genre_map <- c(
    "F" = "Fiction",
    "N" = "Non-fiction", 
    "P" = "Poetry",
    "D" = "Drama",
    "J" = "Juvenile",
    "S" = "Short Stories",
    "B" = "Biography"
  )
  
  # Return mapped value or "Other" - works with vectors
  ifelse(is.na(genre) | genre == "" | is.null(genre), 
         "Other", 
         ifelse(genre %in% names(genre_map), genre_map[genre], "Other"))
}

# Clean and standardize gender
clean_gender <- function(gender) {
  case_when(
    gender == "M" ~ "Male",
    gender == "F" ~ "Female", 
    TRUE ~ "Unknown"
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