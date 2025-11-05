# American Authorship Database - Runbook

Operational guide for running, maintaining, and troubleshooting the application.

## Quick Start

### Local Development

**Prerequisites**:
- R 4.0+
- PostgreSQL 12+
- Git

**Steps**:
```bash
# 1. Install R dependencies
R -e 'install.packages("renv"); renv::restore()'

# 2. Configure environment
export R_CONFIG_ACTIVE=development
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=american_authorship
export DB_USER=app_user
export DB_PASSWORD=your_password

# 3. Run database migrations (first time only)
Rscript scripts/migration/00_run_full_migration.R

# 4. Start the app
R -e 'shiny::runApp("app", port=3838, host="0.0.0.0")'
```

Access the app at: http://localhost:3838

### Docker (Recommended for Production)

**Prerequisites**:
- Docker 20.10+
- Docker Compose 2.0+

**Steps**:
```bash
# 1. Create environment file
cp config/credentials.example.env .env
# Edit .env with your credentials

# 2. Start services
docker-compose up -d

# 3. Check logs
docker-compose logs -f

# 4. Access app
# http://localhost:3838
```

## Configuration

### Environment Variables

All configuration is managed through environment variables:

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `R_CONFIG_ACTIVE` | Config environment (development/test/production) | `default` | No |
| `DB_HOST` | PostgreSQL host | `localhost` | Yes |
| `DB_PORT` | PostgreSQL port | `5432` | No |
| `DB_NAME` | Database name | `american_authorship` | Yes |
| `DB_USER` | Database user | `app_user` | Yes |
| `DB_PASSWORD` | Database password | - | **Yes** |
| `DB_SSL_MODE` | SSL mode (disable/prefer/require) | `prefer` | No |
| `SHINY_PORT` | Shiny server port | `3838` | No |
| `SHINY_HOST` | Shiny server host | `0.0.0.0` | No |

### Configuration Files

- `config/config.yml` - Application settings (uses environment variables)
- `config/app_config.R` - App metadata and constants
- `config/cloud_config.R` - Database configuration loader
- `.env` - Environment variables (gitignored, create from template)

## Database Operations

### Initial Setup

```bash
# Create database and user
sudo -u postgres psql
CREATE DATABASE american_authorship;
CREATE USER app_user WITH ENCRYPTED PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE american_authorship TO app_user;
\q

# Run migrations
Rscript scripts/migration/00_run_full_migration.R
```

### Migrations

Migration scripts are in `scripts/migration/`:

```bash
# Full migration (initial setup)
Rscript scripts/migration/00_run_full_migration.R

# Individual steps
Rscript scripts/migration/01_database_setup.R      # Create database
Rscript scripts/migration/02_create_schema.R       # Create schema
Rscript scripts/migration/03_import_data.R         # Import data

# Verify
Rscript scripts/migration/check_tables.R
```

### Backup and Restore

**Backup**:
```bash
# Dump database
pg_dump -h localhost -U app_user -d american_authorship > backup_$(date +%Y%m%d).sql

# Dump with compression
pg_dump -h localhost -U app_user -Fc -d american_authorship > backup_$(date +%Y%m%d).dump
```

**Restore**:
```bash
# From SQL dump
psql -h localhost -U app_user -d american_authorship < backup.sql

# From compressed dump
pg_restore -h localhost -U app_user -d american_authorship backup.dump
```

### Database Maintenance

```bash
# Vacuum and analyze
psql -h localhost -U app_user -d american_authorship -c "VACUUM ANALYZE;"

# Check database size
psql -h localhost -U app_user -d american_authorship -c "
  SELECT pg_size_pretty(pg_database_size('american_authorship'));"

# Check table sizes
psql -h localhost -U app_user -d american_authorship -c "
  SELECT tablename, pg_size_pretty(pg_total_relation_size(tablename::text))
  FROM pg_tables WHERE schemaname = 'public' ORDER BY pg_total_relation_size(tablename::text) DESC;"
```

## Running Tests

### Linting

```r
# Lint all code
lintr::lint_dir("app")
lintr::lint_dir("R")
lintr::lint_dir("config")

# Lint specific file
lintr::lint("R/database.R")
```

### Unit Tests

```r
# Run all tests
testthat::test_dir("tests/testthat")

# Run specific test
testthat::test_file("tests/testthat/test-queries_sales.R")

# Run with coverage
covr::package_coverage()
```

### Manual Testing

```r
# Start app in test mode
Sys.setenv(R_CONFIG_ACTIVE = "test")
shiny::runApp("app")

# Test specific module
source("app/modules/dashboard_module.R")
# Interactive testing...
```

## Deployment

### Production Checklist

