# Year concepts: publication vs sales isolation, and shared period/filter helpers.

list2env(
  list(
    MIN_YEAR = 1860L,
    MAX_YEAR = 1920L,
    DEFAULT_YEAR_RANGE = c(1880L, 1910L),
    PUBLICATION_YEAR_BUFFER = 5L,
    SALES_YEAR_BUFFER = 2L,
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
  # Shared timeseries WHERE builder is the single source of filter semantics
  ts_where <- function_body_source(
    "../../shiny-app/utils/queries_timeseries.R",
    ".build_sales_timeseries_where",
    "get_sales_timeseries_filtered"
  )
  expect_true(has_sales_year_between(ts_where))
  expect_false(has_publication_year_between(ts_where))

  # Public wrappers delegate to the shared builder (no local year filter)
  ts_filtered <- function_body_source(
    "../../shiny-app/utils/queries_timeseries.R",
    "get_sales_timeseries_filtered",
    "get_sales_timeseries_for_dimension"
  )
  expect_true(grepl("\\.build_sales_timeseries_where", ts_filtered))
  expect_false(has_publication_year_between(ts_filtered))

  ts_dim <- function_body_source(
    "../../shiny-app/utils/queries_timeseries.R",
    "get_sales_timeseries_for_dimension",
    NULL
  )
  expect_true(grepl("\\.build_sales_timeseries_where", ts_dim))
  expect_false(has_publication_year_between(ts_dim))

  sales_where <- function_body_source(
    "../../shiny-app/utils/queries_sales.R",
    ".build_genre_binding_gender_where",
    "get_average_sales_by_binding_genre_gender"
  )
  expect_true(has_sales_year_between(sales_where))
  expect_false(has_publication_year_between(sales_where))

  title_where <- function_body_source(
    "../../shiny-app/utils/queries_sales.R",
    ".build_title_binding_sales_where",
    "get_book_sales_by_title_binding"
  )
  expect_true(has_sales_year_between(title_where))
  expect_false(has_publication_year_between(title_where))

  title_sales <- function_body_source(
    "../../shiny-app/utils/queries_sales.R",
    "get_book_sales_by_title_binding",
    ".build_genre_binding_gender_where"
  )
  expect_true(grepl("\\.build_title_binding_sales_where", title_sales))
  expect_false(has_publication_year_between(title_sales))

  title_avg <- function_body_source(
    "../../shiny-app/utils/queries_sales.R",
    "get_average_sales_by_book_binding",
    NULL
  )
  expect_true(grepl("\\.build_title_binding_sales_where", title_avg))
  expect_false(has_publication_year_between(title_avg))
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
    ".build_title_binding_sales_where"
  )
  expect_true(has_publication_year_between(top_books))
  expect_false(has_sales_year_between(top_books))

  overview <- function_body_source(
    "../../shiny-app/utils/queries_basic.R",
    "get_author_overview_books",
    "get_binding_states"
  )
  expect_true(has_publication_year_between(overview))
  expect_false(has_sales_year_between(overview))
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

test_that("compute_sales_year_bounds uses SALES_YEAR_BUFFER by default", {
  b <- compute_sales_year_bounds(1858, 1920)
  expect_equal(b$observed_min, 1858L)
  expect_equal(b$observed_max, 1920L)
  expect_equal(b$filter_min, 1856L)  # 1858 - 2
  expect_equal(b$filter_max, 1922L)  # 1920 + 2
  expect_equal(b$default_range, c(1858L, 1920L))

  custom <- compute_sales_year_bounds(1860, 1910, buffer = 0L)
  expect_equal(custom$filter_min, 1860L)
  expect_equal(custom$filter_max, 1910L)
})

test_that("sales filter helpers expose slider limits, full range, and preset", {
  SALES_YEAR_BOUNDS <<- compute_sales_year_bounds(1858, 1919, buffer = 2L)

  expect_equal(sales_slider_min(), 1856L)
  expect_equal(sales_slider_max(), 1921L)
  expect_equal(sales_default_range(), c(1858L, 1919L))

  # Preset is DEFAULT_YEAR_RANGE clamped into available filter limits
  expect_equal(sales_preset_range(), c(1880L, 1910L))

  # When preset falls outside available span, clamp or fall back
  SALES_YEAR_BOUNDS <<- compute_sales_year_bounds(1890, 1905, buffer = 0L)
  preset <- sales_preset_range()
  expect_equal(preset[[1]], 1890L)  # clamped up from 1880
  expect_equal(preset[[2]], 1905L)  # clamped down from 1910
})

test_that("year_to_date_string and date range arg builders are consistent", {
  expect_equal(year_to_date_string(1880, "start"), "1880-01-01")
  expect_equal(year_to_date_string(1910, "end"), "1910-12-31")

  args <- year_range_to_date_args(1860, 1920, min_year = 1858, max_year = 1922)
  expect_equal(args$start, "1860-01-01")
  expect_equal(args$end, "1920-12-31")
  expect_equal(args$min, "1858-01-01")
  expect_equal(args$max, "1922-12-31")

  SALES_YEAR_BOUNDS <<- compute_sales_year_bounds(1858, 1920, buffer = 2L)
  sales_args <- sales_date_range_args(use_preset = FALSE)
  expect_equal(sales_args$start, "1858-01-01")
  expect_equal(sales_args$end, "1920-12-31")
  expect_equal(sales_args$min, "1856-01-01")
  expect_equal(sales_args$max, "1922-12-31")

  preset_args <- sales_date_range_args(use_preset = TRUE)
  expect_equal(preset_args$start, "1880-01-01")
  expect_equal(preset_args$end, "1910-12-31")
})

test_that("sales-year UI modules use dynamic sales bounds helpers", {
  st <- paste(readLines("../../shiny-app/modules/sales_trends_module.R", warn = FALSE),
              collapse = "\n")
  expect_true(grepl("sales_slider_min\\(\\)", st))
  expect_true(grepl("sales_slider_max\\(\\)", st))
  expect_true(grepl("sales_preset_range\\(\\)", st))
  expect_false(grepl("min\\s*=\\s*MIN_YEAR", st))

  rq <- paste(readLines("../../shiny-app/modules/royalty_query_module.R", warn = FALSE),
              collapse = "\n")
  expect_true(grepl("sales_slider_min\\(\\)", rq))
  expect_true(grepl("sales_preset_range\\(\\)", rq))

  be <- paste(readLines("../../shiny-app/modules/book_explorer_module.R", warn = FALSE),
              collapse = "\n")
  expect_true(grepl("sales_slider_min\\(\\)", be))
  expect_true(grepl("sales_preset_range\\(\\)", be))

  ga <- paste(readLines("../../shiny-app/modules/genre_analysis_module.R", warn = FALSE),
              collapse = "\n")
  expect_true(grepl("sales_date_range_args", ga))
  expect_false(grepl('start = "1860-01-01"', ga, fixed = TRUE))

  aa <- paste(readLines("../../shiny-app/modules/author_analysis_module.R", warn = FALSE),
              collapse = "\n")
  expect_true(grepl("sales_slider_min\\(\\)", aa) || grepl("sales_default_range\\(\\)", aa))
  expect_true(grepl("publication_slider_min\\(\\)", aa) || grepl("publication_date_range_args", aa))
})

test_that("modules load genre/binding choices via shared filter helpers", {
  modules <- c(
    "../../shiny-app/modules/genre_analysis_module.R",
    "../../shiny-app/modules/genre_content_analysis_module.R",
    "../../shiny-app/modules/author_analysis_module.R",
    "../../shiny-app/modules/sales_trends_module.R",
    "../../shiny-app/modules/book_explorer_module.R",
    "../../shiny-app/modules/royalty_analysis_module.R"
  )
  for (path in modules) {
    src <- paste(readLines(path, warn = FALSE), collapse = "\n")
    expect_true(
      grepl("genre_filter_choices", src) ||
        grepl("get_filter_options", src) ||
        grepl("publisher_filter_choices", src),
      info = paste("expected shared filter helper in", path)
    )
  }
})

test_that("author lookup SQL is centralized (no divergent module copies)", {
  # Shared query functions must exist and use COUNT(DISTINCT book_id)
  surname_opts <- function_body_source(
    "../../shiny-app/utils/queries_basic.R",
    "get_author_surname_options",
    "get_author_ids_by_surname"
  )
  expect_true(grepl("COUNT\\(DISTINCT be\\.book_id\\)", surname_opts))

  ids_by_surname <- function_body_source(
    "../../shiny-app/utils/queries_basic.R",
    "get_author_ids_by_surname",
    "author_surname_select_choices"
  )
  expect_true(grepl("COUNT\\(DISTINCT be\\.book_id\\)", ids_by_surname))
  expect_false(grepl("COUNT\\(\\*\\)\\s+AS book_count", ids_by_surname))

  # Modules must call shared helpers, not re-embed the author lookup SQL
  author_mod <- paste(readLines("../../shiny-app/modules/author_analysis_module.R",
                                warn = FALSE), collapse = "\n")
  expect_true(grepl("author_surname_select_choices", author_mod))
  expect_true(grepl("author_id_select_choices", author_mod))
  expect_true(grepl("get_author_overview_books", author_mod))
  # No inline author_id lookup SQL left in the module
  expect_false(grepl(
    "SELECT DISTINCT be\\.author_id, be\\.author_surname",
    author_mod
  ))
  # Exactly one observeEvent for author_name (duplicate was a real bug)
  matches <- gregexpr("observeEvent\\(input\\$author_name", author_mod)[[1]]
  n_events <- if (length(matches) == 1L && matches[1] == -1L) 0L else length(matches)
  expect_equal(n_events, 1L)

  royalty_q <- paste(readLines("../../shiny-app/modules/royalty_query_module.R",
                               warn = FALSE), collapse = "\n")
  expect_true(grepl("author_surname_select_choices", royalty_q))
  expect_true(grepl("author_id_select_choices", royalty_q))
  expect_false(grepl(
    "SELECT DISTINCT be\\.author_id, be\\.author_surname",
    royalty_q
  ))
})

test_that("stale queries_royalty.R duplicate is not present", {
  expect_false(file.exists("../../shiny-app/utils/queries_royalty.R"))
  expect_true(file.exists("../../shiny-app/utils/queries_royalties.R"))
})

test_that("shared filter choice builders normalize options consistently", {
  genres_df <- data.frame(genre = c("F", "N", "  ", NA_character_), stringsAsFactors = FALSE)
  g_all <- genre_filter_choices(include_all = TRUE, raw_df = genres_df)
  expect_true("" %in% unname(g_all))
  expect_true("F" %in% unname(g_all))
  expect_true("N" %in% unname(g_all))
  expect_false(any(is.na(unname(g_all)) | unname(g_all) == "  "))

  g_multi <- genre_filter_choices(include_all = FALSE, raw_df = genres_df)
  expect_false("" %in% unname(g_multi))

  empty_g <- genre_filter_choices(include_all = TRUE, raw_df = data.frame(genre = character(0)))
  expect_equal(unname(empty_g), "")

  binds_df <- data.frame(binding = c("cloth", "Paper", "", NA_character_), stringsAsFactors = FALSE)
  b_all <- binding_filter_choices(include_all = TRUE, title_case = FALSE, raw_df = binds_df)
  expect_true("" %in% unname(b_all))
  expect_true("cloth" %in% unname(b_all) || "Cloth" %in% unname(b_all))

  pubs <- publisher_filter_choices(
    raw_df = data.frame(publisher = c("Harper", " Scribner ", ""), stringsAsFactors = FALSE)
  )
  expect_equal(sort(unname(pubs)), c("Harper", "Scribner"))

  expect_equal(gender_filter_choices("multi"), c("Male", "Female", "Unknown"))
  single_g <- gender_filter_choices("single")
  expect_true("" %in% unname(single_g))
  expect_true("Male" %in% unname(single_g))
})
