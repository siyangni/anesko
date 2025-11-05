# Test Enhanced Error Handling for Genre Analysis
# This script tests the new error handling improvements

library(dplyr)
library(shiny)

cat("🔧 Testing Enhanced Error Handling\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Load configuration and utilities
source("config/cloud_config.R")
source("utils/database.R")
source("utils/error_handling.R")
source("utils/plotting.R")

# Test 1: Test parameter validation
cat("\n📋 Testing parameter validation...\n")
tryCatch({
  # Test with invalid date range
  validation1 <- validate_analysis_params(
    genre_filter = "Novel",
    binding_filter = "",
    gender_filter = "",
    start_year = 1900,
    end_year = 1895,  # Invalid: end before start
    analysis_type = "distribution"
  )
  
  if (!validation1$valid) {
    cat("✅ Parameter validation correctly identified invalid date range\n")
    cat("Issues:", paste(validation1$issues, collapse = "; "), "\n")
    cat("Suggestions:", paste(validation1$suggestions, collapse = "; "), "\n")
  } else {
    cat("❌ Parameter validation failed to catch invalid date range\n")
  }
  
  # Test with valid parameters
  validation2 <- validate_analysis_params(
    genre_filter = "",
    binding_filter = "",
    gender_filter = "",
    start_year = 1860,
    end_year = 1920,
    analysis_type = "distribution"
  )
  
  if (validation2$valid) {
    cat("✅ Parameter validation correctly accepted valid parameters\n")
  } else {
    cat("❌ Parameter validation incorrectly rejected valid parameters\n")
  }
  
}, error = function(e) {
  cat("❌ Parameter validation test failed:", e$message, "\n")
})

# Test 2: Test data availability check
cat("\n📊 Testing data availability check...\n")
tryCatch({
  availability <- check_data_availability(
    genre_filter = "",  # All genres
    binding_filter = "",  # All bindings
    gender_filter = "",  # All genders
    start_year = 1860,
    end_year = 1920
  )
  
  if (availability$available && availability$count > 0) {
    cat("✅ Data availability check found", availability$count, "records\n")
  } else {
    cat("⚠️ No data available for default parameters\n")
    cat("This might indicate a database issue or very restrictive default filters\n")
  }
  
  # Test with very restrictive parameters
  availability_restrictive <- check_data_availability(
    genre_filter = "NonexistentGenre",
    binding_filter = "NonexistentBinding",
    gender_filter = "NonexistentGender",
    start_year = 1860,
    end_year = 1861
  )
  
  if (!availability_restrictive$available) {
    cat("✅ Data availability check correctly identified no data for restrictive filters\n")
  } else {
    cat("❌ Data availability check incorrectly found data for restrictive filters\n")
  }
  
}, error = function(e) {
  cat("❌ Data availability test failed:", e$message, "\n")
})

# Test 3: Test suggestion generation
cat("\n💡 Testing suggestion generation...\n")
tryCatch({
  suggestions <- generate_data_suggestions(
    genre_filter = "Novel",
    binding_filter = "Cloth",
    gender_filter = "Female",
    start_year = 1900,
    end_year = 1905
  )
  
  if (length(suggestions) > 0) {
    cat("✅ Suggestion generation created", length(suggestions), "suggestions:\n")
    for (i in seq_along(suggestions)) {
      cat("  ", i, ".", suggestions[i], "\n")
    }
  } else {
    cat("⚠️ No suggestions generated\n")
  }
  
}, error = function(e) {
  cat("❌ Suggestion generation test failed:", e$message, "\n")
})

# Test 4: Test context string creation
cat("\n📝 Testing context string creation...\n")
tryCatch({
  context1 <- create_context_string(
    genre_filter = "Novel",
    binding_filter = "Cloth",
    gender_filter = "Female",
    start_year = 1860,
    end_year = 1920
  )
  
  context2 <- create_context_string(
    genre_filter = "",
    binding_filter = "",
    gender_filter = "",
    start_year = 1860,
    end_year = 1920
  )
  
  cat("✅ Context string with filters:", context1, "\n")
  cat("✅ Context string without filters:", context2, "\n")
  
}, error = function(e) {
  cat("❌ Context string creation test failed:", e$message, "\n")
})

# Test 5: Test empty plot message creation
cat("\n🎨 Testing empty plot message creation...\n")
tryCatch({
  message1 <- create_empty_plot_message(
    base_message = "No data available",
    genre_filter = "Novel",
    binding_filter = "Cloth",
    gender_filter = "Female",
    start_year = 1900,
    end_year = 1905
  )
  
  message2 <- create_empty_plot_message(
    base_message = "No data available",
    genre_filter = "",
    binding_filter = "",
    gender_filter = "",
    start_year = 1860,
    end_year = 1920
  )
  
  cat("✅ Empty plot message with filters:\n")
  cat(message1, "\n\n")
  
  cat("✅ Empty plot message without filters:\n")
  cat(message2, "\n\n")
  
}, error = function(e) {
  cat("❌ Empty plot message creation test failed:", e$message, "\n")
})

# Test 6: Test enhanced safe_query
cat("\n🔒 Testing enhanced safe_query...\n")
tryCatch({
  # Test with successful query
  result1 <- safe_query_enhanced(
    function() data.frame(test = 1:3, value = c("a", "b", "c")),
    default_value = data.frame(),
    error_message = "Test query failed",
    context = "test data",
    show_notification = FALSE
  )
  
  if (nrow(result1) == 3) {
    cat("✅ Enhanced safe_query works with successful queries\n")
  } else {
    cat("❌ Enhanced safe_query failed with successful queries\n")
  }
  
  # Test with failing query
  result2 <- safe_query_enhanced(
    function() stop("Simulated error"),
    default_value = data.frame(error = "default"),
    error_message = "Test query failed",
    context = "test data",
    show_notification = FALSE
  )
  
  if (nrow(result2) == 1 && "error" %in% names(result2)) {
    cat("✅ Enhanced safe_query correctly handles errors\n")
  } else {
    cat("❌ Enhanced safe_query failed to handle errors correctly\n")
  }
  
}, error = function(e) {
  cat("❌ Enhanced safe_query test failed:", e$message, "\n")
})

cat("\n🎯 Error handling tests completed!\n")
cat("The enhanced error handling should now provide better user feedback\n")
cat("when the genre analysis module encounters issues.\n")
