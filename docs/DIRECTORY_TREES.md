# Before and After Directory Trees

This document shows the repository structure before and after the refactoring.

## Before Refactoring (Original Structure)

```
anesko/
├── .git/
├── .gitignore
├── Dockerfile
├── License.md
├── README.md
├── author_summary_stats_fixed.R          [ARCHIVED]
├── clean_author_function.R               [ARCHIVED]
├── data/
│   ├── anesko_database.db                [ARCHIVED - SQLite]
│   └── *.xlsx:Zone.Identifier            [REMOVED - Windows metadata]
├── docker-compose.yml
├── docs/
│   ├── data_dictionary.md
│   └── deployment/
│       └── README.md
├── deploy.sh                              [→ deployment/]
├── deploy_to_shinyapps.sh                 [→ deployment/]
├── migrate_to_elephantsql.sh             [ARCHIVED]
├── migrate_to_neon.sh                     [→ deployment/]
├── outputs/
│   └── reports/
│       └── unique_values_analysis.txt
├── scripts/
│   ├── analysis/
│   │   ├── 02_data_cleaning.R
│   │   ├── 03_exploratory_analysis.R
│   │   ├── check_note_like_entries.R
│   │   ├── clean_restore_database.R
│   │   ├── execute_reverse_changes.R
│   │   ├── restore_database.R
│   │   └── reverse_publisher_changes.R
│   ├── cleaning/
│   │   ├── comprehensive_royalty_analysis.R
│   │   └── pre_migration_cleaning.R
│   ├── deployment/
│   │   └── connect_neondb.sh              [→ deployment/]
│   ├── migration/                         [→ db/migrations/]
│   │   ├── 00_package_setup.R
│   │   ├── 00_run_full_migration.R
│   │   ├── 01_database_setup.R
│   │   ├── 02_create_schema.R
│   │   ├── 03_import_data.R
│   │   ├── README.md
│   │   ├── check_tables.R
│   │   ├── fix_view.R
│   │   ├── reset_database.R
│   │   └── test_migration_files.R        [ARCHIVED]
│   ├── test_genre_cleaning_fix.R         [ARCHIVED]
│   └── validation/
│       └── 04_data_validation.R
├── setup_elephantsql.sh                   [ARCHIVED]
├── setup_neon.sh                          [→ deployment/]
├── shiny-app/
│   ├── app.R
│   ├── check_excel_sheets.R              [ARCHIVED]
│   ├── config/
│   │   ├── app_config.R
│   │   ├── app_config_local_backup.R     [ARCHIVED]
│   │   ├── cloud_config.R                [ARCHIVED - had credentials]
│   │   ├── cloud_config.template.R       [NEW - secure template]
│   │   └── .env.template                 [NEW]
│   ├── debug_*.R (4 files)               [ARCHIVED - all]
│   ├── demo_sales_analysis_dropdowns.R   [ARCHIVED]
│   ├── deploy_script.R                   [ARCHIVED]
│   ├── diagnose_genre_inconsistency.R    [ARCHIVED]
│   ├── fix_sliding_scale_migration.R     [ARCHIVED]
│   ├── global.R
│   ├── modules/
│   │   ├── author_analysis_module.R
│   │   ├── author_networks_module.R
│   │   ├── book_explorer_module.R
│   │   ├── dashboard_module.R
│   │   ├── genre_analysis_module.R
│   │   ├── genre_content_analysis_module.R
│   │   ├── royalty_analysis_module.R
│   │   ├── royalty_query_module.R
│   │   ├── sales_analysis_module.R       [Kept for reference]
│   │   ├── sales_analysis_consolidated_module.R  [ARCHIVED]
│   │   ├── sales_analysis_module_clean.R          [ARCHIVED]
│   │   ├── sales_analysis_module_new.R            [ARCHIVED]
│   │   ├── sales_analysis_module_working.R        [ARCHIVED]
│   │   └── sales_trends_module.R
│   ├── server.R
│   ├── test_*.R (26 files)               [ARCHIVED - all]
│   ├── ui.R
│   ├── utils/
│   │   ├── database.R
│   │   ├── data_processing.R
│   │   ├── error_handling.R
│   │   ├── plotting.R
│   │   ├── queries_basic.R
│   │   ├── queries_royalties.R
│   │   ├── queries_royalty.R
│   │   ├── queries_sales.R
│   │   └── queries_timeseries.R
│   ├── verify_dropdown_changes.R         [ARCHIVED]
│   └── www/
│       └── style.css
├── test_app_with_elephantsql.sh          [ARCHIVED]
├── test_app_with_neon.sh                 [→ deployment/]
├── test_neon_connection.R                [ARCHIVED]
├── test_royalty_fix.R                    [ARCHIVED]
├── test_shiny_components.R               [ARCHIVED]
└── verify_neon_migration.R               [ARCHIVED]

Total R files: 95
Total test/debug files: ~44 (to be archived)
Total obsolete files: 54
```

