# Test minimal syntax to isolate the issue
cat("🔧 Testing Minimal Syntax\n")

# Try to parse just the UI function
ui_lines <- readLines("modules/sales_analysis_module.R")[1:110]
writeLines(ui_lines, "temp_ui_only.R")

ui_result <- tryCatch({
  parse("temp_ui_only.R")
  cat("✅ UI function parses OK\n")
  TRUE
}, error = function(e) {
  cat("❌ UI function error:", e$message, "\n")
  FALSE
})

# Try to parse just the server function
server_lines <- readLines("modules/sales_analysis_module.R")[111:347]
# Add the closing brace for the UI function
server_content <- c("# Server function only", server_lines)
writeLines(server_content, "temp_server_only.R")

server_result <- tryCatch({
  parse("temp_server_only.R")
  cat("✅ Server function parses OK\n")
  TRUE
}, error = function(e) {
  cat("❌ Server function error:", e$message, "\n")
  FALSE
})

# Clean up temp files
file.remove("temp_ui_only.R")
file.remove("temp_server_only.R")

if (ui_result && server_result) {
  cat("✅ Both parts parse individually - issue might be in combination\n")
} else {
  cat("❌ Found the problematic section\n")
}

cat("✨ Minimal test completed!\n")
