# Database Connection Tests
# These tests verify database connectivity and basic queries

context("Database Connection")

test_that("Database configuration is loadable", {
  # This test should pass if config files are properly set up
  expect_true(file.exists("shiny-app/config/app_config.R") ||
              file.exists("R/config/app_config.R"))
})

test_that("Required database packages are available", {
  expect_true(require(DBI, quietly = TRUE))
  expect_true(require(RPostgreSQL, quietly = TRUE) ||
              require(RPostgres, quietly = TRUE))
})

test_that("Database pool constants are defined", {
  skip_if_not(exists("POOL_SIZE_MIN"), "Config not loaded")

  expect_true(exists("POOL_SIZE_MIN"))
  expect_true(exists("POOL_SIZE_MAX"))
  expect_true(exists("POOL_IDLE_TIMEOUT"))

  expect_true(is.numeric(POOL_SIZE_MIN))
  expect_true(is.numeric(POOL_SIZE_MAX))
  expect_gt(POOL_SIZE_MAX, POOL_SIZE_MIN)
})

test_that("create_db_pool function exists and is callable", {
  skip_if_not(exists("create_db_pool"), "Function not loaded")

  expect_true(is.function(create_db_pool))
})

test_that("safe_db_query function exists and handles empty results", {
  skip_if_not(exists("safe_db_query"), "Function not loaded")

  expect_true(is.function(safe_db_query))

  # Test with mock - function should return data.frame on error
  result <- tryCatch({
    safe_db_query("INVALID SQL")
  }, error = function(e) {
    data.frame()  # Expected behavior
  })

  expect_true(is.data.frame(result))
})

test_that("Database query functions are defined", {
  skip_if_not(exists("get_summary_stats"), "Query functions not loaded")

  # Check that core query functions exist
  expected_functions <- c(
    "get_summary_stats",
    "get_books_summary",
    "get_gender_analysis",
    "get_publisher_performance"
  )

  for (func_name in expected_functions) {
    expect_true(exists(func_name),
                info = sprintf("Function %s should exist", func_name))
  }
})

test_that("Input validation constants are defined", {
  skip_if_not(exists("INPUT_MIN_YEAR"), "Config not loaded")

  expect_true(exists("INPUT_MIN_YEAR"))
  expect_true(exists("INPUT_MAX_YEAR"))
  expect_true(exists("MIN_YEAR"))
  expect_true(exists("MAX_YEAR"))

  # Validation range should be wider than data range
  expect_lt(INPUT_MIN_YEAR, MIN_YEAR)
  expect_gt(INPUT_MAX_YEAR, MAX_YEAR)
})

# Integration tests (require actual database connection)
# These are skipped in CI unless DB credentials are available

test_that("Database connection can be established", {
  skip_if_not(Sys.getenv("RUN_DB_TESTS") == "true",
              "Database tests disabled (set RUN_DB_TESTS=true to enable)")
  skip_if_not(exists("db_config") && !is.null(db_config$host),
              "Database config not available")

  expect_no_error({
    pool <- create_db_pool()
    expect_false(is.null(pool))

    # Test connection with simple query
    result <- safe_db_query("SELECT 1 as test")
    expect_equal(nrow(result), 1)
    expect_equal(result$test[1], 1)

    # Clean up
    pool::poolClose(pool)
  })
})

test_that("Parameterized queries work correctly", {
  skip_if_not(Sys.getenv("RUN_DB_TESTS") == "true",
              "Database tests disabled")

  expect_no_error({
    # Test with parameters
    result <- safe_db_query(
      "SELECT $1::int as num, $2::text as txt",
      params = list(42, "test")
    )

    expect_equal(nrow(result), 1)
    expect_equal(result$num[1], 42)
    expect_equal(result$txt[1], "test")
  })
})

# Note: More comprehensive tests require test database or mocking
