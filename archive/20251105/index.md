# Archived Items - 2025-11-05

Files archived during repository refactoring. All files moved here are preserved in git history.

## Reason Codes
- **UNREFERENCED**: Not sourced or imported by any active code
- **SUPERSEDED**: Replaced by newer version or better implementation
- **AD_HOC**: Ad-hoc exploratory, test, or debug script
- **DUPLICATE**: Duplicate or backup of another file
- **DEBUG_NOTES**: Debug notes or investigation summaries
- **GENERATED**: Generated artifact that should not be tracked
- **OBSOLETE**: Obsolete functionality no longer needed

## Archived Files

### Test/Debug Scripts from shiny-app/ (34 files)

| File | Reason | Notes |
|------|--------|-------|
| check_excel_sheets.R | AD_HOC | Ad-hoc data exploration script |
| debug_dashboard_fix.R | AD_HOC | Debug script for dashboard issues |
| debug_dashboard_reactive.R | AD_HOC | Debug script for reactive issues |
| debug_filters.R | AD_HOC | Debug script for filter functionality |
| debug_reactive_issue.R | AD_HOC | Debug script for reactive issues |
| demo_sales_analysis_dropdowns.R | AD_HOC | Demo/prototype script for dropdowns |
| diagnose_genre_inconsistency.R | AD_HOC | Diagnostic script for genre data |
| fix_sliding_scale_migration.R | AD_HOC | One-time fix script for migration |
| test_app.R | AD_HOC | Test harness for app |
| test_app_connection.R | AD_HOC | Test script for database connection |
| test_author_network_app.R | AD_HOC | Test script for author network |
| test_author_network_fixes.R | AD_HOC | Test script for network fixes |
| test_complete_author_network.R | AD_HOC | Test script for network completion |
| test_compute_distribution.R | AD_HOC | Test script for distribution calc |
| test_dashboard_genre_complete.R | AD_HOC | Test script for dashboard genre |
| test_dropdown_ui.R | AD_HOC | Test script for dropdown UI |
| test_dropdowns.R | AD_HOC | Test script for dropdowns |
| test_error_handling.R | AD_HOC | Test script for error handling |
| test_fixed_dashboard.R | AD_HOC | Test script for dashboard fix |
| test_fixed_query.R | AD_HOC | Test script for query fix |
| test_fixes.R | AD_HOC | General test script for fixes |
| test_genre_consistency_fix.R | AD_HOC | Test script for genre consistency |
| test_genre_data.R | AD_HOC | Test script for genre data |
| test_genre_fix.R | AD_HOC | Test script for genre fix |
| test_minimal_syntax.R | AD_HOC | Test script for syntax checking |
| test_original_sliding_scale.R | AD_HOC | Test script for sliding scale |
| test_royalty_analysis_fixes.R | AD_HOC | Test script for royalty fixes |
| test_sales_analysis_dropdowns.R | AD_HOC | Test script for sales dropdowns |
| test_sliding_scale_data.R | AD_HOC | Test script for sliding scale data |
| test_sliding_scale_filter.R | AD_HOC | Test script for sliding scale filter |
| test_sliding_scale_migration.R | AD_HOC | Test script for sliding scale migration |
| test_syntax_fix.R | AD_HOC | Test script for syntax fix |
| test_value_box_colors.R | AD_HOC | Test script for value box colors |
| test_value_box_fix.R | AD_HOC | Test script for value box fix |
| test_year_range_fix.R | AD_HOC | Test script for year range fix |
| verify_dropdown_changes.R | AD_HOC | Verification script for dropdowns |

### Duplicate/Superseded Modules from shiny-app/modules/ (5 files)

| File | Reason | Notes |
|------|--------|-------|
| genre_content_analysis_module.R | UNREFERENCED | Not sourced in global.R or referenced anywhere |
| sales_analysis_consolidated_module.R | SUPERSEDED | Superseded by sales_trends_module.R |
| sales_analysis_module_clean.R | SUPERSEDED | Development version, superseded by sales_analysis_module.R |
| sales_analysis_module_new.R | SUPERSEDED | Development version, superseded by sales_analysis_module.R |
| sales_analysis_module_working.R | SUPERSEDED | Development version, superseded by sales_analysis_module.R |

