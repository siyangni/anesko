# Genre Analysis Module
# Literary genre trends and market analysis

genreAnalysisUI <- function(id) {
  ns <- NS(id)

  fluidPage(
    h3("Genre & Market Analysis"),
    p("Comprehensive analysis of literary genre trends, market dynamics, and publishing patterns."),

    # Control Panel
    fluidRow(
      box(
        title = "Analysis Controls", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,

        fluidRow(
          column(3,
            dateRangeInput(ns("date_range"), "Date Range:",
                          start = "1860-01-01", end = "1920-12-31",
                          min = "1860-01-01", max = "1920-12-31",
                          format = "yyyy")
          ),
          column(3,
            selectInput(ns("analysis_type"), "Analysis Type:",
                       choices = list(
                         "Sales Distribution Explorer" = "distribution_explorer",
                         "Period Comparison & Trends" = "period_comparison"
                       ),
                       selected = "distribution_explorer")
          ),
          column(3,
            selectInput(ns("genre_filter"), "Focus on Genre:",
                       choices = NULL, multiple = FALSE)
          ),
          column(3,
            selectInput(ns("gender_filter"), "Author Gender:",
                       choices = list("All Authors" = "", "Male Authors" = "Male", "Female Authors" = "Female"),
                       selected = "")
          )
        ),

        fluidRow(
          column(3,
            selectizeInput(ns("binding_filter"), "Binding Type:",
                           choices = NULL,
                           multiple = FALSE,
                           options = list(
                             placeholder = "Select binding type...",
                             create = FALSE
                           ))
          ),
          column(3,
            conditionalPanel(
              condition = "input.analysis_type == 'distribution_explorer'",
              ns = ns,
              radioButtons(ns("metric_type"), "Metric:",
                          choices = list("Average Sales" = "average", "Total Sales" = "total"),
                          selected = "total", inline = TRUE)
            )
          ),
          column(3,
            br(),
            actionButton(ns("run_analysis"), "Run Analysis",
                        class = "btn-primary", style = "margin-top: 5px;")
          ),
          column(3,
            br(),
            div(style = "margin-top: 5px;",
              actionButton(ns("view_author_analysis"), "View in Author Analysis →",
                          class = "btn-link btn-sm"),
              br(),
              actionButton(ns("view_sales_analysis"), "View Sales Trends →",
                          class = "btn-link btn-sm")
            )
          )
        ),
        # Sales Distribution Explorer controls
        fluidRow(
          conditionalPanel(
            condition = "input.analysis_type == 'distribution_explorer'",
            ns = ns,
            column(3,
              selectInput(ns("primary_breakdown"), "Primary Breakdown:",
                choices = list("Genre" = "genre", "Binding" = "binding"),
                selected = "genre"
              ),
              shiny::helpText("Choose the main category to analyze.")
            ),
            column(3,
              selectInput(ns("secondary_split"), "Secondary Split:",
                choices = list("None" = "", "Gender" = "gender"),
                selected = ""
              ),
              shiny::helpText("Optionally split bars by gender.")
            ),
            column(3,
              radioButtons(ns("normalize"), "Normalization:",
                choices = list("Absolute" = "absolute", "Percent of total" = "percent"),
                selected = "absolute", inline = TRUE
              ),
              shiny::checkboxInput(ns("show_cumulative"), "Show cumulative share (table)", value = FALSE)
            ),
            column(3,
              numericInput(ns("top_n"), "Top N categories:", value = 10, min = 1),
              selectInput(ns("sort_by"), "Sort by:",
                choices = list("Value" = "value", "Share" = "share", "Alphabetical" = "alpha"),
                selected = "value"
              ),
              conditionalPanel(
                condition = "input.secondary_split == 'gender'",
                ns = ns,
                selectInput(ns("bar_mode"), "Bar mode:",
                  choices = list("Grouped" = "group", "Stacked" = "stack"),
                  selected = "group"
                )
              )
            )
          )
        ),
        fluidRow(
          conditionalPanel(
            condition = "input.analysis_type == 'period_comparison'",
            ns = ns,
            column(6,
              dateRangeInput(ns("date_range_p1"), "Period 1:",
                             start = "1860-01-01", end = "1900-12-31",
                             min = "1860-01-01", max = "1920-12-31",
                             format = "yyyy")
            ),
            column(6,
              dateRangeInput(ns("date_range_p2"), "Period 2:",
                             start = "1901-01-01", end = "1920-12-31",
                             min = "1860-01-01", max = "1920-12-31",
                             format = "yyyy")
            )
          )
        )
      )
    ),

    # Summary Statistics Row
    fluidRow(
      uiOutput(ns("summary_boxes"))
    ),

    # Results Section
    fluidRow(
      column(8,
        box(
          title = "Analysis Results", status = "success", solidHeader = TRUE,
          width = NULL,

          # Results table
          DT::dataTableOutput(ns("results_table")),

          # Download button
          br(),
          downloadButton(ns("download_results"), "Download Results", class = "btn-info")
        )
      ),
      column(4,
        box(
          title = "Market Insights", status = "info", solidHeader = TRUE,
          width = NULL,
          uiOutput(ns("insights_panel"))
        )
      )
    ),

    # Visualization Section
    fluidRow(
      column(6,
        box(
          title = "Primary Visualization", status = "warning", solidHeader = TRUE,
          width = NULL,
          plotlyOutput(ns("main_plot"), height = "400px")
        )
      ),
      column(6,
        box(
          title = "Market Trends", status = "info", solidHeader = TRUE,
          width = NULL,
          plotlyOutput(ns("trend_plot"), height = "400px")
        )
      )
    )
  )
}

