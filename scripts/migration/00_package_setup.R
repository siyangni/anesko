# R Package Installation Script for American Authorship Database
# Run this in your R console in WSL2

# Core database packages
install.packages(c(
  "DBI",           # Database interface
  "RPostgreSQL",   # PostgreSQL driver
  "pool"           # Connection pooling for Shiny
))

# Data manipulation and analysis
install.packages(c(
  "dplyr",         # Data manipulation
  "tidyr",         # Data tidying  
  "readxl",        # Reading Excel files
  "stringr",       # String manipulation
  "lubridate",     # Date manipulation
  "purrr",         # Functional programming
  "glue"           # String interpolation
))

# Visualization and Shiny
install.packages(c(
  "ggplot2",       # Grammar of graphics
  "plotly",        # Interactive plots
  "shiny",         # Web applications
  "shinydashboard", # Dashboard framework
  "DT",            # Interactive tables
  "corrplot",      # Correlation plots
  "ggcorrplot"     # ggplot2 correlation plots
))

# Statistical analysis
install.packages(c(
  "broom",         # Tidy statistical output
  "modelr",        # Modeling functions
  "survival",      # Survival analysis (for author career analysis)
  "forecast",      # Time series forecasting
  "tseries"        # Time series analysis
))

# Academic research specific
install.packages(c(
  "knitr",         # Report generation
  "rmarkdown",     # R Markdown documents
  "papaja",        # APA manuscripts
  "stargazer",     # Publication-ready tables
  "gt",            # Grammar of tables
  "flextable"      # Flexible tables
))

# Advanced analysis (optional)
install.packages(c(
  "dbplyr",        # Database backend for dplyr
  "RSQLite",       # SQLite support (backup option)
  "httr",          # HTTP requests (for APIs)
  "jsonlite",      # JSON handling
  "xml2"           # XML parsing
))

# Check installation
required_packages <- c("DBI", "RPostgreSQL", "dplyr", "ggplot2", "shiny")
missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]

if(length(missing_packages) == 0) {
  cat("✅ All required packages installed successfully!\n")
  cat("🚀 Ready to start database migration and analysis!\n")
} else {
  cat("❌ Missing packages:", paste(missing_packages, collapse = ", "), "\n")
  cat("Please install missing packages before proceeding.\n")
}

# Test database connection
library(DBI)
library(RPostgreSQL)

# Replace with your actual credentials
test_connection <- function() {
  tryCatch({
    con <- dbConnect(
      RPostgreSQL::PostgreSQL(),
      host = "localhost",
      dbname = "american_authorship", 
      user = "your_username",
      password = "your_password"
    )
    
    if (dbIsValid(con)) {
      cat("✅ Database connection test successful!\n")
      dbDisconnect(con)
      return(TRUE)
    } else {
      cat("❌ Database connection failed!\n")
      return(FALSE)
    }
  }, error = function(e) {
    cat("❌ Database connection error:", e$message, "\n")
    cat("💡 Make sure PostgreSQL is running: sudo service postgresql start\n")
    return(FALSE)
  })
}

# Uncomment to test connection (after setting up database)
# test_connection()
