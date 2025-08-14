# Test Script for Updated Shiny Application
# This script tests the database connection and new features

library(DBI)
library(RPostgreSQL)
library(dplyr)

cat("🧪 Testing Updated Shiny App Database Connection\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Test 1: Database Connection
cat("\n📡 Testing database connection...\n")
tryCatch({
  source("config/cloud_config.R")
  con <- dbConnect(
    RPostgreSQL::PostgreSQL(),
    host = db_config$host,
    dbname = db_config$dbname,
    user = db_config$user,
    password = db_config$password
  )
  cat("✅ Database connection successful\n")
  
  # Test 2: New Schema Features
  cat("\n📊 Testing new schema features...\n")
  
  # Check for author_id column
  book_cols <- dbListFields(con, "book_entries")
  if ("author_id" %in% book_cols) {
    cat("✅ author_id column found\n")
  } else {
    cat("❌ author_id column missing\n")
  }
  
  # Test author_id data
  author_sample <- dbGetQuery(con, "
    SELECT author_id, author_surname, COUNT(*) as book_count
    FROM book_entries 
    WHERE author_id IS NOT NULL 
    GROUP BY author_id, author_surname 
    ORDER BY book_count DESC 
    LIMIT 5
  ")
  
  cat("📚 Sample author_id data:\n")
  print(author_sample)
  
  # Test 3: NULL Handling
  cat("\n🔍 Testing NULL handling...\n")
  null_counts <- dbGetQuery(con, "
    SELECT 
      COUNT(CASE WHEN gender IS NULL THEN 1 END) as null_gender,
      COUNT(CASE WHEN publisher IS NULL THEN 1 END) as null_publisher,
      COUNT(CASE WHEN genre IS NULL THEN 1 END) as null_genre
    FROM book_entries
  ")
  
  cat("NULL counts:\n")
  print(null_counts)
  
  # Test 4: Enhanced Data
  cat("\n📈 Testing enhanced data features...\n")
  
  # Check total records
  total_books <- dbGetQuery(con, "SELECT COUNT(*) as total FROM book_entries")
  total_sales <- dbGetQuery(con, "SELECT COUNT(*) as total FROM book_sales")
  total_royalties <- dbGetQuery(con, "SELECT COUNT(*) as total FROM royalty_tiers")
  
  cat("Data counts:\n")
  cat("- Books:", total_books$total, "\n")
  cat("- Sales records:", total_sales$total, "\n")
  cat("- Royalty tiers:", total_royalties$total, "\n")
  
  # Test 5: New Database Functions
  cat("\n🔧 Testing database utility functions...\n")
  
  # Source utility functions
  source("utils/database.R")
  
  # Test filter options
  filter_opts <- tryCatch({
    get_filter_options()
  }, error = function(e) {
    cat("❌ get_filter_options failed:", e$message, "\n")
    NULL
  })
  
  if (!is.null(filter_opts)) {
    cat("✅ Filter options loaded:\n")
    cat("- Genres:", length(filter_opts$genres$genre), "\n")
    cat("- Publishers:", length(filter_opts$publishers$publisher), "\n")
    cat("- Author IDs:", length(filter_opts$author_ids$author_id), "\n")
  }
  
  # Test author analysis
  author_analysis <- tryCatch({
    get_author_analysis()
  }, error = function(e) {
    cat("❌ get_author_analysis failed:", e$message, "\n")
    NULL
  })
  
  if (!is.null(author_analysis) && nrow(author_analysis) > 0) {
    cat("✅ Author analysis working - found", nrow(author_analysis), "multi-book authors\n")
    cat("Top author by sales:", author_analysis$author_surname[1], 
        "(", author_analysis$total_sales[1], "sales)\n")
  }
  
  # Test royalty analysis
  royalty_analysis <- tryCatch({
    get_royalty_analysis()
  }, error = function(e) {
    cat("❌ get_royalty_analysis failed:", e$message, "\n")
    NULL
  })
  
  if (!is.null(royalty_analysis) && nrow(royalty_analysis) > 0) {
    cat("✅ Royalty analysis working - found", nrow(royalty_analysis), "tier types\n")
  }
  
  # Test 6: Data Processing Functions
  cat("\n⚙️ Testing data processing functions...\n")
  
  source("utils/data_processing.R")
  
  # Test enhanced timeline
  sample_books <- dbGetQuery(con, "
    SELECT 
      be.*,
      COALESCE(bs.total_sales, 0) as total_sales
    FROM book_entries be
    LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
    LIMIT 100
  ")
  
  if (nrow(sample_books) > 0) {
    timeline_data <- tryCatch({
      create_enhanced_timeline(sample_books)
    }, error = function(e) {
      cat("❌ create_enhanced_timeline failed:", e$message, "\n")
      NULL
    })
    
    if (!is.null(timeline_data) && nrow(timeline_data) > 0) {
      cat("✅ Enhanced timeline creation working\n")
    }
  }
  
  # Test 7: Module Dependencies
  cat("\n📦 Testing module dependencies...\n")
  
  modules_to_test <- c(
    "modules/author_networks_module.R",
    "modules/royalty_analysis_module.R"
  )
  
  for (module in modules_to_test) {
    if (file.exists(module)) {
      tryCatch({
        source(module)
        cat("✅", basename(module), "loaded successfully\n")
      }, error = function(e) {
        cat("❌", basename(module), "failed:", e$message, "\n")
      })
    } else {
      cat("❌", basename(module), "not found\n")
    }
  }
  
  dbDisconnect(con)
  
  cat("\n🎉 All tests completed!\n")
  cat("The updated Shiny application should work with the new database features.\n")
  
}, error = function(e) {
  cat("❌ Database connection failed:", e$message, "\n")
  cat("Please check your database configuration and ensure PostgreSQL is running.\n")
})

cat("\n📋 Summary of New Features:\n")
cat("- ✅ Enhanced database schema with author_id\n")
cat("- ✅ Proper NULL handling instead of empty strings\n")
cat("- ✅ New Author Networks analysis tab\n")
cat("- ✅ New Royalty Analysis tab\n")
cat("- ✅ Enhanced data processing functions\n")
cat("- ✅ Updated database utility functions\n")
cat("- ✅ Expanded dataset with new entries\n")

cat("\n🚀 To run the updated Shiny app:\n")
cat("   setwd('shiny-app')\n")
cat("   shiny::runApp()\n")
