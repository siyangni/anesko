# Unit Tests for Input Validation
# Tests for security and data validation functions

test_that("validate_group_by accepts valid values", {
  source("../../shiny-app/utils/input_validation.R", local = TRUE)

  expect_equal(validate_group_by("gender"), "be.gender")
  expect_equal(validate_group_by("author"), "be.author_surname")
  expect_equal(validate_group_by("publisher"), "be.publisher")
  expect_equal(validate_group_by("book"), "be.book_title")
  expect_equal(validate_group_by("genre"), "be.genre")
  expect_equal(validate_group_by("binding"), "be.binding")
})

test_that("validate_group_by rejects invalid values", {
  source("../../shiny-app/utils/input_validation.R", local = TRUE)

  expect_error(validate_group_by("invalid_field"))
  expect_error(validate_group_by("'; DROP TABLE users; --"))
  expect_error(validate_group_by(NULL))
  expect_error(validate_group_by(123))
})

test_that("validate_year accepts valid years", {
  source("../../shiny-app/utils/input_validation.R", local = TRUE)

  expect_equal(validate_year(1900), 1900L)
  expect_equal(validate_year(2020), 2020L)
  expect_equal(validate_year(1860), 1860L)
})

test_that("validate_year rejects invalid years", {
  source("../../shiny-app/utils/input_validation.R", local = TRUE)

  expect_error(validate_year(1700))  # Too old
  expect_error(validate_year(2200))  # Too future
  expect_error(validate_year("not_a_year"))
  expect_error(validate_year(NULL))
})

test_that("validate_year_range works correctly", {
  source("../../shiny-app/utils/input_validation.R", local = TRUE)

  result <- validate_year_range(1900, 1910)
  expect_equal(result$start_year, 1900L)
  expect_equal(result$end_year, 1910L)

  expect_error(validate_year_range(1910, 1900))  # Reversed
  expect_error(validate_year_range(1900, 1900))  # Same year
})

test_that("sanitize_string_input removes dangerous characters", {
  source("../../shiny-app/utils/input_validation.R", local = TRUE)

  expect_equal(sanitize_string_input("normal text"), "normal text")
  expect_equal(sanitize_string_input("text\0with\0nulls"), "textwith nulls")
  expect_equal(sanitize_string_input("  spaced  "), "spaced")
  expect_equal(sanitize_string_input(c("a", "b", "c")), c("a", "b", "c"))
})

test_that("sanitize_string_input handles edge cases", {
  source("../../shiny-app/utils/input_validation.R", local = TRUE)

  expect_equal(length(sanitize_string_input(NULL)), 0)
  expect_equal(length(sanitize_string_input("")), 0)
  expect_equal(length(sanitize_string_input("   ")), 0)
})

test_that("validate_dimension accepts valid dimensions", {
  source("../../shiny-app/utils/input_validation.R", local = TRUE)

  expect_equal(validate_dimension("book"), "book")
  expect_equal(validate_dimension("author"), "author")
  expect_equal(validate_dimension("publisher"), "publisher")
  expect_equal(validate_dimension("genre"), "genre")
  expect_equal(validate_dimension("binding"), "binding")
  expect_equal(validate_dimension("gender"), "gender")
})

test_that("validate_dimension rejects invalid dimensions", {
  source("../../shiny-app/utils/input_validation.R", local = TRUE)

  expect_error(validate_dimension("invalid"))
  expect_error(validate_dimension(NULL))
  expect_error(validate_dimension(c("book", "author")))  # Multiple values
})

test_that("validate_limit works correctly", {
  source("../../shiny-app/utils/input_validation.R", local = TRUE)

  expect_equal(validate_limit(50), 50L)
  expect_equal(validate_limit(NULL), 100L)  # Default
  expect_equal(validate_limit(20000), 10000L)  # Capped at max
  expect_error(validate_limit(-1))
  expect_error(validate_limit("not_a_number"))
})
