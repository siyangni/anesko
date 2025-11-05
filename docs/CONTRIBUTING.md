# Contributing to the American Authorship Database

Thank you for your interest in contributing to this project! This document provides guidelines for contributing to the American Authorship Database (1860-1920) codebase.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Code Standards](#code-standards)
- [Testing](#testing)
- [Documentation](#documentation)
- [Submitting Changes](#submitting-changes)

## Getting Started

### Prerequisites

- R 4.0 or higher
- PostgreSQL 12 or higher
- Git
- RStudio (recommended)

### Setting Up Development Environment

1. **Clone the repository**:
   ```bash
   git clone https://github.com/siyangni/anesko.git
   cd anesko
   ```

2. **Install R dependencies**:
   ```r
   # Install from DESCRIPTION file
   install.packages("remotes")
   remotes::install_deps(dependencies = TRUE)
   ```

3. **Configure database connection**:
   ```bash
   # Copy environment template
   cp shiny-app/config/.env.template shiny-app/config/.env

   # OR for R/ directory (after reorganization)
   cp R/config/.env.template R/config/.env

   # Edit .env with your database credentials
   ```

4. **Run database migrations** (if needed):
   ```r
   source("db/migrations/00_run_full_migration.R")
   ```

5. **Test the application**:
   ```r
   shiny::runApp("shiny-app/")
   # OR after reorganization:
   shiny::runApp("R/")
   ```

## Development Workflow

### Branching Strategy

- `main` - Production-ready code
- `develop` - Integration branch for features
- `feature/feature-name` - Feature branches
- `bugfix/bug-name` - Bug fix branches
- `refactor/refactor-name` - Refactoring branches

### Creating a Feature Branch

```bash
git checkout -b feature/your-feature-name
```

### Making Changes

1. Make your changes in small, logical commits
2. Write clear, descriptive commit messages
3. Test your changes thoroughly
4. Update documentation as needed

### Commit Message Guidelines

Follow the conventional commits format:

```
type(scope): brief description

Longer description if needed

Fixes #issue-number
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring
- `docs`: Documentation changes
- `test`: Adding or updating tests
- `style`: Code style changes (formatting, etc.)
- `chore`: Maintenance tasks

**Examples**:
```
feat(modules): add author collaboration network visualization

fix(database): correct royalty calculation query

docs(README): update installation instructions
```

## Code Standards

### R Code Style

Follow the [Tidyverse Style Guide](https://style.tidyverse.org/):

- Use snake_case for variables and functions
- Use 2 spaces for indentation (no tabs)
- Limit lines to 80 characters
- Add comments for complex logic
- Use meaningful variable names

**Example**:
```r
# Good
calculate_total_sales <- function(book_id, start_year, end_year) {
  sales_data <- get_sales_by_year(book_id, start_year, end_year)
  total <- sum(sales_data$sales, na.rm = TRUE)
  return(total)
}

# Bad
calc <- function(x,y,z) {
    d<-get(x,y,z)
    return(sum(d$s))
}
```

### Shiny Module Structure

Follow this structure for Shiny modules:

```r
# Module UI
moduleNameUI <- function(id) {
  ns <- NS(id)

  tagList(
    # UI elements
  )
}

# Module Server
moduleNameServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    # Server logic
  })
}
```

### Database Queries

- Use parameterized queries to prevent SQL injection
- Document complex queries with comments
- Use prepared statements with DBI/pool
- Keep queries in `utils/queries_*.R` files

**Example**:
```r
get_book_by_id <- function(pool, book_id) {
  query <- "SELECT * FROM books WHERE book_id = $1"
  pool::dbGetQuery(pool, query, params = list(book_id))
}
```

## Testing

### Writing Tests

Tests use the `testthat` framework:

```r
# tests/testthat/test-example.R
test_that("function calculates correctly", {
  result <- your_function(input)
  expect_equal(result, expected_output)
})
```

### Running Tests

```r
# Run all tests
testthat::test_dir("tests")

# Run specific test file
testthat::test_file("tests/testthat/test-database.R")
```

### Test Coverage

Aim for:
- Unit tests for all utility functions
- Integration tests for database queries
- Module tests for Shiny components (where feasible)

**Note**: Ad-hoc test files (test_*.R, debug_*.R) should NOT be committed. Use the formal `tests/` directory.

## Documentation

### Code Documentation

- Add roxygen2 comments to functions
- Document parameters, return values, and examples
- Keep documentation up-to-date with code changes

**Example**:
```r
#' Calculate Total Sales
#'
#' Calculates the total sales for a book over a given time period.
#'
#' @param book_id Integer. The unique identifier for the book.
#' @param start_year Integer. The starting year (inclusive).
#' @param end_year Integer. The ending year (inclusive).
#'
#' @return Numeric. The total sales amount.
#'
#' @examples
#' total <- calculate_total_sales(123, 1880, 1900)
#'
#' @export
calculate_total_sales <- function(book_id, start_year, end_year) {
  # Function body
}
```

### Updating Documentation

When making changes that affect:
- Installation steps → Update README.md
- Configuration → Update RUNBOOK.md
- API/functions → Update roxygen comments
- Data structure → Update docs/data_dictionary.md

## Submitting Changes

### Before Submitting

1. **Run tests**:
   ```r
   testthat::test_dir("tests")
   ```

2. **Check code style** (optional but recommended):
   ```r
   lintr::lint_package()
   ```

3. **Update documentation**

4. **Commit your changes**:
   ```bash
   git add .
   git commit -m "feat: your clear commit message"
   ```

### Creating a Pull Request

1. **Push your branch**:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create PR on GitHub**:
   - Go to the repository on GitHub
   - Click "New Pull Request"
   - Select your branch
   - Fill in the PR template:
     - Description of changes
     - Related issue(s)
     - Testing performed
     - Screenshots (if UI changes)

3. **PR Review Process**:
   - Address reviewer feedback
   - Make requested changes
   - Keep PR scope focused (one feature/fix per PR)

### PR Checklist

- [ ] Code follows project style guidelines
- [ ] Tests added/updated and passing
- [ ] Documentation updated
- [ ] Commit messages are clear
- [ ] No merge conflicts with target branch
- [ ] Reviewed own changes for quality

## Questions or Issues?

- For bugs or feature requests: [Open an issue](https://github.com/siyangni/anesko/issues)
- For questions: Contact Dr. Michael Anesko at mwa2@psu.edu

## Code of Conduct

- Be respectful and professional
- Focus on constructive feedback
- Credit others' contributions
- Follow academic integrity standards

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to the American Authorship Database project!
