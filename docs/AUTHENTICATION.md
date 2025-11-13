# Authentication System Documentation

## Overview

The American Authorship Database application now includes an optional authentication system using the `shinymanager` package. This provides basic but secure authentication suitable for academic use.

## Security Level

**Current Implementation: BASIC**
- Username/password authentication
- Bcrypt password hashing
- Session management
- Login attempt logging

**Suitable For:**
- Internal academic use
- Small teams (< 50 users)
- Historical research data (non-sensitive PII)

**NOT Suitable For:**
- Public-facing applications with sensitive data
- HIPAA/GDPR-sensitive applications
- High-security requirements

For production deployments with sensitive data, consider upgrading to:
- OAuth2 (Auth0, Okta, Google)
- SAML/LDAP integration
- Multi-factor authentication (MFA)

## Installation

### 1. Install Required Package

```r
install.packages("shinymanager")
install.packages("bcrypt")  # For password hashing
```

### 2. Enable Authentication

```bash
# Option A: Rename authenticated version
mv shiny-app/app.R shiny-app/app_original.R
mv shiny-app/app_with_auth.R shiny-app/app.R

# Option B: Use environment variable
export AUTH_ENABLED=true
```

### 3. Configure Users

See "User Management" section below.

## User Management

### Default Demo Users

For testing purposes, three demo users are provided:

| Username   | Password   | Role       | Notes                        |
|------------|------------|------------|------------------------------|
| admin      | admin123   | Admin      | Full access + user management |
| researcher | research   | User       | Full read access             |
| viewer     | view       | User       | Read-only access             |

⚠️ **CRITICAL**: Change these passwords immediately in production!

### Creating Production Users

#### Method 1: Using R Script

```r
# Load the authentication configuration
source("shiny-app/config/auth_config.R")

# Create a new user
new_user <- create_user(
  username = "john.doe",
  password = "SecurePassword123!",
  is_admin = FALSE,
  expire_date = as.Date("2025-12-31")
)

# Load existing credentials
credentials <- readRDS("shiny-app/config/users.rds")

# Add new user
credentials <- rbind(credentials, new_user)

# Save back
saveRDS(credentials, "shiny-app/config/users.rds")
```

#### Method 2: Interactive User Management

```r
# Run the user management script
source("shiny-app/scripts/manage_users.R")
```

This provides an interactive menu for:
- Adding users
- Removing users
- Changing passwords
- Setting expiration dates
- Enabling/disabling accounts

### Password Requirements

For production, enforce strong passwords:
- Minimum 12 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number
- At least one special character
- Not in common password dictionaries

### Password Hashing

All passwords are hashed using bcrypt before storage:

```r
# Hash a password
hashed <- bcrypt::hashpw("MySecurePassword")

# Verify a password
bcrypt::checkpw("MySecurePassword", hashed)  # Returns TRUE
```

**Never store plain-text passwords!**

## Configuration Options

### Environment Variables

Set these in `.env` file or environment:

```bash
# Authentication settings
AUTH_ENABLED=true
AUTH_SOURCE=demo|file|database
AUTH_SESSION_TIMEOUT=60  # minutes
MAX_FAILED_ATTEMPTS=5
LOCKOUT_DURATION=30  # minutes

# Environment
R_ENV=development|production
```

### Configuration File

Edit `shiny-app/config/auth_config.R` to customize:

```r
# Session timeout (in minutes)
AUTH_SESSION_TIMEOUT <- 60

# Maximum failed login attempts
MAX_FAILED_ATTEMPTS <- 5

# Lockout duration after failed attempts
LOCKOUT_DURATION <- 30  # minutes

# UI customization
auth_ui_config <- list(
  title = "American Authorship Database",
  language = "en",
  logo = "www/logo.png",  # Optional
  background_image = "www/bg.jpg",  # Optional
  cookie_expiration = 7  # days
)
```

## Authentication Sources

### Demo Credentials (Development Only)

```bash
export AUTH_SOURCE=demo
```

Uses hardcoded credentials from `create_demo_credentials()`. **Never use in production!**

### File-Based (Recommended for Small Teams)

```bash
export AUTH_SOURCE=file
```

Stores encrypted credentials in `config/users.rds`:

```r
# Create initial users file
credentials <- data.frame(
  user = c("admin", "user1"),
  password = c(
    bcrypt::hashpw("admin_password"),
    bcrypt::hashpw("user_password")
  ),
  admin = c(TRUE, FALSE),
  start = Sys.Date(),
  expire = Sys.Date() + 365,
  stringsAsFactors = FALSE
)

saveRDS(credentials, "shiny-app/config/users.rds")
```

**Security**: Ensure `users.rds` is in `.gitignore` and has restricted file permissions:

```bash
chmod 600 shiny-app/config/users.rds
```

### Database-Based (Recommended for Production)

```bash
export AUTH_SOURCE=database
```

Stores users in PostgreSQL database. Create the users table:

```sql
CREATE TABLE app_users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    is_admin BOOLEAN DEFAULT FALSE,
    account_start DATE DEFAULT CURRENT_DATE,
    account_expire DATE,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    failed_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP
);

-- Create index for faster lookups
CREATE INDEX idx_app_users_username ON app_users(username);
CREATE INDEX idx_app_users_active ON app_users(active);

-- Example: Insert admin user
INSERT INTO app_users (username, password_hash, is_admin, account_expire)
VALUES (
    'admin',
    '$2a$10$VcfBD4N2Fg5UuHLPKJbPQeFZWwF7x.1D5dTfQ2Rg4Hqm6S8LD/fey',  -- Change this!
    TRUE,
    '2025-12-31'
);
```

