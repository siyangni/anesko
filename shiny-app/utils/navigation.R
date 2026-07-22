# Browser history / deep-link helpers for sidebar navigation
# Syncs shinydashboard sidebarMenu tabs with ?tab= URL query parameters.

VALID_TABS <- c(
  "dashboard", "books", "sales_trends", "authors", "networks",
  "royalties", "royalty_query", "genres", "about"
)

DEFAULT_TAB <- "dashboard"

#' Whether a value is a known main_menu tab name
#'
#' @param tab Candidate tab name
#' @return TRUE if tab is a single valid tab name
is_valid_tab <- function(tab) {
  is.character(tab) &&
    length(tab) == 1 &&
    !is.na(tab) &&
    nzchar(tab) &&
    tab %in% VALID_TABS
}

#' Parse the active tab from a URL search string
#'
#' @param search Character search string (e.g. "?tab=authors"), or NULL/""
#' @return A valid tab name; defaults to DEFAULT_TAB when missing/invalid
tab_from_query <- function(search) {
  if (is.null(search) || length(search) == 0 || !nzchar(search)) {
    return(DEFAULT_TAB)
  }

  query <- shiny::parseQueryString(search)
  tab <- query[["tab"]]

  if (is.null(tab) || !is_valid_tab(tab)) {
    return(DEFAULT_TAB)
  }

  tab
}

#' Whether the search string already includes a tab= parameter
#'
#' @param search Character search string or NULL
#' @return TRUE if a tab parameter is present (value may still be invalid)
has_tab_param <- function(search) {
  if (is.null(search) || length(search) == 0 || !nzchar(search)) {
    return(FALSE)
  }
  grepl("(^|[?&])tab=", search)
}

#' Build a query string that sets tab=, preserving other parameters
#'
#' @param tab Target tab name (invalid values fall back to DEFAULT_TAB)
#' @param current_search Existing search string to merge with
#' @return Query string beginning with "?"
build_tab_query <- function(tab, current_search = "") {
  if (!is_valid_tab(tab)) {
    tab <- DEFAULT_TAB
  }

  params <- list()
  if (!is.null(current_search) && length(current_search) > 0 && nzchar(current_search)) {
    params <- shiny::parseQueryString(current_search)
    if (is.null(params)) {
      params <- list()
    }
  }

  params[["tab"]] <- tab

  # Stable key order: tab first, then remaining keys alphabetically
  other_keys <- setdiff(names(params), "tab")
  ordered_keys <- c("tab", sort(other_keys))

  parts <- vapply(ordered_keys, function(key) {
    value <- params[[key]]
    if (is.null(value)) {
      return(NA_character_)
    }
    paste0(
      utils::URLencode(as.character(key), reserved = TRUE),
      "=",
      utils::URLencode(as.character(value), reserved = TRUE)
    )
  }, character(1))

  parts <- parts[!is.na(parts)]
  paste0("?", paste(parts, collapse = "&"))
}
