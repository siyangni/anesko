# Unit Tests for Error Handling Functions

test_that("validate_analysis_params detects invalid date ranges", {
  source("../../shiny-app/utils/error_handling.R", local = TRUE)

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
  source("../../shiny-app/utils/error_handling.R", local = TRUE)

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
  source("../../shiny-app/utils/error_handling.R", local = TRUE)

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
  source("../../shiny-app/utils/error_handling.R", local = TRUE)

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
})
