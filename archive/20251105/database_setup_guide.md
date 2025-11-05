# Database Setup Guide for Online Hosting

When hosting your Shiny app online, you need a cloud-accessible database. Here are the best options for your American Authorship Database (updated January 2025):

## Option 1: Neon (Recommended - Best ElephantSQL Replacement)

**Neon** is the top choice for PostgreSQL hosting with an excellent free tier.

### Why Neon?
- ✅ **500MB storage** (25x more than old ElephantSQL)
- ✅ **No connection limits**
- ✅ **Built-in connection pooling**
- ✅ **Automatic backups**
- ✅ **Serverless PostgreSQL** with instant scaling
- ✅ **Branch databases** for development

### Setup Steps:

1. **Create Account**
   - Go to [Neon.tech](https://neon.tech/)
   - Sign up for free account
   - Click "Create a project"

2. **Configure Project**
   - Project name: `american-authorship-db`
   - Region: Choose closest to your users (US East/West, EU)
   - PostgreSQL version: Latest (16+)

3. **Get Connection Details**
   - Go to "Connection Details" in dashboard
   - Copy the connection string or individual parameters:
     - Host: `ep-cool-darkness-123456.us-east-2.aws.neon.tech`
     - Database: `neondb` (default)
     - Username: Usually your email prefix
     - Password: Generated password
     - Port: 5432
     - SSL: Required

4. **Update Your .env File**
   ```bash
   ./setup_neon.sh  # Use our helper script
   ```
   Or manually create:
   ```
   DB_HOST=ep-cool-darkness-123456.us-east-2.aws.neon.tech
   DB_NAME=neondb
   DB_USER=your-username
   DB_PASSWORD=your-neon-password
   DB_PORT=5432
   DB_SSLMODE=require
   ```

### Migrate Your Data:
```bash
# Use our migration script
./migrate_to_neon.sh

# Or manually:
pg_dump -h localhost -U siyang american_authorship > backup.sql
psql "postgresql://user:pass@host/dbname?sslmode=require" < backup.sql
```

## Option 2: Supabase (Firebase Alternative)

**Supabase** offers PostgreSQL with a generous free tier and built-in features.

### Benefits:
- ✅ **500MB database**
- ✅ **Real-time features** (if needed later)
- ✅ **Built-in authentication** (optional)
- ✅ **REST API** auto-generated

### Setup Steps:

1. **Create Account**
   - Go to [Supabase.com](https://supabase.com/)
   - Create new project: `american-authorship`

2. **Get Database URL**
   - Go to Settings → Database
   - Copy connection pooling URL (recommended)
   - Format: `postgresql://postgres.[ref]:[password]@aws-0-us-east-1.pooler.supabase.com:6543/postgres`

3. **Configuration**
   ```
   DB_HOST=aws-0-us-east-1.pooler.supabase.com
   DB_NAME=postgres
   DB_USER=postgres.abcdefgh
   DB_PASSWORD=your-supabase-password
   DB_PORT=6543
   DB_SSLMODE=require
   ```

## Option 3: Railway (Simple & Developer-Friendly)

**Railway** offers easy PostgreSQL deployment with generous free credits.

### Benefits:
- ✅ **$5 monthly credits** (covers small databases)
- ✅ **Easy GitHub integration**
- ✅ **One-click PostgreSQL**

### Setup Steps:

1. **Create Account**
   - Go to [Railway.app](https://railway.app/)
   - Sign up with GitHub

2. **Deploy PostgreSQL**
   - New Project → Add PostgreSQL
   - Get connection details from Variables tab

3. **Configuration**
   ```
   DB_HOST=roundhouse.proxy.rlwy.net
   DB_NAME=railway
   DB_USER=postgres
   DB_PASSWORD=generated-password
   DB_PORT=12345
   ```

## Option 4: Convert to SQLite (Simplest for Small Apps)

If your data is relatively small, SQLite is the simplest option requiring no cloud database.

### Migration Script:

```r
# Run this in your local R environment
library(DBI)
library(RPostgreSQL)
library(RSQLite)

# Connect to PostgreSQL
pg_con <- dbConnect(
  RPostgreSQL::PostgreSQL(),
  host = "localhost",
  dbname = "american_authorship",
  user = "siyang",
  password = "your-password"
)

# Create SQLite database
sqlite_con <- dbConnect(RSQLite::SQLite(), "shiny-app/data/american_authorship.sqlite")

# Get all table names
tables <- dbListTables(pg_con)

# Copy each table
for (table in tables) {
  data <- dbReadTable(pg_con, table)
  dbWriteTable(sqlite_con, table, data, overwrite = TRUE)
  cat("Copied table:", table, "\n")
}

# Close connections
dbDisconnect(pg_con)
dbDisconnect(sqlite_con)

cat("✅ SQLite database created at: shiny-app/data/american_authorship.sqlite\n")
```

### Update Database Utils for SQLite:

```r
# In utils/database.R, replace PostgreSQL connection with:
create_db_pool <- function() {
  tryCatch({
    pool::dbPool(
      drv = RSQLite::SQLite(),
      dbname = "data/american_authorship.sqlite",
      minSize = 1,
      maxSize = 5
    )
  }, error = function(e) {
    stop("Failed to create SQLite connection pool: ", e$message)
  })
}
```

## Option 5: PlanetScale (MySQL Alternative)

If you're open to converting from PostgreSQL to MySQL, **PlanetScale** offers excellent free hosting.

### Benefits:
- ✅ **5GB storage**
- ✅ **1 billion reads/month**
- ✅ **Branching databases**

**Note:** Requires converting your PostgreSQL schema to MySQL.

## Cost Comparison (Updated 2025)

| Service | Free Tier | Storage | Connections | Best For |
|---------|-----------|---------|-------------|----------|
| **Neon** | Forever | 500MB | Unlimited | PostgreSQL apps |
| **Supabase** | Forever | 500MB | Unlimited | Full-stack apps |
| **Railway** | $5/month credit | Varies | Unlimited | Simple deployment |
| **AWS RDS** | 12 months | 20GB | Limited | Production apps |
| **SQLite** | Forever | Unlimited | Single-user | Simple apps |

## Recommendations

- **For testing/demo**: Use **Neon** free tier
- **For production**: **Neon** Pro or **Railway**
- **For simple deployment**: Convert to **SQLite**
- **For full-stack features**: **Supabase**

## Quick Start Commands

```bash
# Option 1: Neon (Recommended)
./setup_neon.sh
./migrate_to_neon.sh
./test_app_with_neon.sh
./deploy_to_shinyapps.sh

# Option 2: SQLite (Simplest)
# Convert database first, then deploy
```

## Security Best Practices

1. **Always use SSL** connections (`sslmode=require`)
2. **Never commit credentials** to version control
3. **Use environment variables** for all database credentials
4. **Regular backups** of your cloud database
5. **Monitor usage** to avoid surprise costs

## Troubleshooting

### Common Issues:

1. **SSL Connection Required**: Most cloud providers require SSL
   ```
   DB_SSLMODE=require
   ```

2. **Connection timeout**: Check region and firewall settings

3. **Authentication failed**: 
   - Double-check username format (some providers use email prefixes)
   - Verify password copying (no extra spaces)

### Test Connection:

```r
# Add SSL mode to your connection
con <- dbConnect(
  RPostgreSQL::PostgreSQL(),
  host = "your-host",
  dbname = "your-db",
  user = "your-user", 
  password = "your-password",
  port = 5432,
  sslmode = "require"
)
```

---

**Updated**: January 2025 (Post-ElephantSQL shutdown)  
**Recommended**: Start with Neon for best ElephantSQL replacement experience 