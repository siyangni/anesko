# Application Configuration Preparation for Cloud Deployment
# This script prepares the Shiny application for deployment to shinyapps.io

library(dplyr)

cat("⚙️  Preparing Application Configuration for Cloud Deployment\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

# Get NeonDB configuration
neondb_config <- list(
  host = Sys.getenv("NEONDB_HOST", "your-neondb-host.neon.tech"),
  dbname = Sys.getenv("NEONDB_NAME", "neondb"),
  user = Sys.getenv("NEONDB_USER", "neondb_owner"),
  password = Sys.getenv("NEONDB_PASSWORD", "your-password"),
  port = Sys.getenv("NEONDB_PORT", "5432")
)

# Validate configuration
if (neondb_config$host == "your-neondb-host.neon.tech" || 
    neondb_config$password == "your-password") {
  cat("❌ Please set NeonDB environment variables first:\n")
  cat("   export NEONDB_HOST=your-host.neon.tech\n")
  cat("   export NEONDB_NAME=neondb\n")
  cat("   export NEONDB_USER=neondb_owner\n")
  cat("   export NEONDB_PASSWORD=your-password\n")
  cat("   export NEONDB_PORT=5432\n")
  stop("NeonDB configuration required")
}

# 1. Create .env file for local testing
cat("📝 Creating .env file for local testing...\n")
env_content <- paste0(
  "# NeonDB Configuration for American Authorship Dashboard\n",
  "# Generated: ", Sys.time(), "\n",
  "\n",
  "DB_HOST=", neondb_config$host, "\n",
  "DB_NAME=", neondb_config$dbname, "\n",
  "DB_USER=", neondb_config$user, "\n",
  "DB_PASSWORD=", neondb_config$password, "\n",
  "DB_PORT=", neondb_config$port, "\n"
)

writeLines(env_content, "../shiny-app/.env")
cat("✅ Created .env file in shiny-app directory\n")

# 2. Create .env.template for documentation
cat("📝 Creating .env.template...\n")
template_content <- paste0(
  "# Environment Variables Template for American Authorship Dashboard\n",
  "# Copy this file to .env and fill in your actual values\n",
  "\n",
  "# NeonDB Configuration\n",
  "DB_HOST=your-neondb-host.neon.tech\n",
  "DB_NAME=neondb\n",
  "DB_USER=neondb_owner\n",
  "DB_PASSWORD=your-password\n",
  "DB_PORT=5432\n"
)

writeLines(template_content, ".env.template")
cat("✅ Created .env.template\n")

# 3. Update cloud_config.R for better production handling
cat("📝 Updating cloud_config.R...\n")
cloud_config_content <- '# Cloud Database Configuration
# This configuration loads database credentials from environment variables

# Load environment variables from .env file if it exists (for local testing)
if (file.exists(".env")) {
  env_vars <- readLines(".env")
  env_vars <- env_vars[!grepl("^#", env_vars) & env_vars != "" & !grepl("^\\\\s*$", env_vars)]
  
  for (var in env_vars) {
    if (nchar(trimws(var)) > 0 && grepl("=", var)) {
      parts <- strsplit(var, "=", fixed = TRUE)[[1]]
      if (length(parts) >= 2) {
        key <- trimws(parts[1])
        value <- trimws(paste(parts[-1], collapse = "="))
        if (nchar(key) > 0 && nchar(value) > 0) {
          do.call(Sys.setenv, setNames(list(value), key))
        }
      }
    }
  }
}

# Database configuration using environment variables
# Try local config first for development, then fall back to environment variables
config_paths <- c(
  "../../scripts/config/database_config.R",
  "../scripts/config/database_config.R",
  "scripts/config/database_config.R"
)

config_loaded <- FALSE
for (config_path in config_paths) {
  if (file.exists(config_path)) {
    source(config_path)
    cat("📁 Using local database config from", config_path, "\\n")
    config_loaded <- TRUE
    break
  }
}

if (!config_loaded) {
  # Production configuration using environment variables
  db_config <- list(
    host = Sys.getenv("DB_HOST"),
    dbname = Sys.getenv("DB_NAME"),
    user = Sys.getenv("DB_USER"),
    password = Sys.getenv("DB_PASSWORD"),
    port = as.numeric(Sys.getenv("DB_PORT", "5432"))
  )
  
  # Validate required environment variables
  required_vars <- c("DB_HOST", "DB_NAME", "DB_USER", "DB_PASSWORD")
  missing_vars <- required_vars[sapply(required_vars, function(x) Sys.getenv(x) == "")]
  
  if (length(missing_vars) > 0) {
    stop("Missing required environment variables: ", paste(missing_vars, collapse = ", "))
  }
  
  cat("🌐 Using environment variables for database config\\n")
}

cat("🔗 Database configuration loaded:\\n")
cat("   Host:", db_config$host, "\\n")
cat("   Database:", db_config$dbname, "\\n")
cat("   User:", db_config$user, "\\n")
cat("   Port:", db_config$port, "\\n")
'

writeLines(cloud_config_content, "../shiny-app/config/cloud_config.R")
cat("✅ Updated cloud_config.R\n")

# 4. Check and fix file paths in the application
cat("🔍 Checking file paths in application...\n")

# Get all R files in the shiny-app directory
r_files <- list.files("../shiny-app", pattern = "\\.R$", recursive = TRUE, full.names = TRUE)

path_issues <- c()

for (file in r_files) {
  content <- readLines(file, warn = FALSE)
  
  # Check for absolute paths
  absolute_paths <- grep("^[/~]|^[A-Za-z]:", content, value = TRUE)
  if (length(absolute_paths) > 0) {
    path_issues <- c(path_issues, paste(file, "- Absolute paths found"))
  }
  
  # Check for problematic relative paths
  problematic_paths <- grep("\\.\\./\\.\\./", content, value = TRUE)
  if (length(problematic_paths) > 0) {
    path_issues <- c(path_issues, paste(file, "- Deep relative paths found"))
  }
}

if (length(path_issues) > 0) {
  cat("⚠️  Path issues found:\n")
  for (issue in path_issues) {
    cat("   ", issue, "\n")
  }
  cat("💡 Please review and fix these paths before deployment\n")
} else {
  cat("✅ No obvious path issues found\n")
}

# 5. Create deployment-ready app.R
cat("📝 Creating deployment-ready app.R...\n")
app_r_content <- '# American Authorship Dashboard
# Shiny application for analyzing American authorship data (1860-1920)

library(shiny)
library(shinydashboard)
library(DT)
library(plotly)
library(dplyr)
library(ggplot2)
library(networkD3)
library(visNetwork)
library(RColorBrewer)
library(scales)

# Load configuration and utilities
source("config/cloud_config.R")
source("utils/database.R")
source("utils/data_processing.R")

# Load modules
source("modules/author_networks_module.R")
source("modules/royalty_analysis_module.R")

# Define UI
ui <- dashboardPage(
  dashboardHeader(title = "American Authorship Database (1860-1920)"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
      menuItem("Author Networks", tabName = "networks", icon = icon("project-diagram")),
      menuItem("Royalty Analysis", tabName = "royalty", icon = icon("chart-line")),
      menuItem("About", tabName = "about", icon = icon("info-circle"))
    )
  ),
  
  dashboardBody(
    tags$head(
      tags$style(HTML("
        .content-wrapper, .right-side {
          background-color: #f4f4f4;
        }
        .box {
          border-radius: 5px;
        }
        .info-box {
          border-radius: 5px;
        }
      "))
    ),
    
    tabItems(
      # Dashboard tab
      tabItem(tabName = "dashboard",
        fluidRow(
          box(
            title = "Welcome to the American Authorship Database", 
            status = "primary", 
            solidHeader = TRUE,
            width = 12,
            
            h4("Explore American Publishing History (1860-1920)"),
            p("This dashboard provides interactive analysis of American authorship data, including:"),
            tags$ul(
              tags$li("Author collaboration networks and publishing relationships"),
              tags$li("Royalty structure analysis and tier-based payment schemes"),
              tags$li("Publisher and genre distribution patterns"),
              tags$li("Sales data and market trends")
            ),
            
            br(),
            h5("Navigation:"),
            tags$ul(
              tags$li(strong("Author Networks:"), "Visualize connections between authors, publishers, and genres"),
              tags$li(strong("Royalty Analysis:"), "Analyze royalty rates, tier structures, and sliding scale contracts")
            )
          )
        )
      ),
      
      # Author Networks tab
      tabItem(tabName = "networks",
        author_networks_ui("author_networks")
      ),
      
      # Royalty Analysis tab
      tabItem(tabName = "royalty",
        royalty_analysis_ui("royalty_analysis")
      ),
      
      # About tab
      tabItem(tabName = "about",
        fluidRow(
          box(
            title = "About This Database", 
            status = "info", 
            solidHeader = TRUE,
            width = 12,
            
            h4("Data Source"),
            p("This database contains information about American authors and their publishing contracts from 1860-1920, providing insights into the business of literature during a crucial period in American publishing history."),
            
            h4("Technical Details"),
            p("Built with R Shiny and deployed on shinyapps.io with NeonDB (PostgreSQL) backend."),
            
            h4("Recent Updates"),
            tags$ul(
              tags$li("Fixed sliding scale royalty filter functionality"),
              tags$li("Enhanced error handling and user feedback"),
              tags$li("Improved database query performance"),
              tags$li("Added comprehensive data validation")
            )
          )
        )
      )
    )
  )
)

# Define server logic
server <- function(input, output, session) {
  # Call module servers
  author_networks_server("author_networks")
  royalty_analysis_server("royalty_analysis")
}

# Run the application
shinyApp(ui = ui, server = server)
'

writeLines(app_r_content, "../shiny-app/app.R")
cat("✅ Created deployment-ready app.R\n")

# 6. Create deployment checklist
cat("📝 Creating deployment checklist...\n")
checklist_content <- '# Deployment Checklist

## Pre-Deployment
- [ ] NeonDB database migrated and verified
- [ ] Environment variables configured
- [ ] Application tested locally with NeonDB
- [ ] All file paths are relative
- [ ] Dependencies listed in DESCRIPTION or requirements

## shinyapps.io Configuration
- [ ] rsconnect package installed
- [ ] shinyapps.io account configured
- [ ] Environment variables set in shinyapps.io dashboard:
  - [ ] DB_HOST
  - [ ] DB_NAME  
  - [ ] DB_USER
  - [ ] DB_PASSWORD
  - [ ] DB_PORT

## Post-Deployment Testing
- [ ] Application loads successfully
- [ ] Database connection works
- [ ] Author Networks module functional
- [ ] Royalty Analysis module functional
- [ ] Sliding scale filter works correctly
- [ ] All visualizations render properly
- [ ] Error handling works as expected

## Performance Monitoring
- [ ] Check application logs
- [ ] Monitor memory usage
- [ ] Verify query performance
- [ ] Test with multiple concurrent users
'

writeLines(checklist_content, "deployment_checklist.md")
cat("✅ Created deployment checklist\n")

cat("\n🎉 Application configuration preparation completed!\n")
cat("\n📁 Files created/updated:\n")
cat("   - ../shiny-app/.env (NeonDB credentials for local testing)\n")
cat("   - .env.template (template for environment variables)\n")
cat("   - ../shiny-app/config/cloud_config.R (updated)\n")
cat("   - ../shiny-app/app.R (deployment-ready)\n")
cat("   - deployment_checklist.md (deployment checklist)\n")

cat("\n💡 Next steps:\n")
cat("   1. Test the application locally with: cd ../shiny-app && R -e \"shiny::runApp()\"\n")
cat("   2. If local testing works, run 05_check_dependencies.R\n")
cat("   3. Then proceed with 06_deploy_to_shinyapps.R\n")

cat("\n⚠️  Important notes:\n")
cat("   - The .env file contains sensitive credentials - do not commit to version control\n")
cat("   - Environment variables must be set in shinyapps.io dashboard after deployment\n")
cat("   - Test all functionality locally before deploying to production\n")'
