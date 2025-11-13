# Complete Guide: Hosting R Shiny Dashboard with NeonDB

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Part 1: NeonDB Setup](#part-1-neondb-setup)
4. [Part 2: Database Migration](#part-2-database-migration)
5. [Part 3: Shiny Hosting Options](#part-3-shiny-hosting-options)
6. [Part 4: Production Configuration](#part-4-production-configuration)
7. [Part 5: Testing & Validation](#part-5-testing--validation)
8. [Part 6: Monitoring & Maintenance](#part-6-monitoring--maintenance)
9. [Troubleshooting](#troubleshooting)

---

## Overview

This guide covers hosting your **American Authorship Database (1860-1920)** dashboard using:
- **Backend Database**: NeonDB (Serverless PostgreSQL)
- **Application**: R Shiny Dashboard
- **Hosting Options**: ShinyApps.io, Shiny Server (self-hosted), or Docker-based deployment

### Why NeonDB?
- ✅ Serverless PostgreSQL (autoscales, pay-per-use)
- ✅ Built-in connection pooling
- ✅ Automatic backups and point-in-time recovery
- ✅ Free tier available (3 GiB storage, 10 compute hours)
- ✅ Low latency with edge computing
- ✅ No server maintenance required

### Architecture Overview
```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│   End Users     │────────>│  Shiny Server    │────────>│    NeonDB       │
│   (Browsers)    │<────────│  (R Application) │<────────│  (PostgreSQL)   │
└─────────────────┘         └──────────────────┘         └─────────────────┘
```

---

## Prerequisites

### Required Accounts
1. **NeonDB Account**: [https://neon.tech/](https://neon.tech/) (free tier available)
2. **Shiny Hosting** (choose one):
   - ShinyApps.io account: [https://www.shinyapps.io/](https://www.shinyapps.io/)
   - OR self-hosted server (DigitalOcean, AWS, GCP, etc.)
   - OR Docker environment

### Required Tools
```bash
# R (version 4.0+)
R --version

# PostgreSQL client (for database operations)
psql --version

# Docker (if using Docker deployment)
docker --version
docker-compose --version

# Git
git --version
```

### R Packages
```r
# Install required packages
install.packages(c(
  "shiny", "shinydashboard", "shinydashboardPlus",
  "DBI", "RPostgres", "pool",
  "dplyr", "tidyr", "ggplot2", "plotly",
  "rsconnect"  # for ShinyApps.io deployment
))
```

---

## Part 1: NeonDB Setup

### Step 1.1: Create NeonDB Project

1. **Sign up/Login** to [Neon Console](https://console.neon.tech/)

2. **Create New Project**:
   - Click "Create Project"
   - Project name: `american-authorship-db`
   - PostgreSQL version: `15` (recommended)
   - Region: Choose closest to your Shiny server location
     - US East (Ohio) - `aws-us-east-2`
     - US West (Oregon) - `aws-us-west-2`
     - Europe (Frankfurt) - `aws-eu-central-1`

3. **Save Connection Details**:
   After creation, you'll see:
   ```
   Host: ep-xxx-xxx.us-east-2.aws.neon.tech
   Database: neondb
   User: your-username
   Password: ************
   Port: 5432
   ```

   **Connection String Format**:
   ```
   postgresql://username:password@ep-xxx-xxx.region.aws.neon.tech/neondb?sslmode=require
   ```

### Step 1.2: Configure Database Settings

1. **Enable Connection Pooling** (Recommended for Shiny):
   - In Neon Console → Settings → Connection Pooling
   - Enable "Pooler"
   - Mode: `Transaction` (best for Shiny apps)
   - Pool size: `50` connections (adjust based on traffic)

   **Pooled Connection String**:
   ```
   postgresql://username:password@ep-xxx-xxx-pooler.region.aws.neon.tech/neondb?sslmode=require
   ```

2. **Set Compute Size** (based on expected load):
   - **Free Tier**: 0.25 vCPU, 1 GB RAM (good for development/low traffic)
   - **Small**: 0.5 vCPU, 2 GB RAM (~100 concurrent users)
   - **Medium**: 1 vCPU, 4 GB RAM (~500 concurrent users)
   - **Large**: 2+ vCPU, 8+ GB RAM (high traffic)

3. **Configure Autoscaling**:
   - Settings → Compute → Autoscaling
   - Minimum: 0.25 vCPU (cost-effective)
   - Maximum: 2 vCPU (prevent runaway costs)
   - Auto-suspend: 5 minutes (saves costs when idle)

### Step 1.3: Secure Your Database

1. **IP Allowlist** (Optional but recommended):
   - Settings → Security → IP Allow
   - Add your Shiny server IP address
   - Or use `0.0.0.0/0` for any IP (less secure)

2. **Protected Branches** (Production safety):
   - Create `production` branch (protected)
   - Use `development` branch for testing
   - Prevents accidental data loss

---

## Part 2: Database Migration

### Step 2.1: Prepare Local Data

Your current database structure:
```
Tables:
- book_entries (630+ books)
- book_sales (63 years of sales data)
- royalty_tiers (royalty rate information)
- app_users (optional, for authentication)
```

### Step 2.2: Export Existing Data

If you have an existing PostgreSQL database:

```bash
# Export schema and data
pg_dump -h localhost -U youruser -d yourdb \
  --format=plain \
  --no-owner \
  --no-acl \
  -f american_authorship_backup.sql

# Or export specific tables
pg_dump -h localhost -U youruser -d yourdb \
  -t book_entries -t book_sales -t royalty_tiers \
  --format=plain \
  -f american_authorship_tables.sql
```

If starting from CSV/Excel files (located in your project):
```bash
# Your data files are in: db/data/
# They should NOT be in git (sensitive data)
# Make sure you have:
# - book_entries.csv
# - book_sales.csv
# - royalty_tiers.csv
```

### Step 2.3: Run Migration Script

Your repository includes migration scripts. Use the automated script:

```bash
cd /home/user/anesko

# 1. Set up NeonDB environment variables
export NEON_HOST="ep-xxx-xxx.region.aws.neon.tech"
export NEON_DATABASE="neondb"
export NEON_USER="your-username"
export NEON_PASSWORD="your-password"
export NEON_PORT="5432"

# 2. Run migration script
bash deployment/migrate_to_neon.sh
```

**What this script does**:
1. Tests connection to NeonDB
2. Creates database schema (migrations in `db/migrations/`)
3. Imports data from your local files
4. Creates indexes for performance
5. Sets up user authentication (if using auth)
6. Validates data integrity

### Step 2.4: Manual Migration (Alternative)

If you prefer manual control:

```bash
# 1. Connect to NeonDB
psql "postgresql://username:password@ep-xxx-xxx.region.aws.neon.tech/neondb?sslmode=require"

# 2. Create schema
\i db/migrations/001_create_schema.sql
\i db/migrations/002_create_indexes.sql
\i db/migrations/003_create_auth_tables.sql

# 3. Import data
\copy book_entries FROM 'db/data/book_entries.csv' CSV HEADER;
\copy book_sales FROM 'db/data/book_sales.csv' CSV HEADER;
\copy royalty_tiers FROM 'db/data/royalty_tiers.csv' CSV HEADER;

# 4. Verify
SELECT COUNT(*) FROM book_entries;
SELECT COUNT(*) FROM book_sales;
SELECT COUNT(*) FROM royalty_tiers;

# Should see: 630+ books, 63 years of sales data
```

### Step 2.5: Optimize for Production

```sql
-- Run ANALYZE to update query planner statistics
ANALYZE book_entries;
ANALYZE book_sales;
ANALYZE royalty_tiers;

-- Verify indexes exist
\di

-- Create additional indexes if needed for common queries
CREATE INDEX IF NOT EXISTS idx_sales_year ON book_sales(year);
CREATE INDEX IF NOT EXISTS idx_book_genre ON book_entries(genre);
CREATE INDEX IF NOT EXISTS idx_book_author ON book_entries(author_surname);
CREATE INDEX IF NOT EXISTS idx_book_gender ON book_entries(gender);
```

---

## Part 3: Shiny Hosting Options

You have **three main options** for hosting your Shiny dashboard. Choose based on your needs:

| Option | Best For | Cost | Complexity | Scalability |
|--------|----------|------|------------|-------------|
| **ShinyApps.io** | Quick deployment, small teams | $$ (paid tiers) | Low | Medium |
| **Shiny Server (Self-hosted)** | Full control, cost-effective | $ (server only) | Medium | High |
| **Docker (AWS/GCP/Azure)** | Enterprise, DevOps teams | $$ (cloud costs) | High | Very High |

---

### Option A: ShinyApps.io (Easiest - Recommended for Beginners)

**Pros**: Managed service, easy deployment, automatic scaling
**Cons**: Recurring costs, less control, data transfer limits

#### A.1: Configure Connection

Create a configuration file for NeonDB:

```bash
# Edit: shiny-app/config/.env
cd /home/user/anesko/shiny-app/config
cp .env.template .env
nano .env
```

Add your NeonDB credentials:
```bash
# NeonDB Connection (use pooled connection!)
DB_HOST=ep-xxx-xxx-pooler.region.aws.neon.tech
DB_NAME=neondb
DB_USER=your-username
DB_PASSWORD=your-secure-password
DB_PORT=5432
DB_SSL_MODE=require

# Important: Use the POOLED connection string for production
# Pooled endpoint ends with: -pooler.region.aws.neon.tech
```

#### A.2: Update cloud_config.R

Your app already has cloud configuration. Verify it's reading environment variables:

```bash
# Check: shiny-app/config/cloud_config.R
# Should load .env file automatically
```

#### A.3: Deploy to ShinyApps.io

```bash
# Install rsconnect package
R -e "install.packages('rsconnect')"

# Authenticate (get credentials from shinyapps.io dashboard)
R -e "rsconnect::setAccountInfo(
  name='your-account-name',
  token='YOUR-TOKEN',
  secret='YOUR-SECRET'
)"

# Deploy using your existing script
cd /home/user/anesko
bash deployment/deploy_to_shinyapps.sh
```

Or deploy manually:
```r
library(rsconnect)

# Deploy app
rsconnect::deployApp(
  appDir = "shiny-app",
  appName = "american-authorship",
  appTitle = "American Authorship Database (1860-1920)",
  contentCategory = "application",
  account = "your-account-name",
  forceUpdate = TRUE
)
```

#### A.4: Configure ShinyApps.io Settings

After deployment:

1. **Set Environment Variables**:
   - Go to: https://www.shinyapps.io/admin/#/applications
   - Click your app → Settings → Variables
   - Add:
     ```
     DB_HOST = ep-xxx-xxx-pooler.region.aws.neon.tech
     DB_NAME = neondb
     DB_USER = your-username
     DB_PASSWORD = ************
     DB_PORT = 5432
     DB_SSL_MODE = require
     ```

2. **Configure Instance Size**:
   - Settings → General → Instance Size
   - **Small** (1GB RAM): Good for 25-50 concurrent users
   - **Medium** (2GB RAM): Good for 100-200 users
   - **Large** (4GB RAM): 500+ users

3. **Set Startup Options**:
   - Max Worker Processes: 3-5 (based on instance size)
   - Connection Timeout: 60 seconds
   - Idle Timeout: 5 minutes (to save resources)

4. **Access Your App**:
   ```
   https://your-account-name.shinyapps.io/american-authorship/
   ```

---

### Option B: Self-Hosted Shiny Server (Most Flexible)

**Pros**: Full control, one-time costs, unlimited users (hardware-limited)
**Cons**: Requires server management, security updates

#### B.1: Provision Server

Choose a cloud provider:

**DigitalOcean Droplet** (Recommended for simplicity):
```bash
# Recommended specs:
- Image: Ubuntu 22.04 LTS
- Size: 2 vCPU, 4 GB RAM ($24/month)
- Storage: 80 GB SSD
- Region: Same as NeonDB region
```

**AWS EC2**:
```bash
# Instance type: t3.medium or t3.large
# AMI: Ubuntu Server 22.04 LTS
```

**Google Cloud Compute Engine**:
```bash
# Machine type: e2-medium or e2-standard-2
# Boot disk: Ubuntu 22.04 LTS
```

#### B.2: Install Shiny Server

SSH into your server:
```bash
ssh root@your-server-ip
```

Run the installation script:
```bash
# Update system
apt update && apt upgrade -y

# Install R
apt install -y software-properties-common dirmngr
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marullus.asc | \
  tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"
apt update
apt install -y r-base r-base-dev

# Install system dependencies
apt install -y \
  libpq-dev \
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  libsodium-dev \
  gdebi-core

# Install Shiny and Shiny Server
R -e "install.packages('shiny', repos='https://cran.rstudio.com/')"

# Download and install Shiny Server
wget https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.21.1012-amd64.deb
gdebi -n shiny-server-1.5.21.1012-amd64.deb

# Verify installation
systemctl status shiny-server
```

#### B.3: Install R Dependencies

```bash
# Install all required packages
R -e "install.packages(c(
  'shiny', 'shinydashboard', 'shinydashboardPlus', 'shinyWidgets',
  'DBI', 'RPostgres', 'pool',
  'dplyr', 'tidyr', 'ggplot2', 'plotly', 'DT',
  'lubridate', 'scales', 'stringr', 'htmltools',
  'fresh', 'waiter', 'logger', 'bcrypt'
), repos='https://cran.rstudio.com/')"
```

#### B.4: Deploy Your App

```bash
# Clone your repository
cd /srv/shiny-server
git clone https://github.com/siyangni/anesko.git
cd anesko

# Or upload your app files via rsync
# rsync -avz -e ssh shiny-app/ root@your-server-ip:/srv/shiny-server/american-authorship/

# Create symlink to app
ln -s /srv/shiny-server/anesko/shiny-app /srv/shiny-server/american-authorship

# Set environment variables
nano /etc/environment
```

Add to `/etc/environment`:
```bash
DB_HOST="ep-xxx-xxx-pooler.region.aws.neon.tech"
DB_NAME="neondb"
DB_USER="your-username"
DB_PASSWORD="your-secure-password"
DB_PORT="5432"
DB_SSL_MODE="require"
```

Or use a systemd service file (more secure):
```bash
nano /etc/systemd/system/shiny-server.service.d/override.conf
```

Add:
```ini
[Service]
Environment="DB_HOST=ep-xxx-xxx-pooler.region.aws.neon.tech"
Environment="DB_NAME=neondb"
Environment="DB_USER=your-username"
Environment="DB_PASSWORD=your-secure-password"
Environment="DB_PORT=5432"
Environment="DB_SSL_MODE=require"
```

#### B.5: Configure Shiny Server

Edit configuration:
```bash
nano /etc/shiny-server/shiny-server.conf
```

Recommended production configuration:
```nginx
# Run as shiny user
run_as shiny;

# Define server
server {
  listen 3838;

  # Define location
  location /american-authorship {
    site_dir /srv/shiny-server/american-authorship;
    log_dir /var/log/shiny-server;

    # Directory index
    directory_index off;

    # Connection settings
    app_init_timeout 120;
    app_idle_timeout 300;

    # Resource limits
    simple_scheduler 20;  # Max 20 R processes
  }

  # Health check endpoint
  location /health {
    site_dir /srv/shiny-server/health;
    log_dir /var/log/shiny-server;
  }
}
```

#### B.6: Set Up Nginx Reverse Proxy (Optional but Recommended)

Install Nginx for SSL and better performance:
```bash
apt install -y nginx certbot python3-certbot-nginx
```

Configure Nginx:
```bash
nano /etc/nginx/sites-available/shiny-app
```

Add configuration:
```nginx
server {
    listen 80;
    server_name your-domain.com;

    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    # SSL certificates (obtain via certbot)
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Proxy to Shiny Server
    location / {
        proxy_pass http://127.0.0.1:3838;
        proxy_redirect off;
        proxy_http_version 1.1;

        # WebSocket support (for Shiny reactivity)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
```

Enable and get SSL certificate:
```bash
# Enable site
ln -s /etc/nginx/sites-available/shiny-app /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx

# Get SSL certificate (free from Let's Encrypt)
certbot --nginx -d your-domain.com
```

#### B.7: Start Services

```bash
# Restart Shiny Server
systemctl restart shiny-server
systemctl enable shiny-server

# Check status
systemctl status shiny-server

# View logs
tail -f /var/log/shiny-server/american-authorship-shiny-*.log
```

Access your app:
- HTTP: `http://your-server-ip:3838/american-authorship`
- HTTPS (with Nginx): `https://your-domain.com/`

---

### Option C: Docker Deployment (Most Scalable)

**Pros**: Portable, reproducible, easy scaling, CI/CD friendly
**Cons**: Requires Docker knowledge, more complex setup

Your repository already includes Docker configurations!

#### C.1: Prepare Docker Environment

Your Dockerfile is already configured:
```bash
# Location: /home/user/anesko/Dockerfile
# Includes all dependencies and proper configuration
```

Your docker-compose.yml separates services:
```yaml
services:
  postgres:  # Local PostgreSQL (can skip if using NeonDB)
  shiny:     # R Shiny application
```

#### C.2: Configure for NeonDB

Edit docker-compose to use NeonDB instead of local PostgreSQL:

```bash
cd /home/user/anesko
nano docker-compose.yml
```

Update to:
```yaml
version: '3.8'

services:
  shiny:
    build: .
    container_name: american-authorship-shiny
    ports:
      - "3838:3838"
    environment:
      # NeonDB connection
      DB_HOST: ep-xxx-xxx-pooler.region.aws.neon.tech
      DB_NAME: neondb
      DB_USER: your-username
      DB_PORT: 5432
      DB_SSL_MODE: require
    secrets:
      - db_password
    volumes:
      - ./shiny-app/logs:/var/log/shiny-server
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3838/american-authorship/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'
          memory: 1G

secrets:
  db_password:
    file: ./secrets/db_password.txt

networks:
  default:
    name: authorship_network
```

#### C.3: Build and Deploy Locally

```bash
# 1. Create password secret
echo "your-neondb-password" > secrets/db_password.txt

# 2. Build image
docker-compose build

# 3. Start container
docker-compose up -d

# 4. Check logs
docker-compose logs -f shiny

# 5. Access app
# http://localhost:3838/american-authorship/
```

#### C.4: Deploy to Cloud (DigitalOcean Example)

**Using Docker Droplet**:

```bash
# 1. Create Droplet with Docker pre-installed
# DigitalOcean → Create → Droplets → Marketplace → Docker

# 2. SSH into droplet
ssh root@your-droplet-ip

# 3. Clone repository
git clone https://github.com/siyangni/anesko.git
cd anesko

# 4. Set up secrets
echo "your-neondb-password" > secrets/db_password.txt

# 5. Update docker-compose.yml with NeonDB credentials

# 6. Deploy
docker-compose up -d

# 7. Set up SSL with Nginx proxy (optional)
docker run -d -p 80:80 -p 443:443 \
  --name nginx-proxy \
  -v /var/run/docker.sock:/tmp/docker.sock:ro \
  jwilder/nginx-proxy
```

#### C.5: Deploy to AWS ECS (Advanced)

Your repository includes deployment scripts. To deploy to AWS:

```bash
# 1. Build and tag image
docker build -t american-authorship:latest .

# 2. Push to ECR (Elastic Container Registry)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  your-account-id.dkr.ecr.us-east-1.amazonaws.com

docker tag american-authorship:latest \
  your-account-id.dkr.ecr.us-east-1.amazonaws.com/american-authorship:latest

docker push your-account-id.dkr.ecr.us-east-1.amazonaws.com/american-authorship:latest

# 3. Create ECS task definition with NeonDB environment variables
# 4. Deploy to ECS cluster
# 5. Set up Application Load Balancer
# 6. Configure auto-scaling
```

For detailed AWS deployment, use your existing script:
```bash
bash deployment/deploy.sh
# Select option: AWS ECS
```

---

## Part 4: Production Configuration

### 4.1: Connection Pooling Best Practices

Your app uses the `pool` package. Optimize for NeonDB:

Edit `shiny-app/config/app_config.R`:
```r
# Connection pool settings
POOL_SIZE_MIN <- 2      # Keep 2 warm connections
POOL_SIZE_MAX <- 20     # Max 20 concurrent (adjust based on plan)
POOL_IDLE_TIMEOUT <- 120           # 2 minutes
POOL_VALIDATION_INTERVAL <- 3600   # 1 hour

# Important: NeonDB supports up to:
# - Free tier: 10 connections
# - Pro tier: 100+ connections
# Adjust POOL_SIZE_MAX accordingly
```

### 4.2: Environment Variables

Your app reads from multiple sources (priority order):
1. Docker secrets (`/run/secrets/db_password`)
2. Environment variables (`DB_HOST`, `DB_PASSWORD`, etc.)
3. `.env` file (`shiny-app/config/.env`)

**Production recommendation**: Use Docker secrets or cloud provider secrets management

### 4.3: Authentication Setup (Optional)

Your app includes authentication via `config/auth_config.R`.

To enable:

```bash
# 1. Create app_users table in NeonDB
psql "postgresql://user:pass@ep-xxx.neon.tech/neondb?sslmode=require" \
  -f db/migrations/003_create_auth_tables.sql

# 2. Add users (passwords are bcrypt hashed)
psql "..." -c "
INSERT INTO app_users (username, password_hash, role, active)
VALUES (
  'admin',
  '\$2b\$12\$hashed_password_here',
  'admin',
  true
);
"

# 3. Enable auth in config
# Edit: shiny-app/config/app_config.R
ENABLE_AUTHENTICATION <- TRUE
AUTH_SOURCE <- "database"  # Use database authentication
```

Generate bcrypt password:
```r
library(bcrypt)
hashpw("your-password", gensalt())
```

### 4.4: Performance Optimization

**Database Indexes** (already in migrations):
```sql
-- Verify indexes exist in NeonDB
\c neondb
\di

-- Key indexes for performance:
-- idx_sales_book_id_year (book_sales)
-- idx_book_entries_author (book_entries)
-- idx_book_entries_genre (book_entries)
```

**Query Optimization**:
Your app uses parameterized queries (good!). Monitor slow queries:

```sql
-- Enable query stats in NeonDB
-- Console → Settings → Query Stats → Enable

-- View slow queries
SELECT query, calls, mean_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

**Caching** (optional, for high traffic):
Add caching to expensive queries:

```r
# Install
install.packages("memoise")

# In server.R or utils/queries_*.R
library(memoise)

# Cache query results
get_summary_stats_cached <- memoise(
  get_summary_stats,
  ~timeout(3600)  # Cache for 1 hour
)
```

### 4.5: Security Hardening

**SSL/TLS**: Always use `sslmode=require` for NeonDB
**Input Validation**: Your app already has `utils/input_validation.R` (good!)
**Rate Limiting**: Add rate limiting for public deployments

With Nginx:
```nginx
# In /etc/nginx/sites-available/shiny-app
http {
    limit_req_zone $binary_remote_addr zone=shiny_limit:10m rate=10r/s;

    server {
        location / {
            limit_req zone=shiny_limit burst=20 nodelay;
            proxy_pass http://127.0.0.1:3838;
        }
    }
}
```

**Firewall Rules**:
```bash
# Ubuntu/Debian
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw enable
```

---

## Part 5: Testing & Validation

### 5.1: Test Database Connection

Use your existing test script:
```bash
cd /home/user/anesko
bash deployment/test_app_with_neon.sh
```

Or test manually:
```r
# Test connection
library(DBI)
library(RPostgres)

con <- dbConnect(
  RPostgres::Postgres(),
  host = "ep-xxx-pooler.region.aws.neon.tech",
  dbname = "neondb",
  user = "your-username",
  password = "your-password",
  port = 5432,
  sslmode = "require"
)

# Run test queries
dbGetQuery(con, "SELECT COUNT(*) FROM book_entries")
dbGetQuery(con, "SELECT COUNT(*) FROM book_sales")
dbGetQuery(con, "SELECT * FROM book_entries LIMIT 5")

dbDisconnect(con)
```

### 5.2: Load Testing

Test app performance under load:

```r
# Install load testing package
install.packages("shinyloadtest")

library(shinyloadtest)

# 1. Record session
record_session("https://your-app-url.com/")

# 2. Run load test (simulate 10 concurrent users)
shinycannon recording.log https://your-app-url.com/ \
  --workers 10 \
  --loaded-duration-minutes 5 \
  --output-dir loadtest_results

# 3. Generate report
shinyloadtest::report("loadtest_results/")
```

Expected performance:
- Response time: <500ms for queries
- Concurrent users: 50-100+ (depends on instance size)
- Database query time: <100ms (with indexes)

### 5.3: Monitor Connection Pool

Add monitoring to your app:

```r
# In server.R, add observer
observe({
  pool_status <- pool::dbGetInfo(pool)
  logger::log_info(
    "Pool status: ",
    pool_status$valid, " valid, ",
    pool_status$opened, " opened"
  )
})
```

### 5.4: Automated Testing

Run your existing test suite:
```bash
cd /home/user/anesko

# Run all tests
Rscript -e "devtools::test()"

# Or specific tests
Rscript -e "testthat::test_file('tests/testthat/test-database.R')"
```

---

## Part 6: Monitoring & Maintenance

### 6.1: Application Monitoring

**Shiny Server Logs**:
```bash
# Self-hosted
tail -f /var/log/shiny-server/*.log

# Docker
docker-compose logs -f shiny

# ShinyApps.io
# Dashboard → Your App → Logs tab
```

**Key Metrics to Monitor**:
- Active connections
- Response times
- Error rates
- Memory usage
- Database query performance

### 6.2: NeonDB Monitoring

**Neon Console Dashboard**:
- Navigate to: https://console.neon.tech/
- Select your project
- View:
  - **Monitoring**: CPU, RAM, storage usage
  - **Query Stats**: Slow queries, top queries
  - **Branches**: Production vs development data
  - **Compute Hours**: Track usage against quota

**Set Up Alerts**:
- Console → Settings → Notifications
- Configure alerts for:
  - High CPU usage (>80%)
  - Storage nearly full (>90%)
  - Compute hours approaching limit
  - Connection pool exhaustion

### 6.3: Database Backups

NeonDB provides automatic backups:
- **Point-in-Time Recovery**: Available for Pro tier
- **Branch-based backups**: Create branches as snapshots

Manual backup:
```bash
# Export backup from NeonDB
pg_dump "postgresql://user:pass@ep-xxx.neon.tech/neondb?sslmode=require" \
  --format=custom \
  --file=backup_$(date +%Y%m%d).dump

# Restore if needed
pg_restore -d "postgresql://..." backup_20250113.dump
```

Automate backups (cron job):
```bash
# Create backup script
nano /root/backup-neondb.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
DB_URL="postgresql://user:pass@ep-xxx.neon.tech/neondb?sslmode=require"

pg_dump "$DB_URL" \
  --format=custom \
  --file="$BACKUP_DIR/neondb_$DATE.dump"

# Keep only last 30 days
find $BACKUP_DIR -name "neondb_*.dump" -mtime +30 -delete
```

```bash
# Make executable
chmod +x /root/backup-neondb.sh

# Add to cron (daily at 2 AM)
crontab -e
0 2 * * * /root/backup-neondb.sh
```

### 6.4: Application Health Checks

Your app includes health check endpoints (`health_check.R`).

Set up monitoring:

**UptimeRobot** (free):
1. Sign up at https://uptimerobot.com/
2. Add monitor:
   - Type: HTTP(s)
   - URL: `https://your-app-url.com/health`
   - Interval: 5 minutes
3. Configure alerts (email/SMS)

**Custom health check**:
```bash
# Create monitoring script
nano /root/check-app-health.sh
```

```bash
#!/bin/bash
APP_URL="https://your-app-url.com/health"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL")

if [ "$RESPONSE" != "200" ]; then
  echo "App is DOWN! Response code: $RESPONSE"
  # Send alert (email, Slack, etc.)
  curl -X POST https://hooks.slack.com/your-webhook \
    -H 'Content-Type: application/json' \
    -d "{\"text\":\"American Authorship Dashboard is DOWN!\"}"
fi
```

### 6.5: Update Strategy

**Database Schema Updates**:
```bash
# 1. Test migrations on development branch
# Create dev branch in Neon Console

# 2. Apply migration
psql "postgresql://...@dev-branch.neon.tech/..." \
  -f db/migrations/004_new_feature.sql

# 3. Test thoroughly

# 4. Apply to production
psql "postgresql://...@production.neon.tech/..." \
  -f db/migrations/004_new_feature.sql
```

**Application Updates**:
```bash
# 1. Pull latest code
git pull origin main

# 2. Install new dependencies
Rscript -e "remotes::install_deps()"

# 3. Restart app

# ShinyApps.io:
Rscript -e "rsconnect::deployApp(forceUpdate=TRUE)"

# Self-hosted:
systemctl restart shiny-server

# Docker:
docker-compose down
docker-compose build
docker-compose up -d
```

---

## Troubleshooting

### Issue 1: Cannot Connect to NeonDB

**Symptoms**: `Error: could not connect to server`

**Solutions**:
```bash
# 1. Verify connection string
psql "postgresql://user:pass@ep-xxx.neon.tech/neondb?sslmode=require"

# 2. Check SSL mode
# Must be 'require' for NeonDB
DB_SSL_MODE=require

# 3. Check IP allowlist (if enabled)
# Add your server IP in Neon Console → Settings → IP Allow

# 4. Verify pooled endpoint
# Use: ep-xxx-pooler.region.aws.neon.tech (not ep-xxx.region...)

# 5. Test from R
Rscript -e "
library(DBI)
library(RPostgres)
con <- dbConnect(
  RPostgres::Postgres(),
  host='ep-xxx-pooler.region.aws.neon.tech',
  dbname='neondb',
  user='your-user',
  password='your-pass',
  port=5432,
  sslmode='require'
)
print(dbGetQuery(con, 'SELECT version()'))
"
```

### Issue 2: "Too Many Connections"

**Symptoms**: `FATAL: remaining connection slots are reserved`

**Solutions**:
```r
# 1. Reduce pool size in app_config.R
POOL_SIZE_MAX <- 5  # Lower for free tier

# 2. Enable NeonDB connection pooling
# Use pooled endpoint: -pooler.region.aws.neon.tech

# 3. Reduce idle timeout
POOL_IDLE_TIMEOUT <- 60  # Close connections faster

# 4. Upgrade NeonDB plan (if needed)
# Pro tier supports 100+ connections
```

### Issue 3: Slow Query Performance

**Symptoms**: App loads slowly, timeouts

**Solutions**:
```sql
-- 1. Check if indexes exist
\di

-- 2. Run ANALYZE
ANALYZE book_entries;
ANALYZE book_sales;

-- 3. Identify slow queries
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- 4. Add missing indexes
CREATE INDEX idx_sales_book_year
ON book_sales(book_id, year);

-- 5. Use query caching in R (see Performance Optimization)
```

### Issue 4: ShinyApps.io Deployment Fails

**Symptoms**: Deployment error, dependencies not found

**Solutions**:
```r
# 1. Verify all packages are in DESCRIPTION file
# Your DESCRIPTION already includes all dependencies

# 2. Check app size (ShinyApps.io has limits)
# Remove unnecessary files from shiny-app/

# 3. Test locally first
shiny::runApp("shiny-app/")

# 4. Clear deployment cache
rsconnect::deployApp(forceUpdate=TRUE, launch.browser=FALSE)

# 5. Check logs in ShinyApps.io dashboard
```

### Issue 5: Docker Container Crashes

**Symptoms**: Container exits, won't start

**Solutions**:
```bash
# 1. Check logs
docker-compose logs shiny

# 2. Verify secrets file exists
ls -la secrets/db_password.txt

# 3. Test database connection from container
docker-compose exec shiny bash
Rscript -e "source('config/cloud_config.R'); print(db_connection_info)"

# 4. Increase memory limit
# In docker-compose.yml:
deploy:
  resources:
    limits:
      memory: 4G

# 5. Check disk space
df -h
```

### Issue 6: Authentication Not Working

**Symptoms**: Login fails, users can't access app

**Solutions**:
```r
# 1. Verify app_users table exists in NeonDB
psql "..." -c "\dt"

# 2. Check password hashing
library(bcrypt)
test_hash <- hashpw("password", gensalt())
print(checkpw("password", test_hash))  # Should be TRUE

# 3. Verify auth configuration
# In config/app_config.R:
ENABLE_AUTHENTICATION <- TRUE
AUTH_SOURCE <- "database"

# 4. Check session timeout settings
SESSION_TIMEOUT_MINUTES <- 60

# 5. Review logs for auth errors
# Look for: "Authentication failed for user..."
```

---

## Cost Estimation

### NeonDB Costs
- **Free Tier**: $0/month
  - 3 GiB storage
  - 10 compute hours (~30 days with auto-suspend)
  - 10 concurrent connections
  - Good for: Development, small projects (<100 users/day)

- **Pro Tier**: Starting at $19/month
  - 200 GiB storage
  - Unlimited compute hours
  - 100+ connections
  - Point-in-time recovery
  - Good for: Production apps (100-1000 users/day)

### Shiny Hosting Costs

**ShinyApps.io**:
- **Starter**: $9/month (25 active hours)
- **Basic**: $39/month (500 active hours)
- **Standard**: $99/month (2000 active hours)
- **Professional**: $299/month (10000 active hours)

**Self-Hosted (DigitalOcean)**:
- **Droplet**: $24/month (2 vCPU, 4GB RAM)
- **Storage**: Included
- **Bandwidth**: 4TB included
- Total: ~$25/month

**Docker on Cloud**:
- **AWS EC2 t3.medium**: ~$30/month
- **GCP e2-standard-2**: ~$50/month
- **Azure B2s**: ~$30/month

### Recommended Setups

**Small Project (<100 users/day)**:
- NeonDB: Free tier ($0)
- ShinyApps.io Basic: $39/month
- **Total: $39/month**

**Medium Project (100-500 users/day)**:
- NeonDB Pro: $19/month
- Self-hosted (DigitalOcean): $24/month
- **Total: $43/month**

**Large Project (1000+ users/day)**:
- NeonDB Pro: $19+ /month (based on compute)
- Docker on cloud (2-4 instances): $60-120/month
- Load balancer: $10-20/month
- **Total: $90-160/month**

---

## Next Steps

1. **Set up NeonDB account** and create project
2. **Migrate your data** using provided scripts
3. **Choose hosting option** based on your needs and budget
4. **Deploy application** following option-specific instructions
5. **Test thoroughly** using provided test scripts
6. **Set up monitoring** for production
7. **Configure backups** and alerts
8. **Document** your specific deployment details

---

## Additional Resources

- **NeonDB Documentation**: https://neon.tech/docs
- **Shiny Documentation**: https://shiny.rstudio.com/
- **ShinyApps.io**: https://docs.posit.co/shinyapps.io/
- **Your Project Documentation**: See `/docs/RUNBOOK.md`
- **Your Repository**: https://github.com/siyangni/anesko

---

## Support

For issues specific to your dashboard:
- Review logs in `shiny-app/logs/`
- Check your repository documentation in `docs/`
- Review test suite in `tests/`

For NeonDB issues:
- NeonDB Support: support@neon.tech
- Community: https://community.neon.tech/

For Shiny issues:
- RStudio Community: https://community.rstudio.com/
- Shiny GitHub: https://github.com/rstudio/shiny

---

**Document Version**: 1.0
**Last Updated**: 2025-11-13
**Author**: Claude (AI Assistant)
**Project**: American Authorship Database (1860-1920)
