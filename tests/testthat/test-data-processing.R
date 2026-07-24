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

test_that("clean_gender normalizes blank, whitespace, and codes to Unknown/Male/Female", {
  expect_equal(clean_gender(NULL), character(0))
  expect_equal(clean_gender(NA_character_), "Unknown")
  expect_equal(clean_gender(""), "Unknown")
  expect_equal(clean_gender("   "), "Unknown")
  expect_equal(clean_gender("Male"), "Male")
  expect_equal(clean_gender("female"), "Female")
  expect_equal(clean_gender("M"), "Male")
  expect_equal(clean_gender("F"), "Female")
  expect_equal(clean_gender("Unknown"), "Unknown")
  expect_equal(clean_gender("other"), "Unknown")
  expect_equal(clean_gender("xyz"), "Unknown")
  expect_equal(
    clean_gender(c("Male", NA, "  ", "f", "Unknown")),
    c("Male", "Unknown", "Unknown", "Female", "Unknown")
  )
})

test_that("normalize_gender_filter treats multi empty as empty, not all", {
  multi_empty <- normalize_gender_filter(NULL, mode = "multi")
  expect_true(multi_empty$apply)
  expect_true(multi_empty$empty)
  expect_equal(multi_empty$genders, character(0))

  multi_empty2 <- normalize_gender_filter(character(0), mode = "multi")
  expect_true(multi_empty2$empty)
  expect_equal(multi_empty2$genders, character(0))

  multi_partial <- normalize_gender_filter(c("Male", "  ", "female"), mode = "multi")
  expect_true(multi_partial$apply)
  expect_false(multi_partial$empty)
  expect_equal(sort(multi_partial$genders), c("Female", "Male", "Unknown"))
})

test_that("normalize_gender_filter treats single empty as all genders", {
  single_all <- normalize_gender_filter("", mode = "single")
  expect_false(single_all$apply)
  expect_false(single_all$empty)
  expect_equal(single_all$genders, character(0))

  single_null <- normalize_gender_filter(NULL, mode = "single")
  expect_false(single_null$apply)

  single_male <- normalize_gender_filter("Male", mode = "single")
  expect_true(single_male$apply)
  expect_equal(single_male$genders, "Male")

  single_unknown <- normalize_gender_filter("Unknown", mode = "single")
  expect_true(single_unknown$apply)
  expect_equal(single_unknown$genders, "Unknown")
})

test_that("build_gender_sql_filter maps Unknown to NULL/blank and empty to FALSE", {
  empty_sql <- build_gender_sql_filter(character(0), param_start = 1L)
  expect_equal(empty_sql$clause, "FALSE")
  expect_equal(empty_sql$params, list())

  all_sql <- build_gender_sql_filter(c("Male", "Female", "Unknown"), param_start = 1L)
  expect_null(all_sql$clause)
  expect_equal(all_sql$params, list())

  male_sql <- build_gender_sql_filter("Male", param_start = 3L)
  expect_equal(male_sql$clause, "(be.gender IN ($3))")
  expect_equal(male_sql$params, list("Male"))
  expect_equal(male_sql$next_param, 4L)

  unknown_sql <- build_gender_sql_filter("Unknown", param_start = 2L)
  expect_true(grepl("IS NULL", unknown_sql$clause, fixed = TRUE))
  expect_true(grepl("BTRIM", unknown_sql$clause, fixed = TRUE))
  expect_equal(unknown_sql$params, list())
  expect_equal(unknown_sql$next_param, 2L)

  mixed_sql <- build_gender_sql_filter(c("Female", "Unknown"), param_start = 1L)
  expect_true(grepl("IN \\(\\$1\\)", mixed_sql$clause))
  expect_true(grepl("IS NULL", mixed_sql$clause, fixed = TRUE))
  expect_equal(mixed_sql$params, list("Female"))
  expect_equal(mixed_sql$next_param, 2L)
})

test_that("gender_display_sql normalizes NULL and blank", {
  expr <- gender_display_sql("be.gender")
  expect_true(grepl("COALESCE", expr, fixed = TRUE))
  expect_true(grepl("BTRIM", expr, fixed = TRUE))
  expect_true(grepl("Unknown", expr, fixed = TRUE))
})
