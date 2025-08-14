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
                         "Genre Performance Comparison" = "genre_comparison",
                         "Market Share Analysis" = "market_share",
                         "Genre by Gender Analysis" = "genre_gender",
                         "Binding Format Analysis" = "binding_analysis"
                       ),
                       selected = "genre_comparison")
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
            textInput(ns("binding_filter"), "Binding Type:",
                     placeholder = "e.g., cloth, paper...")
          ),
          column(3,
            conditionalPanel(
              condition = "input.analysis_type == 'genre_comparison' || input.analysis_type == 'genre_gender'",
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
    observeEvent(input$view_author_analysis, {
      showNotification("Navigate to Author Analysis tab to explore author-focused analytics",
                      type = "message", duration = 3)
    })

    observeEvent(input$view_sales_analysis, {
      showNotification("Navigate to Sales Analysis tab to explore book-specific analytics",
                      type = "message", duration = 3)
    })

    # Run analysis when button is clicked
    observeEvent(input$run_analysis, {
      years <- year_range()
      start_year <- years[1]
      end_year <- years[2]

      withProgress(message = "Running genre analysis...", value = 0, {

        results <- switch(input$analysis_type,
          "genre_comparison" = {
            incProgress(0.3, detail = "Analyzing genre performance...")
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

          "market_share" = {
            incProgress(0.3, detail = "Calculating market share...")
            result <- get_total_sales_by_binding_genre_gender(
              input$binding_filter %||% NULL,
              input$genre_filter %||% NULL,
              input$gender_filter %||% NULL,
              start_year, end_year
            )

            # Calculate market share percentages
            if (nrow(result) > 0 && "total_sales" %in% names(result)) {
              total_market <- sum(result$total_sales, na.rm = TRUE)
              result$market_share_pct <- round((result$total_sales / total_market) * 100, 2)
              result$cumulative_share <- cumsum(result$market_share_pct)
            }
            result
          },

          "genre_gender" = {
            incProgress(0.3, detail = "Analyzing genre by gender...")
            get_total_sales_by_binding_genre_gender(
              input$binding_filter %||% NULL,
              input$genre_filter %||% NULL,
              input$gender_filter %||% NULL,
              start_year, end_year
            )
          },

          "binding_analysis" = {
            incProgress(0.3, detail = "Analyzing binding formats...")
            get_total_sales_by_binding_genre_gender(
              input$binding_filter %||% NULL,
              input$genre_filter %||% NULL,
              input$gender_filter %||% NULL,
              start_year, end_year
            )
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
        "genre_comparison" = {
          if ("genre" %in% names(results) && nrow(results) > 0) {
            top_genre <- results[which.max(results$total_sales), ]
            total_sales <- sum(results$total_sales, na.rm = TRUE)
            avg_sales <- mean(results$total_sales, na.rm = TRUE)

            fluidRow(
              column(4, create_value_box(
                value = top_genre$genre[1],
                subtitle = "Top Performing Genre",
                icon = "crown",
                color = "yellow"
              )),
              column(4, create_value_box(
                value = total_sales,
                subtitle = "Total Market Sales",
                icon = "chart-line",
                color = "green"
              )),
              column(4, create_value_box(
                value = nrow(results),
                subtitle = "Genres Analyzed",
                icon = "list",
                color = "blue"
              ))
            )
          }
        },

        "market_share" = {
          if ("market_share_pct" %in% names(results) && nrow(results) > 0) {
            top_genre <- results[1, ]  # Already sorted by total sales
            total_genres <- nrow(results)
            top_3_share <- sum(results$market_share_pct[1:min(3, nrow(results))], na.rm = TRUE)

            fluidRow(
              column(4, create_value_box(
                value = paste0(round(top_genre$market_share_pct[1], 1), "%"),
                subtitle = paste("Market Leader:", top_genre$genre[1]),
                icon = "trophy",
                color = "gold"
              )),
              column(4, create_value_box(
                value = paste0(round(top_3_share, 1), "%"),
                subtitle = "Top 3 Genres Share",
                icon = "chart-pie",
                color = "purple"
              )),
              column(4, create_value_box(
                value = total_genres,
                subtitle = "Total Genres",
                icon = "layer-group",
                color = "blue"
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

      insights <- switch(input$analysis_type,
        "genre_comparison" = {
          if (nrow(results) > 0 && "genre" %in% names(results)) {
            top_genre <- results[which.max(results$total_sales), ]
            bottom_genre <- results[which.min(results$total_sales), ]

            tagList(
              h5("Genre Performance Insights:"),
              p(paste("Best performing genre:", top_genre$genre[1])),
              p(paste("Sales:", format(top_genre$total_sales[1], big.mark = ","), "copies")),
              p(paste("Books published:", top_genre$book_count[1])),
              hr(),
              p(paste("Lowest performing:", bottom_genre$genre[1])),
              p(paste("Performance gap:",
                     format(top_genre$total_sales[1] - bottom_genre$total_sales[1], big.mark = ","),
                     "copies"))
            )
          } else {
            p("No genre data available")
          }
        },

        "market_share" = {
          if (nrow(results) > 0 && "market_share_pct" %in% names(results)) {
            top_3 <- head(results, 3)
            concentration <- sum(top_3$market_share_pct, na.rm = TRUE)

            tagList(
              h5("Market Share Insights:"),
              p(paste("Market concentration: Top 3 genres control",
                     round(concentration, 1), "% of sales")),
              hr(),
              h6("Top 3 Genres:"),
              tags$ol(
                lapply(1:min(3, nrow(top_3)), function(i) {
                  tags$li(paste(top_3$genre[i], "-", round(top_3$market_share_pct[i], 1), "%"))
                })
              )
            )
          } else {
            p("No market share data available")
          }
        },

        "genre_gender" = {
          if (nrow(results) > 0 && "gender" %in% names(results) && "genre" %in% names(results)) {
            male_total <- sum(results[results$gender == "Male", "total_sales"], na.rm = TRUE)
            female_total <- sum(results[results$gender == "Female", "total_sales"], na.rm = TRUE)

            tagList(
              h5("Genre & Gender Insights:"),
              p(paste("Male authors total sales:", format(male_total, big.mark = ","))),
              p(paste("Female authors total sales:", format(female_total, big.mark = ","))),
              p(paste("Female market share:",
                     round(female_total/(male_total + female_total) * 100, 1), "%")),
              hr(),
              if (nrow(results) > 0) {
                best_combo <- results[which.max(results$total_sales), ]
                p(paste("Best performing combination:",
                       best_combo$gender[1], "authors in", best_combo$genre[1]))
              }
            )
          } else {
            p("No genre/gender data available")
          }
        },

        "binding_analysis" = {
          if (nrow(results) > 0 && "binding" %in% names(results)) {
            binding_summary <- aggregate(total_sales ~ binding, results, sum)
            top_binding <- binding_summary[which.max(binding_summary$total_sales), ]

            tagList(
              h5("Binding Format Insights:"),
              p(paste("Most popular binding:", top_binding$binding[1])),
              p(paste("Sales:", format(top_binding$total_sales[1], big.mark = ","), "copies")),
              hr(),
              h6("Binding Performance:"),
              tags$ul(
                lapply(1:nrow(binding_summary), function(i) {
                  tags$li(paste(binding_summary$binding[i], "-",
                               format(binding_summary$total_sales[i], big.mark = ","), "copies"))
                })
              )
            )
          } else {
            p("No binding data available")
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

    # Main plot
    output$main_plot <- renderPlotly({
      results <- analysis_results()
      if (nrow(results) == 0 || "Error" %in% names(results)) {
        return(plotly_empty("Run an analysis to see visualization"))
      }

      switch(input$analysis_type,
        "genre_comparison" = {
          if ("genre" %in% names(results) && "total_sales" %in% names(results) && nrow(results) > 0) {
            y_col <- if (input$metric_type == "average") "avg_total_sales_per_book" else "total_sales"
            y_title <- if (input$metric_type == "average") "Average Sales per Book" else "Total Sales"

            plot_ly(results, x = ~genre, y = as.formula(paste0("~", y_col)),
                   type = "bar", text = ~paste("Books:", book_count),
                   hovertemplate = paste0("%{text}<br>", y_title, ": %{y:,.0f}<extra></extra>")) %>%
              layout(title = paste("Genre Performance -", y_title),
                     xaxis = list(title = "Genre"),
                     yaxis = list(title = y_title))
          } else {
            plotly_empty("No genre data available")
          }
        },

        "market_share" = {
          if ("market_share_pct" %in% names(results) && nrow(results) > 0) {
            plot_ly(results, labels = ~genre, values = ~market_share_pct, type = "pie",
                   textinfo = "label+percent",
                   hovertemplate = "%{label}<br>%{percent}<br>Sales: %{value}%<extra></extra>") %>%
              layout(title = "Market Share by Genre")
          } else {
            plotly_empty("No market share data available")
          }
        },

        "genre_gender" = {
          if ("genre" %in% names(results) && "gender" %in% names(results) && nrow(results) > 0) {
            plot_ly(results, x = ~genre, y = ~total_sales, color = ~gender, type = "bar",
                   colors = c("Male" = "#3498db", "Female" = "#e74c3c"),
                   hovertemplate = "Genre: %{x}<br>Gender: %{color}<br>Sales: %{y:,}<extra></extra>") %>%
              layout(title = "Genre Performance by Gender",
                     xaxis = list(title = "Genre"),
                     yaxis = list(title = "Total Sales"),
                     barmode = "group")
          } else {
            plotly_empty("No genre/gender data available")
          }
        },

        "binding_analysis" = {
          if ("binding" %in% names(results) && "total_sales" %in% names(results) && nrow(results) > 0) {
            plot_ly(results, x = ~binding, y = ~total_sales, type = "bar",
                   text = ~paste("Books:", book_count),
                   hovertemplate = "%{text}<br>Sales: %{y:,}<extra></extra>") %>%
              layout(title = "Sales by Binding Format",
                     xaxis = list(title = "Binding Format"),
                     yaxis = list(title = "Total Sales"))
          } else {
            plotly_empty("No binding data available")
          }
        },

        plotly_empty("Select an analysis type")
      )
    })

    # Trend plot
    output$trend_plot <- renderPlotly({
      results <- analysis_results()
      if (nrow(results) == 0 || "Error" %in% names(results)) {
        return(plotly_empty("Run an analysis to see trends"))
      }

      # For trend analysis, we need time-series data
      # This is a simplified version - in a real implementation, you'd want to get sales by year
      switch(input$analysis_type,
        "genre_comparison" = {
          if ("genre" %in% names(results) && "book_count" %in% names(results) && nrow(results) > 0) {
            plot_ly(results, x = ~book_count, y = ~total_sales, text = ~genre, type = "scatter", mode = "markers+text",
                   textposition = "top center",
                   hovertemplate = "%{text}<br>Books: %{x}<br>Sales: %{y:,}<extra></extra>") %>%
              layout(title = "Books Published vs Total Sales",
                     xaxis = list(title = "Number of Books Published"),
                     yaxis = list(title = "Total Sales"))
          } else {
            plotly_empty("No trend data available")
          }
        },

        "market_share" = {
          if ("cumulative_share" %in% names(results) && nrow(results) > 0) {
            results$rank <- 1:nrow(results)
            plot_ly(results, x = ~rank, y = ~cumulative_share, type = "scatter", mode = "lines+markers",
                   text = ~genre,
                   hovertemplate = "%{text}<br>Rank: %{x}<br>Cumulative: %{y:.1f}%<extra></extra>") %>%
              layout(title = "Cumulative Market Share",
                     xaxis = list(title = "Genre Rank"),
                     yaxis = list(title = "Cumulative Market Share (%)"))
          } else {
            plotly_empty("No cumulative data available")
          }
        },

        plotly_empty("Trend analysis not available for this analysis type")
      )
    })

    # Download handler
    output$download_results <- downloadHandler(
      filename = function() {
        paste0("genre_analysis_", input$analysis_type, "_", Sys.Date(), ".csv")
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