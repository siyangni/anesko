# How to Update the American Authorship Database

A step-by-step guide for adding new data to the American Authorship Database (1860-1920).

---

## Quick Reference Cheat Sheet

| Task | Command |
|------|---------|
| Full migration (everything at once) | `source("db/migrations/00_run_full_migration.R")` |
| Step 1: Clean data only | `source("scripts/cleaning/pre_migration_cleaning.R")` |
| Step 2: Test cleaned CSVs | `source("db/migrations/test_migration_files.R")` |
| Step 3: Import to database | `source("db/migrations/03_import_data.R")` |
| Step 4: Verify import | `source("db/migrations/check_tables.R")` |
| Backup database | `bash scripts/backup/backup_database.sh` |
| Reset database (destructive) | `source("db/migrations/reset_database.R")` |

---

## Part 1: Installation

### 1.1 Install R

R is the programming language this project uses for data processing.

**macOS:**
1. Go to https://cran.r-project.org/bin/macosx/
2. Download the `.pkg` file for your Mac (Intel or Apple Silicon)
3. Run the installer

**Windows:**
1. Go to https://cran.r-project.org/bin/windows/
2. Click "base" then download `R-x.x.x-win.exe`
3. Run the installer with default settings

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install r-base r-base-dev
```

### 1.2 Install RStudio

RStudio is a visual editor that makes working with R much easier.

1. Go to https://posit.co/download/rstudio-desktop/
2. Download the free RStudio Desktop version for your OS
3. Install and open it

When you open RStudio, you will see a console panel at the bottom-left. That is where you will type commands.

### 1.3 Install PostgreSQL

PostgreSQL is the database that stores all the book and sales data.

**macOS (using Homebrew):**
```bash
brew install postgresql@15
brew services start postgresql@15
```

**Windows:**
1. Go to https://www.postgresql.org/download/windows/
2. Download the installer from EDB
3. Run it and remember the password you set for the `postgres` user

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

### 1.4 Create the Database

After installing PostgreSQL, create the database and user that the project expects.

**macOS/Linux** (run in Terminal):
```bash
# Create the database user
createuser authorship_admin

# Create the database
createdb american_authorship -O authorship_admin

# Set a password for the user
psql -c "ALTER USER authorship_admin PASSWORD 'your_password_here';"
```

**Windows** (run in pgAdmin or PowerShell with psql):
```sql
-- Open pgAdmin, connect to the server, then open the Query Tool and run:
CREATE USER authorship_admin WITH PASSWORD 'your_password_here';
CREATE DATABASE american_authorship OWNER authorship_admin;
```

### 1.5 Configure Database Credentials

The project needs to know how to connect to your database. Create a config file:

```r
# In RStudio, open the Console (bottom-left panel) and run:
if (!dir.exists("scripts/config")) dir.create("scripts/config", recursive = TRUE)

writeLines('db_config <- list(
  host = "localhost",
  dbname = "american_authorship",
  user = "authorship_admin",
  password = "your_password_here"
)', "scripts/config/database_config.R")
```

Replace `your_password_here` with the password you set in Step 1.4.

> This file is gitignored — it will never be committed to the repository.

### 1.6 Install R Packages

Open RStudio, set your working directory to the project folder, and run this in the Console:

```r
# Set working directory to the project root
setwd("/path/to/anesko")  # Change this to your actual path

