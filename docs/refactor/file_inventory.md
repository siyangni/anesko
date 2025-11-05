# Repository Refactoring - File Inventory

## R Files Inventory

### Core Application Files (shiny-app/)
| File | Purpose | Referenced By | Keep/Archive |
|------|---------|---------------|--------------|
| app.R | Main entry point | User | **KEEP** |
| global.R | Global setup, loads all modules | app.R | **KEEP** |
| server.R | Server logic | app.R | **KEEP** |
| ui.R | User interface | app.R | **KEEP** |

### Modules (shiny-app/modules/)
| File | Purpose | Referenced By | Keep/Archive |
|------|---------|---------------|--------------|
| author_analysis_module.R | Author analysis features | global.R (line 52) | **KEEP** |
| author_networks_module.R | Author network visualization | global.R (line 53) | **KEEP** |
| book_explorer_module.R | Book exploration interface | global.R (line 47) | **KEEP** |
| dashboard_module.R | Main dashboard | global.R (line 46) | **KEEP** |
| genre_analysis_module.R | Genre analysis | global.R (line 56) | **KEEP** |
| genre_content_analysis_module.R | Genre content analysis | NONE | **ARCHIVE** - unreferenced |
| royalty_analysis_module.R | Royalty analysis | global.R (line 54) | **KEEP** |
| royalty_query_module.R | Royalty query interface | global.R (line 55) | **KEEP** |
| sales_analysis_module.R | Sales analysis (legacy) | global.R (line 51) | **KEEP** - referenced as legacy |
| sales_analysis_consolidated_module.R | Consolidated version | NONE | **ARCHIVE** - superseded |
| sales_analysis_module_clean.R | Clean version | NONE | **ARCHIVE** - superseded |
| sales_analysis_module_new.R | New version | NONE | **ARCHIVE** - superseded |
| sales_analysis_module_working.R | Working version | NONE | **ARCHIVE** - superseded |
| sales_trends_module.R | Sales trends (current) | global.R (line 49) | **KEEP** |

### Utilities (shiny-app/utils/)
| File | Purpose | Referenced By | Keep/Archive |
|------|---------|---------------|--------------|
| data_processing.R | Data processing functions | global.R (line 36) | **KEEP** |
| database.R | Database connection management | global.R (line 35) | **KEEP** |
| error_handling.R | Error handling utilities | global.R (line 41) | **KEEP** |
| plotting.R | Plotting utilities | global.R (line 37) | **KEEP** |
| queries_basic.R | Basic queries | global.R (line 39) | **KEEP** |
| queries_royalties.R | Royalty queries | global.R (line 43) | **KEEP** |
| queries_royalty.R | Royalty queries (alt) | NONE | **CHECK** - may be duplicate |
| queries_sales.R | Sales queries | global.R (line 40) | **KEEP** |
| queries_timeseries.R | Timeseries queries | global.R (line 42) | **KEEP** |

### Configuration (shiny-app/config/)
| File | Purpose | Referenced By | Keep/Archive |
|------|---------|---------------|--------------|
| app_config.R | App configuration | global.R (line 32) | **KEEP** |
| app_config_local_backup.R | Backup config | NONE | **ARCHIVE** - backup |
| cloud_config.R | Cloud database config | app_config.R (line 10) | **KEEP** - needs security fix |

### Test/Debug Files (shiny-app/) - ALL TO ARCHIVE
| File | Reason |
|------|--------|
| check_excel_sheets.R | Ad-hoc exploratory script |
| debug_dashboard_fix.R | Debug script |
| debug_dashboard_reactive.R | Debug script |
| debug_filters.R | Debug script |
| debug_reactive_issue.R | Debug script |
| demo_sales_analysis_dropdowns.R | Demo/exploratory script |
| deploy_script.R | Duplicate deployment script |
| deploy_shinyapps.R | Duplicate deployment script |
| diagnose_genre_inconsistency.R | Debug script |
| fix_sliding_scale_migration.R | One-time fix script |
| test_app.R | Test script |
| test_app_connection.R | Test script |
| test_author_network_app.R | Test script |
| test_author_network_fixes.R | Test script |
| test_complete_author_network.R | Test script |
| test_compute_distribution.R | Test script |
| test_dashboard_genre_complete.R | Test script |
| test_dropdown_ui.R | Test script |
| test_dropdowns.R | Test script |
| test_error_handling.R | Test script |
| test_fixed_dashboard.R | Test script |
| test_fixed_query.R | Test script |
| test_fixes.R | Test script |
| test_genre_consistency_fix.R | Test script |
| test_genre_data.R | Test script |
| test_genre_fix.R | Test script |
| test_minimal_syntax.R | Test script |
| test_original_sliding_scale.R | Test script |
| test_royalty_analysis_fixes.R | Test script |
| test_sales_analysis_dropdowns.R | Test script |
| test_sliding_scale_data.R | Test script |
| test_sliding_scale_filter.R | Test script |
| test_sliding_scale_migration.R | Test script |
| test_syntax_fix.R | Test script |
| test_value_box_colors.R | Test script |
| test_value_box_fix.R | Test script |
| test_year_range_fix.R | Test script |
| verify_dropdown_changes.R | Test script |

