# Deploy to shinyapps.io
# This script deploys the American Authorship Dashboard to shinyapps.io

library(rsconnect)

cat("🚀 Deploying American Authorship Dashboard to shinyapps.io\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

# 1. Check rsconnect configuration
cat("🔍 Checking rsconnect configuration...\n")

# Check if rsconnect is configured
accounts <- rsconnect::accounts()

if (nrow(accounts) == 0) {
  cat("❌ No shinyapps.io accounts configured.\n")
  cat("\n💡 Please configure rsconnect first:\n")
  cat("   1. Go to https://www.shinyapps.io/admin/#/tokens\n")
  cat("   2. Click 'Show' next to your token\n")
  cat("   3. Copy the rsconnect::setAccountInfo() command\n")
  cat("   4. Run it in R console\n")
  cat("\n   Example:\n")
  cat("   rsconnect::setAccountInfo(\n")
  cat("     name = 'your-account-name',\n")
  cat("     token = 'your-token',\n")
  cat("     secret = 'your-secret'\n")
  cat("   )\n")
  stop("rsconnect configuration required")
}

cat("✅ Found", nrow(accounts), "configured account(s):\n")
for (i in 1:nrow(accounts)) {
  cat("   -", accounts$name[i], "(", accounts$server[i], ")\n")
}

# Use the first account
account_name <- accounts$name[1]
cat("📡 Using account:", account_name, "\n")

# 2. Pre-deployment checks
cat("\n🔍 Running pre-deployment checks...\n")

# Check if app directory exists
app_dir <- "../shiny-app"
if (!dir.exists(app_dir)) {
  stop("❌ Shiny app directory not found:", app_dir)
}

# Check for required files
required_files <- c("app.R", "config/cloud_config.R", "utils/database.R")
missing_files <- c()

for (file in required_files) {
  if (!file.exists(file.path(app_dir, file))) {
    missing_files <- c(missing_files, file)
  }
}

if (length(missing_files) > 0) {
  cat("❌ Missing required files:\n")
  for (file in missing_files) {
    cat("   -", file, "\n")
  }
  stop("Required files missing")
}

cat("✅ Required files present\n")

# Check for .env file (should not be deployed)
env_file <- file.path(app_dir, ".env")
if (file.exists(env_file)) {
  cat("⚠️  .env file found - this will NOT be deployed (environment variables must be set in shinyapps.io)\n")
}

# 3. Test local connection to verify app works
cat("\n🧪 Testing database connection...\n")
tryCatch({
  # Set working directory temporarily
  old_wd <- getwd()
  setwd(app_dir)
  
  # Source configuration
  source("config/cloud_config.R")
  source("utils/database.R")
  
  # Test database connection
  test_query <- "SELECT COUNT(*) as count FROM book_entries LIMIT 1"
  result <- safe_db_query(test_query)
  
  if (!is.null(result) && nrow(result) > 0) {
    cat("✅ Database connection test successful\n")
  } else {
    cat("⚠️  Database connection test returned no results\n")
  }
  
  # Restore working directory
  setwd(old_wd)
  
}, error = function(e) {
  setwd(old_wd)
  cat("❌ Database connection test failed:", e$message, "\n")
  cat("⚠️  Deployment will continue, but you must set environment variables in shinyapps.io\n")
})

# 4. Deployment configuration
cat("\n⚙️  Configuring deployment...\n")

app_name <- "american-authorship-dashboard"
app_title <- "American Authorship Database (1860-1920)"

cat("App name:", app_name, "\n")
cat("App title:", app_title, "\n")

# 5. Deploy the application
cat("\n🚀 Starting deployment...\n")
cat("This may take several minutes...\n")

deployment_start <- Sys.time()

tryCatch({
  # Deploy with specific settings
  rsconnect::deployApp(
    appDir = app_dir,
    appName = app_name,
    appTitle = app_title,
    account = account_name,
    server = "shinyapps.io",
    forceUpdate = TRUE,
    launch.browser = FALSE,
    logLevel = "verbose"
  )
  
  deployment_end <- Sys.time()
  deployment_time <- round(as.numeric(deployment_end - deployment_start, units = "mins"), 2)
  
  cat("\n🎉 ✅ Deployment successful!\n")
  cat("⏱️  Deployment time:", deployment_time, "minutes\n")
  
  # Get app URL
  app_url <- paste0("https://", account_name, ".shinyapps.io/", app_name, "/")
  cat("🌐 App URL:", app_url, "\n")
  
}, error = function(e) {
  cat("\n❌ Deployment failed:", e$message, "\n")
  
  # Common troubleshooting tips
  cat("\n🔧 Troubleshooting tips:\n")
  cat("   1. Check that all required packages are installed\n")
  cat("   2. Verify file paths are relative (no absolute paths)\n")
  cat("   3. Ensure no large files are included\n")
  cat("   4. Check rsconnect configuration\n")
  cat("   5. Review deployment logs above for specific errors\n")
  
  stop("Deployment failed")
})

# 6. Post-deployment instructions
cat("\n📋 Post-Deployment Setup Required\n")
cat(paste(rep("-", 40), collapse = ""), "\n")

cat("🔧 IMPORTANT: You must configure environment variables in shinyapps.io:\n")
cat("\n1. Go to: https://www.shinyapps.io/admin/#/applications\n")
cat("2. Click on your app:", app_name, "\n")
cat("3. Go to Settings → Variables\n")
cat("4. Add these environment variables:\n")

# Get NeonDB config for display
neondb_config <- list(
  host = Sys.getenv("NEONDB_HOST", "your-neondb-host.neon.tech"),
  dbname = Sys.getenv("NEONDB_NAME", "neondb"),
  user = Sys.getenv("NEONDB_USER", "neondb_owner"),
  password = Sys.getenv("NEONDB_PASSWORD", "your-password"),
  port = Sys.getenv("NEONDB_PORT", "5432")
)

cat("\n   Variable Name    | Value\n")
cat("   -----------------|------------------\n")
cat("   DB_HOST          |", neondb_config$host, "\n")
cat("   DB_NAME          |", neondb_config$dbname, "\n")
cat("   DB_USER          |", neondb_config$user, "\n")
cat("   DB_PASSWORD      |", neondb_config$password, "\n")
cat("   DB_PORT          |", neondb_config$port, "\n")

cat("\n5. Click 'Save' and restart the application\n")

# 7. Testing checklist
cat("\n✅ Testing Checklist\n")
cat(paste(rep("-", 40), collapse = ""), "\n")

testing_items <- c(
  "Application loads without errors",
  "Database connection works",
  "Author Networks module displays data",
  "Royalty Analysis module displays data", 
  "Sliding Scale filter works correctly",
  "All visualizations render properly",
  "Tables display data correctly",
  "No JavaScript errors in browser console",
  "Application responds within reasonable time",
  "All navigation works correctly"
)

cat("After setting environment variables, test these items:\n")
for (i in seq_along(testing_items)) {
  cat("   [ ]", testing_items[i], "\n")
}

# 8. Monitoring and maintenance
cat("\n📊 Monitoring and Maintenance\n")
cat(paste(rep("-", 40), collapse = ""), "\n")

cat("🔍 Monitor your application:\n")
cat("   - Check logs regularly in shinyapps.io dashboard\n")
cat("   - Monitor usage and performance metrics\n")
cat("   - Set up email notifications for errors\n")

cat("\n🔄 For updates:\n")
cat("   - Make changes locally and test thoroughly\n")
cat("   - Re-run this deployment script\n")
cat("   - Verify all functionality after updates\n")

cat("\n💾 Backup considerations:\n")
cat("   - Your data is in NeonDB (separate from app)\n")
cat("   - Keep local backups of your application code\n")
cat("   - Document any custom configurations\n")

# 9. Save deployment info
cat("\n📄 Saving deployment information...\n")

deployment_info <- list(
  app_name = app_name,
  app_title = app_title,
  account = account_name,
  deployment_time = as.character(deployment_end),
  app_url = paste0("https://", account_name, ".shinyapps.io/", app_name, "/"),
  environment_variables = names(neondb_config)
)

# Save as JSON for reference
jsonlite::write_json(deployment_info, "deployment_info.json", pretty = TRUE)
cat("✅ Saved deployment_info.json\n")

cat("\n🎉 Deployment process completed!\n")
cat("🌐 Your app should be available at:", deployment_info$app_url, "\n")
cat("⚠️  Remember to set environment variables in shinyapps.io dashboard!\n")
