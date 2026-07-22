# Unit tests for browser history / tab deep-link helpers

test_that("is_valid_tab accepts known tabs", {
  source("../../shiny-app/utils/navigation.R", local = TRUE)

  expect_true(is_valid_tab("dashboard"))
  expect_true(is_valid_tab("books"))
  expect_true(is_valid_tab("sales_trends"))
  expect_true(is_valid_tab("authors"))
  expect_true(is_valid_tab("networks"))
  expect_true(is_valid_tab("royalties"))
  expect_true(is_valid_tab("royalty_query"))
  expect_true(is_valid_tab("genres"))
  expect_true(is_valid_tab("about"))
})

test_that("is_valid_tab rejects invalid values", {
  source("../../shiny-app/utils/navigation.R", local = TRUE)

  expect_false(is_valid_tab("not_a_tab"))
  expect_false(is_valid_tab(""))
  expect_false(is_valid_tab(NULL))
  expect_false(is_valid_tab(c("dashboard", "books")))
  expect_false(is_valid_tab(NA_character_))
  expect_false(is_valid_tab(123))
})

test_that("tab_from_query parses valid tab parameters", {
  source("../../shiny-app/utils/navigation.R", local = TRUE)

  expect_equal(tab_from_query("?tab=authors"), "authors")
  expect_equal(tab_from_query("?tab=sales_trends"), "sales_trends")
  expect_equal(tab_from_query("?foo=1&tab=genres"), "genres")
  expect_equal(tab_from_query("tab=about"), "about")
})

test_that("tab_from_query defaults for missing or invalid tabs", {
  source("../../shiny-app/utils/navigation.R", local = TRUE)

  expect_equal(tab_from_query(""), "dashboard")
  expect_equal(tab_from_query(NULL), "dashboard")
  expect_equal(tab_from_query("?foo=bar"), "dashboard")
  expect_equal(tab_from_query("?tab=evil"), "dashboard")
  expect_equal(tab_from_query("?tab="), "dashboard")
})

test_that("has_tab_param detects tab presence", {
  source("../../shiny-app/utils/navigation.R", local = TRUE)

  expect_true(has_tab_param("?tab=books"))
  expect_true(has_tab_param("?x=1&tab=books"))
  expect_true(has_tab_param("?tab=evil"))
  expect_false(has_tab_param(""))
  expect_false(has_tab_param(NULL))
  expect_false(has_tab_param("?foo=bar"))
})

test_that("build_tab_query sets tab and preserves other params", {
  source("../../shiny-app/utils/navigation.R", local = TRUE)

  expect_equal(build_tab_query("books"), "?tab=books")
  expect_equal(build_tab_query("sales_trends", ""), "?tab=sales_trends")
  expect_equal(
    build_tab_query("authors", "?foo=1&bar=2"),
    "?tab=authors&bar=2&foo=1"
  )
  # Invalid tab falls back to dashboard
  expect_equal(build_tab_query("nope"), "?tab=dashboard")
  # Replaces existing tab value
  expect_equal(build_tab_query("genres", "?tab=books"), "?tab=genres")
})
