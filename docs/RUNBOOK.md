# American Authorship Database - Operations Runbook

This runbook provides operational guidance for running, deploying, and troubleshooting the American Authorship Database Shiny application.

## Table of Contents

- [Quick Start](#quick-start)
- [Local Development](#local-development)
- [Database Configuration](#database-configuration)
- [Running the Application](#running-the-application)
- [Testing](#testing)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)
- [Maintenance Tasks](#maintenance-tasks)

## Quick Start

### Minimum Requirements

- **R**: Version 4.0 or higher
- **PostgreSQL**: Version 12 or higher
- **OS**: Linux (WSL2), macOS, or Windows
- **RAM**: 4GB minimum, 8GB recommended
- **Disk**: 2GB for dependencies and data

### 5-Minute Setup

```bash
# 1. Clone repository
git clone https://github.com/siyangni/anesko.git
cd anesko

# 2. Install R dependencies (in R console)
install.packages("remotes")
remotes::install_deps(dependencies = TRUE)

# 3. Configure database (copy and edit)
cp shiny-app/config/.env.template shiny-app/config/.env
# Edit .env with your database credentials

# 4. Run the app
R -e "shiny::runApp('shiny-app/')"
```

The app should now be available at http://localhost:8080 (or the port shown in console).

## Local Development

### Directory Structure

```
anesko/
├── shiny-app/              # Shiny application code
│   ├── app.R               # Main application entry point
│   ├── global.R            # Global setup and libraries
│   ├── server.R            # Server logic
│   ├── ui.R                # User interface
│   ├── config/             # Configuration files
│   ├── modules/            # Shiny modules
│   ├── utils/              # Utility functions
│   └── www/                # Static assets (CSS, JS, images)
├── db/                     # Database scripts
│   └── migrations/         # Database migration scripts
├── scripts/                # Analysis and maintenance scripts
│   ├── analysis/           # Data analysis scripts
│   ├── cleaning/           # Data cleaning scripts
│   └── validation/         # Data validation scripts
├── tests/                  # Formal tests
├── deployment/             # Deployment scripts
├── docs/                   # Documentation
└── archive/                # Archived obsolete files
```

### Key Files

| File | Purpose |
|------|---------|
| `shiny-app/app.R` | Main application entry point |
| `shiny-app/global.R` | Loads libraries, config, and modules |
| `shiny-app/config/app_config.R` | App settings and constants |
| `shiny-app/config/cloud_config.R` | Database connection config |
| `DESCRIPTION` | Package metadata and dependencies |
| `docs/data_dictionary.md` | Database schema documentation |

## Database Configuration

### Environment Variables (Recommended)

Create `.env` file in `shiny-app/config/`:

```bash
# Database Connection
DB_HOST=your-database-host.example.com
DB_NAME=american_authorship
DB_USER=your_username
DB_PASSWORD=your_password
DB_PORT=5432
DB_SSL_MODE=require
```

**Security Note**: NEVER commit `.env` or `cloud_config.R` with real credentials!

### Local PostgreSQL Setup

```bash
# Start PostgreSQL
sudo service postgresql start

# Create database
createdb american_authorship

# Run migrations
R -e "source('db/migrations/00_run_full_migration.R')"
```

### Cloud Database (Neon)

The project uses Neon as the cloud PostgreSQL provider.

1. **Get credentials**:
   - Log in to Neon dashboard
   - Copy connection string

2. **Set environment variables**:
   ```bash
   export DB_HOST=ep-xxxxx.neon.tech
   export DB_NAME=neondb
   export DB_USER=your_user
   export DB_PASSWORD=your_password
   ```

3. **Test connection**:
   ```bash
   R -e "source('shiny-app/config/cloud_config.R'); print(db_config)"
   ```

### Database Migrations

To reset and rebuild the database:

```r
# Full migration (fresh start)
source("db/migrations/00_run_full_migration.R")

# Individual steps
source("db/migrations/00_package_setup.R")      # Install packages
source("db/migrations/01_database_setup.R")     # Create database
source("db/migrations/02_create_schema.R")      # Create tables/views
source("db/migrations/03_import_data.R")        # Import data
```

## Running the Application

### Local Development Mode

```r
# From project root
shiny::runApp("shiny-app/", port = 8080)

# With auto-reload on file changes
options(shiny.autoreload = TRUE)
shiny::runApp("shiny-app/")
```

### Production Mode

```r
# Run with specific host/port
shiny::runApp("shiny-app/", host = "0.0.0.0", port = 3838)
```

### Running in Background

```bash
# Using nohup
nohup R -e "shiny::runApp('shiny-app/', port=8080)" &

# Check if running
ps aux | grep shiny

# Stop
pkill -f "shiny::runApp"
```

### Docker Deployment

```bash
# Build image
docker build -t anesko-dashboard .

# Run container
docker run -p 8080:3838 \
  -e DB_HOST=$DB_HOST \
  -e DB_NAME=$DB_NAME \
  -e DB_USER=$DB_USER \
  -e DB_PASSWORD=$DB_PASSWORD \
  anesko-dashboard
```

## Testing

### Run All Tests

```r
testthat::test_dir("tests/testthat")
```

### Run Specific Test

```r
testthat::test_file("tests/testthat/test-database.R")
```

### Lint Code

```r
lintr::lint_dir("tests/testthat")
```

### Manual Testing Checklist

- [ ] App starts without errors
- [ ] Database connection successful
- [ ] All modules load correctly
- [ ] Dashboard displays summary statistics
- [ ] Book explorer shows data
- [ ] Sales trends visualizations render
- [ ] Author analysis works
- [ ] Royalty queries return results
- [ ] Genre analysis functions properly
- [ ] Filters work correctly
- [ ] Downloads function (if enabled)

## Deployment

### Deploy to shinyapps.io

```bash
# Using deployment script
./deployment/deploy_to_shinyapps.sh

# Or manually in R
library(rsconnect)
rsconnect::deployApp(
  appDir = "shiny-app",
  appName = "american-authorship",
  account = "your-account"
)
```

### Deploy to Custom Server

```bash
# Using main deployment script
./deployment/deploy.sh

# Or using Neon-specific script
./deployment/deploy_neon.sh
```

### Environment Variables for Deployment

Ensure these are set on your deployment platform:

```
DB_HOST=your-database-host
DB_NAME=your-database-name
DB_USER=your-database-user
DB_PASSWORD=your-secure-password
DB_PORT=5432
DB_SSL_MODE=require
```

## Troubleshooting

### Common Issues

#### 1. Database Connection Fails

**Symptoms**: App crashes on startup with database connection error

**Solutions**:
```r
# Check environment variables
Sys.getenv("DB_HOST")
Sys.getenv("DB_PASSWORD")

# Test connection manually
library(RPostgreSQL)
con <- dbConnect(
  PostgreSQL(),
  host = "your-host",
  dbname = "american_authorship",
  user = "your-user",
  password = "your-password"
)
dbGetQuery(con, "SELECT 1")
```

#### 2. Missing R Packages

**Symptoms**: Error about missing package

**Solutions**:
```r
# Install missing packages from DESCRIPTION
remotes::install_deps(dependencies = TRUE)

# Or install specific package
install.packages("package_name")
```

#### 3. Pool Connection Errors

**Symptoms**: "pool is closed" or "connection expired" errors

**Solutions**:
```r
# In global.R, reinitialize pool
if (!is.null(pool)) {
  pool::poolClose(pool)
}
pool <- create_db_pool()
```

#### 4. App Slow to Load

**Solutions**:
- Increase pool size in `config/app_config.R`
- Enable caching for expensive queries
- Check database indexes
- Monitor database query performance

### Logs

#### Application Logs

```bash
# If running with nohup
tail -f nohup.out

# If running in Docker
docker logs <container_id>
```

#### Database Logs

```bash
# PostgreSQL logs (Linux)
sudo tail -f /var/log/postgresql/postgresql-*-main.log
```

### Performance Monitoring

```r
# Check active pool connections
pool::dbGetInfo(pool)

# Query execution time
system.time({
  result <- dbGetQuery(pool, "YOUR QUERY")
})
```

## Maintenance Tasks

### Daily

- Monitor application logs for errors
- Check database connection pool health

### Weekly

- Review application performance metrics
- Check for package updates
- Backup database

### Monthly

- Update R packages
- Review and archive old log files
- Database maintenance (VACUUM, ANALYZE)
- Security updates

### Database Backup

```bash
# Backup database
pg_dump american_authorship > backup_$(date +%Y%m%d).sql

# Restore database
psql american_authorship < backup_YYYYMMDD.sql
```

### Updating Dependencies

```r
# Check for updates
old.packages()

# Update all packages
update.packages(ask = FALSE)

# Update specific package
install.packages("shiny")
```

### Rotating Logs

```bash
# Compress old logs
find . -name "*.log" -mtime +30 -exec gzip {} \;

# Remove very old logs
find . -name "*.log.gz" -mtime +90 -delete
```

## Support Contacts

- **Technical Issues**: Siyang Ni
- **Data Questions**: Dr. Michael Anesko (mwa2@psu.edu)
- **Database Issues**: Check deployment/README.md
- **Repository Issues**: https://github.com/siyangni/anesko/issues

## Version History

- **v1.0.0** (2025-05-23): Initial production release
- Repository restructured (2025-11-05): Refactored directory structure

---

For development guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md)
For data documentation, see [data_dictionary.md](data_dictionary.md)
