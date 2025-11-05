# Contributing to American Authorship Database

Thank you for your interest in contributing to the American Authorship Database project!

## Table of Contents
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Code Style](#code-style)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)

## Getting Started

### Prerequisites
- R 4.0+
- PostgreSQL 12+
- Git
- (Optional) Docker & Docker Compose

### Setup Development Environment

1. **Clone the repository**:
   ```bash
   git clone https://github.com/siyangni/anesko.git
   cd anesko
   ```

2. **Install R dependencies**:
   ```r
   install.packages("renv")
   renv::restore()
   ```

3. **Configure environment variables**:
   ```bash
   cp config/credentials.example.env .env
   # Edit .env with your database credentials
   ```

4. **Set up the database**:
   ```bash
   # Start PostgreSQL
   sudo service postgresql start

   # Run migration scripts
   Rscript scripts/migration/00_run_full_migration.R
   ```

5. **Run the app**:
   ```r
   export R_CONFIG_ACTIVE=development
   R -e 'shiny::runApp("app")'
   ```

### Alternative: Docker Setup

```bash
# Create .env file with credentials
cp config/credentials.example.env .env

# Start services
docker-compose up -d

# View logs
docker-compose logs -f shiny

# Access app at http://localhost:3838
```

## Development Workflow

### Branch Naming
- Feature branches: `feature/descriptive-name`
- Bug fixes: `fix/issue-description`
- Refactoring: `refactor/what-changed`
- Documentation: `docs/what-documented`

### Making Changes

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/my-new-feature
   ```

2. **Make your changes** following our code style guidelines

3. **Run linting**:
   ```r
   lintr::lint_dir("app")
   lintr::lint_dir("R")
   ```

4. **Test your changes**:
   ```r
   # Run tests if they exist
   testthat::test_dir("tests/testthat")

   # Manual testing
   shiny::runApp("app")
   ```

5. **Commit your changes**:
   ```bash
   git add .
   git commit -m "feat: Add descriptive commit message"
   ```

### Commit Message Guidelines

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style changes (formatting, no logic change)
- `refactor:` Code refactoring
- `test:` Adding or updating tests
- `chore:` Maintenance tasks

Examples:
```
feat: Add author network visualization module
fix: Correct royalty calculation in queries_royalties.R
docs: Update README with Docker instructions
refactor: Reorganize database connection pooling
```

## Code Style

### R Code Style

We follow the [tidyverse style guide](https://style.tidyverse.org/) with these specifics:

- **Line length**: Maximum 100 characters
- **Indentation**: 2 spaces (no tabs)
- **Assignment**: Use `<-` for assignment (not `=`)
- **Naming conventions**:
  - Functions: `snake_case()`
  - Variables: `snake_case`
  - Constants: `SCREAMING_SNAKE_CASE`
  - Shiny modules: `camelCaseServer()` and `camelCaseUI()`

- **Spacing**:
  ```r
  # Good
  result <- function_name(arg1, arg2)
  if (condition) {
    do_something()
  }

  # Bad
  result<-function_name( arg1,arg2 )
  if(condition){
    do_something()
  }
  ```

### File Organization

- **Shiny modules**: `app/modules/` - one module per file
- **Utility functions**: `R/` - grouped by functionality
- **Configuration**: `config/` - app settings and environment configs
- **Database queries**: `R/queries_*.R` - grouped by domain
- **Tests**: `tests/testthat/test-*.R` - one test file per module/utility

### Function Documentation

Document all exported functions with roxygen2 comments:

```r
#' Calculate book sales statistics
#'
#' Computes summary statistics for book sales within a date range
#'
#' @param book_id Integer book identifier
#' @param start_year Integer starting year (inclusive)
#' @param end_year Integer ending year (inclusive)
#' @return A data frame with columns: total_sales, avg_sales, sales_count
#' @export
calculate_sales_stats <- function(book_id, start_year, end_year) {
  # Function body
}
```

## Testing

### Writing Tests

Place test files in `tests/testthat/` with the naming pattern `test-*.R`:

```r
# tests/testthat/test-queries_sales.R
test_that("get_sales_by_year returns correct structure", {
  # Mock database connection
  result <- get_sales_by_year(1880, 1890)

  expect_s3_class(result, "data.frame")
  expect_true("year" %in% names(result))
  expect_true("total_sales" %in% names(result))
})
```

### Running Tests

```r
# Run all tests
testthat::test_dir("tests/testthat")

# Run specific test file
testthat::test_file("tests/testthat/test-queries_sales.R")

# Run with coverage
covr::package_coverage()
```

## Pull Request Process

### Before Submitting

- [ ] Code follows our style guidelines
- [ ] Linting passes: `lintr::lint_dir("app")` and `lintr::lint_dir("R")`
- [ ] All tests pass: `testthat::test_dir("tests/testthat")`
- [ ] Commit messages follow conventional commits format
- [ ] Documentation updated (if applicable)
- [ ] No credentials or secrets in code

### PR Template

When creating a PR, include:

1. **Description**: What does this PR do?
2. **Motivation**: Why is this change needed?
3. **Changes**: List of specific changes made
4. **Testing**: How was this tested?
5. **Screenshots**: (if applicable for UI changes)
6. **Breaking Changes**: Any breaking API changes?

### Review Process

1. Automated checks must pass (CI/CD)
2. At least one approving review required
3. No merge conflicts with base branch
4. All conversations resolved

## Questions?

- Check existing issues and discussions
- Contact the development team
- Review project documentation in `docs/`

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (see [License.md](License.md)).
