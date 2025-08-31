# Royalty Income Query Module
# Dedicated module for calculating royalty income from book sales

royaltyQueryUI <- function(id) {
  ns <- NS(id)

  fluidPage(
    h3("Royalty Income Query"),
    p("Calculate royalty income from book sales within a specified date range for specific titles. Optionally filter by binding state or view all formats."),

    # Query Controls
    fluidRow(
      box(
        title = "Query Parameters", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,

        fluidRow(
          column(3,
            sliderInput(
              ns("royalty_year_range"), "Date Range:",
              min = MIN_YEAR, max = MAX_YEAR, value = DEFAULT_YEAR_RANGE,
              step = 1, sep = ""
            ),
            helpText("Select the date range for sales data to include in the royalty calculation.")
          ),
          column(3,
            selectizeInput(
              ns("royalty_book_title"), "Book Title:",
              choices = NULL, multiple = FALSE,
              options = list(
                placeholder = "Search for book title...",
                maxOptions = 200, create = FALSE
              )
            ),
            helpText("Search and select a specific book title.")
          ),
          column(3,
            selectizeInput(
              ns("royalty_binding_state"), "Binding State:",
              choices = NULL, multiple = FALSE,
              options = list(
                placeholder = "All bindings (optional)",
                allowEmptyOption = TRUE,
                clearable = TRUE
              )
            ),
            helpText("Choose a specific binding type or leave blank for all bindings. Click × to clear selection.")
          ),
          column(3,
            br(),
            actionButton(ns("calculate_royalty"), "Calculate Royalty Income", 
                        class = "btn-success btn-lg", style = "margin-top: 5px;"),
            br(), br(),
            div(id = ns("royalty_result_summary"), 
                style = "font-weight: bold; color: #2c3e50; font-size: 16px;")
          )
        )
      )
    ),

    # Results Section
    fluidRow(
      column(8,
        box(title = "Royalty Income Results", status = "success", solidHeader = TRUE,
            width = NULL,
            DT::dataTableOutput(ns("royalty_results_table")),
            br(),
            conditionalPanel(
              condition = "output.royalty_results_available",
              ns = ns,
              downloadButton(ns("download_royalty"), "Download Results", class = "btn-info")
            )
        )
      ),
      column(4,
        box(title = "Calculation Details", status = "info", solidHeader = TRUE,
            width = NULL,
            div(id = ns("calculation_details"), style = "font-size: 14px;"),
            br(),
            h5("Formula:"),
            div(style = "background-color: #f8f9fa; padding: 10px; border-radius: 5px; font-family: monospace;",
                "Royalty Income = Sales Count × Retail Price × Royalty Rate"),
            br(),
            helpText("Note: For books with complex royalty tiers, different rates may apply to different sales volumes.")
        )
      )
    ),

    # Instructions
    fluidRow(
      box(
        title = "How to Use", status = "warning", solidHeader = TRUE,
        width = 12, collapsible = TRUE, collapsed = TRUE,
        
        div(
          h4("Step-by-Step Instructions:"),
          tags$ol(
            tags$li("Select the date range for your query using the slider"),
            tags$li("Search and select a book title from the dropdown"),
            tags$li("Optionally choose a specific binding state, or leave blank to see all formats (use × to clear selection)"),
            tags$li("Click 'Calculate Royalty Income' to run the query"),
            tags$li("View the results in the table below"),
            tags$li("Download the results as CSV if needed")
          ),
          br(),
          h4("Understanding the Results:"),
          tags$ul(
            tags$li(strong("Total Sales:"), " Number of copies sold in the specified date range"),
            tags$li(strong("Retail Price:"), " Price per copy at retail"),
            tags$li(strong("Royalty Income:"), " Total royalty earned (Sales × Price × Rate)")
          )
        )
      )
    )
  )
}

royaltyQueryServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Initialize inputs
    observe({
      # Book titles
      book_titles <- safe_query(function() safe_db_query("SELECT DISTINCT book_title FROM book_entries WHERE book_title IS NOT NULL ORDER BY book_title"),
                               default_value = data.frame(book_title = character(0)))
      if (!is.null(book_titles) && nrow(book_titles) > 0) {
        updateSelectizeInput(session, "royalty_book_title", choices = book_titles$book_title, server = TRUE)
      }

      # Binding states
      bindings <- safe_query(get_binding_states, default_value = data.frame(binding = character(0)))
      if (!is.null(bindings) && nrow(bindings) > 0) {
        binding_choices <- sort(unique(trimws(bindings$binding)))
        updateSelectizeInput(session, "royalty_binding_state", choices = binding_choices, server = TRUE)
      }
    })

    # Royalty calculation reactive
    royalty_results <- eventReactive(input$calculate_royalty, {
      req(input$royalty_book_title, input$royalty_year_range)

      if (is.null(input$royalty_book_title) || input$royalty_book_title == "") {
        return(data.frame())
      }

      waiter <- waiter::Waiter$new(html = waiter::spin_ellipsis(), color = "rgba(255,255,255,0.6)")
      waiter$show()
      on.exit(waiter$hide(), add = TRUE)

      safe_query(function() {
        # If no binding state selected (empty string), pass NULL to get all bindings
        binding_filter <- if (is.null(input$royalty_binding_state) || input$royalty_binding_state == "") {
          NULL
        } else {
          input$royalty_binding_state
        }

        get_royalty_income_by_book_binding_flexible(
          book_title = input$royalty_book_title,
          binding_state = binding_filter,
          start_year = input$royalty_year_range[1],
          end_year = input$royalty_year_range[2]
        )
      }, default_value = data.frame())
    })

    # Results table
    output$royalty_results_table <- DT::renderDataTable({
      results <- royalty_results()
      if (is.null(results) || nrow(results) == 0) {
        return(DT::datatable(data.frame(Message = "No royalty data found for the selected criteria"), 
                            options = list(dom = 't')))
      }
      
      # Format the results for display
      display_results <- results %>%
        dplyr::mutate(
          `Total Sales` = format_number(total_sales),
          `Retail Price` = paste0("$", sprintf("%.2f", retail_price)),
          `Royalty Income` = paste0("$", sprintf("%.2f", royalty_income))
        ) %>%
        dplyr::select(
          `Book Title` = book_title,
          `Author` = author_surname,
          `Binding` = binding,
          `Total Sales`,
          `Retail Price`,
          `Royalty Income`
        )
      
      DT::datatable(display_results, 
                   options = list(pageLength = 10, scrollX = TRUE, dom = 'Bfrtip', 
                                 buttons = c('copy','csv','excel')), 
                   rownames = FALSE)
    })

    # Result summary
    output$royalty_result_summary <- renderText({
      results <- royalty_results()
      if (is.null(results) || nrow(results) == 0) {
        return("")
      }
      
      total_income <- sum(results$royalty_income, na.rm = TRUE)
      total_sales <- sum(results$total_sales, na.rm = TRUE)
      book_count <- nrow(results)
      
      paste0("Found ", book_count, " book(s) with ", format_number(total_sales), 
             " total sales generating $", sprintf("%.2f", total_income), " in royalty income")
    })

    # Calculation details
    output$calculation_details <- renderUI({
      results <- royalty_results()
      if (is.null(results) || nrow(results) == 0) {
        return(div("Run a query to see calculation details."))
      }

      # Show details for the first result
      result <- results[1, ]

      div(
        h5("Sample Calculation:"),
        p(strong("Book:"), result$book_title),
        p(strong("Binding:"), result$binding),
        p(strong("Sales:"), format_number(result$total_sales), "copies"),
        p(strong("Retail Price:"), paste0("$", sprintf("%.2f", result$retail_price))),
        p(strong("Calculation:"),
          paste0(format_number(result$total_sales), " × $", sprintf("%.2f", result$retail_price),
                 " × rate = $", sprintf("%.2f", result$royalty_income))),
        if (nrow(results) > 1) {
          p(em("Note: Multiple binding formats found. Each row shows separate calculations."))
        }
      )
    })

    # Check if results are available
    output$royalty_results_available <- reactive({
      results <- royalty_results()
      !is.null(results) && nrow(results) > 0
    })
    outputOptions(output, "royalty_results_available", suspendWhenHidden = FALSE)

    # Download handler
    output$download_royalty <- downloadHandler(
      filename = function() paste0("royalty_income_", Sys.Date(), ".csv"),
      content = function(file) {
        results <- royalty_results()
        if (!is.null(results) && nrow(results) > 0) {
          utils::write.csv(results, file, row.names = FALSE)
        }
      }
    )
  })
}