## After Refactoring (New Structure)

```
anesko/
├── .git/
├── .github/                               [NEW]
│   └── workflows/
│       └── ci.yml                        [NEW - GitHub Actions CI]
├── .gitignore                            [UPDATED - enhanced security]
├── DESCRIPTION                            [NEW - package metadata]
├── Dockerfile
├── License.md
├── README.md                              [UPDATED]
├── archive/                               [NEW - 54 archived files]
│   ├── README.md                         [NEW - archive index]
│   ├── obsolete_configs/
│   │   ├── app_config_local_backup.R
│   │   └── cloud_config.R                [Had hardcoded credentials]
│   ├── obsolete_databases/
│   │   └── anesko_database.db            [Empty SQLite DB]
│   ├── obsolete_modules/
│   │   ├── sales_analysis_consolidated_module.R
│   │   ├── sales_analysis_module_clean.R
│   │   ├── sales_analysis_module_new.R
│   │   └── sales_analysis_module_working.R
│   ├── obsolete_scripts/
│   │   ├── migrate_to_elephantsql.sh
│   │   ├── setup_elephantsql.sh
│   │   └── test_app_with_elephantsql.sh
│   └── test_files/
│       ├── author_summary_stats_fixed.R
│       ├── check_excel_sheets.R
│       ├── clean_author_function.R
│       ├── debug_dashboard_fix.R
│       ├── debug_dashboard_reactive.R
│       ├── debug_filters.R
│       ├── debug_reactive_issue.R
│       ├── demo_sales_analysis_dropdowns.R
│       ├── deploy_script.R
│       ├── diagnose_genre_inconsistency.R
│       ├── fix_sliding_scale_migration.R
│       ├── test_*.R (26 files)
│       ├── test_genre_cleaning_fix.R
│       ├── test_neon_connection.R
│       ├── test_royalty_fix.R
│       ├── test_shiny_components.R
│       ├── verify_dropdown_changes.R
│       └── verify_neon_migration.R
├── data/
├── db/                                    [NEW]
│   └── migrations/                       [MOVED from scripts/migration/]
│       ├── 00_package_setup.R
│       ├── 00_run_full_migration.R
│       ├── 01_database_setup.R
│       ├── 02_create_schema.R
│       ├── 03_import_data.R
│       ├── README.md
│       ├── check_tables.R
│       ├── fix_view.R
│       └── reset_database.R
├── deployment/                            [NEW - consolidated]
│   ├── connect_neondb.sh
│   ├── deploy.sh
│   ├── deploy_to_shinyapps.sh
│   ├── migrate_to_neon.sh
│   ├── setup_neon.sh
│   └── test_app_with_neon.sh
├── docker-compose.yml
├── docs/
│   ├── CONTRIBUTING.md                    [NEW - 320 lines]
│   ├── INVENTORY.md                       [NEW - this refactor]
│   ├── REFACTOR_CHANGELOG.md              [NEW - this refactor]
│   ├── DIRECTORY_TREES.md                 [NEW - this file]
│   ├── data_dictionary.md
│   ├── deployment/
│   │   └── README.md
│   └── RUNBOOK.md                         [NEW - 433 lines]
├── outputs/
│   └── reports/
│       └── unique_values_analysis.txt
├── scripts/
│   ├── analysis/
│   │   ├── 02_data_cleaning.R
│   │   ├── 03_exploratory_analysis.R
│   │   ├── check_note_like_entries.R
│   │   ├── clean_restore_database.R
│   │   ├── execute_reverse_changes.R
│   │   ├── restore_database.R
│   │   └── reverse_publisher_changes.R
│   ├── cleaning/
│   │   ├── comprehensive_royalty_analysis.R
│   │   └── pre_migration_cleaning.R
│   └── validation/
│       └── 04_data_validation.R
├── shiny-app/                             [CLEANED]
│   ├── app.R
│   ├── config/
│   │   ├── .env.template                 [NEW - secure template]
│   │   ├── app_config.R
│   │   ├── cloud_config.R                [Regenerated from template]
│   │   └── cloud_config.template.R       [NEW - secure template]
│   ├── global.R
│   ├── modules/                          [CLEANED - 9 active modules]
│   │   ├── author_analysis_module.R
│   │   ├── author_networks_module.R
│   │   ├── book_explorer_module.R
│   │   ├── dashboard_module.R
│   │   ├── genre_analysis_module.R
│   │   ├── genre_content_analysis_module.R
│   │   ├── royalty_analysis_module.R
│   │   ├── royalty_query_module.R
│   │   ├── sales_analysis_module.R       [Kept for reference]
│   │   └── sales_trends_module.R
│   ├── server.R
│   ├── ui.R
│   ├── utils/                            [8 utility files]
│   │   ├── database.R
│   │   ├── data_processing.R
│   │   ├── error_handling.R
│   │   ├── plotting.R
│   │   ├── queries_basic.R
│   │   ├── queries_royalties.R
│   │   ├── queries_sales.R
│   │   └── queries_timeseries.R
│   └── www/
│       └── style.css
└── tests/                                 [NEW - formal testing]
    ├── README.md                         [NEW]
    ├── testthat.R                        [NEW]
    └── testthat/
        └── test-database.R               [NEW - placeholder]

Total active R files: ~50 (after archiving 44 test files)
New infrastructure files: 10+
Lines of documentation added: ~1500
```