- [ ] Environment variables configured in production environment
- [ ] Database migrations run and verified
- [ ] Database backups scheduled
- [ ] SSL/TLS enabled for database connections (DB_SSL_MODE=require)
- [ ] Application logs configured
- [ ] Monitoring and alerts set up
- [ ] Firewall rules configured
- [ ] DNS records updated
- [ ] Health checks verified

### Deploying to shinyapps.io

```r
# Install rsconnect
install.packages("rsconnect")

# Configure account (first time only)
rsconnect::setAccountInfo(
  name='your-account',
  token='your-token',
  secret='your-secret'
)

# Deploy
rsconnect::deployApp(
  appDir = "app",
  appName = "american-authorship",
  forceUpdate = TRUE
)
```

### Deploying with Docker

```bash
# Build image
docker build -t american-authorship:latest .

# Tag for registry
docker tag american-authorship:latest registry.example.com/american-authorship:latest

# Push to registry
docker push registry.example.com/american-authorship:latest

# Deploy on server
docker pull registry.example.com/american-authorship:latest
docker-compose up -d
```

## Monitoring

### Health Checks

```bash
# Check app is responding
curl http://localhost:3838/

# Check database connection
psql -h localhost -U app_user -d american_authorship -c "SELECT 1"

# Docker health check
docker inspect --format='{{.State.Health.Status}}' american_authorship_app
```

### Logs

**Application logs**:
```bash
# Docker
docker-compose logs -f shiny

# Direct R session
# Check console output or configure logging to file
```

**Database logs**:
```bash
# PostgreSQL logs (Ubuntu)
sudo tail -f /var/log/postgresql/postgresql-*-main.log

# Docker PostgreSQL logs
docker-compose logs -f postgres
```

### Performance Monitoring

```r
# Monitor database pool
library(pool)
poolCheckout(pool)  # Test checkout
poolReturn(poolConn)  # Return connection

# Check pool status
# Pool info logged on creation

# Profile R code
Rprof("profile.out")
# Run your code
Rprof(NULL)
summaryRprof("profile.out")
```

## Troubleshooting

### App Won't Start

**Symptom**: Error on startup

**Checks**:
1. Verify environment variables are set:
   ```r
   Sys.getenv("DB_HOST")
   Sys.getenv("DB_PASSWORD")
   ```

2. Test database connection:
   ```r
   library(DBI)
   library(RPostgres)
   con <- dbConnect(Postgres(),
     host = Sys.getenv("DB_HOST"),
     dbname = Sys.getenv("DB_NAME"),
     user = Sys.getenv("DB_USER"),
     password = Sys.getenv("DB_PASSWORD")
   )
   dbGetQuery(con, "SELECT 1")
   dbDisconnect(con)
   ```

3. Check file paths are correct:
   ```r
   list.files("app/modules")
   list.files("R")
   ```

### Database Connection Errors

**Symptom**: "could not connect to server" or pool errors

**Solutions**:
1. Verify PostgreSQL is running:
   ```bash
   sudo service postgresql status
   # or
   docker-compose ps
   ```

2. Check connection parameters:
   ```bash
   psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT current_database()"
   ```

3. Verify firewall rules allow connection on port 5432

4. Check PostgreSQL pg_hba.conf for authentication settings

### Module Loading Errors

**Symptom**: "object 'moduleNameUI' not found"

**Solutions**:
1. Verify module file exists:
   ```r
   file.exists("app/modules/module_name_module.R")
   ```

2. Check module is sourced in app/global.R:
   ```r
   source("app/global.R")
   ```

3. Verify module naming conventions:
   - File: `module_name_module.R`
   - UI function: `moduleNameUI`
   - Server function: `moduleNameServer`

### Performance Issues

**Symptom**: Slow queries or timeouts

**Solutions**:
1. Check database indexes:
   ```sql
   SELECT schemaname, tablename, indexname
   FROM pg_indexes
   WHERE schemaname = 'public';
   ```

2. Analyze slow queries:
   ```sql
   EXPLAIN ANALYZE SELECT ...;
   ```

3. Increase pool size in config/config.yml:
   ```yaml
   pool:
     max_size: 10  # Increase from 5
   ```

4. Enable query caching in relevant modules

## Maintenance Tasks

### Weekly
- [ ] Check application logs for errors
- [ ] Review database size and growth
- [ ] Verify backups completed successfully

### Monthly
- [ ] Run database VACUUM ANALYZE
- [ ] Review and rotate logs
- [ ] Update R packages: `renv::update()`
- [ ] Review security advisories

### Quarterly
- [ ] Update R version if needed
- [ ] Review and update dependencies
- [ ] Performance review and optimization
- [ ] Security audit

## Support

For issues not covered in this runbook:
- Check [CONTRIBUTING.md](../CONTRIBUTING.md) for development guidelines
- Review [README.md](../README.md) for project overview
- Contact: Dr. Michael Anesko (mwa2@psu.edu)
