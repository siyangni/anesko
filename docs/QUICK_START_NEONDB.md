# Quick Start: Deploy to NeonDB + ShinyApps.io (15 minutes)

This is the fastest way to get your dashboard online. For detailed explanations, see [NEONDB_HOSTING_GUIDE.md](./NEONDB_HOSTING_GUIDE.md).

## Prerequisites Checklist

- [ ] NeonDB account (free): https://neon.tech/
- [ ] ShinyApps.io account (free tier available): https://www.shinyapps.io/
- [ ] R installed (4.0+)
- [ ] Git installed

## Step 1: Set Up NeonDB (5 minutes)

```bash
# 1. Sign up at https://console.neon.tech/

# 2. Create Project:
#    - Name: american-authorship-db
#    - Region: us-east-2 (or closest to you)
#    - PostgreSQL: 15

# 3. Save connection details (shown after creation):
#    Host: ep-something-pooler.us-east-2.aws.neon.tech
#    Database: neondb
#    User: your-username
#    Password: [save this securely]

# 4. Enable Connection Pooling:
#    Settings → Connection Pooling → Enable
#    Mode: Transaction
#    Use the POOLED endpoint (ends with -pooler)
```

## Step 2: Migrate Database (5 minutes)

```bash
# Export environment variables
export NEON_HOST="ep-xxx-pooler.us-east-2.aws.neon.tech"
export NEON_DATABASE="neondb"
export NEON_USER="your-username"
export NEON_PASSWORD="your-password"
export NEON_PORT="5432"

# Navigate to your project
cd /home/user/anesko

# Run migration script
bash deployment/migrate_to_neon.sh

# Verify data imported successfully
# Should see: ✓ 630+ books, ✓ Sales data, ✓ Royalty tiers
```

## Step 3: Configure App (2 minutes)

```bash
# Create environment file
cd shiny-app/config
cp .env.template .env
nano .env
```

Add your NeonDB credentials:
```bash
DB_HOST=ep-xxx-pooler.us-east-2.aws.neon.tech
DB_NAME=neondb
DB_USER=your-username
DB_PASSWORD=your-password
DB_PORT=5432
DB_SSL_MODE=require
```

## Step 4: Test Locally (2 minutes)

```r
# Install dependencies (if not already installed)
install.packages(c(
  "shiny", "shinydashboard", "shinydashboardPlus",
  "DBI", "RPostgres", "pool",
  "dplyr", "ggplot2", "plotly", "DT",
  "rsconnect"
))

# Test app locally
setwd("/home/user/anesko/shiny-app")
shiny::runApp()

# Open browser to: http://127.0.0.1:XXXX
# Verify:
# - Dashboard loads
# - Data displays correctly
# - No connection errors
```

## Step 5: Deploy to ShinyApps.io (3 minutes)

```r
# Get your ShinyApps.io credentials:
# 1. Go to https://www.shinyapps.io/admin/#/tokens
# 2. Click "Show Secret"
# 3. Copy token and secret

# Set up authentication
library(rsconnect)
rsconnect::setAccountInfo(
  name = 'your-account-name',
  token = 'YOUR-TOKEN',
  secret = 'YOUR-SECRET'
)

# Deploy
setwd("/home/user/anesko")
rsconnect::deployApp(
  appDir = "shiny-app",
  appName = "american-authorship",
  appTitle = "American Authorship Database (1860-1920)",
  forceUpdate = TRUE
)

# Deployment takes 2-5 minutes
# URL will be: https://your-account-name.shinyapps.io/american-authorship/
```

## Step 6: Configure ShinyApps.io (2 minutes)

```bash
# 1. Go to: https://www.shinyapps.io/admin/#/applications

# 2. Click your app → Settings → Variables

# 3. Add environment variables:
DB_HOST = ep-xxx-pooler.us-east-2.aws.neon.tech
DB_NAME = neondb
DB_USER = your-username
DB_PASSWORD = your-password
DB_PORT = 5432
DB_SSL_MODE = require

# 4. Save and restart app
```

## Done! 🎉

Your dashboard is now live at:
```
https://your-account-name.shinyapps.io/american-authorship/
```

## Verify Deployment

- [ ] Dashboard loads without errors
- [ ] Book Explorer shows 630+ books
- [ ] Sales Trends displays data
- [ ] Charts render correctly
- [ ] Data tables are interactive
- [ ] No connection errors in logs

## Optional: Set Up Monitoring

**Quick health checks**:
```bash
# Check app status
curl https://your-account-name.shinyapps.io/american-authorship/

# Monitor NeonDB
# Go to: https://console.neon.tech/ → Your Project → Monitoring
```

**Set up uptime monitoring** (free):
1. Sign up at https://uptimerobot.com/
2. Add monitor: https://your-account-name.shinyapps.io/american-authorship/
3. Get alerts via email if app goes down

## Common Issues

### "Cannot connect to database"
```r
# Test connection manually
library(DBI)
library(RPostgres)
con <- dbConnect(
  RPostgres::Postgres(),
  host = "ep-xxx-pooler.us-east-2.aws.neon.tech",
  dbname = "neondb",
  user = "your-username",
  password = "your-password",
  port = 5432,
  sslmode = "require"
)
# If this works, check environment variables in ShinyApps.io
```

### "Package not found" during deployment
```r
# Make sure all packages are listed in DESCRIPTION
# Your project already has this configured correctly

# Force reinstall
rsconnect::deployApp(forceUpdate = TRUE)
```

### "Too many connections"
```r
# In shiny-app/config/app_config.R, reduce:
POOL_SIZE_MAX <- 5  # Lower for free tier

# Or enable NeonDB connection pooling (Step 1.4)
```

## Cost Summary (Free Tier)

- **NeonDB Free**: $0/month
  - 3 GiB storage (plenty for your data)
  - 10 compute hours (with auto-suspend)
  - Up to 10 connections

- **ShinyApps.io Free**: $0/month
  - 5 applications
  - 25 active hours/month
  - Good for demos and testing

**Total: $0/month** for testing and small deployments!

## Upgrade Paths

When you outgrow free tiers:

**For more users (100+ daily)**:
- NeonDB Pro: $19/month
- ShinyApps.io Basic: $39/month
- **Total: $58/month**

**For production (500+ daily)**:
- Self-hosted option (see main guide)
- **Total: ~$45/month**

## Next Steps

1. **Customize**: Update branding, logos, colors
2. **Secure**: Set up authentication (see docs/AUTHENTICATION.md)
3. **Monitor**: Track usage and performance
4. **Backup**: Set up automated backups (see main guide)
5. **Document**: Record your specific deployment details

## Need More?

- **Full Guide**: See [NEONDB_HOSTING_GUIDE.md](./NEONDB_HOSTING_GUIDE.md)
- **Operations**: See [RUNBOOK.md](./RUNBOOK.md)
- **Troubleshooting**: See main guide Section 7
- **Alternative Hosting**: Docker, self-hosted options in main guide

---

**Time to deploy**: ~15 minutes
**Difficulty**: Beginner-friendly
**Cost**: Free (with limits)
