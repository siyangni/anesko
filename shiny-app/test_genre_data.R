# Test Genre Data for Dashboard Fix
library(DBI)
library(RPostgreSQL)
library(dplyr)

cat("🎭 Testing Genre Data for Dashboard\n")
cat(paste(rep("=", 40), collapse = ""), "\n")

# Load configuration
source("config/cloud_config.R")
source("utils/database.R")

# Test 1: Direct genre query
cat("\n📊 Testing direct genre query...\n")
con <- dbConnect(
  RPostgreSQL::PostgreSQL(),
  host = db_config$host,
  dbname = db_config$dbname,
  user = db_config$user,
  password = db_config$password
)

direct_genre <- dbGetQuery(con, "
  SELECT 
    be.genre,
    COUNT(*) as book_count,
    COALESCE(SUM(bs.total_sales), 0) as total_sales
  FROM book_entries be
  LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
  WHERE be.genre IS NOT NULL
  GROUP BY be.genre
  ORDER BY total_sales DESC
")

cat("Direct genre query results:\n")
print(direct_genre)

dbDisconnect(con)

# Test 2: get_books_summary function
cat("\n📚 Testing get_books_summary function...\n")
books_summary <- get_books_summary()

if (nrow(books_summary) > 0) {
  cat("✅ get_books_summary returned", nrow(books_summary), "books\n")
  
  # Check genre values
  genre_values <- unique(books_summary$genre)
  cat("Unique genres:", paste(genre_values, collapse = ", "), "\n")
  
  # Test the dashboard aggregation logic
  cat("\n🔍 Testing dashboard aggregation logic...\n")
  genre_summary <- books_summary %>%
    group_by(genre) %>%
    summarise(
      total_sales = sum(total_sales, na.rm = TRUE),
      book_count = n(),
      .groups = "drop"
    ) %>%
    filter(!is.na(genre), total_sales > 0) %>%
    arrange(desc(total_sales)) %>%
    slice_head(n = 10)
  
  cat("Dashboard genre aggregation:\n")
  print(genre_summary)
  
  # Test what happens with the old genre cleaning logic
  cat("\n🧹 Testing old genre cleaning logic...\n")
  plot_data_old <- genre_summary %>%
    mutate(genre_clean = case_when(
      is.na(genre) | genre == "" ~ "Other",
      genre == "F" ~ "Fiction",
      genre == "N" ~ "Non-fiction", 
      genre == "P" ~ "Poetry",
      genre == "D" ~ "Drama",
      genre == "J" ~ "Juvenile",
      genre == "S" ~ "Short Stories",
      genre == "B" ~ "Biography",
      TRUE ~ "Other"
    ))
  
  cat("Old cleaning logic results:\n")
  print(plot_data_old[, c("genre", "genre_clean", "total_sales")])
  
  # Test new genre cleaning logic (should use actual names)
  cat("\n✨ Testing new genre cleaning logic...\n")
  plot_data_new <- genre_summary %>%
    mutate(genre_display = case_when(
      is.na(genre) | genre == "" ~ "Other",
      TRUE ~ genre  # Use actual genre names
    ))
  
  cat("New cleaning logic results:\n")
  print(plot_data_new[, c("genre", "genre_display", "total_sales")])
  
} else {
  cat("❌ get_books_summary returned no data\n")
}

cat("\n📋 Analysis:\n")
cat("- Check if genre values are full names (Novel, Poetry) or codes (N, P)\n")
cat("- Check if aggregation is working correctly\n")
cat("- Check if filtering is too restrictive\n")
cat("- Verify the genre cleaning logic matches actual data\n")