### Root Level Test Files - TO ARCHIVE
| File | Reason |
|------|--------|
| test_app_with_elephantsql.sh | Test script |
| test_app_with_neon.sh | Test script |
| test_neon_connection.R | Test script |
| test_royalty_fix.R | Test script |
| test_shiny_components.R | Test script |
| verify_neon_migration.R | Test script |
| author_summary_stats_fixed.R | Ad-hoc script |
| clean_author_function.R | Ad-hoc script |

### Root Level Deployment Files
| File | Purpose | Keep/Archive |
|------|---------|--------------|
| deploy.sh | Deployment script | **ARCHIVE** - superseded/unclear |
| deploy_to_shinyapps.sh | Deployment script | **CHECK** - may be operational |
| migrate_to_elephantsql.sh | Migration script | **ARCHIVE** - superseded by Neon |
| migrate_to_neon.sh | Migration script | **KEEP** - operational |
| setup_elephantsql.sh | Setup script | **ARCHIVE** - superseded |
| setup_neon.sh | Setup script | **KEEP** - operational |

### Scripts Directory (scripts/)
| File | Purpose | Keep/Archive |
|------|---------|--------------|
| migration/00_package_setup.R | Package setup | **KEEP** |
| migration/00_run_full_migration.R | Full migration runner | **KEEP** |
| migration/01_database_setup.R | Database setup | **KEEP** |
| migration/02_create_schema.R | Schema creation | **KEEP** |
| migration/03_import_data.R | Data import | **KEEP** |
| migration/check_tables.R | Table verification | **KEEP** |
| migration/fix_view.R | View fix | **ARCHIVE** - one-time fix |
| migration/reset_database.R | Database reset | **KEEP** |
| migration/test_migration_files.R | Migration tests | **KEEP** |
| analysis/*.R | Data analysis scripts | **KEEP** - operational |
| cleaning/*.R | Data cleaning scripts | **KEEP** - operational |
| validation/*.R | Validation scripts | **KEEP** - operational |
| test_genre_cleaning_fix.R | Test script | **ARCHIVE** |

### Documentation Files (shiny-app/) - TO ARCHIVE
| File | Reason |
|------|--------|
| AUTHOR_NETWORK_FIXES_SUMMARY.md | Debug notes |
| DEPLOYMENT_INFO.txt | Old deployment info |
| GENRE_ANALYSIS_ERROR_HANDLING_IMPROVEMENTS.md | Debug notes |
| QUICK_START.md | Superseded by main README |
| ROYALTY_ANALYSIS_FIXES_SUMMARY.md | Debug notes |
| SLIDING_SCALE_INVESTIGATION_SUMMARY.md | Debug notes |
| database_setup_guide.md | Will consolidate into main docs |

## Summary

- **Total R files analyzed**: 95
- **Files to KEEP**: 41
- **Files to ARCHIVE**: 54
- **Main reason for archival**: Ad-hoc test/debug scripts (38 files), superseded duplicates (8 files), debug notes (6 files)

## Assets Inventory

### Static Assets (shiny-app/www/)
| File | Purpose | Keep/Archive |
|------|---------|--------------|
| style.css | Custom CSS | **KEEP** |

## Data Files

### Data Directory
| File | Purpose | Keep/Archive |
|------|---------|--------------|
| anesko_database.db | SQLite database | **KEEP** - but gitignore |
| AneskoDB 10-21-23_COPY_with additions June 2024.xlsx:Zone.Identifier | Zone identifier | **ARCHIVE** - generated artifact |

## Archive Criteria Applied

1. **Unreferenced**: genre_content_analysis_module.R, all duplicate sales modules
2. **Superseded**: app_config_local_backup.R, ElephantSQL scripts
3. **Ad-hoc exploratory**: All test_*.R, debug_*.R, demo_*.R, diagnose_*.R files (38 files)
4. **Debug notes**: All *_SUMMARY.md files in shiny-app/
5. **Generated artifacts**: Zone.Identifier file
