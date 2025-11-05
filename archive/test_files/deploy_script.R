# ShinyApps.io Deployment Script
library(rsconnect)

# Check authentication
accounts <- rsconnect::accounts()
if (nrow(accounts) == 0) {
  stop("❌ ShinyApps.io authentication not configured!")
}

cat("🔗 Deploying to account:", accounts$name[1], "\n")

# Deploy the application
cat("📤 Starting deployment...\n")

deployment_result <- tryCatch({
  rsconnect::deployApp(
    appDir = ".",
    appName = "american-authorship-database",
    appTitle = "American Authorship Database (1860-1920)",
    appFiles = c(
      "app.R",
      "global.R", 
      "ui.R",
      "server.R",
      ".env",
      "config/",
      "modules/",
      "utils/",
      "www/",
      "DEPLOYMENT_INFO.txt"
    ),
    forceUpdate = TRUE,
    launch.browser = FALSE  # Don't auto-open browser
  )
}, error = function(e) {
  cat("❌ Deployment failed:", e$message, "\n")
  return(NULL)
})

if (!is.null(deployment_result)) {
  app_url <- paste0("https://", accounts$name[1], ".shinyapps.io/american-authorship-database/")
  cat("\n🎉 Deployment successful!\n")
  cat("🌐 Your app is now live at:\n")
  cat("   ", app_url, "\n\n")
  
  cat("📱 App Details:\n")
  cat("   Name: american-authorship-database\n")
  cat("   Account:", accounts$name[1], "\n")
  cat("   Database: Neon PostgreSQL (cloud)\n")
  cat("   Status: Active\n\n")
  
  cat("📝 Next steps:\n")
  cat("1. Test your live app thoroughly\n")
  cat("2. Share the URL with colleagues\n") 
  cat("3. Monitor usage on ShinyApps.io dashboard\n")
  cat("4. Consider upgrading plan if you exceed free tier limits\n\n")
  
  # Try to open in browser
  tryCatch({
    browseURL(app_url)
    cat("🌐 Opening app in your default browser...\n")
  }, error = function(e) {
    cat("ℹ️  Please manually open the URL above in your browser\n")
  })
  
} else {
  cat("❌ Deployment failed. Please check the error messages above.\n")
}
