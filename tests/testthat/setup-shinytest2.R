# Setup for shinytest2 UI tests
# This file configures shinytest2 testing environment

# Check if shinytest2 is installed
if (requireNamespace("shinytest2", quietly = TRUE)) {
  # Configure shinytest2 options
  options(
    shinytest2.debug = FALSE,
    shinytest2.load_timeout = 10000,  # 10 seconds
    shinytest2.browser = "chromote"  # Use headless Chrome
  )

  # Set screenshot comparison threshold
  options(shinytest2.snapshot_tolerance = 0.05)  # 5% difference allowed

  cat("✓ shinytest2 configured for UI testing\n")
} else {
  cat("⚠ shinytest2 not installed. UI tests will be skipped.\n")
  cat("Install with: install.packages('shinytest2')\n")
}
