# CLAUDE.md - American Authorship Database Project Guide

**Purpose**: Comprehensive guide for AI assistants working on this codebase.  
**Project**: American Authorship Database (1860-1920) - Interactive Shiny Dashboard  
**Last Updated**: November 13, 2025  
**Repository**: https://github.com/siyangni/anesko

---

## 1. PROJECT OVERVIEW

### What This Project Does
This is an **interactive research database and dashboard** for exploring American literary publishing and sales data from 1860-1920. It provides quantitative analysis of the American literary marketplace, with focus on:
- Gender analysis (male vs female authors)
- Genre trends and market evolution
- Publisher analysis and market concentration
- Author economics and royalty structures
- Sales performance across time periods

### Project Type
**Shiny Web Application** - Interactive R-based dashboard running on PostgreSQL

### Key Stakeholders
- **Principal Investigator**: Dr. Michael Anesko (Penn State University)
- **Current Analysts**: Siyang Ni (2025-)
- **Institution**: Penn State University, College of Liberal Arts
- **Funding**: CHI Digital Humanities Grant (Summer 2023), C-SoDA Grant (Winter 2024)

---

## 2. PROJECT STRUCTURE & ARCHITECTURE

### Directory Layout

```
anesko/
├── shiny-app/                      # Main Shiny application (7.5K+ lines)
│   ├── app.R                       # Entry point with dependency checks
│   ├── global.R                    # Libraries, config, pool initialization
│   ├── ui.R                        # Main UI definition
│   ├── server.R                    # Server logic and module bindings
│   ├── app_with_auth.R             # Authentication-enabled variant
│   ├── config/                     # Configuration files
│   │   ├── app_config.R            # App settings and constants
│   │   ├── auth_config.R           # User authentication settings
│   │   ├── cloud_config.R          # Database connection (DO NOT COMMIT)
│   │   ├── cloud_config.template.R # Template for database config
│   │   └── .env.template           # Environment variables template
│   ├── modules/                    # 10 Shiny modules (5,930 lines total)
│   │   ├── dashboard_module.R      # Overview dashboard
│   │   ├── book_explorer_module.R  # Book browsing and filtering
│   │   ├── sales_trends_module.R   # Sales trend analysis (ACTIVE)
│   │   ├── sales_analysis_module.R # Alternative (legacy reference)
│   │   ├── author_analysis_module.R# Author demographics
│   │   ├── author_networks_module.R# Author relationship networks
│   │   ├── genre_analysis_module.R # Genre trends
│   │   ├── genre_content_analysis_module.R # Content analysis
│   │   ├── royalty_analysis_module.R# Royalty data analysis
│   │   └── royalty_query_module.R  # Royalty income queries
│   ├── utils/                      # Utility functions (11 files)
│   │   ├── database.R              # DB connection, pooling (36K code)
│   │   ├── data_processing.R       # Data transformation (14K code)
│   │   ├── plotting.R              # Visualization helpers (11K code)
│   │   ├── error_handling.R        # Error/exception handling
│   │   ├── input_validation.R      # Input sanitization
│   │   ├── queries_basic.R         # Basic database queries
│   │   ├── queries_sales.R         # Sales-specific queries
│   │   ├── queries_timeseries.R    # Time series queries
│   │   └── queries_royalties.R     # Royalty-specific queries
│   ├── www/                        # Static assets
│   │   ├── style.css               # Custom styling
│   │   ├── psu_cla_logo.png        # Branding
│   │   └── psu_dla_logo.png        # Branding
│   ├── health_check.R              # Health check script
│   ├── deploy_shinyapps.R          # ShinyApps.io deployment
│   ├── manifest.json               # rsconnect deployment manifest
│   └── README.md                   # Shiny-app specific docs
│
├── db/                             # Database layer
│   └── migrations/                 # Database setup and migrations
│       ├── 00_run_full_migration.R # Master migration orchestrator
│       ├── 00_package_setup.R      # R package setup
│       ├── 01_database_setup.R     # Database creation
│       ├── 02_create_schema.R      # Table/schema creation
│       ├── 03_import_data.R        # Data import from CSV
│       ├── check_tables.R          # Schema verification
│       ├── fix_view.R              # View creation/repair
│       ├── reset_database.R        # Complete reset script
│       └── README.md               # Migration documentation
│
├── scripts/                        # Analysis and maintenance scripts
│   ├── analysis/                   # Statistical analysis scripts
│   │   ├── 02_data_cleaning.R      # Data cleaning procedures
│   │   ├── 03_exploratory_analysis.R# EDA and summaries
│   │   └── [restoration scripts]   # Database restoration utilities
│   ├── cleaning/                   # Data cleaning
│   │   ├── pre_migration_cleaning.R# Pre-import cleaning
│   │   └── comprehensive_royalty_analysis.R
│   ├── validation/                 # Data validation
│   │   └── 04_data_validation.R    # Data quality checks
│   ├── auth/                       # Authentication utilities
│   │   └── manage_users.R          # User management
│   ├── backup/                     # Backup procedures
│   └── deployment/                 # Deployment helpers
│       ├── deploy_to_shinyapps_io.R
│       ├── deploy_shiny.R
│       └── README.md
│
├── tests/                          # Formal test suite
│   ├── testthat/                   # testthat framework
│   │   ├── setup-shinytest2.R      # UI testing config
│   │   ├── test-database.R         # DB connection tests
│   │   ├── test-data-processing.R  # Data transformation tests
│   │   ├── test-error-handling.R   # Error handling tests
│   │   ├── test-input-validation.R # Input sanitization tests
│   │   └── test-ui-dashboard.R     # UI integration tests
│   ├── testthat.R                  # Test runner
│   └── README.md                   # Testing guide
│
├── docs/                           # Documentation
│   ├── README.md                   # Documentation index
│   ├── RUNBOOK.md                  # Operations guide
│   ├── CONTRIBUTING.md             # Development guidelines
│   ├── AUTHENTICATION.md           # Auth setup guide
│   ├── data_dictionary.md          # Database schema docs
│   ├── DIRECTORY_TREES.md          # Project structure reference
│   ├── deployment/                 # Deployment guides
│   │   ├── DEPLOYMENT_DECISION_GUIDE.md
│   │   ├── DEPLOYMENT_WORKSHEET.md
│   │   ├── IMPLEMENTATION_GUIDE.md
│   │   └── README.md
│   └── [additional deployment guides]
│
├── deployment/                     # Deployment configurations
│   └── [deployment scripts]
│
├── archive/                        # Archived obsolete files (git history preserved)
│   ├── test_files/                 # Ad-hoc test scripts (37 files)
│   ├── obsolete_modules/           # Superseded modules (4 files)
│   ├── obsolete_scripts/           # Legacy deployment scripts
│   ├── obsolete_configs/           # Backup configs (with security notes)
│   ├── obsolete_databases/         # Deprecated DB engines (SQLite)
│   └── README.md                   # Archive documentation
│
├── monitoring/                     # Monitoring stack configuration
│   ├── prometheus.yml
│   ├── alertmanager.yml
│   └── grafana/
│
├── secrets/                        # Credential storage (NEVER COMMIT)
│   ├── db_password.txt             # Docker secret (template only)
│   ├── grafana_password.txt        # Monitoring secret (template only)
│   └── README.md
│
├── outputs/                        # Generated outputs
│   ├── plots/
│   ├── tables/
│   └── reports/
│
├── logos/                          # Branding materials
│
├── DESCRIPTION                     # R package metadata
├── Dockerfile                      # Container configuration
├── docker-compose.yml              # Docker orchestration
├── docker-compose.monitoring.yml   # Monitoring stack
├── README.md                       # Main project README
├── License.md                      # MIT License
├── CITATION                        # Citation information
├── CLAUDE.md                       # This file
├── .lintr                          # Code linting rules
├── .styler.R                       # Code styling rules
├── .gitignore                      # Git ignore rules
└── .github/workflows/              # CI/CD pipelines
    ├── ci.yml                      # Main CI pipeline
    └── ci-improved.yml             # Enhanced CI pipeline
```

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      BROWSER/CLIENT                             │
└─────────────────────────────────────────┬───────────────────────┘
                                          │
                      ┌───────────────────┴────────────────────┐
                      │                                        │
              ┌───────▼────────┐                    ┌──────────▼──────┐
              │   Shiny App    │                    │   Deployment    │
              │                │                    │                 │
              │ • ui.R         │                    │ • ShinyApps.io  │
              │ • server.R     │                    │ • Docker        │
              │ • modules/ (10)│                    │ • Self-hosted   │
              │ • global.R     │                    │ • Cloud (AWS)   │
              └───────┬────────┘                    └─────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
        ▼             ▼             ▼
   ┌────────┐   ┌──────────┐   ┌──────────┐
   │ Config │   │  Utils   │   │ Modules  │
   │        │   │          │   │          │
   │Auth    │   │Database  │   │Dashboard │
   │Cloud   │   │Plotting  │   │Analysis  │
   │        │   │Queries   │   │Explorer  │
   └───┬────┘   └────┬─────┘   └────┬─────┘
       │             │              │
       └─────────────┼──────────────┘
                     │
        ┌────────────▼─────────────┐
        │   Database Layer         │
        │                          │
        │  • pool.R (connection)   │
        │  • Parameterized queries │
        │  • Connection pooling    │
        └────────────┬─────────────┘
                     │
        ┌────────────▼─────────────┐
        │   PostgreSQL Database    │
        │                          │
        │  • book_entries          │
        │  • book_sales            │
        │  • book_sales_summary    │
        │  • [other tables]        │
        └──────────────────────────┘