# Install all required packages
install.packages(c(
  "DBI", "RPostgreSQL", "pool",      # Database
  "dplyr", "tidyr", "stringr",       # Data manipulation
  "readxl", "here", "pacman",        # File reading
  "shiny", "ggplot2", "plotly",      # App/visualization
  "bslib", "DT", "scales"            # UI components
))
```

To verify the installation:
```r
library(DBI)
library(RPostgreSQL)
cat("All database packages loaded successfully!\n")
```

### 1.7 Set Your Working Directory

**Important:** Every time you open RStudio, set your working directory to the project root folder.

In RStudio:
1. Go to **Session** > **Set Working Directory** > **Choose Directory...**
2. Navigate to the `anesko` project folder and click **Open**

Or in the Console:
```r
setwd("/path/to/anesko")  # Change to your actual path
```

You can verify it worked:
```r
getwd()  # Should show the path to the anesko folder
```

---

## Part 2: Understanding the Data Pipeline

### How Data Flows

```
  Excel files (.xlsx)
       |
       v
  Cleaning script (pre_migration_cleaning.R)
       |
       v
  Cleaned CSV files (.csv)
       |
       v
  Import script (03_import_data.R)
       |
       v
  PostgreSQL database
       |
       v
  Shiny dashboard (read-only)
```

Data always flows in one direction: Excel → CSV → PostgreSQL. The Shiny app only reads from the database; it never writes to it.

### The Three Database Tables

The database has three tables connected by `book_id`:

**`book_entries`** — One row per book (the main table)

| Column | What it stores | Example |
|--------|---------------|---------|
| `book_id` | Unique identifier | `BH1870A` |
| `author_surname` | Author's last name | `Harte` |
| `gender` | `Male`, `Female`, or NULL | `Male` |
| `book_title` | Full title | `The Luck of Roaring Camp` |
| `genre` | Full genre name | `Short Story Collection/Novella` |
| `binding` | Format type | `Cloth` |
| `publisher` | Standardized name | `Houghton Mifflin` |
| `publication_year` | Year published | `1870` |
| `retail_price` | Price in dollars | `1.50` |
| `royalty_rate` | Base royalty rate | `0.10` |
| `notes` | Archival notes | (free text) |
| `contract_terms` | Contract details | (free text) |
| `author_id` | Author code from book_id | `BH` |

**`book_sales`** — One row per book per year of sales

| Column | What it stores | Example |
|--------|---------------|---------|
| `sale_id` | Auto-generated ID | `1` |
| `book_id` | Links to book_entries | `BH1870A` |
| `year` | Year of sales | `1875` |
| `sales_count` | Copies sold (can be negative for returns) | `1523` |

**`royalty_tiers`** — Sliding-scale royalty rates per book

| Column | What it stores | Example |
|--------|---------------|---------|
| `tier_id` | Auto-generated ID | `1` |
| `book_id` | Links to book_entries | `BH1870A` |
| `tier` | Tier number (1, 2, 3, or 4) | `1` |
| `rate` | Rate for this tier | `0.10` |
| `lower_limit` | Sales threshold to enter tier | `1` |
| `upper_limit` | Sales ceiling (NULL = unlimited) | `5000` |
| `sliding_scale` | Whether sliding scale applies | `TRUE` |

### Code Values Used in the Excel Files

The Excel files use short codes. The cleaning script converts them automatically:

| Code | Genre | | Code | Binding | | Code | Gender |
|------|-------|-|------|---------|-|------|--------|
| A | Anthology | | C | Cloth | | M | Male |
| C | Children's Literature | | P | Paper | | F | Female |
| D | Drama | | D | Deluxe | | | |
| E | Essay/Other Non-Fiction | | I | Illustrated | | | |
| N | Novel | | R | Reprint | | | |
| M | Memoir | | | | | | |
| S | Short Story Collection | | | | | | |
| T | Travel | | | | | | |
| P | Poetry | | | | | | |
| J | Children's Literature | | | | | | |

### Excel File Format Requirements

The cleaning script expects two Excel files in `data/original/`:

1. **`anesko_db_original.xlsx`** (the main dataset) with sheets:
   - `Book_Entry_Table` — book metadata
   - `Book Sales_Table` — sales data (wide format: one column per year like `y1858`, `y1859`, etc.) plus royalty columns (`r1`-`r4`, `limit1`-`limit4`, `Sliding Scale?`)

2. **`anesko_db_original_aug_addition.xlsx`** (additional entries) with sheets:
   - `Book_Entry` — same columns as `Book_Entry_Table`
   - `Sales_Table` — same columns as `Book Sales_Table`

Both files must have a `Book ID` column in the book entry sheets and a `book_ID` column in the sales sheets.

---

## Part 3: Adding New Data (Step by Step)

This is the main workflow for adding a new batch of data.

### Step 1: Place the New Excel File

Copy your new Excel file into the `data/original/` folder:

```bash
# Example: copying from a USB drive or Downloads folder
cp ~/Downloads/new_data.xlsx /path/to/anesko/data/original/
```

### Step 2: Update the Cleaning Script

Open `scripts/cleaning/pre_migration_cleaning.R` in RStudio and add your new file.

Find lines 10-13 where the Excel files are defined:

```r
excel_file <- here::here("data/original/anesko_db_original.xlsx")
excel_file_new <- here::here("data/original/anesko_db_original_aug_addition.xlsx")
```

Add a third variable for your new file:

```r
excel_file <- here::here("data/original/anesko_db_original.xlsx")
excel_file_new <- here::here("data/original/anesko_db_original_aug_addition.xlsx")
excel_file_batch3 <- here::here("data/original/new_data.xlsx")  # <-- Add this
```

Then find lines 28-33 where the sheets are read:

```r
book_entries_orig <- read_excel(excel_file, sheet = "Book_Entry_Table")
book_sales_orig <- read_excel(excel_file, sheet = "Book Sales_Table")

