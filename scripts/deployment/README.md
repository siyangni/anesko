# Deployment Scripts

This directory contains deployment scripts for the anesko project.

## 🔐 Security Setup (IMPORTANT - READ FIRST)

These scripts use environment variables for credentials instead of hardcoded values for better security.

### Initial Setup

1. **Copy the environment template:**
   ```bash
   cp scripts/deployment/.env.template scripts/deployment/.env
   ```

2. **Edit the .env file with your actual credentials:**
   ```bash
   nano scripts/deployment/.env  # or use your preferred editor
   ```

3. **Source the environment variables before running scripts:**
   ```bash
   source scripts/deployment/.env
   ```

4. **Add .env to .gitignore (if not already done):**
   ```bash
   echo "scripts/deployment/.env" >> .gitignore
   ```

### Required Environment Variables

**For Database Connection (connect_neondb.sh):**
- `DB_HOST` - NeonDB host address
- `DB_USER` - Database username
- `DB_PASSWORD` - Database password
- `DB_NAME` - Database name
- `DB_SSL_MODE` - SSL mode (usually 'require')
- `DB_CHANNEL_BINDING` - Channel binding (usually 'require')

**For Shiny Deployment (deploy_shiny.R):**
- `SHINY_ACCOUNT_NAME` - Your shinyapps.io account name
- `SHINY_TOKEN` - Your shinyapps.io token
- `SHINY_SECRET` - Your shinyapps.io secret

## Scripts Overview

### 1. Database Connection Script (`connect_neondb.sh`)

A bash script for connecting to the NeonDB PostgreSQL database.

**Prerequisites:**
- PostgreSQL client (`psql`) must be installed
- Environment variables configured (see Security Setup above)
- Network connectivity to NeonDB

**Usage:**
```bash
# First, source your environment variables
source scripts/deployment/.env

# Interactive connection (default)
./scripts/deployment/connect_neondb.sh

# Test database connection
./scripts/deployment/connect_neondb.sh test

# Show database information
./scripts/deployment/connect_neondb.sh info

# Execute SQL command
./scripts/deployment/connect_neondb.sh sql "SELECT NOW();"

# Show help
./scripts/deployment/connect_neondb.sh help
```

**Installation of PostgreSQL client:**
- Ubuntu/Debian: `sudo apt-get install postgresql-client`
- macOS: `brew install postgresql`
- CentOS/RHEL: `sudo yum install postgresql`

### 2. Shiny App Deployment Script (`deploy_shiny.R`)

An R script for deploying Shiny applications to shinyapps.io.

**Prerequisites:**
- R with `rsconnect` and `shiny` packages installed
- Environment variables configured (see Security Setup above)
- Shiny app files (app.R, ui.R, or server.R)
- Network connectivity to shinyapps.io

**Usage:**
```bash
# First, source your environment variables
source scripts/deployment/.env

# Deploy current directory
Rscript scripts/deployment/deploy_shiny.R

# Deploy specific directory
Rscript scripts/deployment/deploy_shiny.R deploy ./path/to/app

# Deploy with custom app name
Rscript scripts/deployment/deploy_shiny.R deploy ./path/to/app my_custom_name

# Check deployment status
Rscript scripts/deployment/deploy_shiny.R status

# Show help
Rscript scripts/deployment/deploy_shiny.R help
```

**Installation of required R packages:**
```r
install.packages(c("rsconnect", "shiny"))
```

## Security Notes

✅ **Secure Configuration:** These scripts now use environment variables for all sensitive credentials.

**Security Features:**
- No hardcoded credentials in script files
- Credentials stored in `.env` file (excluded from version control)
- Environment variable validation before script execution
- Clear error messages for missing credentials

**Security Best Practices:**
1. **Never commit the .env file** - ensure it's in your .gitignore
2. **Restrict file permissions:** `chmod 600 scripts/deployment/.env`
3. **Regularly rotate credentials** in your .env file
4. **Use different credentials** for different environments (dev/staging/prod)
5. **Keep the .env.template file** updated but without actual values

## Environment Variable Setup Examples

### Quick Setup
```bash
# Copy template and edit
cp scripts/deployment/.env.template scripts/deployment/.env
nano scripts/deployment/.env

# Source before each use
source scripts/deployment/.env

# Run scripts
./scripts/deployment/connect_neondb.sh test
Rscript scripts/deployment/deploy_shiny.R status
```

### Automated Setup (for CI/CD)
```bash
# Set environment variables directly
export DB_HOST="your-host.aws.neon.tech"
export DB_USER="your_user"
export DB_PASSWORD="your_password"
export DB_NAME="your_database"
export DB_SSL_MODE="require"
export DB_CHANNEL_BINDING="require"
export SHINY_ACCOUNT_NAME="your_account"
export SHINY_TOKEN="your_token"
export SHINY_SECRET="your_secret"

# Run scripts directly
./scripts/deployment/connect_neondb.sh
Rscript scripts/deployment/deploy_shiny.R
```

## Troubleshooting

### Database Connection Issues
- Verify PostgreSQL client is installed: `psql --version`
- Test network connectivity to NeonDB
- Check firewall settings
- Verify SSL requirements are met

### Shiny Deployment Issues
- Ensure all required packages are installed
- Check app directory contains valid Shiny files
- Verify shinyapps.io account credentials
- Check for package dependency conflicts

### Common Error Solutions

**"Missing required environment variables"**
```bash
# Make sure you've sourced your .env file
source scripts/deployment/.env

# Or check if variables are set
echo $DB_HOST
echo $SHINY_ACCOUNT_NAME
```

**"psql: command not found"**
```bash
# Install PostgreSQL client
sudo apt-get install postgresql-client  # Ubuntu/Debian
brew install postgresql                 # macOS
```

**"rsconnect package not found"**
```r
install.packages("rsconnect")
```

**"SSL connection error"**
- Ensure your system supports SSL/TLS connections
- Check if corporate firewall is blocking connections
- Verify DB_SSL_MODE is set correctly in .env

**"Invalid credentials"**
- Double-check your .env file values
- Ensure no extra spaces or quotes around values
- Verify credentials are still valid (not expired)

## File Permissions

Both scripts are executable. If you need to reset permissions:
```bash
chmod +x scripts/deployment/connect_neondb.sh
chmod +x scripts/deployment/deploy_shiny.R
```

## Support

For issues with:
- **NeonDB**: Check NeonDB documentation and support
- **shinyapps.io**: Check RStudio/Posit documentation
- **Script bugs**: Review error messages and logs
