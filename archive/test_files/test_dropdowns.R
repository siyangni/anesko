# Test dropdown functionality for Sales Analysis
library(shiny)

cat("🔧 Testing Sales Analysis Dropdown Functions\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Load required components
source("config/cloud_config.R")
source("utils/database.R")

# Test the new functions
cat("\n📊 Testing get_book_titles()...\n")
titles <- tryCatch({
  get_book_titles()
}, error = function(e) {
  cat("❌ Error:", e$message, "\n")
  NULL
})

if (!is.null(titles) && nrow(titles) > 0) {
  cat("✅ Found", nrow(titles), "unique book titles\n")
  cat("Sample titles:\n")
  for(i in 1:min(5, nrow(titles))) {
    cat("  ", titles$book_title[i], "\n")
  }
} else {
  cat("❌ No book titles found\n")
}

cat("\n📊 Testing get_binding_states()...\n")
bindings <- tryCatch({
  get_binding_states()
}, error = function(e) {
  cat("❌ Error:", e$message, "\n")
  NULL
})

if (!is.null(bindings) && nrow(bindings) > 0) {
  cat("✅ Found", nrow(bindings), "unique binding states\n")
  cat("All binding states:\n")
  for(i in 1:nrow(bindings)) {
    cat("  ", bindings$binding[i], "\n")
  }
} else {
  cat("❌ No binding states found\n")
}

cat("\n✨ Test completed!\n")