## Security Logging

All authentication events are logged to `logs/auth/auth_YYYYMM.log`:

```
[2025-11-13 10:15:32] login_success | User: admin | IP: 192.168.1.100 | Session: abc123
[2025-11-13 10:45:18] login_failure | User: hacker | IP: 10.0.0.5 | Invalid password
[2025-11-13 11:30:22] logout | User: admin | IP: 192.168.1.100 | Session ended
```

### Monitoring Failed Login Attempts

```bash
# Show failed login attempts
grep "login_failure" logs/auth/auth_*.log

# Show suspicious activity (multiple failures from same IP)
grep "login_failure" logs/auth/auth_*.log | awk '{print $8}' | sort | uniq -c | sort -rn

# Lock an account after suspicious activity
# (Implement in database or user management script)
```

## Session Management

### Session Timeout

Sessions automatically expire after `AUTH_SESSION_TIMEOUT` minutes of inactivity:

```r
# In server
observe({
  invalidateLater(AUTH_SESSION_TIMEOUT * 60 * 1000)

  showNotification(
    paste("Session expires in", AUTH_SESSION_TIMEOUT, "minutes"),
    type = "warning"
  )
})
```

### Forced Logout

Admins can force logout all users by restarting the Shiny server.

For individual user logout, implement in the database:

```sql
-- Add to app_users table
ALTER TABLE app_users ADD COLUMN force_logout BOOLEAN DEFAULT FALSE;

-- Force logout a user
UPDATE app_users SET force_logout = TRUE WHERE username = 'john.doe';
```

## Admin Panel

When `enable_admin = TRUE`, admin users can access the user management panel:

1. Login as an admin user
2. Click the "Admin" button in the top-right corner
3. Manage users:
   - Add new users
   - Edit existing users
   - Deactivate accounts
   - Reset passwords
   - View login history

## Troubleshooting

### Issue: "shinymanager package not found"

```r
install.packages("shinymanager")
install.packages("bcrypt")
```

### Issue: "Credentials not found"

Ensure AUTH_SOURCE is set correctly:

```bash
export AUTH_SOURCE=demo  # or file, or database
```

### Issue: "Cannot login with correct password"

Check password hash:

```r
# Verify password
bcrypt::checkpw("your_password", "$2a$10$...")

# If false, regenerate hash
new_hash <- bcrypt::hashpw("your_password")
```

### Issue: "Session expires too quickly"

Increase timeout:

```bash
export AUTH_SESSION_TIMEOUT=120  # 2 hours
```

### Issue: "Too many failed login attempts"

Reset failed attempts:

```sql
-- If using database
UPDATE app_users SET failed_attempts = 0, locked_until = NULL WHERE username = 'john.doe';
```

```r
# If using file
credentials <- readRDS("config/users.rds")
# Manually edit and save
saveRDS(credentials, "config/users.rds")
```

## Migration from Unauthenticated Version

To migrate from the unauthenticated version:

1. **Backup current app.R**:
   ```bash
   cp shiny-app/app.R shiny-app/app_no_auth.R
   ```

2. **Copy authenticated version**:
   ```bash
   cp shiny-app/app_with_auth.R shiny-app/app.R
   ```

3. **Install dependencies**:
   ```r
   install.packages(c("shinymanager", "bcrypt"))
   ```

4. **Create initial users**:
   ```r
   source("shiny-app/config/auth_config.R")
   credentials <- create_demo_credentials()  # Replace with real users
   saveRDS(credentials, "shiny-app/config/users.rds")
   ```

5. **Test locally**:
   ```r
   shiny::runApp("shiny-app/")
   ```

6. **Configure for production**:
   ```bash
   export AUTH_SOURCE=file  # or database
   export AUTH_SESSION_TIMEOUT=60
   ```

## Best Practices

### Development

- ✅ Use demo credentials
- ✅ Set AUTH_SOURCE=demo
- ✅ Log all authentication events
- ✅ Test with different user roles

### Staging

- ✅ Use file-based credentials
- ✅ Set AUTH_SOURCE=file
- ✅ Test password changes
- ✅ Test session timeouts
- ✅ Monitor authentication logs

### Production

- ✅ Use database-based credentials
- ✅ Set AUTH_SOURCE=database
- ✅ Use strong passwords (12+ characters)
- ✅ Enforce password expiration (90 days)
- ✅ Enable account lockout after failed attempts
- ✅ Monitor logs for suspicious activity
- ✅ Regular security audits
- ✅ Consider upgrading to OAuth2/SAML for sensitive data
- ❌ Never use demo credentials
- ❌ Never store passwords in plain text
- ❌ Never commit users.rds to git

## Future Enhancements

Consider implementing:

1. **Multi-Factor Authentication (MFA)**
   - TOTP (Google Authenticator, Authy)
   - SMS verification
   - Email verification

2. **OAuth2 Integration**
   - Google Sign-In
   - Microsoft Azure AD
   - GitHub authentication

3. **SAML/LDAP**
   - Enterprise SSO
   - Active Directory integration

4. **Enhanced Security**
   - Password complexity requirements
   - Password history (prevent reuse)
   - Account lockout policies
   - IP whitelisting
   - Rate limiting

5. **Audit Trail**
   - User activity logging
   - Data access logs
   - Compliance reporting

## References

- [shinymanager documentation](https://datastorm-open.github.io/shinymanager/)
- [bcrypt package](https://cran.r-project.org/package=bcrypt)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
