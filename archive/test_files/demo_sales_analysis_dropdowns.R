# Demo: Sales Analysis with Dropdown Menus
# This script demonstrates the new dropdown functionality

library(shiny)
library(shinydashboard)
library(DT)
library(plotly)

cat("🎯 Sales Analysis Dropdown Demo\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Load all required components
source("config/cloud_config.R")
source("utils/database.R")
source("utils/data_processing.R")
source("utils/plotting.R")
source("modules/sales_analysis_module.R")

cat("\n📊 Available Data:\n")
titles <- get_book_titles()
bindings <- get_binding_states()

cat("✅ Book Titles:", nrow(titles), "available\n")
cat("✅ Binding States:", nrow(bindings), "available\n")

cat("\nSample Book Titles:\n")
for(i in 1:min(10, nrow(titles))) {
  cat("  •", titles$book_title[i], "\n")
}

cat("\nAvailable Binding States:\n")
for(i in 1:nrow(bindings)) {
  cat("  •", bindings$binding[i], "\n")
}

cat("\n🚀 Starting Shiny Demo App...\n")
cat("The app will open with dropdown menus that allow you to:\n")
cat("  • Click to select from available options\n")
cat("  • Type to search and filter options\n")
cat("  • Use both book titles and binding states\n")

# Create demo app
ui <- dashboardPage(
  dashboardHeader(title = "Sales Analysis - Dropdown Demo"),
  dashboardSidebar(disable = TRUE),
  dashboardBody(
    tags$head(
      tags$style(HTML("
        .content-wrapper, .right-side {
          background-color: #f4f4f4;
        }
      "))
    ),
    
    fluidRow(
      column(12,
        box(
          title = "📋 How to Use the New Dropdowns", 
          status = "info", 
          solidHeader = TRUE,
          width = NULL,
          p("The Book Title and Binding State fields now have enhanced dropdown functionality:"),
          tags$ul(
            tags$li("🖱️ Click the dropdown to see all available options"),
            tags$li("⌨️ Type to search and filter the options in real-time"),
            tags$li("📝 Select exact matches for precise analysis"),
            tags$li("🔍 Use the search functionality to quickly find specific titles")
          ),
          p(strong("Available Data:"), 
            paste0(nrow(titles), " book titles and ", nrow(bindings), " binding states"))
        )
      )
    ),
    
    salesAnalysisUI("demo")
  )
)

server <- function(input, output, session) {
  salesAnalysisServer("demo")
}

# Run the app
cat("\n🌐 Launching demo app...\n")
shinyApp(ui = ui, server = server)