```

---

## 3. TECHNOLOGY STACK

### Languages & Frameworks
- **Primary Language**: R (4.0+)
- **Web Framework**: Shiny (1.8.0+)
- **Dashboard Framework**: shinydashboard (0.7.2+)
- **Package Manager**: remotes, renv

### Databases
- **Primary**: PostgreSQL 12+ (relational)
- **Connection**: RPostgreSQL/RPostgres with pool management
- **Legacy** (archived): SQLite (now PostgreSQL only)

### Data Processing & Visualization
- **Data Manipulation**: dplyr (1.1.0+), tidyr (1.3.0+)
- **Visualization**: ggplot2 (3.5.0+), plotly (4.10.4+)
- **Tables**: DT (0.32+)
- **Time Series**: lubridate (1.9.3+)
- **String Processing**: stringr (1.5.1+)

### UI/UX Libraries
- **Advanced Dashboards**: shinydashboardPlus (2.0.0+)
- **Widgets**: shinyWidgets (0.8.0+)
- **Loading Animations**: waiter (0.2.5+)
- **Theming**: fresh (0.2.0+)
- **HTML Tools**: htmltools (0.5.7+)

### Infrastructure & DevOps
- **Container**: Docker (Dockerfile, docker-compose.yml)
- **Monitoring** (optional): Prometheus, Grafana, Node Exporter, AlertManager
- **Deployment**: ShinyApps.io, self-hosted (Shiny Server/Nginx), Docker
- **CI/CD**: GitHub Actions (2 workflows)

### Development Tools
- **Testing Framework**: testthat (3.2.0+)
- **Code Quality**: lintr (3.1.0+)
- **Code Formatting**: styler (1.10.0+)
- **UI Testing**: shinytest2 (0.3.0+)
- **Coverage**: covr (3.6.0+)
- **Profiling**: profvis (0.3.8+)
- **Load Testing**: shinyloadtest (1.2.0+)
- **Logging**: logger (0.3.0+)

### Version Control
- Git with GitHub Actions CI/CD

---

## 4. DATA STRUCTURE

### Database Schema

**Primary Tables**:
1. **book_entries**: Book metadata, author info, genre, publisher
   - ~630 rows (books)
   - Fields: title, author, gender, genre, publisher, publication_year, etc.

2. **book_sales**: Annual sales records per book
   - ~10K+ rows (year × book combinations)
   - Fields: book_id, year, sales_units, revenue, royalties, etc.

3. **book_sales_summary**: Pre-aggregated views for performance
   - Optimized for dashboard queries

**Supporting Objects**:
- Indexes on common query fields
- Views for complex aggregations
- Triggers for data consistency

**Historical Coverage**: 1858-1920 (63 years)

**Data Sources**:
- Houghton Library (Harvard) - Houghton Mifflin records
- Princeton University - Scribner Archive
- University of Pennsylvania - J.B. Lippincott deposit
- Chadwyck-Healey microfilm - Harper & Brothers

### Data Governance
- **Validation**: scripts/validation/04_data_validation.R
- **Cleaning**: scripts/cleaning/ directory
- **Migrations**: db/migrations/ with version control
- **Backups**: Database backup scripts available

---

## 5. KEY MODULES & COMPONENTS

### Shiny Modules (in modules/ directory)

| Module | Purpose | Size | Status |
|--------|---------|------|--------|
| **dashboard_module.R** | Overview dashboard with KPIs | 13.6K | Active |
| **book_explorer_module.R** | Book search and filtering | 14.6K | Active |
| **sales_trends_module.R** | Time series analysis | 13.9K | Active |
| **author_analysis_module.R** | Author demographics | 37.1K | Active |
| **author_networks_module.R** | Author relationships | 11.2K | Active |
| **genre_analysis_module.R** | Genre trends | 40.5K | Active |
| **genre_content_analysis_module.R** | Content analysis | 35.7K | Active |
| **royalty_analysis_module.R** | Royalty data analysis | 15.0K | Active |
| **royalty_query_module.R** | Royalty queries | 32.6K | Active |
| **sales_analysis_module.R** | Sales analysis (legacy) | 12.3K | Reference Only |

**Pattern**: All modules follow Shiny's namespace-based pattern:
```r
moduleNameUI <- function(id) { ... }
moduleNameServer <- function(id) { ... }
```

### Utility Functions (in utils/ directory)

| File | Functions | Purpose |
|------|-----------|---------|
| **database.R** | Connection pooling, queries | DB abstraction layer |
| **data_processing.R** | Data transformation | ETL and formatting |
| **plotting.R** | Visualization helpers | ggplot2 wrappers |
| **error_handling.R** | Error management | Try-catch patterns |
| **input_validation.R** | Input sanitization | Security/validation |
| **queries_*.R** | SQL generation | Specific domain queries |

### Configuration Files (in config/ directory)

1. **app_config.R**: Application settings
   - Database connection parameters
   - UI constants and theme
   - Performance tuning
   - Feature flags

2. **auth_config.R**: Authentication settings
   - User management
   - Permission levels
   - Session configuration

3. **cloud_config.R**: Cloud database settings (GITIGNORED)
   - Database host, credentials
   - SSL/TLS settings
   - Connection pool size

4. **.env.template**: Environment variable template
   - DB_HOST, DB_NAME, DB_USER, DB_PASSWORD, DB_PORT

---

## 6. DEVELOPMENT WORKFLOW

### Setting Up Development Environment

```bash
# 1. Clone and navigate
git clone https://github.com/siyangni/anesko.git
cd anesko