book_entries_new <- read_excel(excel_file_new, sheet = "Book_Entry")
book_sales_new <- read_excel(excel_file_new, sheet = "Sales_Table")
```

Add reading of your new file:

```r
book_entries_orig <- read_excel(excel_file, sheet = "Book_Entry_Table")
book_sales_orig <- read_excel(excel_file, sheet = "Book Sales_Table")

book_entries_new <- read_excel(excel_file_new, sheet = "Book_Entry")
book_sales_new <- read_excel(excel_file_new, sheet = "Sales_Table")

# Add your new file (adjust sheet names to match your Excel file)
book_entries_batch3 <- read_excel(excel_file_batch3, sheet = "Book_Entry")
book_sales_batch3 <- read_excel(excel_file_batch3, sheet = "Sales_Table")
```

Then find lines 76-77 where data is combined:

```r
book_entries <- bind_rows(book_entries_orig, book_entries_new)
book_sales <- bind_rows(book_sales_orig, book_sales_new)
```

Update to include your new data:

```r
book_entries <- bind_rows(book_entries_orig, book_entries_new, book_entries_batch3)
book_sales <- bind_rows(book_sales_orig, book_sales_new, book_sales_batch3)
```

> **Tip:** If your new file uses the exact same sheet names as one of the existing files, you can simply replace the file instead of adding a new variable. For example, if you are providing an updated version of the augmentation data, just overwrite `anesko_db_original_aug_addition.xlsx`.

### Step 3: Run the Cleaning Script

In the RStudio Console, run:

```r
source("scripts/cleaning/pre_migration_cleaning.R")
```

What this does:
- Reads both Excel files
- Combines and deduplicates the data (if a Book ID exists in both files, the original is kept)
- Standardizes publisher names (e.g., "Harper & Bros" → "Harper & Brothers")
- Converts genre codes to full names (e.g., "N" → "Novel")
- Converts binding codes (e.g., "C" → "Cloth")
- Converts gender codes (e.g., "M" → "Male")
- Reshapes sales from wide to long format (one row per book per year)
- Extracts royalty tiers from the r1-r4 / limit1-limit4 columns
- Writes three cleaned CSV files to `data/cleaned/`

You should see output like:
```
=== GENRE RECODING ===
Original Genre values:
...
Genre values after recoding:
...

