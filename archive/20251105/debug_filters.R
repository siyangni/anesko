# Debug Script for Filter Issues
# This script tests the specific filter functions causing problems

library(DBI)
library(RPostgreSQL)
library(dplyr)

cat("🔍 Debugging Filter Issues\n")
cat(paste(rep("=", 40), collapse = ""), "\n")

# Load configuration and utilities
source("config/cloud_config.R")
source("utils/database.R")

# Test 1: Direct Database Connection
cat("\n📡 Testing direct database connection...\n")
tryCatch({
  con <- dbConnect(
    RPostgreSQL::PostgreSQL(),
    host = db_config$host,
    dbname = db_config$dbname,
    user = db_config$user,
    password = db_config$password
  )
  
  # Test gender data directly
  cat("🔍 Testing gender data directly...\n")
  gender_direct <- dbGetQuery(con, "
    SELECT 
      gender,
      COUNT(*) as book_count,
      COUNT(DISTINCT author_id) as unique_authors
    FROM book_entries 
    WHERE gender IS NOT NULL 
    GROUP BY gender
    ORDER BY book_count DESC
  ")
  
  cat("Direct gender query results:\n")
  print(gender_direct)
  
  # Test filter options
  cat("\n🔍 Testing filter options...\n")
  genres_direct <- dbGetQuery(con, "SELECT DISTINCT genre FROM book_entries WHERE genre IS NOT NULL ORDER BY genre LIMIT 10")
  cat("Sample genres:", paste(genres_direct$genre, collapse = ", "), "\n")
  
  publishers_direct <- dbGetQuery(con, "SELECT DISTINCT publisher FROM book_entries WHERE publisher IS NOT NULL ORDER BY publisher LIMIT 5")
  cat("Sample publishers:", paste(publishers_direct$publisher, collapse = ", "), "\n")
  
  # Test search_books function components
  cat("\n🔍 Testing search_books query components...\n")
  
  # Test basic book query
  basic_books <- dbGetQuery(con, "
    SELECT 
      be.book_id,
      be.author_surname,
      be.gender,
      be.book_title,
      be.genre,
      be.publisher,
      be.publication_year,
      COALESCE(bs.total_sales, 0) as total_sales
    FROM book_entries be
    LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
    WHERE be.gender = 'Male'
    LIMIT 5
  ")
  
  cat("Sample books with Male gender filter:\n")
  print(basic_books[, c("book_id", "author_surname", "gender", "book_title")])
  
  # Test genre filter
  genre_books <- dbGetQuery(con, "
    SELECT book_id, book_title, genre
    FROM book_entries 
    WHERE genre = 'Novel'
    LIMIT 5
  ")
  
  cat("\nSample books with Novel genre filter:\n")
  print(genre_books)
  
  dbDisconnect(con)
  
}, error = function(e) {
  cat("❌ Direct database test failed:", e$message, "\n")
})

# Test 2: Database Utility Functions
cat("\n🔧 Testing database utility functions...\n")

# Test get_filter_options
cat("Testing get_filter_options()...\n")
filter_opts <- tryCatch({
  get_filter_options()
}, error = function(e) {
  cat("❌ get_filter_options failed:", e$message, "\n")
  NULL
})

if (!is.null(filter_opts)) {
  cat("✅ Filter options loaded:\n")
  cat("- Genres found:", nrow(filter_opts$genres), "\n")
  cat("- Publishers found:", nrow(filter_opts$publishers), "\n")
  cat("- Genders found:", nrow(filter_opts$genders), "\n")
  
  if (nrow(filter_opts$genders) > 0) {
    cat("- Gender values:", paste(filter_opts$genders$gender, collapse = ", "), "\n")
  }
  
  if (nrow(filter_opts$genres) > 0) {
    cat("- Sample genres:", paste(head(filter_opts$genres$genre, 5), collapse = ", "), "\n")
  }
} else {
  cat("❌ Filter options failed to load\n")
}

# Test 3: Search Books Function
cat("\n📚 Testing search_books function...\n")

# Test with no filters
cat("Testing search_books with no filters...\n")
all_books <- tryCatch({
  search_books()
}, error = function(e) {
  cat("❌ search_books (no filters) failed:", e$message, "\n")
  NULL
})

if (!is.null(all_books) && nrow(all_books) > 0) {
  cat("✅ search_books (no filters) returned", nrow(all_books), "books\n")
  cat("Sample book:", all_books$book_title[1], "by", all_books$author_surname[1], "\n")
} else {
  cat("❌ search_books (no filters) returned no results\n")
}

# Test with gender filter
cat("\nTesting search_books with gender filter...\n")
male_books <- tryCatch({
  search_books(gender_filter = c("Male"))
}, error = function(e) {
  cat("❌ search_books (gender filter) failed:", e$message, "\n")
  NULL
})

if (!is.null(male_books) && nrow(male_books) > 0) {
  cat("✅ search_books (Male filter) returned", nrow(male_books), "books\n")
  unique_genders <- unique(male_books$gender)
  cat("Genders in results:", paste(unique_genders, collapse = ", "), "\n")
} else {
  cat("❌ search_books (Male filter) returned no results\n")
}

# Test with genre filter
cat("\nTesting search_books with genre filter...\n")
novel_books <- tryCatch({
  search_books(genre_filter = c("Novel"))
}, error = function(e) {
  cat("❌ search_books (genre filter) failed:", e$message, "\n")
  NULL
})

if (!is.null(novel_books) && nrow(novel_books) > 0) {
  cat("✅ search_books (Novel filter) returned", nrow(novel_books), "books\n")
  unique_genres <- unique(novel_books$genre)
  cat("Genres in results:", paste(unique_genres, collapse = ", "), "\n")
} else {
  cat("❌ search_books (Novel filter) returned no results\n")
}

# Test 4: Gender Analysis Function
cat("\n👥 Testing get_gender_analysis function...\n")
gender_analysis <- tryCatch({
  get_gender_analysis()
}, error = function(e) {
  cat("❌ get_gender_analysis failed:", e$message, "\n")
  NULL
})

if (!is.null(gender_analysis) && nrow(gender_analysis) > 0) {
  cat("✅ get_gender_analysis returned", nrow(gender_analysis), "rows\n")
  print(gender_analysis)
} else {
  cat("❌ get_gender_analysis returned no results\n")
}

cat("\n📋 Debug Summary:\n")
cat("- Check if direct database queries work\n")
cat("- Check if utility functions return data\n")
cat("- Check if search_books handles filters correctly\n")
cat("- Check if gender analysis returns proper values\n")

cat("\n🔧 Next Steps:\n")
cat("1. If direct queries work but utility functions don't, check safe_db_query\n")
cat("2. If gender analysis returns empty, check the query in get_gender_analysis\n")
cat("3. If search_books fails, check parameter handling\n")
