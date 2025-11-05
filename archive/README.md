# Archive Directory

This directory contains files that have been archived from the active codebase. Files here are preserved for historical reference but are not part of the current application.

## Archive Categories

### test_files/
Ad-hoc test and debug scripts that were used during development but are not part of the formal test suite.

**Reason Code**: Criterion #1 - Unreferenced by app, not part of library entrypoint

**Files**: 37 test/debug scripts from shiny-app/ and root
- All test_*.R and debug_*.R files from shiny-app/
- Root-level ad-hoc test files

### obsolete_modules/
Shiny module variants that have been superseded by newer implementations.

**Reason Code**: Criterion #2 - Superseded by newer file

**Files**: 4 sales analysis module variants
- sales_analysis_module_clean.R (stub, 825 bytes)
- sales_analysis_module_new.R (variant)
- sales_analysis_module_working.R (variant)
- sales_analysis_consolidated_module.R (not wired into UI)

All superseded by `sales_trends_module.R` which is the active implementation.

### obsolete_scripts/
Shell scripts and R scripts for obsolete services or one-time migrations.

**Reason Code**: Criterion #2 - Superseded by newer infrastructure

**Files**: ElephantSQL-related scripts (project migrated to Neon)
- migrate_to_elephantsql.sh
- setup_elephantsql.sh
- test_app_with_elephantsql.sh

### obsolete_configs/
Backup configuration files and files with hardcoded credentials.

**Reason Code**:
- Criterion #2 - Backup files
- Security: Hardcoded credentials

**Files**:
- app_config_local_backup.R (backup)
- cloud_config.R (contained hardcoded credentials - archived for security)

**Note**: Template versions without secrets have been created in the active config/.

### obsolete_databases/
Database files from deprecated database engines.

**Reason Code**: Criterion #2 - Superseded by PostgreSQL

**Files**:
- anesko_database.db (SQLite - project uses PostgreSQL)
- Zone.Identifier files (Windows metadata)

## Archival Date
2025-11-05

## How to Access Archived File History
All files were moved using `git mv` to preserve their commit history. To view the history of an archived file:

```bash
# View the history of an archived file
git log --follow archive/test_files/<filename>

# View the file at a specific point in time
git show <commit-hash>:path/to/old/location/<filename>
```

## Restoration
If you need to restore an archived file:

```bash
# Copy (don't move) the file back to restore it
cp archive/<category>/<filename> <destination>/

# Then commit the restoration
git add <destination>/<filename>
git commit -m "Restore <filename> from archive"
```
