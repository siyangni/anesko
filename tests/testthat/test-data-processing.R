# Unit Tests for Data Processing Functions

list2env(
  list(
    FORMAT_MILLION_THRESHOLD = 1000000,
    FORMAT_THOUSAND_THRESHOLD = 1000
  ),
  envir = environment()
)
source("../../shiny-app/utils/data_processing.R", local = TRUE)

test_that("format_number handles various inputs", {
  expect_equal(format_number(1500), "1.5K")
  expect_equal(format_number(1500000), "1.5M")
  expect_equal(format_number(500), "500")
  expect_equal(format_number(0), "0")
  expect_equal(format_number(NULL), "N/A")
  expect_equal(format_number(NA), "N/A")
  expect_equal(format_number(-100), "N/A")  # Negative should be N/A
})

test_that("format_number handles vectors", {
  result <- format_number(c(1000, 2000, 3000))
  expect_equal(length(result), 3)
  expect_equal(result[1], "1K")
  expect_equal(result[2], "2K")
  expect_equal(result[3], "3K")
})

test_that("NULL coalescing operator works", {
  expect_equal(NULL %||% "default", "default")
  expect_equal("value" %||% "default", "value")
  expect_equal(NA %||% "default", "default")
  expect_equal(character(0) %||% "default", "default")
  expect_equal(0 %||% "default", 0)  # 0 is not NULL
})

test_that("format_title_catalog_style repositions leading articles", {
  expect_equal(format_title_catalog_style("A Boy's Town"), "Boy's Town, A")
  expect_equal(
    format_title_catalog_style("The Wings of the Dove"),
    "Wings of the Dove, The"
  )
  expect_equal(format_title_catalog_style("An Old Story"), "Old Story, An")
  expect_equal(format_title_catalog_style("Boy's Town"), "Boy's Town")
})

test_that("format_title_catalog_style avoids false positives and handles edge cases", {
  # Must not treat Ann / Their / Theatricals as articles
  expect_equal(format_title_catalog_style("Ann Boyd"), "Ann Boyd")
  expect_equal(format_title_catalog_style("Theatricals"), "Theatricals")
  expect_equal(
    format_title_catalog_style("Their Wedding Journey"),
    "Their Wedding Journey"
  )

  # Empty / NA / NULL
  expect_equal(format_title_catalog_style(""), "")
  expect_true(is.na(format_title_catalog_style(NA_character_)))
  expect_equal(format_title_catalog_style(NULL), character(0))

  # Lowercase article is normalized; body casing preserved
  expect_equal(format_title_catalog_style("a boy's town"), "boy's town, A")
  expect_equal(format_title_catalog_style("THE SCARLET LETTER"), "SCARLET LETTER, The")

  # Vectorized mixed input
  result <- format_title_catalog_style(c(
    "A Boy's Town",
    "Ann Boyd",
    NA_character_,
    "The Wings of the Dove"
  ))
  expect_equal(
    result,
    c("Boy's Town, A", "Ann Boyd", NA_character_, "Wings of the Dove, The")
  )
})

test_that("make_title_choices uses catalog labels and original values", {
  titles <- c("The Wings of the Dove", "A Boy's Town", "Ann Boyd", "A Boy's Town")
  choices <- make_title_choices(titles)

  # Values are original stored titles (deduped)
  expect_equal(unname(choices), c("Ann Boyd", "A Boy's Town", "The Wings of the Dove"))
  # Labels are catalog style
  expect_equal(names(choices), c("Ann Boyd", "Boy's Town, A", "Wings of the Dove, The"))
  # Sorted by catalog label (A before B before W)
  expect_equal(names(choices)[1], "Ann Boyd")
  expect_equal(names(choices)[2], "Boy's Town, A")

  # Custom labels (e.g. with year suffix)
  with_year <- make_title_choices(
    c("A Boy's Town", "The Wings of the Dove"),
    labels = c("Boy's Town, A (1890)", "Wings of the Dove, The (1902)")
  )
  expect_equal(unname(with_year), c("A Boy's Town", "The Wings of the Dove"))
  expect_equal(
    names(with_year),
    c("Boy's Town, A (1890)", "Wings of the Dove, The (1902)")
  )

  expect_equal(length(make_title_choices(character(0))), 0)
  expect_equal(length(make_title_choices(c(NA_character_, ""))), 0)
})
