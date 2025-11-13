# Deploy to ShinyApps.io
# Run this script to deploy your app to shinyapps.io

# Install required packages for deployment
if (!require("rsconnect")) {
  install.packages("rsconnect")
  library(rsconnect)
}

# ===== IMPORTANT: DATABASE SETUP =====
# ShinyApps.io doesn't support PostgreSQL directly
# You have 3 options:

# Option A: Use cloud PostgreSQL (Recommended)
# 1. Set up cloud PostgreSQL (see instructions below)
# 2. Update database credentials in environment variables

# Option B: Convert to SQLite (for smaller datasets)
# 1. Export PostgreSQL data to SQLite
# 2. Modify database connection code

# Option C: Use external database hosting
# 1. Use services like ElephantSQL, Amazon RDS, etc.

cat("📋 Pre-deployment checklist:\n")
cat("1. ✅ Set up cloud database or convert to SQLite\n")
cat("2. ✅ Update database credentials\n") 
cat("3. ✅ Test app locally with new database\n")
cat("4. ✅ Create ShinyApps.io account\n")
cat("5. ✅ Configure rsconnect authentication\n\n")

# Step 1: Set up your ShinyApps.io account
cat("🔑 Step 1: Configure ShinyApps.io authentication\n")
cat("Go to: https://www.shinyapps.io/admin/#/tokens\n")
cat("Copy your token and secret, then run:\n")
cat("rsconnect::setAccountInfo(name='your-username', token='your-token', secret='your-secret')\n\n")

# Step 2: Prepare environment variables for production
cat("🌍 Step 2: Set environment variables\n")
create_env_file <- function() {
  env_content <- '# Environment variables for production deployment
# Add your cloud database credentials here

DB_HOST=your-cloud-db-host.com
DB_NAME=american_authorship
DB_USER=your-db-username  
DB_PASSWORD=your-db-password
DB_PORT=5432

# Example for ElephantSQL:
# DB_HOST=bubble.db.elephantsql.com
# DB_NAME=your-instance-name
# DB_USER=your-instance-name
# DB_PASSWORD=your-elephantsql-password
'
  
  writeLines(env_content, ".env")
  cat("✅ Created .env file template\n")
  cat("📝 Edit .env with your actual database credentials\n\n")
}

create_env_file()

# Step 3: Update app configuration for deployment
cat("⚙️  Step 3: Update app configuration\n")

# Create production config
production_config <- '# Production database configuration
# This replaces the local database config for deployment

if (file.exists(".env")) {
  # Load environment variables from .env file
  env_vars <- readLines(".env")
  env_vars <- env_vars[!grepl("^#", env_vars) & env_vars != ""]
  
  for (var in env_vars) {
    parts <- strsplit(var, "=")[[1]]
    if (length(parts) == 2) {
      Sys.setenv(setNames(parts[2], parts[1]))
    }
  }
}

# Use environment variables for database connection
db_config <- list(
  host = Sys.getenv("DB_HOST", "localhost"),
  dbname = Sys.getenv("DB_NAME", "american_authorship"),
  user = Sys.getenv("DB_USER", ""),
  password = Sys.getenv("DB_PASSWORD", ""),
  port = as.numeric(Sys.getenv("DB_PORT", "5432"))
)

# Validate configuration
if (db_config$host == "localhost" || db_config$user == "" || db_config$password == "") {
  stop("Database credentials not properly configured. Please check your .env file or environment variables.")
}
'

writeLines(production_config, "config/production_config.R")
cat("✅ Created production configuration file\n\n")

# Step 4: Deploy the app
deploy_app <- function() {
  cat("🚀 Step 4: Deploy to ShinyApps.io\n")
  
  # Check if authenticated
  accounts <- rsconnect::accounts()
  if (nrow(accounts) == 0) {
    stop("❌ Please configure rsconnect authentication first!")
  }
  
  cat("📦 Deploying app...\n")
  
  # Deploy with specific files
  rsconnect::deployApp(
    appDir = ".",
    appName = "american-authorship-db",
    appTitle = "American Authorship Database (1860-1920)",
    appFiles = c(
      "app.R", "global.R", "ui.R", "server.R",
      "modules/", "utils/", "config/", "www/",
      ".env"  # Include environment file
    ),
    forceUpdate = TRUE,
    launch.browser = TRUE
  )
  
  cat("✅ Deployment complete!\n")
  cat("🌐 Your app should open in the browser\n")
}

# Uncomment the line below when ready to deploy
# deploy_app()

cat("📚 Next steps:\n")
cat("1. Set up cloud database (see database_setup_guide.md)\n")
cat("2. Update .env file with your credentials\n") 
cat("3. Test app locally with new database\n")
cat("4. Run: source('deploy_shinyapps.R') then deploy_app()\n") 