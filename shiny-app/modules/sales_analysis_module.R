# Sales Analysis Module
# Advanced sales analytics with date range filtering and detailed calculations

salesAnalysisUI <- function(id) {
  ns <- NS(id)

  fluidPage(
    h3("Advanced Sales Analytics"),
    p("Comprehensive sales analysis with date range filtering and detailed calculations."),

    # Control Panel
    fluidRow(
      box(
        title = "Analysis Controls", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,

        fluidRow(
          column(3,
            {
              sales_dr <- sales_date_range_args(use_preset = FALSE)
              dateRangeInput(ns("date_range"), "Sales Year Range:",
                            start = sales_dr$start, end = sales_dr$end,
                            min = sales_dr$min, max = sales_dr$max,
                            format = "yyyy")
            }
          ),
          column(3,
            selectInput(ns("analysis_type"), "Analysis Type:",
                       choices = list(
                         "Book Sales by Title & Binding" = "book_sales",
                         "Royalty Income by Book & Binding" = "royalty_book",
                         "Average Sales by Book & Binding" = "avg_book_sales"
                       ),
                       selected = "book_sales")
          ),
          column(3,
            selectizeInput(ns("book_title"), "Book Title:",
                           choices = NULL,
                           multiple = FALSE,
                           options = list(
                             placeholder = "Select or type book title...",
                             create = FALSE,
                             onInitialize = I('function() { this.setValue(""); }')
                           ))
          ),
          column(3,
            selectizeInput(ns("binding_state"), "Binding State:",
                           choices = NULL,
                           multiple = FALSE,
                           options = list(
                             placeholder = "Select or type binding state...",
                             create = FALSE,
                             onInitialize = I('function() { this.setValue(""); }')
                           ))
          )
        ),

        fluidRow(
          column(4,
            br(),
            actionButton(ns("run_analysis"), "Run Analysis",
                        class = "btn-primary", style = "margin-top: 5px;")
          ),
          column(4,
            br(),
            div(style = "margin-top: 5px;",
              h6("Looking for other analytics?"),
              actionButton(ns("view_author_analysis"), "Author & Gender Analysis →",
                          class = "btn-link btn-sm"),
              br(),
              actionButton(ns("view_genre_analysis"), "Genre & Market Analysis →",
                          class = "btn-link btn-sm")
            )
          ),
          column(4,
            br(),
            div(class = "alert alert-info", style = "margin-top: 5px; padding: 10px;",
              h6("Sales Analysis Focus:"),
              p("This module focuses on book-specific sales queries. For author comparisons or genre trends, use the specialized modules.",
                style = "font-size: 12px; margin-bottom: 0;")
            )
          )
        )
      )
    ),

    # Results Section
    fluidRow(
      box(
        title = "Analysis Results", status = "success", solidHeader = TRUE,
        width = 12,

        # Summary info
        uiOutput(ns("analysis_summary")),

        # Results table
        DT::dataTableOutput(ns("results_table")),

        # Download button
        br(),
        downloadButton(ns("download_results"), "Download Results", class = "btn-info")
      )
    ),

    # Visualization Section
    fluidRow(
      box(
        title = "Data Visualization", status = "info", solidHeader = TRUE,
        width = 12,
        plotlyOutput(ns("results_plot"), height = "400px")
      )
    )
  )
}

