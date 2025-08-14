# NeonDB Verification Script
# This script verifies the database migration and data integrity

library(DBI)
library(RPostgreSQL)
library(dplyr)

cat("🔍 Starting NeonDB Verification\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

# NeonDB Configuration (same as import script)
neondb_config <- list(
  host = Sys.getenv("NEONDB_HOST", "your-neondb-host.neon.tech"),
  dbname = Sys.getenv("NEONDB_NAME", "neondb"),
  user = Sys.getenv("NEONDB_USER", "neondb_owner"),
  password = Sys.getenv("NEONDB_PASSWORD", "your-password"),
  port = as.numeric(Sys.getenv("NEONDB_PORT", "5432"))
)

# Connect to NeonDB
cat("📡 Connecting to NeonDB...\n")
neon_con <- tryCatch({
  dbConnect(
    RPostgreSQL::PostgreSQL(),
    host = neondb_config$host,
    dbname = neondb_config$dbname,
    user = neondb_config$user,
    password = neondb_config$password,
    port = neondb_config$port
  )
}, error = function(e) {
  stop("❌ Failed to connect to NeonDB: ", e$message)
})

cat("✅ Connected to NeonDB\n")

# Verification Tests
verification_results <- list()

# Test 1: Table Existence and Row Counts
cat("\n📊 Test 1: Table Existence and Row Counts\n")
expected_tables <- c("book_entries", "royalty_tiers", "book_sales", "book_sales_summary")

table_verification <- data.frame(
  table = character(),
  exists = logical(),
  row_count = integer(),
  status = character(),
  stringsAsFactors = FALSE
)

for (table in expected_tables) {
  tryCatch({
    # Check if table exists
    exists_query <- paste0("
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = '", table, "'
      )
    ")
    
    table_exists <- dbGetQuery(neon_con, exists_query)[[1]]
    
    if (table_exists) {
      # Get row count
      count_result <- dbGetQuery(neon_con, paste("SELECT COUNT(*) as count FROM", table))
      row_count <- count_result$count
      status <- if (row_count > 0) "✅ OK" else "⚠️  Empty"
    } else {
      row_count <- 0
      status <- "❌ Missing"
    }
    
    table_verification <- rbind(table_verification, data.frame(
      table = table,
      exists = table_exists,
      row_count = row_count,
      status = status,
      stringsAsFactors = FALSE
    ))
    
    cat("  ", table, ":", if (table_exists) paste(row_count, "rows") else "Missing", "\n")
    
  }, error = function(e) {
    table_verification <<- rbind(table_verification, data.frame(
      table = table,
      exists = FALSE,
      row_count = 0,
      status = "❌ Error",
      stringsAsFactors = FALSE
    ))
    cat("  ", table, ": Error -", e$message, "\n")
  })
}

verification_results$tables <- table_verification

# Test 2: Data Integrity Checks
cat("\n🔍 Test 2: Data Integrity Checks\n")

integrity_tests <- list()

# Test 2.1: Foreign Key Relationships
cat("  Testing foreign key relationships...\n")
tryCatch({
  # Check book_entries -> royalty_tiers relationship
  orphaned_royalty <- dbGetQuery(neon_con, "
    SELECT COUNT(*) as count
    FROM royalty_tiers rt
    LEFT JOIN book_entries be ON rt.book_id = be.book_id
    WHERE be.book_id IS NULL
  ")
  
  integrity_tests$orphaned_royalty_tiers <- orphaned_royalty$count
  cat("    Orphaned royalty tiers:", orphaned_royalty$count, "\n")
  
  # Check book_entries -> book_sales relationship
  orphaned_sales <- dbGetQuery(neon_con, "
    SELECT COUNT(*) as count
    FROM book_sales bs
    LEFT JOIN book_entries be ON bs.book_id = be.book_id
    WHERE be.book_id IS NULL
  ")
  
  integrity_tests$orphaned_sales <- orphaned_sales$count
  cat("    Orphaned book sales:", orphaned_sales$count, "\n")
  
}, error = function(e) {
  cat("    ❌ Foreign key test failed:", e$message, "\n")
  integrity_tests$foreign_key_error <- e$message
})

# Test 2.2: Data Completeness
cat("  Testing data completeness...\n")
tryCatch({
  # Check for NULL values in critical fields
  null_book_ids <- dbGetQuery(neon_con, "
    SELECT COUNT(*) as count FROM book_entries WHERE book_id IS NULL
  ")
  integrity_tests$null_book_ids <- null_book_ids$count
  
  null_titles <- dbGetQuery(neon_con, "
    SELECT COUNT(*) as count FROM book_entries WHERE book_title IS NULL OR book_title = ''
  ")
  integrity_tests$null_titles <- null_titles$count
  
  cat("    NULL book IDs:", null_book_ids$count, "\n")
  cat("    NULL/empty titles:", null_titles$count, "\n")
  
}, error = function(e) {
  cat("    ❌ Completeness test failed:", e$message, "\n")
})

verification_results$integrity <- integrity_tests

# Test 3: Sliding Scale Data Verification
cat("\n🎯 Test 3: Sliding Scale Data Verification\n")
tryCatch({
  sliding_scale_summary <- dbGetQuery(neon_con, "
    SELECT 
      sliding_scale,
      COUNT(*) as count,
      COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage
    FROM royalty_tiers 
    GROUP BY sliding_scale
    ORDER BY sliding_scale
  ")
  
  cat("    Sliding scale distribution:\n")
  print(sliding_scale_summary)
  
  # Check for the expected sliding scale data
  true_count <- sum(sliding_scale_summary$count[sliding_scale_summary$sliding_scale == TRUE], na.rm = TRUE)
  false_count <- sum(sliding_scale_summary$count[sliding_scale_summary$sliding_scale == FALSE], na.rm = TRUE)
  
  verification_results$sliding_scale <- list(
    true_count = true_count,
    false_count = false_count,
    total = true_count + false_count
  )
  
  if (true_count > 0) {
    cat("    ✅ Sliding scale data looks correct\n")
  } else {
    cat("    ⚠️  No sliding scale TRUE records found\n")
  }
  
}, error = function(e) {
  cat("    ❌ Sliding scale test failed:", e$message, "\n")
})

# Test 4: Sample Queries (Application Functionality)
cat("\n🧪 Test 4: Sample Application Queries\n")

# Test 4.1: Author Networks Query
cat("  Testing author networks query...\n")
tryCatch({
  author_network_sample <- dbGetQuery(neon_con, "
    SELECT 
      be.author_id,
      be.author_surname,
      COUNT(DISTINCT be.book_id) as book_count,
      COUNT(DISTINCT be.publisher) as publisher_count
    FROM book_entries be
    WHERE be.publication_year BETWEEN 1860 AND 1920
    GROUP BY be.author_id, be.author_surname
    HAVING COUNT(DISTINCT be.book_id) > 1
    ORDER BY book_count DESC
    LIMIT 5
  ")
  
  if (nrow(author_network_sample) > 0) {
    cat("    ✅ Author networks query successful\n")
    cat("    Sample results:\n")
    print(author_network_sample)
  } else {
    cat("    ⚠️  Author networks query returned no results\n")
  }
  
  verification_results$author_networks <- nrow(author_network_sample) > 0
  
}, error = function(e) {
  cat("    ❌ Author networks query failed:", e$message, "\n")
  verification_results$author_networks <- FALSE
})

# Test 4.2: Royalty Analysis Query
cat("  Testing royalty analysis query...\n")
tryCatch({
  royalty_analysis_sample <- dbGetQuery(neon_con, "
    SELECT 
      rt.tier,
      COUNT(*) as tier_count,
      AVG(rt.rate) as avg_rate,
      COUNT(CASE WHEN rt.sliding_scale = TRUE THEN 1 END) as sliding_scale_count
    FROM royalty_tiers rt
    JOIN book_entries be ON rt.book_id = be.book_id
    WHERE be.publication_year BETWEEN 1860 AND 1920
    GROUP BY rt.tier
    ORDER BY rt.tier
  ")
  
  if (nrow(royalty_analysis_sample) > 0) {
    cat("    ✅ Royalty analysis query successful\n")
    cat("    Sample results:\n")
    print(royalty_analysis_sample)
  } else {
    cat("    ⚠️  Royalty analysis query returned no results\n")
  }
  
  verification_results$royalty_analysis <- nrow(royalty_analysis_sample) > 0
  
}, error = function(e) {
  cat("    ❌ Royalty analysis query failed:", e$message, "\n")
  verification_results$royalty_analysis <- FALSE
})

# Test 4.3: Sliding Scale Filter Query
cat("  Testing sliding scale filter query...\n")
tryCatch({
  sliding_scale_filter_sample <- dbGetQuery(neon_con, "
    SELECT 
      rt.book_id,
      be.book_title,
      be.author_surname,
      rt.tier,
      rt.rate,
      rt.sliding_scale
    FROM royalty_tiers rt
    JOIN book_entries be ON rt.book_id = be.book_id
    WHERE be.publication_year BETWEEN 1860 AND 1920
      AND rt.sliding_scale = TRUE
    LIMIT 5
  ")
  
  if (nrow(sliding_scale_filter_sample) > 0) {
    cat("    ✅ Sliding scale filter query successful\n")
    cat("    Sample results:\n")
    print(sliding_scale_filter_sample)
  } else {
    cat("    ⚠️  Sliding scale filter query returned no results\n")
  }
  
  verification_results$sliding_scale_filter <- nrow(sliding_scale_filter_sample) > 0
  
}, error = function(e) {
  cat("    ❌ Sliding scale filter query failed:", e$message, "\n")
  verification_results$sliding_scale_filter <- FALSE
})

# Close connection
dbDisconnect(neon_con)

# Final Verification Summary
cat("\n📈 Verification Summary\n")
cat(paste(rep("-", 40), collapse = ""), "\n")

# Table summary
cat("Tables:\n")
for (i in 1:nrow(table_verification)) {
  row <- table_verification[i, ]
  cat("  ", row$table, ":", row$status, 
      if (row$exists) paste("(", row$row_count, "rows)") else "", "\n")
}

# Integrity summary
cat("\nData Integrity:\n")
if (length(integrity_tests) > 0) {
  if (!is.null(integrity_tests$orphaned_royalty_tiers)) {
    cat("  Orphaned royalty tiers:", integrity_tests$orphaned_royalty_tiers, "\n")
  }
  if (!is.null(integrity_tests$orphaned_sales)) {
    cat("  Orphaned sales records:", integrity_tests$orphaned_sales, "\n")
  }
  if (!is.null(integrity_tests$null_book_ids)) {
    cat("  NULL book IDs:", integrity_tests$null_book_ids, "\n")
  }
}

# Application functionality summary
cat("\nApplication Functionality:\n")
cat("  Author networks query:", if (verification_results$author_networks) "✅ OK" else "❌ Failed", "\n")
cat("  Royalty analysis query:", if (verification_results$royalty_analysis) "✅ OK" else "❌ Failed", "\n")
cat("  Sliding scale filter:", if (verification_results$sliding_scale_filter) "✅ OK" else "❌ Failed", "\n")

# Overall assessment
successful_tables <- sum(table_verification$status == "✅ OK")
total_tables <- nrow(table_verification)
functional_tests_passed <- sum(c(
  verification_results$author_networks,
  verification_results$royalty_analysis,
  verification_results$sliding_scale_filter
), na.rm = TRUE)

cat("\n🎯 Overall Assessment:\n")
cat("  Tables:", successful_tables, "of", total_tables, "successful\n")
cat("  Functional tests:", functional_tests_passed, "of 3 passed\n")

if (successful_tables == total_tables && functional_tests_passed == 3) {
  cat("\n🎉 ✅ NeonDB migration verification PASSED!\n")
  cat("Your database is ready for production use.\n")
  cat("\n💡 Next steps:\n")
  cat("   1. Update your application configuration\n")
  cat("   2. Run 04_prepare_app_config.R\n")
  cat("   3. Test the application locally with NeonDB\n")
} else {
  cat("\n⚠️  NeonDB migration verification has issues.\n")
  cat("Please review the results above and fix any problems before proceeding.\n")
  
  if (successful_tables < total_tables) {
    cat("\n🔧 Table issues detected. Consider:\n")
    cat("   - Re-running the import script\n")
    cat("   - Checking NeonDB permissions\n")
    cat("   - Manual data verification\n")
  }
  
  if (functional_tests_passed < 3) {
    cat("\n🔧 Functional test issues detected. Consider:\n")
    cat("   - Checking data relationships\n")
    cat("   - Verifying sliding scale data migration\n")
    cat("   - Testing queries manually in NeonDB console\n")
  }
}
