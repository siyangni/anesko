# Tests

This directory contains formal tests for the American Authorship Database application.

## Structure

- `testthat.R` - Test runner
- `testthat/` - Test files using the testthat framework

## Running Tests

```r
# Run all tests
testthat::test_dir("tests")

# Run a specific test file
testthat::test_file("tests/testthat/test-database.R")
```

## Test Coverage

Currently, this is a placeholder structure. As the application matures, tests should be added for:

- Database connectivity
- Query functions
- Data processing utilities
- Module functionality
- UI rendering (where applicable)

## Note on Ad-hoc Tests

Ad-hoc test files (test_*.R, debug_*.R) have been archived to `archive/test_files/`.
Only formal, structured tests should be added to this directory.
