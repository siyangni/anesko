# Application Configuration
# Contains database settings, constants, and app-wide configurations

# App metadata
APP_TITLE <- "American Authorship Database (1860-1920)"
APP_VERSION <- "1.0.0"
APP_DESCRIPTION <- "Interactive dashboard for exploring American literary marketplace data"

# Database configuration
# Try to load from parent config first, then fallback to environment variables
if (file.exists("../scripts/config/database_config.R")) {
  source("../scripts/config/database_config.R")
} else {
  # Fallback configuration
  db_config <- list(
    host = ifelse(Sys.getenv("DB_HOST") != "", Sys.getenv("DB_HOST"), "localhost"),
    dbname = ifelse(Sys.getenv("DB_NAME") != "", Sys.getenv("DB_NAME"), "american_authorship"),
    user = ifelse(Sys.getenv("DB_USER") != "", Sys.getenv("DB_USER"), "siyang"),
    password = ifelse(Sys.getenv("DB_PASSWORD") != "", Sys.getenv("DB_PASSWORD"), "anesko2024")
  )
}

# Connection pool settings
POOL_SIZE_MIN <- 1
POOL_SIZE_MAX <- 5
POOL_IDLE_TIMEOUT <- 60

# Data refresh settings
CACHE_REFRESH_MINUTES <- 30
DEFAULT_PAGE_SIZE <- 25

# Plot settings
DEFAULT_PLOT_HEIGHT <- 400
DEFAULT_PLOT_WIDTH <- 800

# Date ranges
MIN_YEAR <- 1860
MAX_YEAR <- 1920
DEFAULT_YEAR_RANGE <- c(1880, 1910)

# UI settings
SIDEBAR_WIDTH <- 300
NAVBAR_FIXED <- TRUE

# Feature flags
ENABLE_DOWNLOADS <- TRUE
ENABLE_BOOKMARKS <- TRUE
ENABLE_TOOLTIPS <- TRUE

# Text constants
ABOUT_TEXT <- "
This dashboard provides interactive exploration of the American Authorship Database (1860-1920), 
a comprehensive collection of publishing and sales data from major American publishers during 
the transformative period of the late 19th and early 20th centuries.

**Data Sources:**
- Houghton, Mifflin Co. and predecessors (Harvard University)
- Harper & Brothers (Chadwyck-Healey Microfilm)  
- Scribner Archive (Princeton University)
- J. B. Lippincott Deposit (University of Pennsylvania)

**Principal Investigator:** Dr. Michael Anesko (Penn State University)
"

METHODOLOGY_TEXT <- "
**Data Collection:**
All data has been hand-transcribed from original publisher archives, including sales records, 
royalty statements, and contract information.

**Coverage:**
- 630+ book entries with comprehensive metadata
- 63 years of sales data (1858-1920)
- Focus on major publishers and commercially successful works

**Validation:**
Data has been cross-referenced across multiple sources where possible to ensure accuracy.
" 