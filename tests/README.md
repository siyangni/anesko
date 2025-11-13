# Testing Guide for American Authorship Database

This directory contains automated tests for the Shiny application.

## Test Structure

```
tests/
├── testthat.R              # Test runner entry point
├── testthat/
│   ├── setup-shinytest2.R  # UI testing configuration
│   ├── test-database.R     # Database connection tests
│   ├── test-input-validation.R  # Security/validation tests
│   ├── test-data-processing.R   # Data formatting tests
│   ├── test-error-handling.R    # Error handling tests
│   └── test-ui-dashboard.R      # UI/integration tests
└── README.md               # This file
```

## Running Tests

### Run All Tests

```r
# From project root
testthat::test_dir("tests")

# Or use devtools
devtools::test()
```

### Run Specific Test File

```r
testthat::test_file("tests/testthat/test-input-validation.R")
```

### Run with Coverage

```r
# Generate coverage report
covr::package_coverage()

# View coverage in browser
covr::report()
```

## Test Categories

### Unit Tests (Fast)

Tests for individual functions without external dependencies.

- `test-input-validation.R` - Input sanitization and validation
- `test-data-processing.R` - Data formatting and helpers
- `test-error-handling.R` - Error validation logic

**Run with**: `testthat::test_dir("tests", filter = "input|data|error")`

### Integration Tests (Medium)

Tests that require database connections.

- `test-database.R` - Database connectivity and queries

**Prerequisites**: PostgreSQL must be running with test database

**Run with**: `testthat::test_file("tests/testthat/test-database.R")`

### UI Tests (Slow)

End-to-end tests using shinytest2.

- `test-ui-dashboard.R` - Dashboard UI functionality

**Prerequisites**:
- `install.packages("shinytest2")`
- Chrome/Chromium browser installed

**Run with**: `testthat::test_file("tests/testthat/test-ui-dashboard.R")`

## Writing New Tests

### Unit Test Template

```r
test_that("function_name works correctly", {
  # Arrange
  input <- "test_data"

  # Act
  result <- my_function(input)

  # Assert
  expect_equal(result, expected_output)
})
```

### UI Test Template

```r
test_that("ui component works", {
  skip_if_not_installed("shinytest2")

  app <- shinytest2::AppDriver$new(
    app_dir = "../../shiny-app"
  )

  app$wait_for_idle()

  # Interact with app
  app$set_inputs(input_id = "value")

  # Check results
  expect_true(app$get_value("output_id") != "")
})
```

## Test Best Practices

### DO

- ✅ Write tests before fixing bugs (TDD)
- ✅ Test edge cases (NULL, NA, empty values)
- ✅ Use descriptive test names
- ✅ Keep tests fast and independent
- ✅ Mock external dependencies when possible

### DON'T

- ❌ Test framework code (only test your code)
- ❌ Write tests that depend on each other
- ❌ Use hardcoded passwords or secrets
- ❌ Skip cleanup in test teardown
- ❌ Commit screenshot files (unless for regression testing)

## Test Coverage Goals

| Component | Current | Target |
|-----------|---------|--------|
| Utils | 70% | 80% |
| Modules | 40% | 60% |
| Queries | 50% | 70% |
| **Overall** | **55%** | **70%** |

## Continuous Integration

Tests run automatically on:
- Every push to `main`, `develop`, or `claude/*` branches
- Every pull request

See `.github/workflows/ci-improved.yml` for CI configuration.

## Troubleshooting

### Tests Fail Locally But Pass in CI

- Check R version matches CI (`R --version`)
- Ensure all packages are up to date
- Check for local config files interfering

### UI Tests Fail with "Chrome not found"

```bash
# Install chromote
R -e "install.packages('chromote')"

# Or install Chrome manually
# Ubuntu/Debian:
sudo apt install chromium-browser

# macOS:
brew install chromium
```

### Database Tests Fail

```bash
# Ensure PostgreSQL is running
sudo service postgresql start

# Check connection
psql -U authorship_admin -d american_authorship -c "SELECT 1"

# If connection fails, check config files:
# - shiny-app/config/cloud_config.R
# - secrets/db_password.txt
```

### Tests Timeout

Increase timeout in test:

```r
app$wait_for_idle(duration = 10000)  # 10 seconds
```

Or globally:

```r
options(shinytest2.load_timeout = 20000)  # 20 seconds
```

## Resources

- [testthat documentation](https://testthat.r-lib.org/)
- [shinytest2 documentation](https://rstudio.github.io/shinytest2/)
- [R Testing Best Practices](https://r-pkgs.org/testing-basics.html)
