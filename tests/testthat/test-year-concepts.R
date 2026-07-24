# Year concepts: publication vs sales isolation, and publication filter bounds.

list2env(
  list(
    MIN_YEAR = 1860L,
    MAX_YEAR = 1920L,
    DEFAULT_YEAR_RANGE = c(1880L, 1910L),
    PUBLICATION_YEAR_BUFFER = 5L,
    FORMAT_MILLION_THRESHOLD = 1000000,
    FORMAT_THOUSAND_THRESHOLD = 1000,
    MAX_FILTER_VALUES = 100,
    MAX_QUERY_LIMIT = 10000,
    DEFAULT_QUERY_LIMIT = 100,
    INPUT_MIN_YEAR = 1800,
    INPUT_MAX_YEAR = 2100
  ),
  envir = environment()
)
source("../../shiny-app/utils/data_processing.R", local = TRUE)

function_body_source <- function(path, fn_name, next_fn_name = NULL) {
  src <- paste(readLines(path, warn = FALSE), collapse = "\n")
  start_pat <- paste0(fn_name, "\\s*<-\\s*function")
  start <- regexpr(start_pat, src)
  if (start < 0) {
    stop("Function not found: ", fn_name, " in ", path)
  }
  rest <- substring(src, start)
  if (!is.null(next_fn_name)) {
    end_pat <- paste0("\n", next_fn_name, "\\s*<-\\s*function")
    end <- regexpr(end_pat, rest)
    if (end > 0) {
      rest <- substring(rest, 1, end)
    }
  }
  rest
}

has_publication_year_between <- function(body) {
  grepl("publication_year\\s+BETWEEN", body, ignore.case = TRUE)
}

has_sales_year_between <- function(body) {
  grepl("bs\\.year\\s+BETWEEN", body)
}

test_that("sales-year query builders do not filter on publication_year", {
  ts_body <- function_body_source(
    "../../shiny-app/utils/queries_timeseries.R",
    "get_sales_timeseries_filtered",
    "get_sales_timeseries_for_dimension"
  )
  expect_true(has_sales_year_between(ts_body))
  expect_false(has_publication_year_between(ts_body))

  sales_where <- function_body_source(
    "../../shiny-app/utils/queries_sales.R",
    ".build_genre_binding_gender_where",
    "get_average_sales_by_binding_genre_gender"
  )
  expect_true(has_sales_year_between(sales_where))
  expect_false(has_publication_year_between(sales_where))

  title_sales <- function_body_source(
    "../../shiny-app/utils/queries_sales.R",
    "get_book_sales_by_title_binding",
    ".build_genre_binding_gender_where"
  )
  expect_true(has_sales_year_between(title_sales))
  expect_false(has_publication_year_between(title_sales))
})

test_that("publication-year query builders do not filter on sales year", {
  search_body <- function_body_source(
    "../../shiny-app/utils/queries_basic.R",
    "search_books",
    "get_filter_options"
  )
  expect_true(has_publication_year_between(search_body))
  expect_false(has_sales_year_between(search_body))

  top_books <- function_body_source(
    "../../shiny-app/utils/queries_sales.R",
    "get_top_books",
    "get_book_sales_by_title_binding"
  )
  expect_true(has_publication_year_between(top_books))
  expect_false(has_sales_year_between(top_books))
})

test_that("compute_publication_year_bounds covers observed span plus buffer", {
  b <- compute_publication_year_bounds(1858, 1920, buffer = 5L)
  expect_equal(b$observed_min, 1858L)
  expect_equal(b$observed_max, 1920L)
  expect_equal(b$filter_min, 1853L)
  expect_equal(b$filter_max, 1925L)
  expect_equal(b$buffer, 5L)
  # Default selection is full observed range (not the buffer wings)
  expect_equal(b$default_range, c(1858L, 1920L))

  fb <- compute_publication_year_bounds(
    NA, NA, buffer = 5L, fallback_min = 1860L, fallback_max = 1920L
  )
  expect_equal(fb$filter_min, 1855L)
  expect_equal(fb$filter_max, 1925L)
  expect_equal(fb$default_range, c(1860L, 1920L))

  inv <- compute_publication_year_bounds(1920, 1860, buffer = 2L)
  expect_equal(inv$observed_min, 1860L)
  expect_equal(inv$observed_max, 1920L)
  expect_equal(inv$filter_min, 1858L)
  expect_equal(inv$filter_max, 1922L)
})

