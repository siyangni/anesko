# Unit Tests for Data Processing Functions

test_that("format_number handles various inputs", {
  source("../../shiny-app/global.R", local = TRUE)

  expect_equal(format_number(1500), "1.5K")
  expect_equal(format_number(1500000), "1.5M")
  expect_equal(format_number(500), "500")
  expect_equal(format_number(0), "0")
  expect_equal(format_number(NULL), "N/A")
  expect_equal(format_number(NA), "N/A")
  expect_equal(format_number(-100), "N/A")  # Negative should be N/A
})

test_that("format_number handles vectors", {
  source("../../shiny-app/global.R", local = TRUE)

  result <- format_number(c(1000, 2000, 3000))
  expect_equal(length(result), 3)
  expect_equal(result[1], "1K")
  expect_equal(result[2], "2K")
  expect_equal(result[3], "3K")
})

test_that("NULL coalescing operator works", {
  source("../../shiny-app/global.R", local = TRUE)

  expect_equal(NULL %||% "default", "default")
  expect_equal("value" %||% "default", "value")
  expect_equal(NA %||% "default", "default")
  expect_equal(character(0) %||% "default", "default")
  expect_equal(0 %||% "default", 0)  # 0 is not NULL
})