# 2. Install R dependencies
R -e "install.packages('remotes'); remotes::install_deps(TRUE)"

# 3. Configure database
cp shiny-app/config/.env.template shiny-app/config/.env
# Edit .env with your database credentials

# 4. Start database
sudo service postgresql start

# 5. Run migrations (if needed)
R -e "source('db/migrations/00_run_full_migration.R')"

# 6. Run application
R -e "shiny::runApp('shiny-app/')"
```

### Code Standards

**Style Guide**: Follow R style guide with lintr/styler configs
- Line length: 120 characters (extended for Shiny)
- Naming: snake_case for functions and variables
- Spacing: 2-space indentation
- Comments: Use #, ## for sections, ### for code blocks

**Configuration Files**:
```r
# .lintr rules:
- object_name_linter with snake_case
- line_length_linter (120 char)
- cyclocomp_linter (complexity limit 25)
- Security linters enabled (absolute_path, equals_na, etc.)
```

### Branching Strategy

- `main`: Production-ready code
- `develop`: Integration branch
- `feature/name`: Feature branches
- `bugfix/name`: Bug fix branches
- `refactor/name`: Refactoring branches
- `claude/*`: AI-assisted development branches

### Git Workflow

```bash
# 1. Create feature branch
git checkout -b feature/new-feature

# 2. Make changes and test
# Edit files, run tests
testthat::test_dir("tests")

# 3. Run linters and styling
lintr::lint_package()
styler::style_pkg()

# 4. Commit with conventional commits format
git commit -m "feat(module): description"

# 5. Push and create pull request
git push origin feature/new-feature

# 6. PR checks run automatically via GitHub Actions
```

### Conventional Commit Types

- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code restructuring
- `docs`: Documentation changes
- `test`: Test additions
- `perf`: Performance improvements
- `chore`: Build/tooling changes

---

## 7. TESTING & QUALITY ASSURANCE

### Test Framework: testthat (3.2.0+)

**Test Categories**:
1. **Unit Tests** (fast): Individual functions without DB
2. **Integration Tests** (medium): Database-dependent tests
3. **UI Tests** (slow): End-to-end with browser

**Test Files**:
- test-input-validation.R: Input sanitization (security)
- test-data-processing.R: Data transformation
- test-error-handling.R: Error handling
- test-database.R: DB connections
- test-ui-dashboard.R: UI interactions

**Running Tests**:
```r
# All tests
testthat::test_dir("tests")

# Specific file
testthat::test_file("tests/testthat/test-input-validation.R")

# With coverage
covr::package_coverage()
covr::report()

# Via GitHub Actions
# Tests run automatically on push and PR
```

### Code Quality Tools

**lintr**: Code linting
```bash
R -e "lintr::lint_package()"
```

**styler**: Code formatting
```bash
R -e "styler::style_pkg()"
```

**CI/CD**: GitHub Actions runs these on every push/PR:
- Linting (non-blocking)
- Tests (blocking)
- Structure checks
- Documentation validation

---

## 8. DEPLOYMENT OPTIONS

### Option 1: ShinyApps.io (Easiest)
- **Time**: 15 minutes
- **Cost**: Free tier (5 apps, 25 hrs/month) or $58/month basic
- **Setup**: One rsconnect deployment command
- **Pros**: No infrastructure management
- **Cons**: Limited customization

### Option 2: Self-Hosted (Recommended for Production)
- **Time**: 1-2 hours
- **Cost**: $43/month (VPS) + domain
- **Setup**: Shiny Server + Nginx + PostgreSQL
- **Pros**: Full control, custom domain
- **Cons**: Server management required

### Option 3: Docker (Enterprise-Grade)
- **Time**: 2-4 hours
- **Cost**: $100+/month (cloud platform)
- **Setup**: Docker containers + orchestration
- **Pros**: Scalable, reproducible
- **Cons**: Complex infrastructure

### Deployment Files

- **Dockerfile**: App containerization
- **docker-compose.yml**: App + database orchestration
- **docker-compose.monitoring.yml**: Optional monitoring stack
- **deployment/**: Shell and R deployment scripts
- **scripts/deployment/**: Deployment utilities

**See**: docs/deployment/ for detailed guides

---

## 9. SECURITY CONSIDERATIONS

### Credentials Management

**CRITICAL: Never Commit Secrets**

Sensitive files (DO NOT COMMIT):
- `shiny-app/config/cloud_config.R` (contains DB password)
- `secrets/db_password.txt` (database password)
- `secrets/grafana_password.txt` (monitoring password)
- `.env` files with credentials
- Any file with hardcoded passwords

**Use Instead**:
1. Environment variables (recommended)
2. Docker secrets
3. .env.template (for examples only)
4. Configuration management systems

### SQL Injection Prevention

All database queries use **parameterized queries**:
```r
# SAFE - Uses parameterized query
pool::dbGetQuery(
  pool,
  "SELECT * FROM books WHERE author = ?",
  params = list(user_input)
)

# UNSAFE - Never do this!
query <- paste0("SELECT * FROM books WHERE author = '", user_input, "'")
```

### Input Validation

All user inputs validated in `utils/input_validation.R`:
- Length checks
- Type validation
- Character escaping
- Range validation
- Pattern matching

### Connection Security

- Connection pooling prevents resource exhaustion
- SSL/TLS support for remote databases
- Prepared statements used everywhere
- Error messages sanitized (no SQL exposure)

---

## 10. COMMON TASKS FOR AI ASSISTANTS

### Adding a New Analysis Module

1. **Create module file**: `shiny-app/modules/new_analysis_module.R`
2. **Follow template**:
   ```r
   # UI function
   newAnalysisUI <- function(id) {
     ns <- NS(id)
     # UI elements
   }
   
   # Server function
   newAnalysisServer <- function(id) {
     moduleServer(id, function(input, output, session) {
       # Server logic
     })
   }
   ```
3. **Register in global.R**: `source("modules/new_analysis_module.R")`
4. **Add to ui.R**: Include in navbar or tabPanel
5. **Bind in server.R**: `newAnalysisServer("module_id")`

### Adding a Database Query

1. **Create function in utils/queries_*.R**:
   ```r
   get_custom_data <- function(filter_var = NULL) {
     query <- "SELECT * FROM table WHERE condition = ?"
     pool::dbGetQuery(pool, query, params = list(filter_var))
   }
   ```
2. **Test with test-database.R**
3. **Use in modules** via `source()` in global.R

### Running Full Database Migration

```r
source("db/migrations/00_run_full_migration.R")
```

This orchestrates:
1. Data cleaning
2. Database setup
3. Schema creation
4. Data import

### Updating Dependencies

```bash
# Update DESCRIPTION file with new packages
# Then in R console:
remotes::install_deps(dependencies = TRUE)

# Or for Docker:
# Update Dockerfile with new packages
docker build -t anesko .
```

---

## 11. TROUBLESHOOTING GUIDE

### Database Connection Issues

**Problem**: "Could not connect to PostgreSQL"

**Solutions**:
```bash
# 1. Verify PostgreSQL is running
sudo service postgresql status
sudo service postgresql start

# 2. Check credentials in config files
cat shiny-app/config/.env

# 3. Test connection independently
psql -h localhost -U authorship_admin -d american_authorship

# 4. Check firewall/network
ping database-host
```

### Missing Dependencies

**Problem**: "Package 'X' not found"

**Solutions**:
```r
# Install from DESCRIPTION
remotes::install_deps(dependencies = TRUE)

# Or manually
install.packages("package_name")

# Check version compatibility
packageVersion("package_name")
```

### Tests Failing Locally

**Possible Causes**:
- Wrong R version (need 4.0+)
- Missing dependencies
- Database not running (for integration tests)
- Configuration file issues

**Diagnostic**:
```bash
# Check R version
R --version

# Check installed packages
R -e "packageVersion('shiny')"

# Run specific test with verbose output
R -e "testthat::test_file('tests/testthat/test-database.R')"
```

### Shiny App Not Starting

**Check in order**:
1. Run `shiny::runApp('shiny-app/')` in R console
2. Check error messages in console
3. Verify global.R loads without errors
4. Test database connection independently
5. Check for syntax errors in app.R, ui.R, server.R

---

## 12. KEY FILES FOR UNDERSTANDING THE CODEBASE

**Start Here**:
- `README.md` - Project overview
- `DESCRIPTION` - Package dependencies
- `shiny-app/app.R` - Entry point
- `shiny-app/global.R` - All libraries and utilities loaded

**Application Code**:
- `shiny-app/ui.R` - UI definition
- `shiny-app/server.R` - Server logic
- `shiny-app/modules/` - Individual feature modules
- `shiny-app/utils/database.R` - DB abstraction

**Configuration**:
- `shiny-app/config/app_config.R` - Settings
- `shiny-app/config/.env.template` - Environment variables
- `.lintr` - Code style rules
- `.styler.R` - Formatting rules

**Database**:
- `db/migrations/00_run_full_migration.R` - Master migration
- `db/migrations/02_create_schema.R` - Table definitions
- `docs/data_dictionary.md` - Schema documentation

**Testing & Quality**:
- `tests/testthat/` - Test suite
- `.github/workflows/ci.yml` - CI/CD pipeline
- `docs/CONTRIBUTING.md` - Development guidelines

**Documentation**:
- `docs/README.md` - Documentation index
- `docs/RUNBOOK.md` - Operations guide
- `docs/deployment/` - Deployment guides
- `docs/AUTHENTICATION.md` - Auth setup

---

## 13. ARCHIVED & DEPRECATED CODE

**Location**: `archive/` directory (with git history preserved)

**Categories**:
1. **test_files/** (37 files): Ad-hoc test scripts
2. **obsolete_modules/** (4 files): Superseded Shiny modules
3. **obsolete_scripts/** (3 files): Legacy deployment scripts
4. **obsolete_configs/** (2 files): Backup config files
5. **obsolete_databases/** (2 files): SQLite database (now PostgreSQL)

**Accessing Archived Files**:
```bash
# View git history of archived file
git log --follow archive/category/filename

# Restore archived file
cp archive/category/filename destination/
git commit -m "Restore filename from archive"
```

**Note**: Files were moved with `git mv` to preserve commit history

---

## 14. USEFUL COMMANDS & ALIASES

### Quick Start
```bash
cd /home/user/anesko
R -e "shiny::runApp('shiny-app/')"
```

### Testing
```r
# Run all tests
testthat::test_dir("tests")

# Run with coverage
covr::package_coverage()
covr::report()

# Specific test category
testthat::test_dir("tests", filter = "database")
```

### Code Quality
```r
lintr::lint_package()
styler::style_pkg()
```

### Database Operations
```bash
# Start PostgreSQL
sudo service postgresql start

# Connect to database
psql -U authorship_admin -d american_authorship

# Run migration
R -e "source('db/migrations/00_run_full_migration.R')"
```

### Docker Operations
```bash
# Build image
docker build -t anesko:latest .

# Run with docker-compose
docker-compose up -d

# Run with monitoring
docker-compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d
```

---

## 15. PROJECT STATISTICS

| Metric | Value |
|--------|-------|
| **Total Code Lines** | ~7,500+ (app code) |
| **Module Code** | 5,930+ lines (10 modules) |
| **Utility Code** | ~133K code |
| **Database Scripts** | 9 migration/setup files |
| **Analysis Scripts** | 13+ scripts |
| **Test Files** | 6 test files |
| **Documentation** | 15+ docs |
| **Archived Files** | 54 files |
| **Database Records** | 630+ books, 10K+ sales records |
| **Time Period Covered** | 1858-1920 (63 years) |
| **Dependencies** | 24+ R packages |

---

## 16. QUICK REFERENCE: KEY FUNCTIONS

### Database Functions (utils/database.R)
```r
create_db_pool()              # Create connection pool
safe_db_query()               # Parameterized query execution
close_db_pool()               # Cleanup connections
```

### Data Processing (utils/data_processing.R)
```r
format_currency()             # Format as currency
format_percentage()           # Format as percentage
summarize_sales_data()        # Aggregate sales
```

### Validation (utils/input_validation.R)
```r
validate_year_range()         # Validate year inputs
sanitize_text_input()         # Clean text inputs
validate_gender()             # Validate gender field
```

### Plotting (utils/plotting.R)
```r
theme_custom()                # Custom ggplot theme
create_sales_plot()           # Sales visualization
create_genre_chart()          # Genre distribution
```

---

## 17. CONTACT & RESOURCES

### Project Leadership
- **Principal Investigator**: Dr. Michael Anesko (mwa2@psu.edu)
- **Project Repository**: https://github.com/siyangni/anesko
- **Institution**: Penn State University, College of Liberal Arts

### Documentation
- **Main README**: See `README.md`
- **Deployment Guides**: See `docs/deployment/`
- **Operations Guide**: See `docs/RUNBOOK.md`
- **Contributing**: See `docs/CONTRIBUTING.md`

### External Resources
- **Shiny**: https://shiny.rstudio.com/
- **testthat**: https://testthat.r-lib.org/
- **PostgreSQL**: https://www.postgresql.org/docs/
- **R Packages**: https://www.r-project.org/

---

## 18. LAST UPDATES & RECENT CHANGES

**November 5, 2025**: Major repository reorganization
- Moved 54 files to `archive/` with git history preserved
- Established `db/`, `deployment/`, `tests/`, `.github/workflows/` directories
- Added comprehensive documentation and deployment guides
- Implemented CI/CD with GitHub Actions
- Added formal test suite with testthat

**November 13, 2025**: Documentation expansion
- Created comprehensive deployment decision guide
- Added NeonDB hosting guide
- Expanded troubleshooting documentation
- Created this CLAUDE.md for AI assistants

---

## 19. PROJECT STATUS & ROADMAP

### Current Status
- ✅ Core dashboard functional (9 modules)
- ✅ Database fully populated (630+ books, 63 years data)
- ✅ Tests and CI/CD implemented
- ✅ Multiple deployment options available
- ✅ Comprehensive documentation

### Planned Enhancements
- Advanced sales analysis (seasonal patterns, market cycles)
- Author demographics and career trajectories
- Genre evolution and market share trends
- Publisher analytics and market concentration
- PDF report export functionality
- User preferences and bookmarks
- Mobile optimization
- WCAG accessibility improvements

### Known Limitations
- Shiny app performance with very large data ranges
- Real-time data updates not yet implemented
- Some advanced statistical analyses planned
- Mobile responsiveness could be improved

---

**END OF CLAUDE.md**

*For questions or updates, please contact the development team or refer to the comprehensive documentation in the `docs/` directory.*