genreAnalysisServer <- function(id) {
  moduleServer(id, function(input, output, session) {

    # Initialize genre choices
    observe({
      genres <- safe_query(function() {
        query <- "SELECT DISTINCT genre FROM book_entries WHERE genre IS NOT NULL ORDER BY genre"
        result <- safe_db_query(query)
        if (nrow(result) > 0) {
          choices <- c("All Genres" = "", setNames(result$genre, result$genre))
          return(choices)
        }
        return(c("All Genres" = ""))
      }, default_value = c("All Genres" = ""))

      updateSelectInput(session, "genre_filter", choices = genres)
    })

        # Initialize binding choices
        observe({
          binding_states <- safe_query(get_binding_states,
                                       default_value = data.frame(binding = character(0)))
          if (nrow(binding_states) > 0) {
            bindings <- binding_states$binding
            bindings <- sort(unique(stringr::str_to_title(trimws(bindings))))
            updateSelectizeInput(session, "binding_filter",
                                 choices = c("All Binding Types" = "", stats::setNames(bindings, bindings)),
                                 selected = "",
                                 server = TRUE)
          } else {
            updateSelectizeInput(session, "binding_filter",
                                 choices = c("All Binding Types" = ""),
                                 selected = "")
          }
        })


    # Map standardized IDs to internal handlers (global reactive)
    legacy_type <- reactive({
      switch(input$analysis_type,
        "distribution_explorer" = "distribution",
        "period_comparison"    = "cross_period_avg",
        input$analysis_type
      )
    })





    # Reactive values for storing results
    analysis_results <- reactiveVal(data.frame())

    # Store base dataset and params for distribution explorer (tied to Run Analysis)
    dist_base_raw <- reactiveVal(data.frame())
    dist_params <- reactiveVal(list())

    # Enhanced helper to compute distribution results from base + params
    compute_distribution <- function(base_df, params) {
      if (is.null(base_df) || nrow(base_df) == 0) {
        showNotification(
          "No data available for the selected parameters. Try adjusting your filters, date range, or analysis type.",
          type = "warning",
          duration = 8
        )
        return(data.frame())
      }

      primary <- params$primary_breakdown %||% "genre"  # 'genre' or 'binding'
      split <- params$secondary_split %||% ""
      normalize <- params$normalize %||% "absolute"
      top_n <- params$top_n %||% 10
      sort_by <- params$sort_by %||% "value"
      metric <- params$metric_type %||% "total"  # 'total' or 'average'

      # Determine value column with better error messages
      if (metric == "average") {
        value_col <- "avg_total_sales_per_book"
        # Ensure column exists (from average query)
        if (!(value_col %in% names(base_df))) {
          showNotification(
            "Data format error: Average sales data not available. Try switching to 'Total Sales' metric.",
            type = "error",
            duration = 8
          )
          return(data.frame())
        }
      } else {
        value_col <- "total_sales"
        if (!(value_col %in% names(base_df))) {
          showNotification(
            "Data format error: Total sales data not available. Please contact support.",
            type = "error",
            duration = 8
          )
          return(data.frame())
        }
      }

      # Columns to keep
      keep_cols <- c("genre", "binding", "gender", "book_count", value_col)
      df <- base_df[, intersect(keep_cols, names(base_df)), drop = FALSE]

      # Aggregate by chosen breakdown
      if (split == "") {
        # Group by primary only
        if (primary == "genre") {
          # Check if required columns exist
          if (!("genre" %in% names(df))) {
            showNotification("Data format error: 'genre' column missing from results",
                           type = "error", duration = 8)
            return(data.frame())
          }

          agg <- aggregate(df[[value_col]] ~ genre, df, sum)
          names(agg)[2] <- value_col  # Fix column name directly

          if ("book_count" %in% names(df)) {
            bc <- aggregate(book_count ~ genre, df, sum)
            out <- merge(agg, bc, by = "genre", all = TRUE)
          } else {
            out <- agg
            out$book_count <- 1  # Fallback
          }

          # Safely select existing columns
          available_cols <- intersect(c("genre", value_col, "book_count"), names(out))
          out <- out[, available_cols, drop = FALSE]

        } else {
          # Check if required columns exist
          if (!("binding" %in% names(df))) {
            showNotification("Data format error: 'binding' column missing from results",
                           type = "error", duration = 8)
            return(data.frame())
          }

          agg <- aggregate(df[[value_col]] ~ binding, df, sum)
          names(agg)[2] <- value_col  # Fix column name directly

          if ("book_count" %in% names(df)) {
            bc <- aggregate(book_count ~ binding, df, sum)
            out <- merge(agg, bc, by = "binding", all = TRUE)
          } else {
            out <- agg
            out$book_count <- 1  # Fallback
          }

          # Safely select existing columns
          available_cols <- intersect(c("binding", value_col, "book_count"), names(out))
          out <- out[, available_cols, drop = FALSE]
        }
        # Weighted average for metric == average
        if (metric == "average") {
          if (primary == "genre") {
            wa <- aggregate(cbind(val = df[[value_col]], w = df$book_count) ~ genre, df, sum)
            out[[value_col]] <- wa$val / pmax(wa$w, 1)
          } else {
            wa <- aggregate(cbind(val = df[[value_col]], w = df$book_count) ~ binding, df, sum)
            out[[value_col]] <- wa$val / pmax(wa$w, 1)
          }
        }
      } else if (split == "gender") {
        # Group by primary and gender
        if (primary == "genre") {
          agg <- aggregate(df[[value_col]] ~ genre + gender, df, sum)
          names(agg)[3] <- value_col  # Fix column name directly

          if ("book_count" %in% names(df)) {
            bc <- aggregate(book_count ~ genre + gender, df, sum)
            out <- merge(agg, bc, by = c("genre", "gender"), all = TRUE)
          } else {
            out <- agg
            out$book_count <- 1
          }

          # Safely select existing columns
          available_cols <- intersect(c("genre", "gender", value_col, "book_count"), names(out))
          out <- out[, available_cols, drop = FALSE]

        } else {
          agg <- aggregate(df[[value_col]] ~ binding + gender, df, sum)
          names(agg)[3] <- value_col  # Fix column name directly

          if ("book_count" %in% names(df)) {
            bc <- aggregate(book_count ~ binding + gender, df, sum)
            out <- merge(agg, bc, by = c("binding", "gender"), all = TRUE)
          } else {
            out <- agg
            out$book_count <- 1
          }

          # Safely select existing columns
          available_cols <- intersect(c("binding", "gender", value_col, "book_count"), names(out))
          out <- out[, available_cols, drop = FALSE]
        }
        # Weighted average for metric == average
        if (metric == "average") {
          if (primary == "genre") {
            wa <- aggregate(cbind(val = df[[value_col]], w = df$book_count) ~ genre + gender, df, sum)
            out[[value_col]] <- wa$val / pmax(wa$w, 1)
          } else {
            wa <- aggregate(cbind(val = df[[value_col]], w = df$book_count) ~ binding + gender, df, sum)
            out[[value_col]] <- wa$val / pmax(wa$w, 1)
          }
        }
      } else {
        return(data.frame(Error = "Unsupported split"))
      }

      # Normalization and sorting
      if (normalize == "percent") {
        total_val <- sum(out[[value_col]], na.rm = TRUE)
        out$market_share_pct <- if (total_val > 0) 100 * out[[value_col]] / total_val else 0
        # Cumulative share only meaningful without split; compute after sort
      }

      # Sorting
      if (normalize == "percent" && sort_by == "share" && ("market_share_pct" %in% names(out))) {
        ord <- order(out$market_share_pct, decreasing = TRUE, na.last = TRUE)
      } else if (sort_by == "alpha") {
        key <- if (primary == "genre") out$genre else out$binding
        ord <- order(key, decreasing = FALSE, na.last = TRUE)
      } else {
        ord <- order(out[[value_col]], decreasing = TRUE, na.last = TRUE)
      }
      out <- out[ord, , drop = FALSE]

      # Top N by primary
      if (top_n > 0) {
        if (split == "") {
          out <- head(out, top_n)
        } else {
          # Keep top N primaries and all their split rows
          prim_col <- if (primary == "genre") "genre" else "binding"
          tops <- unique(out[[prim_col]])[1:min(top_n, length(unique(out[[prim_col]])))]
          out <- out[out[[prim_col]] %in% tops, , drop = FALSE]
        }
      }

      # Cumulative share (no split only)
      if (normalize == "percent" && split == "" && ("market_share_pct" %in% names(out))) {
        if (isTRUE(params$show_cumulative %||% FALSE)) {
          out$cumulative_share <- cumsum(out$market_share_pct)
        }
      }

      out
    }

    # Unified distribution results reactive (computed from last Run Analysis params)
    dist_results <- reactive({
      base <- dist_base_raw()
      params <- dist_params()
      if (is.null(params) || length(params) == 0) return(data.frame())
      compute_distribution(base, params)
    })

        # Keep dist_params in sync with UI controls (no requery). Metric change requires rerun.
        observeEvent(input$primary_breakdown, ignoreInit = TRUE, {
          p <- dist_params()
          p$primary_breakdown <- input$primary_breakdown
          dist_params(p)
        })
        observeEvent(input$secondary_split, ignoreInit = TRUE, {
          p <- dist_params()
          p$secondary_split <- input$secondary_split
          dist_params(p)
        })
        observeEvent(input$normalize, ignoreInit = TRUE, {
          p <- dist_params()
          p$normalize <- input$normalize
          dist_params(p)
        })
        observeEvent(input$top_n, ignoreInit = TRUE, {
          p <- dist_params()
          p$top_n <- input$top_n
          dist_params(p)
        })
        observeEvent(input$sort_by, ignoreInit = TRUE, {
          p <- dist_params()
          p$sort_by <- input$sort_by
          dist_params(p)
        })
        observeEvent(input$bar_mode, ignoreInit = TRUE, {
          p <- dist_params()
          p$bar_mode <- input$bar_mode
          dist_params(p)
        })
        observeEvent(input$show_cumulative, ignoreInit = TRUE, {
          p <- dist_params()
          p$show_cumulative <- isTRUE(input$show_cumulative)
          dist_params(p)
        })
        observeEvent(input$metric_type, ignoreInit = TRUE, {
          if (input$analysis_type == "distribution_explorer") {
            showNotification(
              "Changing Metric requires re-running the analysis to refresh the base data.",
              type = "message", duration = 3
            )
          }
        })

        # Helper to get current results (distribution explorer is dynamic)
        current_results <- reactive({
          if (legacy_type() == "distribution") dist_results() else analysis_results()
        })



    # Convert date range to years
    year_range <- reactive({
      dates <- input$date_range
      if (is.null(dates) || length(dates) != 2) {
        return(c(1860, 1920))









      }
      c(as.numeric(format(dates[1], "%Y")), as.numeric(format(dates[2], "%Y")))
    })

    # Navigation handlers
    observeEvent(input$view_author_analysis, {
      showNotification("Navigate to Author Analysis tab to explore author-focused analytics",
                      type = "message", duration = 3)
    })

    observeEvent(input$view_sales_analysis, {
      try({ shinydashboard::updateTabItems(session, inputId = "main_menu", selected = "sales_trends") }, silent = TRUE)
    })

    # Run analysis when button is clicked
    observeEvent(input$run_analysis, {
      years <- year_range()
      start_year <- years[1]
      end_year <- years[2]

      # Validate parameters before running analysis
      validation <- validate_analysis_params(
        input$genre_filter,
        input$binding_filter,
        input$gender_filter,
        start_year,
        end_year,
        legacy_type()
      )

      if (!validation$valid) {
        showNotification(
          paste("Parameter validation failed:",
                paste(validation$issues, collapse = "; ")),
          type = "error",
          duration = 10
        )
        if (length(validation$suggestions) > 0) {
          showNotification(
            paste("Suggestions:",
                  paste(validation$suggestions, collapse = "; ")),
            type = "message",
            duration = 12
          )
        }
        return()
      }

      # Check data availability before running expensive queries
      availability <- check_data_availability(
        input$genre_filter,
        input$binding_filter,
        input$gender_filter,
        start_year,
        end_year
      )

      if (!availability$available) {
        showNotification(
          paste("No data found for your selected parameters.",
                "Try expanding your date range or removing some filters."),
          type = "warning",
          duration = 10
        )

        # Use utility function to generate suggestions
        suggestions <- generate_data_suggestions(
          input$genre_filter,
          input$binding_filter,
          input$gender_filter,
          start_year,
          end_year
        )

        if (length(suggestions) > 0) {
          showNotification(
            paste("Suggestions:", paste(suggestions, collapse = "; ")),
            type = "message",
            duration = 15
          )
        }

        return()
      }

      withProgress(message = "Running genre analysis...", value = 0, {
        incProgress(0.1, detail = paste("Found", availability$count, "records to analyze..."))

        # Map standardized IDs to internal handlers
        # (moved to outer scope)

        results <- switch(legacy_type(),
          "distribution" = {
            incProgress(0.3, detail = "Preparing distribution data...")

            # Create context for better error messages
            context <- create_context_string(
              input$genre_filter,
              input$binding_filter,
              input$gender_filter,
              start_year,
              end_year
            )

            base <- safe_query_enhanced(function() {
              if (input$metric_type == "average") {
                get_average_sales_by_binding_genre_gender(
                  input$binding_filter %||% NULL,
                  input$genre_filter %||% NULL,
                  input$gender_filter %||% NULL,
                  start_year, end_year
                )
              } else {
                get_total_sales_by_binding_genre_gender(
                  input$binding_filter %||% NULL,
                  input$genre_filter %||% NULL,
                  input$gender_filter %||% NULL,
                  start_year, end_year
                )
              }
            },
            default_value = data.frame(),
            error_message = "Failed to retrieve sales data",
            context = context)

            # Check if we got meaningful data
            if (is.null(base) || nrow(base) == 0) {
              showNotification(
                paste("No sales data found for:", context,
                      "- Try different filters or expand your date range"),
                type = "warning",
                duration = 12
              )
              return(data.frame())
            }

            incProgress(0.5, detail = "Processing distribution analysis...")

            # Save base and params for reactive explorer
            dist_base_raw(base)
            dist_params(list(
              primary_breakdown = input$primary_breakdown %||% "genre",
              secondary_split = input$secondary_split %||% "",
              normalize = input$normalize %||% "absolute",
              show_cumulative = isTRUE(input$show_cumulative %||% FALSE),
              top_n = input$top_n %||% 10,
              sort_by = input$sort_by %||% "value",
              metric_type = input$metric_type %||% "total"
            ))

            # Compute once for this run
            result <- compute_distribution(base, dist_params())

            if (is.null(result) || nrow(result) == 0) {
              showNotification(
                "Distribution analysis produced no results. This may be due to data processing constraints.",
                type = "warning",
                duration = 10
              )
            }

            result
          },

          "cross_period_avg" = {
            incProgress(0.3, detail = "Computing cross-period averages...")
            # Need genre and binding
            if (is.null(input$genre_filter) || input$genre_filter == "" ||
                is.null(input$binding_filter) || input$binding_filter == "") {
              showNotification("Please select both a Genre and a Binding type.", type = "warning")
              data.frame(Error = "Select a specific genre and binding")
            } else {
              p1 <- input$date_range_p1; p2 <- input$date_range_p2
              if (is.null(p1) || length(p1) != 2 || is.null(p2) || length(p2) != 2) {
                showNotification("Please set both Period 1 and Period 2 date ranges.", type = "warning")
                data.frame(Error = "Please set both periods")
              } else {
                p1_years <- c(as.numeric(format(p1[1], "%Y")), as.numeric(format(p1[2], "%Y")))
                p2_years <- c(as.numeric(format(p2[1], "%Y")), as.numeric(format(p2[2], "%Y")))

                # Use per-book totals for each period to enable significance testing
                books_p1 <- safe_query(function() {
                  get_total_sales_per_book_by_genre_binding(input$binding_filter, input$genre_filter, p1_years[1], p1_years[2])
                }, default_value = data.frame())
                books_p2 <- safe_query(function() {
                  get_total_sales_per_book_by_genre_binding(input$binding_filter, input$genre_filter, p2_years[1], p2_years[2])
                }, default_value = data.frame())

                avg1 <- if (nrow(books_p1) > 0) mean(books_p1$total_sales, na.rm = TRUE) else NA_real_
                avg2 <- if (nrow(books_p2) > 0) mean(books_p2$total_sales, na.rm = TRUE) else NA_real_
                n1 <- nrow(books_p1); n2 <- nrow(books_p2)
                pct_change <- if (is.na(avg1) || avg1 == 0 || is.na(avg2)) NA_real_ else ((avg2 - avg1) / avg1) * 100

                p_value <- NA_real_
                test_method <- NA_character_
                if (n1 > 1 && n2 > 1 && all(is.finite(c(avg1, avg2)))) {
                  tt <- try(stats::t.test(books_p1$total_sales, books_p2$total_sales), silent = TRUE)
                  if (!inherits(tt, "try-error")) {
                    p_value <- tt$p.value
                    test_method <- "t-test"
                  }
                }

                data.frame(
                  genre = input$genre_filter,
                  binding = input$binding_filter,
                  period = c("Period 1", "Period 2"),
                  start_year = c(p1_years[1], p2_years[1]),
                  end_year = c(p1_years[2], p2_years[2]),
                  avg_sales_per_book = c(avg1, avg2),
                  n_books = c(n1, n2),
                  pct_change = c(NA_real_, pct_change),
                  p_value = c(NA_real_, p_value),
                  test = c(NA_character_, test_method),
                  stringsAsFactors = FALSE
                )
              }
            }
          },

          data.frame(Error = "Unknown analysis type")
        )

        incProgress(0.7, detail = "Processing results...")
        analysis_results(results)
        incProgress(1, detail = "Complete!")
      })
    })

    # Enhanced summary boxes with better empty state handling
    output$summary_boxes <- renderUI({
      results <- analysis_results()

      # Provide helpful message when no results
      if (nrow(results) == 0 || "Error" %in% names(results)) {
        return(
          fluidRow(
            column(12, create_no_data_summary())
          )
        )
      }

      years <- year_range()

      boxes <- switch(legacy_type(),
        "distribution" = {
          res <- dist_results()
          if (nrow(res) > 0) {
            # Determine primary for labeling
            primary <- dist_params()$primary_breakdown %||% "genre"
            label_col <- if (primary == "genre") "genre" else "binding"
            value_col <- if ((dist_params()$metric_type %||% "total") == "average") "avg_total_sales_per_book" else "total_sales"

            top_row <- res[1, , drop = FALSE]
            top_label <- if (label_col %in% names(res)) top_row[[label_col]][1] else ""
            total_cats <- nrow(res)

            value_box_1 <- create_value_box(
              value = top_label,
              subtitle = paste("Top", if (primary == "genre") "Genre" else "Binding"),
              icon = "crown",
              color = "blue"
            )

            value_sum <- if (value_col %in% names(res)) sum(res[[value_col]], na.rm = TRUE) else NA
            value_box_2 <- create_value_box(
              value = if (!is.na(value_sum)) format(round(value_sum, 1), big.mark = ",") else "N/A",
              subtitle = if ((dist_params()$metric_type %||% "total") == "average") "Sum of Averages" else "Total Market Sales",
              icon = "chart-line",
              color = "green"
            )

            value_box_3 <- create_value_box(
              value = total_cats,
              subtitle = paste(if (primary == "genre") "Genres" else "Bindings", "Analyzed"),
              icon = "list",
              color = "navy"
            )

            fluidRow(
              column(4, value_box_1),
              column(4, value_box_2),
              column(4, value_box_3)
            )
          }
        },

        "cross_period_avg" = {
          if ("pct_change" %in% names(results) && nrow(results) > 0) {
            last_row <- tail(results, 1)
            fluidRow(
              column(6, create_value_box(
                value = ifelse(is.na(last_row$pct_change), "NA", paste0(round(last_row$pct_change, 1), "%")),
                subtitle = "Percent Change (P2 vs P1)",
                icon = "percent",
                color = "orange"
              )),
              column(6, create_value_box(
                value = ifelse(is.na(last_row$p_value), "N/A", paste0("p=", signif(last_row$p_value, 3))),
                subtitle = paste0("Significance", ifelse(is.na(last_row$test), "", paste0(" (", last_row$test, ")"))),
                icon = "flask",
                color = "green"
              ))
            )
          }
        },

        NULL
      )

      boxes
    })

    # Insights panel
    output$insights_panel <- renderUI({
      results <- analysis_results()
      if (nrow(results) == 0 || "Error" %in% names(results)) {
        return(div(class = "alert alert-warning", "Run an analysis to see market insights"))
      }

      insights <- switch(legacy_type(),
        "distribution" = {
          res <- dist_results()
          if (nrow(res) > 0) {
            primary <- dist_params()$primary_breakdown %||% "genre"
            metric <- dist_params()$metric_type %||% "total"
            normalize <- dist_params()$normalize %||% "absolute"
            label <- if (primary == "genre") "Genre" else "Binding"

            top_label <- if (primary == "genre") res$genre[1] else res$binding[1]
            conc_text <- NULL
            if ("market_share_pct" %in% names(res)) {
              top3 <- head(res$market_share_pct, 3)
              conc <- round(sum(top3, na.rm = TRUE), 1)
              conc_text <- paste("Top 3", label, "share:", paste0(conc, "%"))
            }

            tagList(
              h5("Distribution Insights:"),
              p(paste("Top", label, ":", top_label)),
              if (!is.null(conc_text)) p(conc_text) else NULL,
              if (metric == "average") p("Metric: Average Sales per Book") else p(if (normalize == "percent") "Metric: Market Share" else "Metric: Total Sales")
            )
          } else {
            p("No distribution data available")
          }
        },

        "cross_period_avg" = {
          if (nrow(results) > 0 && "pct_change" %in% names(results)) {
            last_row <- tail(results, 1)
            tagList(
              h5("Cross-Period Average Sales Insights:"),
              p(paste("Percent change (P2 vs P1):", ifelse(is.na(last_row$pct_change), "NA", paste0(round(last_row$pct_change, 1), "%")))),
              p(paste("Significance test:", ifelse(is.na(last_row$p_value), "N/A", paste0("p=", signif(last_row$p_value, 3))),
                      ifelse(is.na(last_row$test), "", paste0(" (", last_row$test, ")"))))
            )
          } else {
            p("No cross-period data available")
          }
        },

        p("Select an analysis type to see insights")
      )

      insights
    })

    # Results table
    output$results_table <- DT::renderDataTable({
      results <- if (legacy_type() == "distribution") dist_results() else analysis_results()
      if (nrow(results) == 0) {
        return(DT::datatable(data.frame(Message = "No analysis run yet"), options = list(dom = 't')))
      }

      if ("Error" %in% names(results)) {
        return(DT::datatable(results, options = list(dom = 't')))
      }

      # Format the results for display
      display_results <- results

      # Format numeric columns
      if ("total_sales" %in% names(display_results)) {
        display_results$total_sales <- format(display_results$total_sales, big.mark = ",")
      }
      if ("avg_sales_per_year" %in% names(display_results)) {
        display_results$avg_sales_per_year <- round(display_results$avg_sales_per_year, 1)
      }
      if ("avg_total_sales_per_book" %in% names(display_results)) {
        display_results$avg_total_sales_per_book <- round(display_results$avg_total_sales_per_book, 1)
      }
      if ("avg_sales_per_book" %in% names(display_results)) {
        display_results$avg_sales_per_book <- round(display_results$avg_sales_per_book, 1)
      }
      if ("pct_change" %in% names(display_results)) {
        display_results$pct_change <- ifelse(is.na(display_results$pct_change), NA, round(display_results$pct_change, 1))
      }
      if ("p_value" %in% names(display_results)) {
        display_results$p_value <- ifelse(is.na(display_results$p_value), NA, signif(display_results$p_value, 3))
      }
      if ("market_share_pct" %in% names(display_results)) {
          display_results$market_share_pct <- paste0(display_results$market_share_pct, "%")
        }
        if ("cumulative_share" %in% names(display_results)) {
          display_results$cumulative_share <- paste0(round(display_results$cumulative_share, 1), "%")
        }

        DT::datatable(
          display_results,
          options = list(
            pageLength = 15,
            scrollX = TRUE,
            dom = 'Bfrtip',
            buttons = c('copy', 'csv', 'excel')
          ),
          rownames = FALSE
        )
      })

      # Enhanced main plot with better empty state messages
      output$main_plot <- renderPlotly({
        results <- analysis_results()
        if (nrow(results) == 0 || "Error" %in% names(results)) {
          # Use utility function to create enhanced empty plot message
          years <- year_range()
          empty_message <- create_empty_plot_message(
            "No data available for visualization",
            input$genre_filter,
            input$binding_filter,
            input$gender_filter,
            years[1],
            years[2]
          )

          return(plotly_empty(empty_message))
        }

        switch(legacy_type(),
          "distribution" = {
            res <- current_results()
            if (nrow(res) == 0) return(plotly_empty("No data available"))
            primary <- dist_params()$primary_breakdown %||% "genre"
            split <- dist_params()$secondary_split %||% ""
            normalize <- dist_params()$normalize %||% "absolute"
            metric <- dist_params()$metric_type %||% "total"
            value_col <- if (metric == "average") "avg_total_sales_per_book" else "total_sales"
            y_title <- if (metric == "average") "Average Sales per Book" else if (normalize == "percent") "Market Share (%)" else "Total Sales"

            if (split == "gender") {
              x_map <- if (primary == "genre") ~genre else ~binding
              y_map <- if (normalize == "percent") ~market_share_pct else as.formula(paste0("~", value_col))
              plot_ly(res, x = x_map, y = y_map, color = ~gender, type = "bar",
                    colors = c("Male" = "#4C78A8", "Female" = "#F58518")) %>%
                layout(title = if (primary == "genre") "Genre Performance by Gender" else "Binding Performance by Gender",
                      xaxis = list(title = if (primary == "genre") "Genre" else "Binding"),
                      yaxis = list(title = y_title),
                      barmode = if ((dist_params()$bar_mode %||% "group") == "stack") "stack" else "group")
            } else {
              x_map <- if (primary == "genre") ~genre else ~binding
              y_map <- if (normalize == "percent") ~market_share_pct else as.formula(paste0("~", value_col))
              plot_ly(res, x = x_map, y = y_map, type = "bar") %>%
                layout(title = if (primary == "genre") "Sales by Genre" else "Sales by Binding",
                      xaxis = list(title = if (primary == "genre") "Genre" else "Binding"),
                      yaxis = list(title = y_title))
            }
          },

          "cross_period_avg" = {
            if (all(c("period", "avg_sales_per_book") %in% names(results)) && nrow(results) > 0) {
              plot_ly(results, x = ~period, y = ~avg_sales_per_book, type = "bar",
                    hovertemplate = "Period: %{x}<br>Avg Sales/Book: %{y:,.1f}<extra></extra>") %>%
                layout(title = paste0("Average Sales per Book (", input$genre_filter, " / ", input$binding_filter, ")"),
                      xaxis = list(title = "Period"),
                      yaxis = list(title = "Average Sales per Book"))
            } else {
              plotly_empty("No cross-period data available")
            }
          },

          plotly_empty("Select an analysis type")
        )
      })

      # Enhanced trend plot with better empty state handling
      output$trend_plot <- renderPlotly({
        results <- if (legacy_type() == "distribution") dist_results() else analysis_results()
        if (nrow(results) == 0 || "Error" %in% names(results)) {
        # Provide context-specific message for trend plot
        trend_message <- "No trend data available"

        if (legacy_type() == "distribution") {
          trend_message <- paste(trend_message,
                               "\nEnable 'Show cumulative share' and use",
                               "'Percent of total' normalization",
                               "\nto see cumulative market share trends")
        } else if (legacy_type() == "cross_period_avg") {
          trend_message <- paste(trend_message,
                               "\nPeriod comparison requires data from both periods",
                               "\nTry expanding date range or adjusting filters")
        }

        return(plotly_empty(trend_message))
      }

      switch(legacy_type(),
        "distribution" = {
          # For distribution explorer, draw cumulative market share curve when normalized percent and cumulative enabled
          params <- dist_params()
          if ((params$normalize %||% "absolute") == "percent" && isTRUE(params$show_cumulative %||% FALSE) &&
              ("cumulative_share" %in% names(results))) {
            results$rank <- seq_len(nrow(results))
            x_lab <- if ((params$primary_breakdown %||% "genre") == "genre") "Genre Rank" else "Binding Rank"
            plot_ly(results, x = ~rank, y = ~cumulative_share, type = "scatter", mode = "lines+markers",
                   text = ~ifelse(!is.null(results$genre), results$genre, results$binding),
                   hovertemplate = "%{text}<br>Rank: %{x}<br>Cumulative: %{y:.1f}%<extra></extra>") %>%
              layout(title = "Cumulative Market Share",
                     xaxis = list(title = x_lab),
                     yaxis = list(title = "Cumulative Market Share (%)"))
          } else {
            plotly_empty("Trend analysis available when viewing Percent + Cumulative")
          }
        },

        "cross_period_avg" = plotly_empty("Trend analysis not available for this analysis type")
      )
    })

    # Download handler
    output$download_results <- downloadHandler(
      filename = function() {
        paste0("genre_analysis_", input$analysis_type, "_", Sys.Date(), ".csv")
      },
      content = function(file) {
        results <- if (legacy_type() == "distribution") dist_results() else analysis_results()
        if (nrow(results) > 0 && !("Error" %in% names(results))) {
          write.csv(results, file, row.names = FALSE)
        }
      }
    )
  })
}