## Key Differences Summary

### Additions

| Item | Count/Description |
|------|-------------------|
| New directories | 7 (.github/workflows/, db/, deployment/, tests/, archive/ + 4 subdirs) |
| New documentation | 5 major docs (CONTRIBUTING, RUNBOOK, INVENTORY, CHANGELOG, DIRECTORY_TREES) |
| Configuration templates | 2 (.env.template, cloud_config.template.R) |
| CI/CD | 1 GitHub Actions workflow |
| Test structure | Formal testthat framework |
| Package metadata | DESCRIPTION file |

### Removals/Archives

| Item | Count |
|------|-------|
| Test/debug files | 44 (archived) |
| Obsolete modules | 4 (archived) |
| Obsolete scripts | 3 (archived) |
| Config backups | 2 (archived) |
| Database files | 1 (archived) |
| **Total archived** | **54 files** |

### Reorganizations

| From | To | Count |
|------|-----|-------|
| scripts/migration/ | db/migrations/ | 10 files |
| Root/*.sh + scripts/deployment/ | deployment/ | 6 files |
| Various test_*.R | archive/test_files/ | 44 files |

### Security

- ❌ Removed hardcoded credentials from cloud_config.R
- ✅ Added secure configuration templates
- ✅ Enhanced .gitignore to prevent credential commits
- ✅ Archived insecure config file with history preserved

---

*Directory trees generated for repository refactoring PR*
