# Author Analysis Module
# Gender analysis and author performance metrics

authorAnalysisUI <- function(id) {
  ns <- NS(id)

  fluidPage(
    h3("Author & Gender Analysis"),
    p("Comprehensive analysis of author performance, gender disparities, and career metrics.", 
      style = "font-size: 16px;"),
    tags$style(HTML("\n      .insights-large, .insights-large p { font-size: 1.15rem; line-height: 1.5; }\n      .insights-large h5 { font-size: 1.3rem; font-weight: 600; margin-top: 8px; }\n      .metric-emphasis { font-size: 1.2rem; font-weight: 600; }\n      .control-group label { font-size: 16px; font-weight: 500; }\n    ")),

    # Control Panel
    fluidRow(
      box(
        title = "Analysis Controls", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,

        fluidRow(
          column(3,
            tags$div(class = "control-group",
              # Shared control: concept switches with analysis type.
              # Default UI bounds use the union of publication and sales limits so
              # either mode remains selectable; observe() below tightens label/help
              # and may re-clamp selection when the concept changes.
              {
                union_min <- min(publication_slider_min(), sales_slider_min())
                union_max <- max(publication_slider_max(), sales_slider_max())
                # Start on sales concept (gender_performance default analysis type)
                sales_sel <- sales_default_range()
                dateRangeInput(
                  ns("date_range"), "Sales Year Range:",
                  start = year_to_date_string(sales_sel[[1]], "start"),
                  end = year_to_date_string(sales_sel[[2]], "end"),
                  min = year_to_date_string(union_min, "start"),
                  max = year_to_date_string(union_max, "end"),
                  format = "yyyy"
                )
              },
              uiOutput(ns("year_range_help"))
            )
          ),
          column(3,
            tags$div(class = "control-group",
              selectInput(ns("analysis_type"), "Analysis Type:",
                         choices = list(
                           "Gender Performance" = "gender_performance",
                           "Genre Mix by Author Gender" = "genre_by_gender",
                           "Author Career Overview" = "author_overview"
                         ),
                         selected = "gender_performance")
            )
          ),
          column(3,
            conditionalPanel(
              condition = "input.analysis_type == 'author_overview'",
              ns = ns,
              tags$div(class = "control-group",
                tagList(
                  selectizeInput(ns("author_name"), "Author Surname:",
                                 choices = NULL,
                                 multiple = FALSE,
                                 options = list(
                                   placeholder = "Select author surname...",
                                   create = TRUE,
                                   persist = TRUE,
                                   onInitialize = I('function() { this.setValue(""); }')
                                 )),
                  br(),
                  selectizeInput(ns("author_id"), "Author ID:",
                                 choices = NULL,
                                 multiple = FALSE,
                                 options = list(
                                   placeholder = "Select author ID (optional)...",
                                   create = FALSE,
                                   persist = TRUE,
                                   onInitialize = I('function() { this.setValue(""); }')
                                 ))
                )
              )
            ),
            conditionalPanel(
              condition = "input.analysis_type == 'gender_performance' || input.analysis_type == 'genre_by_gender'",
              ns = ns,
              tags$div(class = "control-group",
                selectInput(ns("gender_filter"), "Focus on Gender:",
                           choices = gender_filter_choices(mode = "single"),
                           selected = "")
              )
            )
          ),
          column(3,
            conditionalPanel(
              condition = "input.analysis_type == 'gender_performance' || input.analysis_type == 'genre_by_gender'",
              ns = ns,
              tags$div(class = "control-group",
                selectInput(ns("genre_filter"), "Genre Focus:",
                           choices = NULL, multiple = FALSE)
              )
            ),
            conditionalPanel(
              condition = "input.analysis_type == 'gender_performance' || input.analysis_type == 'genre_by_gender'",
              ns = ns,
              tags$div(class = "control-group",
                tagList(
                  selectizeInput(ns("binding_filter"), "Binding Type:",
                                 choices = NULL,
                                 multiple = FALSE,
                                 options = list(
                                   placeholder = "Select or type binding type...",
                                   create = FALSE
                                 )),
                  helpText("Hint: try 'cloth', 'paper'", style = "font-size: 14px;"),
                  actionButton(ns("clear_binding"), "Clear", class = "btn-link btn-sm")
                )
              )
            )
          )
        ),

        fluidRow(
          column(4,
            conditionalPanel(
              condition = "input.analysis_type == 'gender_performance'",
              ns = ns,
              tags$div(class = "author-metric-group"),
              radioButtons(
                ns("metric_type"),
                tags$span(style = "font-size: 18px; font-weight: 200;", "Metric:"),
                choiceNames = list(
                  tags$span(style = "font-size: 18px; font-weight: 200;", "Average Sales"),
                  tags$span(style = "font-size: 18px; font-weight: 200;", "Total Sales")
                ),
                choiceValues = list("average", "total"),
                selected = "average",
                inline = TRUE
              )
            )
          ),
          column(4,
            br(),
            actionButton(ns("run_analysis"), "Run Analysis",
                        class = "btn-primary", style = "margin-top: 5px; font-size: 16px;")
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
          title = "Key Insights", status = "info", solidHeader = TRUE,
          width = NULL,
          div(class = "insights-large", uiOutput(ns("insights_panel")))
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
          title = "Comparative Analysis", status = "info", solidHeader = TRUE,
          width = NULL,
          plotlyOutput(ns("comparison_plot"), height = "400px")
        )
      )
    )
  )
}

authorAnalysisServer <- function(id) {
  moduleServer(id, function(input, output, session) {

    # Clarify year concept based on analysis type (same control, different meaning)
    output$year_range_help <- renderUI({
      if (identical(input$analysis_type, "author_overview")) {
        helpText(
          "Publication years: filters books by when they were published. Covers full observed catalog span plus buffer.",
          style = "font-size: 13px; margin-top: -6px;"
        )
      } else {
        helpText(
          "Sales years: years when copies were sold (not publication year). Covers full observed sales span plus buffer.",
          style = "font-size: 13px; margin-top: -6px;"
        )
      }
    })

    # Switch label and available bounds only when analysis type (year concept) changes.
    # Avoid reading input$date_range as a reactive dependency here to prevent update loops.
    observeEvent(input$analysis_type, {
      is_pub <- identical(input$analysis_type, "author_overview")
      label <- if (is_pub) "Publication Year Range:" else "Sales Year Range:"
      default_span <- if (is_pub) publication_default_range() else sales_default_range()
      min_y <- if (is_pub) publication_slider_min() else sales_slider_min()
      max_y <- if (is_pub) publication_slider_max() else sales_slider_max()

      # Preserve selection if still valid under the new concept bounds
      current <- isolate(resolve_year_range(
        input$date_range,
        default = default_span
      ))
      start_y <- max(min(current$start, max_y), min_y)
      end_y <- min(max(current$end, min_y), max_y)
      if (is.na(start_y) || is.na(end_y) || start_y > end_y) {
        start_y <- default_span[[1]]
        end_y <- default_span[[2]]
      }
      updateDateRangeInput(
        session, "date_range",
        label = label,
        start = year_to_date_string(start_y, "start"),
        end = year_to_date_string(end_y, "end"),
        min = year_to_date_string(min_y, "start"),
        max = year_to_date_string(max_y, "end")
      )
    }, ignoreNULL = FALSE)

    # Initialize genre choices and binding states from shared helpers
    observe({
      opts <- safe_query(get_filter_options, default_value = list(
        genres = data.frame(genre = character(0)),
        binding_states = data.frame(binding = character(0))
      ))
      updateSelectInput(
        session, "genre_filter",
        choices = genre_filter_choices(include_all = TRUE, raw_df = opts$genres)
      )

      bind_df <- if (is.null(opts$binding_states)) {
        data.frame(binding = character(0))
      } else {
        opts$binding_states
      }
      bind_choices <- binding_filter_choices(
        include_all = TRUE,
        raw_df = bind_df
      )
      if (length(bind_choices) > 0) {
        # "" is the intentional "All Binding Types" sentinel from binding_filter_choices()
        updateSelectizeInput(
          session, "binding_filter",
          choices = bind_choices,
          selected = "",
          server = TRUE
        )
      }

      # Author surname choices via shared query (single SQL semantics across analyses)
      author_choices <- safe_query(
        author_surname_select_choices,
        default_value = character(0)
      )

      # Render Author ID input only when a surname is selected
      output$author_id_ui <- renderUI({
        req(input$author_name)
        if (is.null(input$author_name) || identical(input$author_name, "")) {
          return(NULL)
        }
        selectizeInput(ns("author_id"), "Author ID:",
                       choices = NULL,
                       multiple = FALSE,
                       options = list(
                         placeholder = "Select author ID (optional)...",
                         create = FALSE,
                         persist = TRUE,
                         onInitialize = I('function() { this.setValue(""); }')
                       ))
      })

      # Populate Author ID choices after a surname is selected (once; shared SQL).
      # Leave empty — optional disambiguator; do not auto-pick first ID.
      observeEvent(input$author_name, {
        surname <- input$author_name
        if (is.null(surname) || identical(surname, "")) {
          updateSelectizeInput(
            session, "author_id",
            choices = character(0),
            selected = character(0),
            server = TRUE
          )
          return()
        }
        choices <- safe_query(
          function() author_id_select_choices(surname),
          default_value = character(0)
        )
        updateSelectizeInput(
          session, "author_id",
          choices = choices,
          selected = character(0),
          server = TRUE
        )
      })

      # Initialize dropdown with choices (empty selection until user picks)
      updateSelectizeInput(
        session, "author_name",
        choices = author_choices,
        selected = character(0),
        server = TRUE
      )
    })

    # Map standardized IDs to internal handlers (global reactive)
    legacy_type <- reactive({
      switch(input$analysis_type,
        "gender_performance" = "gender_comparison",
        "genre_by_gender" = "gender_genre",
        input$analysis_type
      )
    })

    # Reactive values for storing results
    analysis_results <- reactiveVal(data.frame())

    # Convert date range to years (concept depends on analysis type)
    year_range <- reactive({
      default_span <- if (identical(input$analysis_type, "author_overview")) {
        publication_default_range()
      } else {
        sales_default_range()
      }
      resolved <- resolve_year_range(
        input$date_range,
        default = default_span
      )
      c(resolved$start, resolved$end)
    })

    observeEvent(input$run_analysis, {
      years <- year_range()
      # Gender/genre analyses filter sales years; author overview uses publication years
      sales_start_year <- years[1]
      sales_end_year <- years[2]
      publication_start_year <- years[1]
      publication_end_year <- years[2]
      # Keep legacy names for call sites that still expect start_year/end_year
      start_year <- years[1]
      end_year <- years[2]

      withProgress(message = "Running author analysis...", value = 0, {

        results <- switch(legacy_type(),
          "gender_comparison" = {
            incProgress(0.3, detail = "Analyzing gender performance...")
            if (input$metric_type == "average") {
              get_average_sales_by_binding_genre_gender(
                optional_filter_or_null(input$binding_filter),
                optional_filter_or_null(input$genre_filter),
                optional_filter_or_null(input$gender_filter),
                sales_start_year = sales_start_year,
                sales_end_year = sales_end_year
              )
            } else {
              get_total_sales_by_binding_genre_gender(
                optional_filter_or_null(input$binding_filter),
                optional_filter_or_null(input$genre_filter),
                optional_filter_or_null(input$gender_filter),
                sales_start_year = sales_start_year,
                sales_end_year = sales_end_year
              )
            }
          },

          "author_royalty" = {
            incProgress(0.3, detail = "Calculating author royalty income...")
            if (is.null(input$author_name) || input$author_name == "") {
              data.frame(Error = "Please enter an author surname")
            } else {
              get_total_royalty_income_by_author(
                input$author_name %||% "",
                start_year, end_year,
                author_id = (input$author_id %||% NULL)
              )
            }
          },

          "gender_genre" = {
            incProgress(0.3, detail = "Analyzing gender by genre...")
            metric <- input$metric_type %||% "total"
            if (identical(metric, "average")) {
              get_average_sales_by_binding_genre_gender(
                optional_filter_or_null(input$binding_filter),
                optional_filter_or_null(input$genre_filter),
                optional_filter_or_null(input$gender_filter),
                sales_start_year = sales_start_year,
                sales_end_year = sales_end_year
              )
            } else {
              get_total_sales_by_binding_genre_gender(
                optional_filter_or_null(input$binding_filter),
                optional_filter_or_null(input$genre_filter),
                optional_filter_or_null(input$gender_filter),
                sales_start_year = sales_start_year,
                sales_end_year = sales_end_year
              )
            }
          },

          "author_overview" = {
            incProgress(0.3, detail = "Generating author overview...")
            if (is.null(input$author_name) || input$author_name == "") {
              data.frame(Error = "Please enter an author surname")
            } else {
              # Career overview filters by publication year (catalog metadata)
              get_author_overview_books(
                author_surname = input$author_name,
                author_id = if (is.null(input$author_id) || input$author_id == "") {
                  NULL
                } else {
                  input$author_id
                },
                publication_start_year = publication_start_year,
                publication_end_year = publication_end_year
              )
            }
          },

          data.frame(Error = "Unknown analysis type")
        )

        incProgress(0.7, detail = "Processing results...")
        analysis_results(results)
        incProgress(1, detail = "Complete!")
      })
    })

    # Summary boxes
    output$summary_boxes <- renderUI({
      results <- analysis_results()
      if (nrow(results) == 0 || "Error" %in% names(results)) {
        return(NULL)
      }

      years <- year_range()

      boxes <- switch(legacy_type(),
        "gender_comparison" = {
          if (input$metric_type == "average") {
            male_avg <- mean(results[results$gender == "Male", "avg_total_sales_per_book"], na.rm = TRUE)
            female_avg <- mean(results[results$gender == "Female", "avg_total_sales_per_book"], na.rm = TRUE)
            # Guard against NaN values from mean(numeric(0))
            if (is.nan(male_avg)) male_avg <- NA_real_
            if (is.nan(female_avg)) female_avg <- NA_real_

            # Safe performance comparison and color
            perf_pct <- if (!is.na(male_avg) && male_avg > 0 && !is.na(female_avg)) round((female_avg / male_avg - 1) * 100, 1) else NA_real_
            perf_value <- if (!is.na(perf_pct) && is.finite(perf_pct)) paste0(perf_pct, "%") else "N/A"
            perf_color <- if (!is.na(perf_pct) && perf_pct > 0) "green" else "orange"

            fluidRow(
              column(4, create_value_box(
                value = round(male_avg, 0),
                subtitle = "Avg Sales - Male Authors",
                icon = "male",
                color = "blue"
              )),
              column(4, create_value_box(
                value = round(female_avg, 0),
                subtitle = "Avg Sales - Female Authors",
                icon = "female",
                color = "red"
              )),
              column(4, create_value_box(
                value = perf_value,
                subtitle = "Female vs Male Performance",
                icon = "balance-scale",
                color = perf_color
              ))
            )
          } else {
            male_total <- sum(results[results$gender == "Male", "total_sales"], na.rm = TRUE)
            female_total <- sum(results[results$gender == "Female", "total_sales"], na.rm = TRUE)

            fluidRow(
              column(4, create_value_box(
                value = male_total,
                subtitle = "Total Sales - Male Authors",
                icon = "male",
                color = "blue"
              )),
              column(4, create_value_box(
                value = female_total,
                subtitle = "Total Sales - Female Authors",
                icon = "female",
                color = "red"
              )),
              column(4, create_value_box(
                value = paste0(round(female_total/(male_total + female_total) * 100, 1), "%"),
                subtitle = "Female Market Share",
                icon = "chart-pie",
                color = "purple"
              ))
            )
          }
        },

        "author_royalty" = {
          total_royalty <- sum(results[results$book_id != "TOTAL", "royalty_income"], na.rm = TRUE)
          book_count <- nrow(results[results$book_id != "TOTAL", ])
          avg_royalty <- if(book_count > 0) total_royalty / book_count else 0

          fluidRow(
            column(4, create_value_box(
              value = paste0("$", format(round(total_royalty, 2), big.mark = ",")),
              subtitle = "Total Royalty Income",
              icon = "dollar-sign",
              color = "green"
            )),
            column(4, create_value_box(
              value = book_count,
              subtitle = "Books Published",
              icon = "book",
              color = "blue"
            )),
            column(4, create_value_box(
              value = paste0("$", format(round(avg_royalty, 2), big.mark = ",")),
              subtitle = "Avg Royalty per Book",
              icon = "calculator",
              color = "orange"
            ))
          )
        },

        "gender_genre" = {
          male_total <- sum(results[results$gender == "Male", "total_sales"], na.rm = TRUE)
          female_total <- sum(results[results$gender == "Female", "total_sales"], na.rm = TRUE)
          total_genres <- length(unique(results$genre))

          fluidRow(
            column(4, create_value_box(
              value = male_total,
              subtitle = "Total Sales - Male Authors",
              icon = "male",
              color = "blue"
            )),
            column(4, create_value_box(
              value = female_total,
              subtitle = "Total Sales - Female Authors",
              icon = "female",
              color = "red"
            )),
            column(4, create_value_box(
              value = total_genres,
              subtitle = "Genres Analyzed",
              icon = "list",
              color = "green"
            ))
          )
        },

        NULL
      )

      boxes
    })

    # Insights panel
    output$insights_panel <- renderUI({
      results <- analysis_results()
      if (nrow(results) == 0 || "Error" %in% names(results)) {
        return(div(class = "alert alert-warning", style = "font-size: 16px;", "Run an analysis to see insights"))
      }

      insights <- switch(legacy_type(),
        "gender_comparison" = {
          if (nrow(results) > 0 && "gender" %in% names(results)) {
            male_data <- results[results$gender == "Male", ]
            female_data <- results[results$gender == "Female", ]

            tagList(
              h5("Gender Analysis Insights:", style = "font-size: 18px; font-weight: bold;"),
              if (nrow(male_data) > 0 && nrow(female_data) > 0) {
                if (input$metric_type == "average") {
                  male_avg <- mean(male_data$avg_total_sales_per_book, na.rm = TRUE)
                  female_avg <- mean(female_data$avg_total_sales_per_book, na.rm = TRUE)
                  # Guard against NaN comparisons when one gender has no data
                  if (is.nan(male_avg)) male_avg <- NA_real_
                  if (is.nan(female_avg)) female_avg <- NA_real_
                  comparison_msg <- if (isTRUE(female_avg > male_avg)) {
                    "Female authors outperformed male authors"
                  } else if (isTRUE(male_avg > female_avg)) {
                    "Male authors outperformed female authors"
                  } else {
                    "Performance similar or insufficient data for comparison"
                  }
                  tagList(
                    p(paste("Male authors averaged", round(male_avg, 0), "sales per book"), style = "font-size: 16px;"),
                    p(paste("Female authors averaged", round(female_avg, 0), "sales per book"), style = "font-size: 16px;"),
                    p(comparison_msg, style = "font-size: 16px;")
                  )
                } else {
                  male_total <- sum(male_data$total_sales, na.rm = TRUE)
                  female_total <- sum(female_data$total_sales, na.rm = TRUE)
                  tagList(
                    p(paste("Male authors:", format(male_total, big.mark = ","), "total sales"), style = "font-size: 16px;"),
                    p(paste("Female authors:", format(female_total, big.mark = ","), "total sales"), style = "font-size: 16px;"),
                    p(paste("Female market share:", round(female_total/(male_total + female_total) * 100, 1), "%"), style = "font-size: 16px;")
                  )
                }
              } else {
                p("Insufficient data for gender comparison", style = "font-size: 16px;")
              }
            )
          } else {
            p("No gender data available", style = "font-size: 16px;")
          }
        },

        "author_royalty" = {
          if (nrow(results) > 1) {
            book_data <- results[results$book_id != "TOTAL", ]
            total_row <- results[results$book_id == "TOTAL", ]

            tagList(
              h5("Author Royalty Insights:"),
              p(paste("Analyzed", nrow(book_data), "books")),
              if (nrow(total_row) > 0) {
                p(paste("Total royalty income: $", format(round(total_row$royalty_income[1], 2), big.mark = ",")))
              },
              if (nrow(book_data) > 0) {
                best_book <- book_data[which.max(book_data$royalty_income), ]
                p(paste("Best performing book:",
                       format_title_catalog_style(best_book$book_title[1]),
                       "($", format(round(best_book$royalty_income[1], 2), big.mark = ","), ")"))
              }
            )
          } else {
            p("No royalty data available")
          }
        },

        "gender_genre" = {
          if (nrow(results) > 0 && "gender" %in% names(results) && "genre" %in% names(results)) {
            male_data <- results[results$gender == "Male", ]
            female_data <- results[results$gender == "Female", ]

            tagList(
              h5("Genre by Gender Insights:"),
              p(paste("Analyzed", nrow(results), "genre-gender combinations")),
              if (nrow(male_data) > 0 && nrow(female_data) > 0) {
                male_total <- sum(male_data$total_sales, na.rm = TRUE)
                female_total <- sum(female_data$total_sales, na.rm = TRUE)
                p(paste("Male authors total sales:", format(male_total, big.mark = ","), "copies"))
                p(paste("Female authors total sales:", format(female_total, big.mark = ","), "copies"))
              }
            )
          } else {
            p("No genre/gender data available")
          }
        },

        "author_overview" = {
          if (nrow(results) > 0) {
            career_span <- max(results$publication_year, na.rm = TRUE) - min(results$publication_year, na.rm = TRUE) + 1
            total_sales <- sum(results$total_sales, na.rm = TRUE)

            tagList(
              h5("Author Career Insights:"),
              p(paste("Career span:", career_span, "years")),
              p(paste("Total books:", nrow(results))),
              p(class = "metric-emphasis", paste("Total sales:", format(total_sales, big.mark = ","), "copies")),
              if (nrow(results) > 0) {
                best_book <- results[which.max(results$total_sales), ]
                p(paste("Best seller:",
                       format_title_catalog_style(best_book$book_title[1]),
                       "(", format(best_book$total_sales[1], big.mark = ","), "copies)"))
              }
            )
          } else {
            p("No author data available")
          }
        },

        p("Select an analysis type to see insights")
      )

      insights
    })

    # Results table
    output$results_table <- DT::renderDataTable({
      results <- analysis_results()
      if (nrow(results) == 0) {
        return(DT::datatable(data.frame(Message = "No analysis run yet"), options = list(dom = 't')))
      }

      if ("Error" %in% names(results)) {
        return(DT::datatable(results, options = list(dom = 't')))
      }

      # Format the results for display
      display_results <- results

      # Format numeric columns based on analysis type
      if ("total_sales" %in% names(display_results)) {
        display_results$total_sales <- format(display_results$total_sales, big.mark = ",")
      }
      if ("avg_sales_per_year" %in% names(display_results)) {
        display_results$avg_sales_per_year <- round(display_results$avg_sales_per_year, 1)
      }
      if ("avg_total_sales_per_book" %in% names(display_results)) {
        display_results$avg_total_sales_per_book <- round(display_results$avg_total_sales_per_book, 1)
      }
      if ("royalty_income" %in% names(display_results)) {
        display_results$royalty_income <- paste0("$", format(round(display_results$royalty_income, 2), big.mark = ","))
      }
      if ("retail_price" %in% names(display_results)) {
        display_results$retail_price <- ifelse(is.na(display_results$retail_price), "N/A",
                                              paste0("$", format(display_results$retail_price, digits = 2)))
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

    # Main plot
    output$main_plot <- renderPlotly({
      results <- analysis_results()
      if (nrow(results) == 0 || "Error" %in% names(results)) {
        return(plotly_empty("Run an analysis to see visualization"))
      }

      switch(legacy_type(),
        "gender_comparison" = {
          if ("gender" %in% names(results) && nrow(results) > 0) {
            metric <- input$metric_type; if (is.null(metric) || length(metric) == 0) metric <- "total"
            y_col <- if (identical(metric, "average")) "avg_total_sales_per_book" else "total_sales"
            y_title <- if (identical(metric, "average")) "Average Sales per Book" else "Total Sales"

            plot_ly(results, x = ~gender, y = as.formula(paste0("~", y_col)),
                   type = "bar", color = ~gender,
                   colors = c("Male" = "#3498db", "Female" = "#e74c3c"),
                   hovertemplate = paste0("Gender: %{x}<br>Books: %{customdata}<br>", y_title, ": %{y:,.0f}<extra></extra>"),
                   customdata = ~book_count) %>%
              layout(
                title = list(text = paste("Sales by Gender -", y_title), font = list(size = 18)),
                xaxis = list(
                  title = list(text = "Author Gender", font = list(size = 16)),
                  tickfont = list(size = 14)
                ),
                yaxis = list(
                  title = list(text = y_title, font = list(size = 16)),
                  tickfont = list(size = 14)
                ),
                margin = list(t = 80, b = 80, l = 80, r = 50)
              ) %>%
              config(displayModeBar = TRUE, modeBarButtonsToRemove = c('select2d', 'lasso2d'), displaylogo = FALSE)
          } else {
            plotly_empty("No gender data available")
          }
        },

        "gender_genre" = {
          if ("genre" %in% names(results) && "gender" %in% names(results) && nrow(results) > 0) {
            metric <- input$metric_type; if (is.null(metric) || length(metric) == 0) metric <- "total"
            y_col <- if (identical(metric, "average")) "avg_total_sales_per_book" else "total_sales"
            y_title <- if (identical(metric, "average")) "Average Sales per Book" else "Total Sales"

            plot_ly(results, x = ~genre, y = as.formula(paste0("~", y_col)),
                   color = ~gender, type = "bar",
                   colors = c("Male" = "#3498db", "Female" = "#e74c3c"),
                   hovertemplate = paste0("Genre: %{x}<br>Gender: %{color}<br>", y_title, ": %{y:,.0f}<extra></extra>")) %>%
              layout(
                title = list(text = paste("Sales by Genre and Gender -", y_title), font = list(size = 18)),
                xaxis = list(
                  title = list(text = "Genre", font = list(size = 16)),
                  tickfont = list(size = 14)
                ),
                yaxis = list(
                  title = list(text = y_title, font = list(size = 16)),
                  tickfont = list(size = 14)
                ),
                legend = list(font = list(size = 14)),
                barmode = "group",
                margin = list(t = 80, b = 80, l = 80, r = 50)
              ) %>%
              config(displayModeBar = TRUE, modeBarButtonsToRemove = c('select2d', 'lasso2d'), displaylogo = FALSE)
          } else {
            plotly_empty("No genre/gender data available")
          }
        },

        "author_royalty" = {
          if ("royalty_income" %in% names(results) && nrow(results) > 1) {
            plot_data <- results[results$book_id != "TOTAL", ]
            if (nrow(plot_data) > 0) {
              plot_data$book_title <- format_title_catalog_style(plot_data$book_title)
              plot_ly(plot_data, x = ~book_title, y = ~royalty_income, type = "bar",
                     text = ~paste("Sales:", total_sales),
                     hovertemplate = "%{text}<br>Royalty: $%{y:,.2f}<extra></extra>") %>%
                layout(
                  title = list(text = paste("Royalty Income by Book -", input$author_name), font = list(size = 18)),
                  xaxis = list(
                    title = list(text = "Book Title", font = list(size = 16)),
                    tickfont = list(size = 14)
                  ),
                  yaxis = list(
                    title = list(text = "Royalty Income ($)", font = list(size = 16)),
                    tickfont = list(size = 14)
                  ),
                  margin = list(t = 80, b = 100, l = 80, r = 50)
                ) %>%
                config(displayModeBar = TRUE, modeBarButtonsToRemove = c('select2d', 'lasso2d'), displaylogo = FALSE)
            } else {
              plotly_empty("No royalty data available")
            }
          } else {
            plotly_empty("No royalty data available")
          }
        },

        "author_overview" = {
          if ("total_sales" %in% names(results) && nrow(results) > 0) {
            plot_data <- results
            plot_data$book_title <- format_title_catalog_style(plot_data$book_title)
            plot_ly(plot_data, x = ~publication_year, y = ~total_sales, type = "scatter", mode = "markers+lines",
                   text = ~book_title, size = ~total_sales,
                   hovertemplate = "%{text}<br>Year: %{x}<br>Sales: %{y:,}<extra></extra>") %>%
              layout(
                title = list(text = paste("Publication Timeline -", input$author_name), font = list(size = 18)),
                xaxis = list(
                  title = list(text = "Publication Year", font = list(size = 16)),
                  tickfont = list(size = 14)
                ),
                yaxis = list(
                  title = list(text = "Total Sales", font = list(size = 16)),
                  tickfont = list(size = 14)
                ),
                margin = list(t = 80, b = 80, l = 80, r = 50)
              ) %>%
              config(displayModeBar = TRUE, modeBarButtonsToRemove = c('select2d', 'lasso2d'), displaylogo = FALSE)
          } else {
            plotly_empty("No author data available")
          }
        },

        plotly_empty("Select an analysis type")
      )
    })

    # Comparison plot
    output$comparison_plot <- renderPlotly({
      results <- analysis_results()
      if (nrow(results) == 0 || "Error" %in% names(results)) {
        return(plotly_empty("Run an analysis to see comparison"))
      }

      switch(legacy_type(),
        "gender_comparison" = {
          if ("genre" %in% names(results) && "gender" %in% names(results) && nrow(results) > 0) {
            metric <- input$metric_type; if (is.null(metric) || length(metric) == 0) metric <- "total"
            y_col <- if (identical(metric, "average")) "avg_total_sales_per_book" else "total_sales"
            y_title <- if (identical(metric, "average")) "Average Sales per Book" else "Total Sales"

            plot_ly(results, x = ~genre, y = as.formula(paste0("~", y_col)),
                   color = ~gender, type = "bar",
                   colors = c("Male" = "#3498db", "Female" = "#e74c3c"),
                   hovertemplate = paste0("Genre: %{x}<br>Gender: %{color}<br>", y_title, ": %{y:,.0f}<extra></extra>")) %>%
              layout(
                title = list(text = paste("Gender Performance by Genre -", y_title), font = list(size = 18)),
                xaxis = list(
                  title = list(text = "Genre", font = list(size = 16)),
                  tickfont = list(size = 14)
                ),
                yaxis = list(
                  title = list(text = y_title, font = list(size = 16)),
                  tickfont = list(size = 14)
                ),
                legend = list(font = list(size = 14)),
                barmode = "group",
                margin = list(t = 80, b = 80, l = 80, r = 50)
              ) %>%
              config(displayModeBar = TRUE, modeBarButtonsToRemove = c('select2d', 'lasso2d'), displaylogo = FALSE)
          } else {
            plotly_empty("No genre/gender data available")
          }
        },

        "gender_genre" = {
          if (all(c("binding", "gender") %in% names(results)) && nrow(results) > 0) {
            metric <- input$metric_type; if (is.null(metric) || length(metric) == 0) metric <- "total"
            y_col <- if (identical(metric, "average")) "avg_total_sales_per_book" else "total_sales"
            y_title <- if (identical(metric, "average")) "Average Sales per Book" else "Total Sales"

            plot_ly(results, x = ~binding, y = as.formula(paste0("~", y_col)),
                   color = ~gender, type = "bar",
                   colors = c("Male" = "#3498db", "Female" = "#e74c3c"),
                   hovertemplate = paste0("Binding: %{x}<br>Gender: %{color}<br>", y_title, ": %{y:,.0f}<extra></extra>")) %>%
              layout(
                title = list(text = paste("Sales by Binding and Gender -", y_title), font = list(size = 18)),
                xaxis = list(
                  title = list(text = "Binding", font = list(size = 16)),
                  tickfont = list(size = 14)
                ),
                yaxis = list(
                  title = list(text = y_title, font = list(size = 16)),
                  tickfont = list(size = 14)
                ),
                legend = list(font = list(size = 14)),
                barmode = "group",
                margin = list(t = 80, b = 80, l = 80, r = 50)
              ) %>%
              config(displayModeBar = TRUE, modeBarButtonsToRemove = c('select2d', 'lasso2d'), displaylogo = FALSE)
          } else {
            plotly_empty("No binding/gender data available")
          }
        },

        "author_royalty" = {
          if ("book_title" %in% names(results) && "total_sales" %in% names(results) && nrow(results) > 1) {
            plot_data <- results[results$book_id != "TOTAL", ]
            if (nrow(plot_data) > 0) {
              plot_data$book_title <- format_title_catalog_style(plot_data$book_title)
              plot_ly(plot_data, x = ~total_sales, y = ~royalty_income, type = "scatter", mode = "markers",
                     text = ~book_title, size = ~total_sales,
                     hovertemplate = "%{text}<br>Sales: %{x:,}<br>Royalty: $%{y:,.2f}<extra></extra>") %>%
                layout(
                  title = list(text = "Sales vs Royalty Income", font = list(size = 18)),
                  xaxis = list(
                    title = list(text = "Total Sales", font = list(size = 16)),
                    tickfont = list(size = 14)
                  ),
                  yaxis = list(
                    title = list(text = "Royalty Income ($)", font = list(size = 16)),
                    tickfont = list(size = 14)
                  ),
                  margin = list(t = 80, b = 80, l = 80, r = 50)
                ) %>%
                config(displayModeBar = TRUE, modeBarButtonsToRemove = c('select2d', 'lasso2d'), displaylogo = FALSE)
            } else {
              plotly_empty("No comparison data available")
            }
          } else {
            plotly_empty("No comparison data available")
          }
        },

        "author_overview" = {
          if ("genre" %in% names(results) && "total_sales" %in% names(results) && nrow(results) > 0) {
            plot_data <- results
            plot_data$book_title <- format_title_catalog_style(plot_data$book_title)
            plot_ly(plot_data, x = ~genre, y = ~total_sales, type = "bar",
                   hovertemplate = "Genre: %{x}<br>Sales: %{y:,}<br>Book: %{customdata}<extra></extra>",
                   customdata = ~book_title) %>%
              layout(
                title = list(text = paste("Sales by Genre -", input$author_name), font = list(size = 18)),
                xaxis = list(
                  title = list(text = "Genre", font = list(size = 16)),
                  tickfont = list(size = 14)
                ),
                yaxis = list(
                  title = list(text = "Total Sales", font = list(size = 16)),
                  tickfont = list(size = 14)
                ),
                margin = list(t = 80, b = 80, l = 80, r = 50)
              ) %>%
              config(displayModeBar = TRUE, modeBarButtonsToRemove = c('select2d', 'lasso2d'), displaylogo = FALSE)
          } else {
            plotly_empty("No genre data available")
          }
        },

        plotly_empty("Select an analysis type")
      )
    })

    # Download handler
    output$download_results <- downloadHandler(
      filename = function() {
        paste0("author_analysis_", input$analysis_type, "_", Sys.Date(), ".csv")
      },
      content = function(file) {
        results <- analysis_results()
        if (nrow(results) > 0 && !("Error" %in% names(results))) {
          write.csv(results, file, row.names = FALSE)
        }
      }
    )
  })
}