test_that("publication filter helpers expose slider limits and default range", {
  # Assign into this test env so publication_filter_limits() finds them via inherits
  PUBLICATION_YEAR_BOUNDS <<- compute_publication_year_bounds(1858, 1919, buffer = 5L)

  expect_equal(publication_slider_min(), 1853L)
  expect_equal(publication_slider_max(), 1924L)
  expect_equal(publication_default_range(), c(1858L, 1919L))
  limits <- publication_filter_limits()
  expect_true(limits$filter_min < limits$observed_min)
  expect_true(limits$filter_max > limits$observed_max)
})

test_that("publication filter UI modules use dynamic publication bounds helpers", {
  be <- paste(readLines("../../shiny-app/modules/book_explorer_module.R", warn = FALSE),
              collapse = "\n")
  expect_true(grepl("publication_slider_min\\(\\)", be))
  expect_true(grepl("publication_slider_max\\(\\)", be))
  expect_true(grepl("publication_default_range\\(\\)", be))

  an <- paste(readLines("../../shiny-app/modules/author_networks_module.R", warn = FALSE),
              collapse = "\n")
  expect_true(grepl("publication_slider_min\\(\\)", an))
  expect_true(grepl("publication_default_range\\(\\)", an))

  ra <- paste(readLines("../../shiny-app/modules/royalty_analysis_module.R", warn = FALSE),
              collapse = "\n")
  expect_true(grepl("publication_slider_min\\(\\)", ra))
  expect_true(grepl("publication_default_range\\(\\)", ra))
})

test_that("book explorer separates publication list filter from sales comparison filter", {
  be <- paste(readLines("../../shiny-app/modules/book_explorer_module.R", warn = FALSE),
              collapse = "\n")
  expect_true(grepl("publication_year_range\\s*=", be))
  expect_true(grepl("cmp_sales_year_range", be, fixed = TRUE))
  expect_true(grepl("sales_start_year\\s*=\\s*sales_years\\$start", be))

  cmp_block_start <- regexpr("cmp_results\\s*<-\\s*eventReactive", be)
  expect_true(cmp_block_start > 0)
  cmp_block <- substring(be, cmp_block_start, cmp_block_start + 2500)
  expect_true(grepl("cmp_sales_year_range", cmp_block, fixed = TRUE))
  expect_false(grepl("publication_year_range", cmp_block, fixed = TRUE))
  expect_false(grepl("input\\$year_range", cmp_block))
})

test_that("filter_min/max always include full observed span with buffer headroom", {
  # Property: for any observed [a,b] and buffer k>0:
  # filter_min <= a <= b <= filter_max and (b-a) + 2k == filter_max - filter_min
  cases <- list(
    c(1860, 1920, 5),
    c(1858, 1918, 3),
    c(1900, 1900, 5),
    c(1875, 1910, 1)
  )
  for (case in cases) {
    a <- case[[1]]; b <- case[[2]]; k <- case[[3]]
    res <- compute_publication_year_bounds(a, b, buffer = k)
    expect_lte(res$filter_min, res$observed_min)
    expect_gte(res$filter_max, res$observed_max)
    expect_equal(res$filter_min, res$observed_min - k)
    expect_equal(res$filter_max, res$observed_max + k)
    expect_equal(res$default_range[[1]], res$observed_min)
    expect_equal(res$default_range[[2]], res$observed_max)
  }
})
