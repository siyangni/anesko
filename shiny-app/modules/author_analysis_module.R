# Author Analysis Module
# Gender analysis and author performance metrics

authorAnalysisUI <- function(id) {
  ns <- NS(id)

  fluidPage(
    h3("Author & Gender Analysis"),
    p("Comprehensive analysis of author performance, gender disparities, and career metrics."),

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
                         "Gender Performance Comparison" = "gender_comparison",
                         "Author Royalty Income Analysis" = "author_royalty",
                         "Gender by Genre Analysis" = "gender_genre",
                         "Author Career Overview" = "author_overview"
                       ),
                       selected = "gender_comparison")
          ),
          column(3,
            conditionalPanel(
              condition = "input.analysis_type == 'author_royalty' || input.analysis_type == 'author_overview'",
              ns = ns,
              tagList(
                selectizeInput(ns("author_name"), "Author Surname:",
                               choices = NULL,
                               multiple = FALSE,
                               options = list(
                                 placeholder = "Select author surname...",
                                 create = TRUE,
                                 persist = TRUE
                               )),
                br(),
                selectizeInput(ns("author_id"), "Author ID:",
                               choices = NULL,
                               multiple = FALSE,
                               options = list(
                                 placeholder = "Select author ID (optional)...",
                                 create = FALSE,
                                 persist = TRUE
                               ))
              )
            ),
            conditionalPanel(
              condition = "input.analysis_type == 'gender_comparison' || input.analysis_type == 'gender_genre'",
              ns = ns,
              selectInput(ns("gender_filter"), "Focus on Gender:",
                         choices = list("Compare Both" = "", "Male Authors" = "Male", "Female Authors" = "Female"),
                         selected = "")
            )
          ),
          column(3,
            conditionalPanel(
              condition = "input.analysis_type == 'gender_comparison' || input.analysis_type == 'gender_genre'",
              ns = ns,
              selectInput(ns("genre_filter"), "Genre Focus:",
                         choices = NULL, multiple = FALSE)
            ),
            conditionalPanel(
              condition = "input.analysis_type == 'gender_comparison' || input.analysis_type == 'gender_genre'",
              ns = ns,
              tagList(
                selectizeInput(ns("binding_filter"), "Binding Type:",
                               choices = NULL,
                               multiple = FALSE,
                               options = list(
                                 placeholder = "Select or type binding type...",
                                 create = FALSE
                               )),
                helpText("Hint: try 'cloth', 'paper'"),
                actionButton(ns("clear_binding"), "Clear", class = "btn-link btn-sm")
              )
            )
          )
        ),

        fluidRow(
          column(4,
            conditionalPanel(
              condition = "input.analysis_type == 'gender_comparison'",
              ns = ns,
              radioButtons(ns("metric_type"), "Metric:",
                          choices = list("Average Sales" = "average", "Total Sales" = "total"),
                          selected = "average", inline = TRUE)
            )
          ),
          column(4,
            br(),
            actionButton(ns("run_analysis"), "Run Analysis",
                        class = "btn-primary", style = "margin-top: 5px;")
          ),
          column(4,
            br(),
            div(style = "margin-top: 5px;",
              actionButton(ns("view_genre_analysis"), "View in Genre Analysis →",
                          class = "btn-link btn-sm"),
              br(),
              actionButton(ns("view_sales_analysis"), "View in Sales Analysis →",
                          class = "btn-link btn-sm")
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
          title = "Key Insights", status = "info", solidHeader = TRUE,
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

    # Initialize genre choices and binding states
    observe({
      # Genre choices
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

      # Binding states for gender_comparison
      binding_states <- safe_query(get_binding_states,
                                   default_value = data.frame(binding = character(0)))
      if (nrow(binding_states) > 0) {
        # Normalize casing and sort alphabetically
        bindings <- binding_states$binding
        bindings <- sort(unique(stringr::str_to_title(trimws(bindings))))
        updateSelectizeInput(session, "binding_filter",
                             choices = c("All Binding Types" = "", stats::setNames(bindings, bindings)),
                             selected = "",
                             server = TRUE)
      }

      # Author surname choices for royalty/overview analyses
      author_choices <- safe_query(function() {
        query <- "
          SELECT
            be.author_surname,
            COUNT(*) AS book_count,
            COALESCE(SUM(bs.total_sales), 0) AS total_sales
          FROM book_entries be
          LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
          WHERE be.author_surname IS NOT NULL
            AND (
              be.royalty_rate IS NOT NULL OR
              EXISTS (SELECT 1 FROM royalty_tiers rt WHERE rt.book_id = be.book_id)
            )
          GROUP BY be.author_surname
          HAVING COUNT(*) >= 1
          ORDER BY book_count DESC, total_sales DESC, be.author_surname
          LIMIT 200
        "
        df <- safe_db_query(query)
        if (!is.null(df) && nrow(df) > 0) {
          labels <- paste0(df$author_surname, " (", df$book_count, ifelse(df$book_count == 1, " book", " books"), ")")



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
                         persist = TRUE
                       ))
      })

      # Populate Author ID choices after a surname is selected
      observeEvent(input$author_name, {
        surname <- input$author_name
        if (is.null(surname) || identical(surname, "")) {
          updateSelectizeInput(session, "author_id", choices = character(0), selected = NULL, server = TRUE)
          return()
        }
        id_df <- safe_query(function() {
          q <- "
            SELECT DISTINCT be.author_id, be.author_surname, COUNT(*) AS book_count
            FROM book_entries be
            WHERE be.author_surname = $1 AND be.author_id IS NOT NULL
            GROUP BY be.author_id, be.author_surname
            ORDER BY book_count DESC, be.author_id
          "
          safe_db_query(q, params = list(surname))


        }, default_value = data.frame(author_id = character(0), author_surname = character(0), book_count = integer(0)))
        if (!is.null(id_df) && nrow(id_df) > 0) {
          labels <- paste0(id_df$author_id, " (", id_df$author_surname, ", ", id_df$book_count,
                           ifelse(id_df$book_count == 1, " book)", " books)"))
          choices <- stats::setNames(id_df$author_id, labels)
          updateSelectizeInput(session, "author_id", choices = choices, selected = NULL, server = TRUE)
        } else {
          updateSelectizeInput(session, "author_id", choices = character(0), selected = NULL, server = TRUE)
        }
      })

          return(stats::setNames(df$author_surname, labels))
        }
        return(character(0))
      }, default_value = character(0))

      updateSelectizeInput(
        session, "author_name",
        choices = author_choices,
        selected = NULL,
        server = TRUE
      )

      binding_states <- safe_query(get_binding_states,
                                   default_value = data.frame(binding = character(0)))
      if (nrow(binding_states) > 0) {
        updateSelectizeInput(session, "binding_filter",
                             choices = binding_states$binding,
                             server = TRUE)
      }
    })

    # Reactive values for storing results
    analysis_results <- reactiveVal(data.frame())

    # Convert date range to years
    year_range <- reactive({
      dates <- input$date_range
      if (is.null(dates) || length(dates) != 2) {
        return(c(1860, 1920))
      }
      c(as.numeric(format(dates[1], "%Y")), as.numeric(format(dates[2], "%Y")))
    })

    # Navigation handlers
    observeEvent(input$view_genre_analysis, {
      showNotification("Navigate to Genre Analysis tab to explore genre-focused analytics",
                      type = "message", duration = 3)
    })

    observeEvent(input$view_sales_analysis, {
      showNotification("Navigate to Sales Analysis tab to explore book-specific analytics",
                      type = "message", duration = 3)
    })

    # Run analysis when button is clicked

	    # Populate Author ID choices after a surname is selected
	    observeEvent(input$author_name, {
	      surname <- input$author_name
	      if (is.null(surname) || identical(surname, "")) {
	        updateSelectizeInput(session, "author_id",
	                             choices = character(0), selected = NULL, server = TRUE)
	        return()
	      }
	      id_df <- safe_query(function() {
	        q <- "
	          SELECT DISTINCT be.author_id, be.author_surname, COUNT(*) AS book_count
	          FROM book_entries be
	          WHERE be.author_surname = $1 AND be.author_id IS NOT NULL
	          GROUP BY be.author_id, be.author_surname
	          ORDER BY book_count DESC, be.author_id
	        "
	        safe_db_query(q, params = list(surname))
	      }, default_value = data.frame(author_id = character(0), author_surname = character(0), book_count = integer(0)))
	      if (!is.null(id_df) && nrow(id_df) > 0) {
	        labels <- paste0(id_df$author_id, " (", id_df$author_surname, ", ", id_df$book_count,
	                         ifelse(id_df$book_count == 1, " book)", " books)"))
	        choices <- stats::setNames(id_df$author_id, labels)
	        updateSelectizeInput(session, "author_id", choices = choices, selected = NULL, server = TRUE)
	      } else {
	        updateSelectizeInput(session, "author_id", choices = character(0), selected = NULL, server = TRUE)
	      }
	    })

    observeEvent(input$run_analysis, {
      years <- year_range()
      start_year <- years[1]
      end_year <- years[2]

      withProgress(message = "Running author analysis...", value = 0, {

        results <- switch(input$analysis_type,
          "gender_comparison" = {
            incProgress(0.3, detail = "Analyzing gender performance...")
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
            get_total_sales_by_binding_genre_gender(
              input$binding_filter %||% NULL,
              input$genre_filter %||% NULL,
              input$gender_filter %||% NULL,
              start_year, end_year
            )
          },

          "author_overview" = {
            incProgress(0.3, detail = "Generating author overview...")
            if (is.null(input$author_name) || input$author_name == "") {
              data.frame(Error = "Please enter an author surname")
            } else {
              # Get comprehensive author data
              query <- "
                SELECT
                  be.book_id,
                  be.book_title,
                  be.author_surname,
                  be.genre,
                  be.binding,
                  be.publication_year,
                  be.retail_price,
                  be.royalty_rate,
                  COALESCE(bs.total_sales, 0) as total_sales,
                  COALESCE(bs.years_with_sales, 0) as years_with_sales,
                  bs.first_sale_year,
                  bs.last_sale_year
                FROM book_entries be
                LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
                WHERE (
                  CASE WHEN $1 IS NOT NULL AND $1 <> '' THEN be.author_id = $1 ELSE TRUE END
                ) AND (
                  CASE WHEN $2 IS NOT NULL AND $2 <> '' THEN LOWER(be.author_surname) LIKE LOWER($2) ELSE TRUE END
                )
                  AND be.publication_year BETWEEN $3 AND $4
                ORDER BY be.publication_year, be.book_title
              "
              safe_db_query(query, params = list(
                input$author_id %||% NULL,
                paste0("%", input$author_name, "%"),
                start_year, end_year
              ))
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

      boxes <- switch(input$analysis_type,
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

        NULL
      )

      boxes
    })

    # Insights panel
    output$insights_panel <- renderUI({
      results <- analysis_results()
      if (nrow(results) == 0 || "Error" %in% names(results)) {
        return(div(class = "alert alert-warning", "Run an analysis to see insights"))
      }

      insights <- switch(input$analysis_type,
        "gender_comparison" = {
          if (nrow(results) > 0 && "gender" %in% names(results)) {
            male_data <- results[results$gender == "Male", ]
            female_data <- results[results$gender == "Female", ]

            tagList(
              h5("Gender Analysis Insights:"),
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
                    p(paste("Male authors averaged", round(male_avg, 0), "sales per book")),
                    p(paste("Female authors averaged", round(female_avg, 0), "sales per book")),
                    p(comparison_msg)
                  )
                } else {
                  male_total <- sum(male_data$total_sales, na.rm = TRUE)
                  female_total <- sum(female_data$total_sales, na.rm = TRUE)
                  tagList(
                    p(paste("Male authors:", format(male_total, big.mark = ","), "total sales")),
                    p(paste("Female authors:", format(female_total, big.mark = ","), "total sales")),
                    p(paste("Female market share:", round(female_total/(male_total + female_total) * 100, 1), "%"))
                  )
                }
              } else {
                p("Insufficient data for gender comparison")
              }
            )
          } else {
            p("No gender data available")
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
                p(paste("Best performing book:", best_book$book_title[1],
                       "($", format(round(best_book$royalty_income[1], 2), big.mark = ","), ")"))
              }
            )
          } else {
            p("No royalty data available")
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
              p(paste("Total sales:", format(total_sales, big.mark = ","), "copies")),
              if (nrow(results) > 0) {
                best_book <- results[which.max(results$total_sales), ]
                p(paste("Best seller:", best_book$book_title[1],
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

      switch(input$analysis_type,
        "gender_comparison" = {
          if ("gender" %in% names(results) && nrow(results) > 0) {
            y_col <- if (input$metric_type == "average") "avg_total_sales_per_book" else "total_sales"
            y_title <- if (input$metric_type == "average") "Average Sales per Book" else "Total Sales"

            plot_ly(results, x = ~gender, y = as.formula(paste0("~", y_col)),
                   type = "bar", color = ~gender,
                   colors = c("Male" = "#3498db", "Female" = "#e74c3c"),
                   text = ~paste("Books:", book_count),
                   hovertemplate = paste0("%{text}<br>", y_title, ": %{y:,.0f}<extra></extra>")) %>%
              layout(title = paste("Sales by Gender -", y_title),
                     xaxis = list(title = "Author Gender"),
                     yaxis = list(title = y_title))
          } else {
            plotly_empty("No gender data available")
          }
        },

        "author_royalty" = {
          if ("royalty_income" %in% names(results) && nrow(results) > 1) {
            plot_data <- results[results$book_id != "TOTAL", ]
            if (nrow(plot_data) > 0) {
              plot_ly(plot_data, x = ~book_title, y = ~royalty_income, type = "bar",
                     text = ~paste("Sales:", total_sales),
                     hovertemplate = "%{text}<br>Royalty: $%{y:,.2f}<extra></extra>") %>%
                layout(title = paste("Royalty Income by Book -", input$author_name),
                       xaxis = list(title = "Book Title"),
                       yaxis = list(title = "Royalty Income ($)"))
            } else {
              plotly_empty("No royalty data available")
            }
          } else {
            plotly_empty("No royalty data available")
          }
        },

        "author_overview" = {
          if ("total_sales" %in% names(results) && nrow(results) > 0) {
            plot_ly(results, x = ~publication_year, y = ~total_sales, type = "scatter", mode = "markers+lines",
                   text = ~book_title, size = ~total_sales,
                   hovertemplate = "%{text}<br>Year: %{x}<br>Sales: %{y:,}<extra></extra>") %>%
              layout(title = paste("Publication Timeline -", input$author_name),
                     xaxis = list(title = "Publication Year"),
                     yaxis = list(title = "Total Sales"))
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

      switch(input$analysis_type,
        "gender_comparison" = {
          if ("genre" %in% names(results) && "gender" %in% names(results) && nrow(results) > 0) {
            y_col <- if (input$metric_type == "average") "avg_total_sales_per_book" else "total_sales"
            y_title <- if (input$metric_type == "average") "Average Sales per Book" else "Total Sales"

            plot_ly(results, x = ~genre, y = as.formula(paste0("~", y_col)),
                   color = ~gender, type = "bar",
                   colors = c("Male" = "#3498db", "Female" = "#e74c3c"),
                   hovertemplate = paste0("Genre: %{x}<br>Gender: %{color}<br>", y_title, ": %{y:,.0f}<extra></extra>")) %>%
              layout(title = paste("Gender Performance by Genre -", y_title),
                     xaxis = list(title = "Genre"),
                     yaxis = list(title = y_title),
                     barmode = "group")
          } else {
            plotly_empty("No genre/gender data available")
          }
        },

        "author_royalty" = {
          if ("book_title" %in% names(results) && "total_sales" %in% names(results) && nrow(results) > 1) {
            plot_data <- results[results$book_id != "TOTAL", ]
            if (nrow(plot_data) > 0) {
              plot_ly(plot_data, x = ~total_sales, y = ~royalty_income, type = "scatter", mode = "markers",
                     text = ~book_title, size = ~total_sales,
                     hovertemplate = "%{text}<br>Sales: %{x:,}<br>Royalty: $%{y:,.2f}<extra></extra>") %>%
                layout(title = "Sales vs Royalty Income",
                       xaxis = list(title = "Total Sales"),
                       yaxis = list(title = "Royalty Income ($)"))
            } else {
              plotly_empty("No comparison data available")
            }
          } else {
            plotly_empty("No comparison data available")
          }
        },

        "author_overview" = {
          if ("genre" %in% names(results) && "total_sales" %in% names(results) && nrow(results) > 0) {
            plot_ly(results, x = ~genre, y = ~total_sales, type = "bar",
                   text = ~book_title,
                   hovertemplate = "%{text}<br>Genre: %{x}<br>Sales: %{y:,}<extra></extra>") %>%
              layout(title = paste("Sales by Genre -", input$author_name),
                     xaxis = list(title = "Genre"),
                     yaxis = list(title = "Total Sales"))
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