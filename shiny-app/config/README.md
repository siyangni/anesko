# Configuration Directory

This directory contains configuration files for the American Authorship Database Shiny application.

## Files

### `app_config.R`
Main application configuration with constants and settings. **Tracked in git.**

Contains:
- App metadata (title, version)
- UI settings (sidebar width, plot dimensions)
- Data processing constants (thresholds, limits)
- Feature flags
- Text constants

### `cloud_config.R`
Database connection configuration. **NOT tracked in git** (in .gitignore).

⚠️ **SECURITY: Never commit this file with real credentials!**

#### Setup for Development

The file has been created with localhost defaults. To use a different database:

1. Set environment variables:
```bash
export DB_HOST="your-database-host"
export DB_NAME="american_authorship"
export DB_USER="your-username"
export DB_PASSWORD="your-password"
export DB_PORT="5432"
```

2. Or create a `.env` file in the shiny-app directory:
```
DB_HOST=your-database-host
DB_NAME=american_authorship
DB_USER=your-username
DB_PASSWORD=your-password
DB_PORT=5432
```

#### Setup for Production

For production deployments (ShinyApps.io, Docker, etc.):

1. **Never hardcode credentials** in cloud_config.R
2. Use platform-specific secret management:
   - **ShinyApps.io**: Set in application settings
   - **Docker**: Use secrets or environment variables
   - **Self-hosted**: Use system environment variables

### `cloud_config.template.R`
Template for cloud_config.R with environment variable loading logic. **Tracked in git.**

Use this as a reference when setting up a new environment.

### `.env.template`
Template for environment variables file. **Tracked in git.**

Copy to `.env` and fill in your credentials (`.env` is gitignored).

### `auth_config.R`
Authentication configuration for app_with_auth.R variant. **Tracked in git.**

## Security Best Practices

1. ✅ `cloud_config.R` is in `.gitignore` - never commit it
2. ✅ Use environment variables for all sensitive data
3. ✅ Rotate credentials if they were ever committed to git
4. ✅ Use different credentials for dev/staging/production
5. ✅ Enable SSL/TLS for remote database connections

## Current Status

- `cloud_config.R` - **Created locally** (uses localhost defaults for development)
- **Action Required**: Update with your database credentials or set environment variables

## Troubleshooting

**App fails to start with "cannot open cloud_config.R"**
- The file should now exist with development defaults
- Check that you're in the `shiny-app/` directory when running the app

**Database connection fails**
- Verify PostgreSQL is running: `sudo service postgresql status`
- Check credentials in cloud_config.R or environment variables
- Test connection: `psql -h localhost -U siyang -d american_authorship`

**"Using local database (development mode)" warning**
- This is normal for local development
- Set environment variables to connect to a remote database
