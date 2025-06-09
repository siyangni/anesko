#!/bin/bash

# Deploy to ShinyApps.io
# Final deployment script after Neon setup and testing

echo "🚀 Deploy to ShinyApps.io"
echo "========================"
echo ""

# Check prerequisites
echo "🔍 Checking prerequisites..."

if [ ! -f "shiny-app/.env" ]; then
    echo "❌ Neon configuration missing. Run ./setup_neon.sh first"
    exit 1
fi

if [ ! -f "shiny-app/config/cloud_config.R" ]; then
    echo "❌ Cloud configuration missing. Run ./test_app_with_neon.sh first"
    exit 1
fi

echo "✅ Prerequisites met"
echo ""

echo "📋 Pre-deployment checklist:"
echo "[ ] Neon database setup and tested"
echo "[ ] Data migrated to Neon"
echo "[ ] App tested locally with cloud database"
echo "[ ] ShinyApps.io account created"
echo ""

read -p "Have you completed all prerequisites? (y/n): " ready

if [ "$ready" != "y" ]; then
    echo "ℹ️  Please complete the prerequisites first:"
    echo "1. Run ./setup_neon.sh"
    echo "2. Run ./migrate_to_neon.sh"
    echo "3. Run ./test_app_with_neon.sh"
    echo "4. Create account at https://www.shinyapps.io"
    exit 0
fi

echo ""
echo "🔧 Step 1: Installing rsconnect package..."

R -e "if (!require('rsconnect')) { install.packages('rsconnect'); library(rsconnect) }"

echo ""
echo "🔑 Step 2: Configure ShinyApps.io authentication"
echo ""
echo "Please complete these steps:"
echo "1. Go to https://www.shinyapps.io/admin/#/tokens"
echo "2. Copy your token and secret"
echo "3. Run the following command with YOUR credentials:"
echo ""
echo "   R -e \"rsconnect::setAccountInfo(name='YOUR_USERNAME', token='YOUR_TOKEN', secret='YOUR_SECRET')\""
echo ""

read -p "Have you configured authentication? (y/n): " auth_done

if [ "$auth_done" != "y" ]; then
    echo "ℹ️  Please configure authentication first, then run this script again"
    exit 0
fi

echo ""
echo "📦 Step 3: Preparing app for deployment..."

cd shiny-app

# Create deployment directory structure
echo "📁 Organizing files for deployment..."

# Ensure all necessary files are present
files_to_check=(
    "app.R"
    "global.R" 
    "ui.R"
    "server.R"
    ".env"
    "config/cloud_config.R"
    "modules/dashboard_module.R"
    "utils/database.R"
    "www/style.css"
)

missing_files=()
for file in "${files_to_check[@]}"; do
    if [ ! -f "$file" ]; then
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -gt 0 ]; then
    echo "❌ Missing required files:"
    printf '%s\n' "${missing_files[@]}"
    exit 1
fi

echo "✅ All required files present"

# Create deployment info
cat > "DEPLOYMENT_INFO.txt" << EOF
American Authorship Database Deployment
======================================

Deployed: $(date)
Database: Neon PostgreSQL (Cloud)
Platform: ShinyApps.io
Version: 1.0.0

App URL: Will be provided after deployment
Database: Hosted on Neon.tech
Source: GitHub repository

For support, contact: Dr. Michael Anesko
Institution: Penn State University
EOF

echo ""
echo "🚀 Step 4: Deploying to ShinyApps.io..."

# Create deployment script
cat > "deploy_script.R" << 'EOF'
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
EOF

# Run the deployment
Rscript deploy_script.R

deployment_status=$?

cd ..

echo ""
if [ $deployment_status -eq 0 ]; then
    echo "🎊 Congratulations! Your American Authorship Database is now live!"
    echo ""
    echo "📋 Deployment Summary:"
    echo "   Platform: ShinyApps.io"
    echo "   Database: Neon PostgreSQL"
    echo "   Status: Live and accessible"
    echo ""
    echo "📚 Resources:"
    echo "   - ShinyApps.io Dashboard: https://www.shinyapps.io/admin/"
    echo "   - Neon Console: https://console.neon.tech/"
    echo "   - Usage monitoring available on both platforms"
    echo ""
    echo "🎯 Free Tier Limits:"
    echo "   - ShinyApps.io: 25 active hours/month"
    echo "   - Neon: 500MB database, unlimited connections"
    echo ""
    echo "💡 Tips:"
    echo "   - Monitor your usage to stay within free limits"
    echo "   - Consider upgrading if you get heavy traffic"
    echo "   - Regular backups recommended for important data"
else
    echo "❌ Deployment encountered issues."
    echo ""
    echo "🔍 Troubleshooting:"
    echo "1. Check ShinyApps.io authentication"
    echo "2. Verify all files are present"
    echo "3. Test app locally first"
    echo "4. Check deployment logs for specific errors"
    echo ""
    echo "🆘 Get help:"
    echo "   - ShinyApps.io support: https://shinyapps.io/admin/#/support"
    echo "   - Re-run with: ./deploy_to_shinyapps.sh"
fi 