salesAnalysisServer <- function(id) {
  moduleServer(id, function(input, output, session) {

    # Initialize dropdown options
    observe({
      # Get book titles and binding states for dropdowns
      book_titles <- safe_query(get_book_titles,
                               default_value = data.frame(book_title = character(0)))
      binding_states <- safe_query(get_binding_states,
                                  default_value = data.frame(binding = character(0)))

      # Update book title choices (catalog-style labels; values stay original titles).
      # selected = character(0) prevents selectize from auto-picking the first title.
      if (nrow(book_titles) > 0) {
        updateSelectizeInput(
          session, "book_title",
          choices = make_title_choices(book_titles$book_title),
          selected = character(0),
          server = TRUE
        )
      }

      # Update binding state choices (optional filter — leave empty until user chooses)
      if (nrow(binding_states) > 0) {
        updateSelectizeInput(
          session, "binding_state",
          choices = binding_states$binding,
          selected = character(0),
          server = TRUE
        )
      }
    })

    # Navigation handlers
    observeEvent(input$view_author_analysis, {
      showNotification("Navigate to Author Analysis tab for gender comparisons and author-focused analytics",
                      type = "message", duration = 4)
    })

    observeEvent(input$view_genre_analysis, {
      showNotification("Navigate to Genre Analysis tab for market trends and genre comparisons",
                      type = "message", duration = 4)
    })

    # Reactive values for storing results
    analysis_results <- reactiveVal(data.frame())

    # Convert date range to sales years (shared bounds / resolver)
    year_range <- reactive({
      resolved <- resolve_year_range(input$date_range, default = sales_default_range())
      c(resolved$start, resolved$end)
    })

    # Run analysis when button is clicked
    observeEvent(input$run_analysis, {
      years <- year_range()
      start_year <- years[1]
      end_year <- years[2]

      withProgress(message = "Running analysis...", value = 0, {

        results <- switch(input$analysis_type,
          "book_sales" = {
            incProgress(0.3, detail = "Fetching book sales data...")
            if (is.null(input$book_title) || input$book_title == "") {
              data.frame(Error = "Please enter a book title")
            } else {
              get_book_sales_by_title_binding(
                input$book_title,
                input$binding_state %||% "",
                start_year, end_year
              )
            }
          },

          "royalty_book" = {
            incProgress(0.3, detail = "Calculating royalty income...")
            if (is.null(input$book_title) || input$book_title == "") {
              data.frame(Error = "Please enter a book title")
            } else {
              get_royalty_income_by_book_binding(
                input$book_title,
                input$binding_state %||% "",
                start_year, end_year
              )
            }
          },

          "avg_book_sales" = {
            incProgress(0.3, detail = "Calculating average book sales...")
            if (is.null(input$book_title) || input$book_title == "") {
              data.frame(Error = "Please enter a book title")
            } else {
              get_average_sales_by_book_binding(
                input$book_title,
                input$binding_state %||% "",
                start_year, end_year
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

    # Analysis summary
    output$analysis_summary <- renderUI({
      results <- analysis_results()
      if (nrow(results) == 0) {
        return(div(class = "alert alert-warning", "No analysis run yet. Please select parameters and click 'Run Analysis'."))
      }

      if ("Error" %in% names(results)) {
        return(div(class = "alert alert-danger", paste("Error:", results$Error[1])))
      }

      years <- year_range()
      analysis_name <- switch(input$analysis_type,
        "book_sales" = "Book Sales Analysis",
        "royalty_book" = "Book Royalty Income Analysis",
        "avg_book_sales" = "Average Book Sales Analysis",
        "Book Analysis"
      )

      div(class = "alert alert-info",
        h4(analysis_name),
        p(paste("Date Range:", years[1], "-", years[2])),
        p(paste("Results found:", nrow(results), "records"))
      )
    })

    # Results table
    output$results_table <- DT::renderDataTable({
      results <- analysis_results()
      if (nrow(results) == 0) {
        return(DT::datatable(data.frame(Message = "No data to display"), options = list(dom = 't')))
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
      if ("royalty_income" %in% names(display_results)) {
        display_results$royalty_income <- paste0("USD ", format(round(display_results$royalty_income, 2), big.mark = ","))
      }
      if ("retail_price" %in% names(display_results)) {
        display_results$retail_price <- ifelse(is.na(display_results$retail_price), "N/A",
                                              paste0("USD ", format(display_results$retail_price, digits = 2)))
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

    # Results plot
    output$results_plot <- renderPlotly({
      results <- analysis_results()
      if (nrow(results) == 0 || "Error" %in% names(results)) {
        return(plotly_empty())
      }

      # Create appropriate visualization based on analysis type
      switch(input$analysis_type,
        "book_sales" = {
          if ("total_sales" %in% names(results) && nrow(results) > 0) {
            plot_data <- results
            plot_data$book_title <- format_title_catalog_style(plot_data$book_title)
            plot_ly(plot_data, x = ~book_title, y = ~total_sales, type = "bar",
                   text = ~paste("Author:", author_surname, "<br>Binding:", binding),
                   hovertemplate = "%{text}<br>Sales: %{y:,}<extra></extra>") %>%
              layout(title = "Book Sales by Title", xaxis = list(title = "Book Title"),
                     yaxis = list(title = "Total Sales"))
          } else {
            plotly_empty()
          }
        },

        "royalty_book" = {
          if ("royalty_income" %in% names(results) && nrow(results) > 0) {
            plot_data <- results
            plot_data$book_title <- format_title_catalog_style(plot_data$book_title)
            plot_ly(plot_data, x = ~book_title, y = ~royalty_income, type = "bar",
                   text = ~paste("Sales:", total_sales, "<br>Price: USD", retail_price),
                   hovertemplate = "%{text}<br>Royalty: USD %{y:,.2f}<extra></extra>") %>%
              layout(title = "Royalty Income by Book", xaxis = list(title = "Book Title"),
                     yaxis = list(title = "Royalty Income (USD)"))
          } else {
            plotly_empty()
          }
        },

        "avg_book_sales" = {
          if ("avg_sales_per_year" %in% names(results) && nrow(results) > 0) {
            plot_data <- results
            plot_data$book_title <- format_title_catalog_style(plot_data$book_title)
            plot_ly(plot_data, x = ~book_title, y = ~avg_sales_per_year, type = "bar",
                   text = ~paste("Years:", years_with_sales, "<br>Total:", total_sales),
                   hovertemplate = "%{text}<br>Avg/Year: %{y:.1f}<extra></extra>") %>%
              layout(title = "Average Sales per Year by Book", xaxis = list(title = "Book Title"),
                     yaxis = list(title = "Average Sales per Year"))
          } else {
            plotly_empty()
          }
        },

        plotly_empty("Select an analysis type to see visualization")
      )
    })

    # Download handler
    output$download_results <- downloadHandler(
      filename = function() {
        paste0("sales_analysis_", input$analysis_type, "_", Sys.Date(), ".csv")
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