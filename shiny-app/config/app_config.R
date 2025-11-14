# Application Configuration
# Updated for cloud database deployment

# App metadata
APP_TITLE <- "American Authorship Database (1860-1920)"
APP_VERSION <- "1.0.0"
APP_DESCRIPTION <- "Interactive dashboard for exploring American literary marketplace data"

# Load cloud database configuration
# Try cloud_config.R first, fall back to template if it doesn't exist
if (file.exists("config/cloud_config.R")) {
  source("config/cloud_config.R")
} else if (file.exists("config/cloud_config.template.R")) {
  cat("⚠️  cloud_config.R not found, using template\n")
  cat("   For production, create cloud_config.R from template with your credentials\n")
  source("config/cloud_config.template.R")
} else {
  stop("Database configuration not found. Please create config/cloud_config.R from template")
}

# Connection pool settings
POOL_SIZE_MIN <- 1
POOL_SIZE_MAX <- 5  # Neon handles more connections than ElephantSQL
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

# Formatting constants (for number display)
FORMAT_MILLION_THRESHOLD <- 1000000
FORMAT_THOUSAND_THRESHOLD <- 1000

# Analysis thresholds
MIN_BOOKS_FOR_AUTHOR_ANALYSIS <- 2  # Authors need at least 2 books
MIN_BOOKS_FOR_PUBLISHER_ANALYSIS <- 5  # Publishers need at least 5 books
MIN_PERIOD_COMPARISON_YEARS <- 10  # Period comparison needs 10+ years

# Query limits (security: prevent excessive resource usage)
MAX_FILTER_VALUES <- 100  # Maximum values in IN clause
MAX_QUERY_LIMIT <- 10000   # Maximum rows returned
DEFAULT_QUERY_LIMIT <- 100 # Default rows if not specified

# Input validation ranges (wider than data range for flexibility)
INPUT_MIN_YEAR <- 1800
INPUT_MAX_YEAR <- 2100

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