=== RESHAPING BOOK_SALES TO LONG FORMAT ===
...
Reshaped book_sales_long dimensions: ...
```

### Step 4: Validate the Cleaned CSVs

Before importing, verify the CSV files are correct:

```r
source("db/migrations/test_migration_files.R")
```

This checks:
- All three CSV files exist
- Column names match what the import script expects
- Data types are correct (e.g., years are numbers, IDs are text)

You should see:
```
✅ File existence
✅ Book entries mapping
✅ Sales data processing
✅ Royalty data processing
🎉 All tests passed! Migration files are ready.
```

If any test fails, check the error message and fix the issue in the cleaning script before proceeding.

### Step 5: Import into the Database

> **Warning:** This step deletes all existing data in the database and replaces it with the cleaned CSV data. Back up first if needed (see Part 5).

```r
source("db/migrations/03_import_data.R")
```

This script:
1. Connects to PostgreSQL
2. TRUNCATES (empties) all three tables
3. Reads the cleaned CSV files
4. Inserts data in chunks of 1,000 rows
5. Verifies the import with counts and sample queries

You should see:
```
🔗 Connected to database
📖 Reading cleaned CSV files...
📊 Found ... cleaned book entries
📊 Found ... royalty tier records
...
✅ Data import complete!
```

### Step 6: Verify the Import

Run the verification script to check data quality:

```r
source("db/migrations/check_tables.R")
```

This shows:
- Row counts for each table
- Gender, genre, and publisher distributions
- Sales summary by decade
- Royalty rate distributions

Review the output to make sure everything looks reasonable.

---

## Part 4: Full Migration vs. Individual Steps

### Full Migration (One Command)

If you want to run everything at once — clean, set up schema, and import — use the master script:

```r
source("db/migrations/00_run_full_migration.R")
```

This runs all four steps in sequence:
1. Data cleaning
2. Database connection test
3. Schema creation (drops and recreates tables)
4. Data import

Use this when:
- Setting up the database for the first time
- Doing a complete refresh with all data
- You want a clean slate

### Individual Steps

Run steps individually when:
- You only changed the cleaning script and want to re-import
- You want to debug a specific step
- You want to verify CSVs before importing

Use the commands from the cheat sheet at the top of this document.

---

## Part 5: Making Small Direct Edits

For small changes (fixing a typo in a publisher name, correcting a genre), you can update the database directly without re-running the full pipeline.

### Using R

Connect to the database and run SQL:

```r
library(DBI)
library(RPostgreSQL)
source("scripts/config/database_config.R")

con <- dbConnect(
  RPostgreSQL::PostgreSQL(),
  host = db_config$host,
  dbname = db_config$dbname,
  user = db_config$user,
  password = db_config$password
)

