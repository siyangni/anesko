# Quick Start Guide - American Authorship Dashboard

## ✅ Database Connection Issue Fixed!

The "app only works once" issue has been resolved. The problem was that the database connection pool was being closed when individual user sessions ended, affecting all subsequent users.

## 🚀 How to Run the App

### Option 1: Simple Start (Recommended)
```bash
cd ~/anesko/shiny-app
Rscript app.R
```

### Option 2: From R Console
```r
setwd("~/anesko/shiny-app")
shiny::runApp(".")
```

### Option 3: From Project Root
```r
shiny::runApp("shiny-app/")
```

## 🔍 Before Running - Quick Health Check

Run this diagnostic to ensure everything is working:

```bash
cd ~/anesko/shiny-app
Rscript test_connection.R
```

**Expected output**: All tests should show ✅ (green checkmarks)

## 🛠️ What Was Fixed

1. **Improved Database Pool Management**: Pool now persists across sessions instead of being closed when individual sessions end
2. **Better Error Handling**: Added automatic retry logic when database connections fail
3. **Robust Initialization**: Pool creation now checks for existing valid connections before creating new ones
4. **Diagnostic Tools**: Added test scripts to help identify connection issues

## 🔧 If You Still Have Issues

### Quick Reset
```r
# In R console
rm(list = ls())  # Clear workspace
.rs.restartR()   # Restart R session (if using RStudio)
```

### Check Database Service
```bash
sudo service postgresql restart
```

### Run Full Diagnostic
```bash
cd ~/anesko/shiny-app
Rscript test_app.R
```

## 📊 App Features

- **Dashboard**: Overview with key statistics and trends
- **Book Explorer**: Search and filter books with advanced criteria  
- **Real-time Filtering**: Instant results as you type and select filters
- **Interactive Charts**: Hover for details, zoom, and export capabilities
- **Responsive Design**: Works on desktop and mobile devices

## 🎯 Success Indicators

When the app starts successfully, you should see:
- ✅ All required packages are available
- ✅ Global configuration loaded
- ✅ UI components loaded  
- ✅ Server logic loaded
- 🚀 Starting American Authorship Database Dashboard...

The app will be available at: `http://localhost:3838`

## 📞 Need Help?

If you encounter any issues:
1. Run the diagnostic scripts first
2. Check the error messages in the R console
3. Ensure PostgreSQL is running
4. Verify database credentials in `config/app_config.R`

---

**Last Updated**: June 4, 2025
**Fix Version**: 1.1.0 - Database Connection Stability 