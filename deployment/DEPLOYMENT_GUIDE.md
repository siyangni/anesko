# Cloud Deployment Guide: American Authorship Dashboard

This guide provides step-by-step instructions for deploying the American Authorship Shiny dashboard to production using NeonDB and shinyapps.io.

## Overview

**Database**: Local PostgreSQL → NeonDB (cloud PostgreSQL)
**Application**: Local Shiny → shinyapps.io
**Timeline**: ~2-3 hours for complete deployment

## Prerequisites

1. **NeonDB Account**: Sign up at [neon.tech](https://neon.tech)
2. **shinyapps.io Account**: Sign up at [shinyapps.io](https://shinyapps.io)
3. **R Packages**: `rsconnect`, `DBI`, `RPostgreSQL`
4. **Local Database**: Current PostgreSQL database with all data

## Phase 1: Database Migration to NeonDB

### Step 1.1: Export Current Database

```bash
# Navigate to deployment directory
cd deployment

# Run database export script
Rscript 01_export_database.R
```

This creates:
- `database_schema.sql` - Database structure
- `database_data.sql` - All data
- `database_full_backup.sql` - Complete backup

### Step 1.2: Set Up NeonDB Instance

1. **Create NeonDB Project**:
   - Go to [neon.tech](https://neon.tech)
   - Click "Create Project"
   - Name: `american-authorship-db`
   - Region: Choose closest to your users
   - PostgreSQL version: 15 (recommended)

2. **Get Connection Details**:
   - Copy the connection string (format: `postgresql://user:password@host/dbname`)
   - Note down individual components:
     - Host: `ep-xxx-xxx.us-east-2.aws.neon.tech`
     - Database: `neondb`
     - User: `neondb_owner`
     - Password: `[generated password]`

### Step 1.3: Import Data to NeonDB

```bash
# Update NeonDB connection details in the script
# Edit deployment/02_import_to_neondb.R with your NeonDB credentials

# Run import script
Rscript 02_import_to_neondb.R
```

### Step 1.4: Verify Database Migration

```bash
# Test the NeonDB connection and data integrity
Rscript 03_verify_neondb.R
```

## Phase 2: Application Preparation

### Step 2.1: Update Database Configuration

```bash
# Create production environment configuration
Rscript 04_prepare_app_config.R
```

This creates:
- `.env` file with NeonDB credentials
- Updated `cloud_config.R` for production
- `app.R` optimized for shinyapps.io

### Step 2.2: Check Dependencies and Paths

```bash
# Verify all dependencies and fix file paths
Rscript 05_check_dependencies.R
```

### Step 2.3: Test Locally with Cloud Database

```bash
# Test the app locally using NeonDB
cd ../shiny-app
R -e "shiny::runApp()"
```

Verify all modules work with the cloud database:
- ✅ Author Networks
- ✅ Royalty Analysis (including sliding scale filter)
- ✅ Data tables and visualizations

## Phase 3: Deploy to shinyapps.io

### Step 3.1: Install and Configure rsconnect

```r
# In R console
install.packages("rsconnect")
library(rsconnect)

# Get your token and secret from shinyapps.io account
rsconnect::setAccountInfo(
  name = "your-account-name",
  token = "your-token",
  secret = "your-secret"
)
```

### Step 3.2: Deploy Application

```bash
# Run deployment script
cd deployment
Rscript 06_deploy_to_shinyapps.R
```

### Step 3.3: Configure Environment Variables

In shinyapps.io dashboard:
1. Go to your deployed app
2. Click "Settings" → "Variables"
3. Add environment variables:
   - `DB_HOST`: Your NeonDB host
   - `DB_NAME`: `neondb`
   - `DB_USER`: Your NeonDB user
   - `DB_PASSWORD`: Your NeonDB password
   - `DB_PORT`: `5432`

## Phase 4: Testing and Validation

### Step 4.1: Functional Testing

Test all major features:
- [ ] Dashboard loads successfully
- [ ] Author Networks module works
- [ ] Royalty Analysis displays data
- [ ] Sliding scale filter works correctly
- [ ] Data tables render properly
- [ ] Visualizations display correctly

### Step 4.2: Performance Testing

```bash
# Run performance tests
Rscript 07_test_performance.R
```

### Step 4.3: Error Monitoring

Monitor logs in shinyapps.io:
1. Go to app dashboard
2. Click "Logs" tab
3. Check for any errors or warnings

## Troubleshooting

### Common Issues

1. **Database Connection Errors**:
   - Verify NeonDB credentials
   - Check firewall settings
   - Ensure connection pooling is enabled

2. **Package Installation Errors**:
   - Check `renv.lock` file
   - Verify all packages are available on CRAN

3. **File Path Issues**:
   - Ensure all paths are relative
   - Check working directory assumptions

4. **Memory Issues**:
   - Monitor app memory usage
   - Consider data optimization

### Support Resources

- **NeonDB Documentation**: [docs.neon.tech](https://docs.neon.tech)
- **shinyapps.io Guide**: [docs.rstudio.com/shinyapps.io](https://docs.rstudio.com/shinyapps.io)
- **Deployment Logs**: Available in shinyapps.io dashboard

## Next Steps

After successful deployment:
1. Set up monitoring and alerts
2. Configure custom domain (optional)
3. Set up automated backups
4. Plan for scaling if needed

## Quick Start Commands

```bash
# 1. Export database
cd deployment
Rscript 01_export_database.R

# 2. Set NeonDB environment variables
export NEONDB_HOST=your-host.neon.tech
export NEONDB_NAME=neondb
export NEONDB_USER=neondb_owner
export NEONDB_PASSWORD=your-password
export NEONDB_PORT=5432

# 3. Import to NeonDB
Rscript 02_import_to_neondb.R

# 4. Verify migration
Rscript 03_verify_neondb.R

# 5. Prepare app configuration
Rscript 04_prepare_app_config.R

# 6. Check dependencies
Rscript 05_check_dependencies.R

# 7. Deploy to shinyapps.io
Rscript 06_deploy_to_shinyapps.R

# 8. Test performance (after setting APP_URL)
export APP_URL=https://youraccount.shinyapps.io/american-authorship-dashboard/
Rscript 07_test_performance.R
```

## Files Created

This deployment process creates:
- `01_export_database.R` - Database export script
- `02_import_to_neondb.R` - NeonDB import script
- `03_verify_neondb.R` - Database verification
- `04_prepare_app_config.R` - App configuration
- `05_check_dependencies.R` - Dependency checker
- `06_deploy_to_shinyapps.R` - Deployment script
- `07_test_performance.R` - Performance testing
- `.env.template` - Environment variables template
- `deployment_checklist.md` - Deployment checklist
- `dependency_report.md` - Detailed dependency analysis
- `performance_report.json` - Performance test results