# Example: fix a publisher name
dbExecute(con, "
  UPDATE book_entries
  SET publisher = 'Harper & Brothers'
  WHERE publisher = 'Harper and Brothers'
")

# Verify the change
result <- dbGetQuery(con, "
  SELECT publisher, COUNT(*) as count
  FROM book_entries
  GROUP BY publisher
  ORDER BY count DESC
")
print(result)

dbDisconnect(con)
```

### Using pgAdmin (Graphical Tool)

1. Open pgAdmin (installed with PostgreSQL on Windows, or download separately)
2. Connect to your server
3. Expand **Databases** > **american_authorship** > **Schemas** > **public** > **Tables**
4. Right-click a table and select **Query Tool**
5. Write your SQL and click the Execute button (lightning bolt)

### Common Direct Edits

Fix a publisher name:
```sql
UPDATE book_entries
SET publisher = 'Scribner''s'
WHERE publisher = 'Scribners';
```

Fix a genre:
```sql
UPDATE book_entries
SET genre = 'Novel'
WHERE genre = 'novel';
```

Add a missing sales record:
```sql
INSERT INTO book_sales (book_id, year, sales_count)
VALUES ('BH1870A', 1875, 1500);
```

Delete a duplicate entry:
```sql
DELETE FROM book_sales
WHERE sale_id = 12345;
```

---

## Part 6: Backup and Restore

### Before Making Changes — Back Up

Always back up before importing new data or making direct edits.

**Quick backup (in Terminal):**
```bash
bash scripts/backup/backup_database.sh
```

This creates a compressed `.sql.gz` file in the `backups/` directory with automatic rotation (keeps last 10 backups, 30-day retention).

**Manual backup (in Terminal):**
```bash
pg_dump -U authorship_admin -h localhost american_authorship | gzip > backup_$(date +%Y%m%d).sql.gz
```

### Restore from Backup

If something goes wrong, restore from a backup:

```r
# In RStudio
source("scripts/analysis/restore_database.R")
```

Or from the Terminal:
```bash
gunzip < backup_20240101.sql.gz | psql -U authorship_admin -h localhost american_authorship
```

---

## Part 7: Troubleshooting

### "Original Excel file not found"

**Error:** `Original Excel file not found: /path/to/data/original/anesko_db_original.xlsx`

**Fix:** Make sure the Excel file is in `data/original/`. Check that the filename matches exactly (including capitalization and spaces).

### "Database connection failed"

**Error:** `Database connection failed. Please check your configuration.`

**Fix:**
1. Check that PostgreSQL is running:
   ```bash
   # macOS
   brew services list | grep postgresql

   # Linux
   sudo systemctl status postgresql
   ```
2. Verify your credentials in `scripts/config/database_config.R`
3. Test the connection directly:
   ```bash
   psql -U authorship_admin -h localhost american_authorship -c "SELECT 1;"
   ```

### "Cleaned book entries file not found"

**Error:** `Cleaned book entries file not found: .../data/cleaned/book_entry_cleaned.csv`

**Fix:** Run the cleaning script first:
```r
source("scripts/cleaning/pre_migration_cleaning.R")
```

### "Column mapping failed" in test script

**Fix:** Your Excel file may have different column names than expected. Open the Excel file and check that:
- The book entry sheet has a `Book ID` column
- The sales sheet has a `book_ID` column and year columns starting with `y` (like `y1858`, `y1859`)

### "duplicate Book IDs" warning

This is normal. The cleaning script keeps the original data when the same Book ID appears in both files. If you want the new data to take priority, swap the file assignments in the cleaning script.

### R packages not found

**Error:** `there is no package called 'RPostgreSQL'`

**Fix:** Install missing packages:
```r
install.packages("RPostgreSQL")
```

Or install all at once:
```r
install.packages(c("DBI", "RPostgreSQL", "pool", "dplyr", "tidyr", "stringr", "readxl", "here"))
```

### Working directory is wrong

**Error:** `cannot open file 'scripts/config/database_config.R': No such file or directory`

**Fix:** Set your working directory to the project root:
```r
setwd("/path/to/anesko")
getwd()  # Verify it shows the anesko folder
```

---

## Part 8: What to Do After Importing

After a successful import:

1. **Restart the Shiny app** (if running) to pick up the new data
2. **Check the dashboard** — browse through the visualizations to confirm the new data appears
3. **Commit your changes** if you updated the cleaning script:
   ```bash
   git add scripts/cleaning/pre_migration_cleaning.R
   git commit -m "Add batch 3 data to cleaning pipeline"
   ```

---

## Glossary

| Term | Meaning |
|------|---------|
| **TRUNCATE** | Deletes all rows from a table (faster than DELETE) |
| **CASCADE** | When deleting from a parent table, also delete related child rows |
| **FOREIGN KEY** | A column that references the primary key of another table |
| **source()** | An R command that runs all the code in a file |
| **CSV** | Comma-Separated Values — a plain text spreadsheet format |
| **pg_dump** | PostgreSQL's built-in backup tool |
| **ETL** | Extract, Transform, Load — the data pipeline pattern |
| **Long format** | One row per observation (e.g., one row per book per year) |
| **Wide format** | One row per entity, columns for each time period |