### Configuration Backups from shiny-app/config/ (1 file)

| File | Reason | Notes |
|------|--------|-------|
| app_config_local_backup.R | DUPLICATE | Backup copy of app_config.R |

### Deployment Scripts from shiny-app/ (2 files)

| File | Reason | Notes |
|------|--------|-------|
| deploy_script.R | DUPLICATE | Duplicate of deploy_shinyapps.R |
| deploy_shinyapps.R | DUPLICATE | Superseded by scripts/deployment/deploy_shiny.R |

### Debug Notes from shiny-app/ (6 files)

| File | Reason | Notes |
|------|--------|-------|
| AUTHOR_NETWORK_FIXES_SUMMARY.md | DEBUG_NOTES | Debug/investigation notes |
| DEPLOYMENT_INFO.txt | DEBUG_NOTES | Old deployment notes |
| GENRE_ANALYSIS_ERROR_HANDLING_IMPROVEMENTS.md | DEBUG_NOTES | Debug/investigation notes |
| ROYALTY_ANALYSIS_FIXES_SUMMARY.md | DEBUG_NOTES | Debug/investigation notes |
| SLIDING_SCALE_INVESTIGATION_SUMMARY.md | DEBUG_NOTES | Debug/investigation notes |
| database_setup_guide.md | DEBUG_NOTES | Superseded by main documentation |

### Shiny App Documentation from shiny-app/ (2 files)

| File | Reason | Notes |
|------|--------|-------|
| QUICK_START.md | DEBUG_NOTES | Superseded by main README |
| README.md | DEBUG_NOTES | Will consolidate into main README |

### Test Scripts from Root Directory (6 files)

| File | Reason | Notes |
|------|--------|-------|
| test_app_with_elephantsql.sh | AD_HOC | Test script for ElephantSQL |
| test_app_with_neon.sh | AD_HOC | Test script for Neon |
| test_neon_connection.R | AD_HOC | Test script for Neon connection |
| test_royalty_fix.R | AD_HOC | Test script for royalty fix |
| test_shiny_components.R | AD_HOC | Test script for Shiny components |
| verify_neon_migration.R | AD_HOC | Verification script for migration |

### Ad-hoc Scripts from Root Directory (2 files)

| File | Reason | Notes |
|------|--------|-------|
| author_summary_stats_fixed.R | AD_HOC | Ad-hoc analysis script |
| clean_author_function.R | AD_HOC | Ad-hoc utility function |

### Superseded Deployment Scripts from Root (4 files)

| File | Reason | Notes |
|------|--------|-------|
| deploy.sh | OBSOLETE | Unclear purpose, likely superseded |
| migrate_to_elephantsql.sh | OBSOLETE | ElephantSQL superseded by Neon |
| setup_elephantsql.sh | OBSOLETE | ElephantSQL superseded by Neon |
| test_app_with_elephantsql.sh | AD_HOC | Test script for obsolete platform |

### Migration One-time Fixes from scripts/migration/ (1 file)

| File | Reason | Notes |
|------|--------|-------|
| fix_view.R | AD_HOC | One-time fix for database view |

### Test Scripts from scripts/ (1 file)

| File | Reason | Notes |
|------|--------|-------|
| test_genre_cleaning_fix.R | AD_HOC | Test script for genre cleaning |

### Generated Artifacts from data/ (1 file)

| File | Reason | Notes |
|------|--------|-------|
| AneskoDB 10-21-23_COPY_with additions June 2024.xlsx:Zone.Identifier | GENERATED | Windows Zone.Identifier file |

## Total Archived Files: 66

## Recovery Instructions

To recover any archived file:
```bash
git log --all --full-history archive/20251105/[filename]
git checkout [commit-hash] -- [original-path]
```

Or simply:
```bash
cp archive/20251105/[filename] [destination]
```
