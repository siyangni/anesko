# American Authorship Database Migration

This directory contains scripts for migrating the American Authorship data from Excel to PostgreSQL database.

## Overview

The migration process has been designed to separate data cleaning from database operations:

- **Data cleaning** is handled entirely by `scripts/cleaning/pre_migration_cleaning.R`
- **Database setup and import** is handled by the migration scripts in this directory

## Migration Process

### Option 1: Run Full Migration (Recommended)

Use the master script to run the entire process:

```r
source("scripts/migration/00_run_full_migration.R")
```

This will automatically run all steps in the correct order.

### Option 2: Run Individual Steps

If you need to run steps individually:

#### Step 1: Data Cleaning
```r
source("scripts/cleaning/pre_migration_cleaning.R")
```

This script:
- Reads the original Excel file (`data/original/anesko_db_original.xlsx`)
- Performs all data cleaning operations:
  - Publisher recoding and standardization
  - Genre recoding (C→cloth, P→paper, etc.)
  - Reshapes book sales data to long format
  - Creates royalty tiers structure
- Exports cleaned CSV files to `data/cleaned/`:
  - `book_entries_final.csv` - cleaned book entries
  - `book_sales_long.csv` - reshaped sales data
  - `royalty_tiers_corrected.csv` - royalty structure

#### Step 2: Database Setup
```r
source("scripts/migration/01_database_setup.R")
```

Tests database connection and sets up configuration.

#### Step 3: Schema Creation
```r
source("scripts/migration/02_create_schema.R")
```

Creates database tables:
- `book_entries` - main book information
- `book_sales` - year-based sales data
- `royalty_tiers` - royalty structure with tiers and rates

#### Step 4: Data Import
```r
source("scripts/migration/03_import_data.R")
```

Imports the cleaned CSV files into the database tables.

## Database Schema

### book_entries
- `book_id` (VARCHAR, PRIMARY KEY)
- `author_surname` (VARCHAR)
- `gender` (CHAR)
- `book_title` (TEXT)
- `genre` (VARCHAR) - cleaned values: Novel, Poetry, Drama, etc.
- `binding` (VARCHAR)
- `notes` (TEXT)
- `retail_price` (DECIMAL)
- `royalty_rate` (DECIMAL)
- `contract_terms` (TEXT)
- `publisher` (VARCHAR) - standardized publisher names
- `publication_year` (INTEGER)

### book_sales
- `sale_id` (SERIAL, PRIMARY KEY)
- `book_id` (VARCHAR, FOREIGN KEY)
- `year` (INTEGER)
- `sales_count` (INTEGER)

### royalty_tiers
- `tier_id` (SERIAL, PRIMARY KEY)
- `book_id` (VARCHAR, FOREIGN KEY)
- `tier` (INTEGER)
- `rate` (DECIMAL)
- `lower_limit` (INTEGER)
- `upper_limit` (INTEGER) - NULL means infinite
- `sliding_scale` (BOOLEAN)

## Data Cleaning Details

The `pre_migration_cleaning.R` script performs comprehensive data cleaning:

### Publisher Standardization
- Consolidates publisher name variations
- Moves special copyright text to Notes field
- Standardizes spacing and punctuation

### Genre Recoding
- A → Anthology
- C → Children's Literature/Juvenile
- D → Drama
- E → Essay/Other Non-Fiction
- N → Novel
- P → Poetry
- S → Short Story Collection/Novella
- T → Travel

### Binding Recoding
- C → Cloth
- P → Paper
- D → Deluxe
- I → Illustrated
- R → Reprint

### Sales Data Restructuring
- Converts wide format (y1858, y1859, etc.) to long format
- Creates year-sales pairs for analysis

### Royalty Structure
- Processes complex royalty tiers (r1-r4, limit1-limit4)
- Handles infinite upper limits (limit=0)
- Preserves sliding scale indicators

## Prerequisites

1. **Database Setup**: Ensure PostgreSQL is running and accessible
2. **R Packages**: Install required packages using `00_package_setup.R`
3. **Data File**: Place `anesko_db_original.xlsx` in `data/original/`
4. **Database Config**: Set up database credentials (see `01_database_setup.R`)

## File Dependencies

This script:
- Reads the original Excel files:
  - `data/original/anesko_db_original.xlsx` (main dataset)
  - `data/original/anesko_db_original_aug_addition.xlsx` (additional entries)
- Combines and deduplicates the datasets
- Performs all data cleaning operations:
  - Publisher normalization and canonicalization
  - Genre recoding (A→Anthology, N→Novel, etc.)
  - Binding recoding (C→Cloth, P→Paper, etc.)
  - Gender recoding (M→Male, F→Female)
  - Reshapes book sales data to long format
  - Creates normalized royalty tiers structure
- Exports cleaned CSV files to `data/cleaned/`:
  - `book_entry_cleaned.csv` - cleaned book entries
  - `book_sales_cleaned.csv` - reshaped sales data (long format)
  - `royalty_tiers_cleaned.csv` - normalized royalty structure

## Troubleshooting

- **File not found errors**: Ensure `pre_migration_cleaning.R` has been run first
- **Database connection errors**: Check database credentials and server status
- **Data type errors**: Verify CSV files were created correctly by cleaning script
