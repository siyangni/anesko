# Test Value Box Color Fix
# This script tests that value boxes use valid colors

library(shinydashboard)
library(shiny)

cat("🎨 Testing Value Box Color Fix\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Load global functions
source("global.R")

# Test the create_value_box function with different colors
cat("\n📦 Testing create_value_box function...\n")

# Test valid colors
valid_colors <- c("red", "yellow", "aqua", "blue", "light-blue", "green", 
                  "navy", "teal", "olive", "lime", "orange", "fuchsia", 
                  "purple", "maroon", "black")

cat("Valid colors for valueBox:", paste(valid_colors, collapse = ", "), "\n")

# Test each color
for (color in c("blue", "green", "navy", "orange")) {
  tryCatch({
    test_box <- create_value_box(
      value = "Test",
      subtitle = paste("Test", color, "box"),
      icon = "star",
      color = color
    )
    cat("✅", color, "color works\n")
  }, error = function(e) {
    cat("❌", color, "color failed:", e$message, "\n")
  })
}

# Test that hex colors would fail (but we don't use them anymore)
cat("\n🚫 Testing that hex colors would fail (for reference)...\n")
tryCatch({
  test_hex <- valueBox(
    value = "Test",
    subtitle = "Test hex color",
    icon = icon("star"),
    color = "#4C78A8"  # This should fail
  )
  cat("❌ Hex color unexpectedly worked\n")
}, error = function(e) {
  cat("✅ Hex color correctly failed:", e$message, "\n")
})

cat("\n🎯 Value box color test completed!\n")
cat("All value boxes should now use valid named colors.\n")
