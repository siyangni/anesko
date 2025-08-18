# Test Sales Analysis Module with Dropdowns
library(shiny)
library(shinydashboard)
library(DT)
library(plotly)

cat("🚀 Testing Sales Analysis Module with Dropdowns\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Load all required components
source("config/cloud_config.R")
source("utils/database.R")
source("utils/data_processing.R")
source("utils/plotting.R")
source("modules/sales_analysis_module.R")

# Test the module functions directly
cat("\n📊 Testing dropdown initialization...\n")

# Test that the new database functions work
titles <- get_book_titles()
bindings <- get_binding_states()

cat("✅ Book titles available:", nrow(titles), "\n")
cat("✅ Binding states available:", nrow(bindings), "\n")

# Test a sample analysis with dropdown values
if (nrow(titles) > 0 && nrow(bindings) > 0) {
  sample_title <- titles$book_title[1]
  sample_binding <- bindings$binding[1]
  
  cat("\n🔍 Testing analysis with sample values:\n")
  cat("  Book Title:", sample_title, "\n")
  cat("  Binding State:", sample_binding, "\n")
  
  # Test the analysis function
  result <- tryCatch({
    get_book_sales_by_title_binding(sample_title, sample_binding, 1860, 1920)
  }, error = function(e) {
    cat("❌ Analysis error:", e$message, "\n")
    NULL
  })
  
  if (!is.null(result)) {
    cat("✅ Analysis successful! Found", nrow(result), "results\n")
  }
}

cat("\n✨ Dropdown test completed!\n")

# Create a minimal test app
cat("\n🌐 Creating test Shiny app...\n")

ui <- dashboardPage(
  dashboardHeader(title = "Sales Analysis Test"),
  dashboardSidebar(disable = TRUE),
  dashboardBody(
    salesAnalysisUI("test")
  )
)

server <- function(input, output, session) {
  salesAnalysisServer("test")
}

cat("✅ Test app created successfully!\n")
cat("📝 To run the app, use: shiny::runApp(list(ui = ui, server = server))\n")
