# Repository Refactoring Inventory

Generated: 2025-11-05

This document provides comprehensive inventories of files, their references, and archival decisions made during the repository reorganization.

## Table of Contents

1. [R Source Files Inventory](#r-source-files-inventory)
2. [SQL Files Inventory](#sql-files-inventory)
3. [Static Assets Inventory](#static-assets-inventory)
4. [Archived Files with Reasons](#archived-files-with-reasons)

---

## R Source Files Inventory

### Active Modules (shiny-app/modules/)

| File | Size | Referenced By | Status |
|------|------|---------------|--------|
| dashboard_module.R | ~15KB | global.R, server.R | Active |
| book_explorer_module.R | ~12KB | global.R, server.R | Active |
| sales_trends_module.R | ~14KB | global.R, server.R | Active - Replaces old sales_analysis |
| author_analysis_module.R | ~13KB | global.R, server.R | Active |
| author_networks_module.R | ~11KB | global.R, server.R | Active |
| royalty_analysis_module.R | ~15KB | global.R, server.R | Active |
| royalty_query_module.R | ~10KB | global.R, server.R | Active |
| genre_analysis_module.R | ~12KB | global.R, server.R | Active |
| sales_analysis_module.R | ~13KB | global.R | Kept for reference, not in UI |

### Utility Files (shiny-app/utils/)

| File | Referenced By | Purpose |
|------|---------------|---------|
| database.R | global.R, modules | Database connection pool management |
| data_processing.R | global.R, modules | Data transformation functions |
| plotting.R | global.R, modules | Chart and plot utilities |
| queries_basic.R | global.R, modules | Basic database queries |
| queries_sales.R | global.R, modules | Sales-related queries |
| queries_royalties.R | global.R, modules | Royalty queries |
| queries_timeseries.R | global.R, modules | Time series queries |
| error_handling.R | global.R, modules | Error handling utilities |

### Database Migration Scripts (db/migrations/)

| File | Purpose | Callable |
|------|---------|----------|
| 00_package_setup.R | Install required R packages | Yes |
| 01_database_setup.R | Create database and roles | Yes |
| 02_create_schema.R | Create tables and views | Yes |
| 03_import_data.R | Import data from Excel | Yes |
| 00_run_full_migration.R | Run complete migration | Yes - Main entry point |
| reset_database.R | Reset database to clean state | Yes |
| check_tables.R | Verify table creation | Yes |
| fix_view.R | Fix materialized view | Yes |
| test_migration_files.R | Test migration scripts | Archived to test_files/ |

### Analysis Scripts (scripts/analysis/)

| File | Purpose | Dependencies |
|------|---------|--------------|
| 02_data_cleaning.R | Data cleaning operations | Database connection |
| 03_exploratory_analysis.R | Exploratory data analysis | Database, ggplot2 |
| restore_database.R | Restore from backup | PostgreSQL |
| clean_restore_database.R | Clean and restore | PostgreSQL |
| check_note_like_entries.R | Data quality checks | Database |
| execute_reverse_changes.R | Reverse database changes | Database |
| reverse_publisher_changes.R | Revert publisher edits | Database |

### Deployment Scripts (deployment/)

| File | Purpose | Platform |
|------|---------|----------|
| deploy.sh | General deployment | Generic server |
| deploy_to_shinyapps.sh | Deploy to shinyapps.io | shinyapps.io |
| migrate_to_neon.sh | Migrate to Neon DB | Neon PostgreSQL |
| setup_neon.sh | Configure Neon connection | Neon PostgreSQL |
| test_app_with_neon.sh | Test with Neon | Neon PostgreSQL |
| connect_neondb.sh | Connect to Neon | Neon PostgreSQL |

---

## SQL Files Inventory

**Note**: This project uses R-based database operations via DBI/RPostgreSQL. SQL queries are embedded in R utility files.

| Location | Query Type | Files |
|----------|------------|-------|
| utils/queries_basic.R | SELECT, aggregate queries | Basic book/author queries |
| utils/queries_sales.R | Sales analytics | Time series, aggregations |
| utils/queries_royalties.R | Royalty calculations | Complex joins, aggregations |
| utils/queries_timeseries.R | Time series analysis | Window functions, rolling aggregates |
| db/migrations/02_create_schema.R | DDL | CREATE TABLE, CREATE VIEW statements |

### SQL Query Examples by Function

| Function | Query Type | Location |
|----------|------------|----------|
| get_book_sales_summary() | SELECT | utils/queries_sales.R |
| get_author_royalties() | SELECT with JOIN | utils/queries_royalties.R |
| compute_sales_distribution() | Aggregate | utils/queries_sales.R |
| get_genre_trends() | GROUP BY, time series | utils/queries_basic.R |

---

## Static Assets Inventory

### Web Assets (shiny-app/www/)

| File | Type | Referenced By | Purpose |
|------|------|---------------|---------|
| style.css | CSS | ui.R (tags$link) | Custom styling for dashboard |

**Note**: Other potential assets (images, JS) are not present. App uses CSS only for custom styling.

### Configuration Templates

| File | Type | Purpose | Commit to Repo? |
|------|------|---------|-----------------|
| .env.template | Environment | Database credential template | Yes (template only) |
| cloud_config.template.R | R | Database config template | Yes (template only) |
| cloud_config.R | R | Active database config | NO - Contains credentials |

---

## Archived Files with Reasons

### Summary

| Category | Count | Reason Code |
|----------|-------|-------------|
| Test/Debug Files | 44 | Criterion #1 - Unreferenced |
| Module Variants | 4 | Criterion #2 - Superseded |
| Deployment Scripts | 3 | Criterion #2 - Obsolete (ElephantSQL) |
| Config Backups | 2 | Criterion #2 - Backup files |
| Database Files | 1 | Criterion #2 - Obsolete (SQLite) |
| **Total** | **54** | |

### Detailed Archive List

#### Test and Debug Files (44 files → archive/test_files/)

| File | Reason | Last Used |
|------|--------|-----------|
| test_dropdown_ui.R | Ad-hoc test, not in test suite | Development |
| test_dropdowns.R | Ad-hoc test, not in test suite | Development |
| test_fixes.R | Ad-hoc test, not in test suite | Development |
| test_value_box_fix.R | Ad-hoc test, not in test suite | Development |
| test_value_box_colors.R | Ad-hoc test, not in test suite | Development |
| debug_dashboard_fix.R | Debug script, issue resolved | Development |
| debug_dashboard_reactive.R | Debug script, issue resolved | Development |
| debug_filters.R | Debug script, issue resolved | Development |
| debug_reactive_issue.R | Debug script, issue resolved | Development |
| test_author_network_fixes.R | Ad-hoc test, not in test suite | Development |
| test_complete_author_network.R | Ad-hoc test, not in test suite | Development |
| test_author_network_app.R | Ad-hoc test, not in test suite | Development |
| test_fixed_dashboard.R | Ad-hoc test, not in test suite | Development |
| test_genre_fix.R | Ad-hoc test, not in test suite | Development |
| test_genre_consistency_fix.R | Ad-hoc test, not in test suite | Development |
| test_genre_data.R | Ad-hoc test, not in test suite | Development |
| test_sliding_scale_filter.R | Ad-hoc test, not in test suite | Development |
| test_sliding_scale_migration.R | Ad-hoc test, not in test suite | Development |
| test_sliding_scale_data.R | Ad-hoc test, not in test suite | Development |
| test_original_sliding_scale.R | Ad-hoc test, not in test suite | Development |
| test_fixed_query.R | Ad-hoc test, not in test suite | Development |
| test_minimal_syntax.R | Ad-hoc test, not in test suite | Development |
| test_syntax_fix.R | Ad-hoc test, not in test suite | Development |
| test_year_range_fix.R | Ad-hoc test, not in test suite | Development |
| test_royalty_analysis_fixes.R | Ad-hoc test, not in test suite | Development |
| test_sales_analysis_dropdowns.R | Ad-hoc test, not in test suite | Development |
| demo_sales_analysis_dropdowns.R | Demo script, not needed | Development |
| test_dashboard_genre_complete.R | Ad-hoc test, not in test suite | Development |
| test_app.R | Ad-hoc test, not in test suite | Development |
| test_app_connection.R | Ad-hoc test, not in test suite | Development |
| test_compute_distribution.R | Ad-hoc test, not in test suite | Development |
| test_error_handling.R | Ad-hoc test, not in test suite | Development |
| check_excel_sheets.R | One-time check, completed | Development |
| diagnose_genre_inconsistency.R | Diagnostic script, issue resolved | Development |
| verify_dropdown_changes.R | Verification script, completed | Development |
| fix_sliding_scale_migration.R | Migration fix, completed | Development |
| deploy_script.R | Replaced by deployment/*.sh | Development |
| test_neon_connection.R | One-time test, connection verified | Migration |
| test_shiny_components.R | Ad-hoc test | Development |
| test_royalty_fix.R | Ad-hoc test | Development |
| verify_neon_migration.R | One-time verification, completed | Migration |
| author_summary_stats_fixed.R | One-time fix, completed | Development |
| clean_author_function.R | Function extraction, integrated | Development |
| test_genre_cleaning_fix.R | Ad-hoc test | Development |

**Reason**: Criterion #1 - Unreferenced by app, not part of formal test suite

#### Obsolete Module Variants (4 files → archive/obsolete_modules/)

| File | Size | Reason | Superseded By |
|------|------|--------|---------------|
| sales_analysis_module_clean.R | 825B | Stub/incomplete | sales_trends_module.R |
| sales_analysis_module_new.R | 13KB | Development variant | sales_trends_module.R |
| sales_analysis_module_working.R | 11KB | Development variant | sales_trends_module.R |
| sales_analysis_consolidated_module.R | 15KB | Consolidation attempt, not wired to UI | sales_trends_module.R |

**Reason**: Criterion #2 - Superseded by sales_trends_module.R (active implementation)

#### Obsolete Deployment Scripts (3 files → archive/obsolete_scripts/)

| File | Size | Reason | Replacement |
|------|------|--------|-------------|
| migrate_to_elephantsql.sh | 7.5KB | ElephantSQL no longer used | migrate_to_neon.sh |
| setup_elephantsql.sh | 3.3KB | ElephantSQL no longer used | setup_neon.sh |
| test_app_with_elephantsql.sh | 7.3KB | ElephantSQL no longer used | test_app_with_neon.sh |

**Reason**: Criterion #2 - Project migrated to Neon, ElephantSQL scripts obsolete

#### Obsolete Config Files (2 files → archive/obsolete_configs/)

| File | Reason |
|------|--------|
| app_config_local_backup.R | Backup file (Criterion #2) |
| cloud_config.R | Contained hardcoded credentials - SECURITY ISSUE (replaced with template) |

**Reason**: Criterion #2 - Backup file; Security: hardcoded credentials removed

#### Obsolete Database Files (1 file → archive/obsolete_databases/)

| File | Size | Reason |
|------|------|--------|
| anesko_database.db | 0 bytes | Empty SQLite database (Criterion #2) |

**Reason**: Criterion #2 - Project uses PostgreSQL, SQLite database obsolete

---

## Risk Assessment

### Low-Risk Archives (No Reference Risk)

- All test_*.R and debug_*.R files: Not referenced by any production code
- Obsolete module variants: Not wired into server.R or UI
- ElephantSQL scripts: Platform no longer in use
- SQLite database: Empty, no data loss

### Medium-Risk Archives (Potential Legacy Dependencies)

- None identified

### Files Requiring User Confirmation (Not Archived)

- Database migration files in db/migrations/: Active, required for database setup
- License.md: Legal document, must remain
- Core app files (app.R, global.R, server.R, ui.R): Application entry points

---

## Restoration Instructions

To restore an archived file:

```bash
# View archived file
cat archive/<category>/<filename>

# Copy back to restore (preserves archive copy)
cp archive/<category>/<filename> <original-location>/

# View file history
git log --follow archive/<category>/<filename>
```

---

*Inventory generated as part of repository refactoring PR*
