# Unit Tests for Error Handling Functions

list2env(
  list(
    MIN_YEAR = 1860L,
    MAX_YEAR = 1920L,
    DEFAULT_YEAR_RANGE = c(1880L, 1910L),
    FORMAT_MILLION_THRESHOLD = 1000000,
    FORMAT_THOUSAND_THRESHOLD = 1000
  ),
  envir = environment()
)
source("../../shiny-app/utils/data_processing.R", local = TRUE)
source("../../shiny-app/utils/error_handling.R", local = TRUE)

test_that("validate_analysis_params detects invalid date ranges", {

  result <- validate_analysis_params(
    genre_filter = NULL,
    binding_filter = NULL,
    gender_filter = NULL,
    start_year = 1900,
    end_year = 1880,  # Invalid: end < start
    analysis_type = "distribution"
  )

  expect_false(result$valid)
  expect_true(length(result$issues) > 0)
})

test_that("validate_analysis_params accepts valid parameters", {
  result <- validate_analysis_params(
    genre_filter = "Fiction",
    binding_filter = "Cloth",
    gender_filter = "Male",
    start_year = 1880,
    end_year = 1920,
    analysis_type = "distribution"
  )

  expect_true(result$valid)
})

test_that("validate_analysis_params warns about narrow date ranges", {
  result <- validate_analysis_params(
    genre_filter = NULL,
    binding_filter = NULL,
    gender_filter = NULL,
    start_year = 1900,
    end_year = 1903,  # Only 3 years
    analysis_type = "distribution"
  )

  expect_true(length(result$suggestions) > 0)
})

test_that("create_context_string builds correct context", {
  context <- create_context_string(
    genre_filter = "Fiction",
    binding_filter = "Cloth",
    gender_filter = "Male",
    start_year = 1880,
    end_year = 1920
  )

  expect_true(grepl("Fiction", context))
  expect_true(grepl("Cloth", context))
  expect_true(grepl("Male", context))
  expect_true(grepl("1880", context))
  expect_true(grepl("1920", context))
  expect_true(grepl("sales years", context))
})
