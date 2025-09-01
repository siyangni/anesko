# Royalty Income Query Module
# Dedicated module for calculating royalty income from book sales

royaltyQueryUI <- function(id) {
  ns <- NS(id)

  fluidPage(
    h3("Royalty Income Query"),
    p("Calculate royalty income from book sales within a specified date range. Choose between book-specific queries or author-wide summaries."),

    # Query Type Selection
    fluidRow(
      box(
        title = "Query Type", status = "info", solidHeader = TRUE,
        width = 12,
        radioButtons(
          ns("query_type"), "Select Query Type:",
          choices = list(
            "Book-Specific Royalty" = "book",
            "Author Total Royalty" = "author"
          ),
          selected = "book",
          inline = TRUE
        )
      )
    ),

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

          # Book-specific inputs (conditional)
          conditionalPanel(
            condition = "input.query_type == 'book'",
            ns = ns,
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
            )
          ),

          # Author-specific inputs (conditional)
          conditionalPanel(
            condition = "input.query_type == 'author'",
            ns = ns,
            column(3,
              selectizeInput(
                ns("royalty_author_name"), "Author Surname:",
                choices = NULL, multiple = FALSE,
                options = list(
                  placeholder = "Search for author surname...",
                  maxOptions = 200, create = TRUE
                )
              ),
              helpText("Search and select an author surname.")
            ),
            column(3,
              selectizeInput(
                ns("royalty_author_id"), "Author ID (optional):",
                choices = NULL, multiple = FALSE,
                options = list(
                  placeholder = "Select author ID (optional)...",
                  create = FALSE
                )
              ),
              helpText("Optional: Select specific author ID if multiple exist.")
            )
          ),

          column(3,
            br(),
            actionButton(ns("calculate_royalty"), "Calculate Royalty Income",
                        class = "btn-success btn-lg", style = "margin-top: 5px;"),
            br(), br(),
            div(style = "font-weight: bold; color: #2c3e50; font-size: 16px;",
                textOutput(ns("royalty_result_summary"))
            )
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
                conditionalPanel(
                  condition = "input.query_type == 'book'",
                  ns = ns,
                  "Book Royalty Income = Sales Count × Retail Price × Royalty Rate"
                ),
                conditionalPanel(
                  condition = "input.query_type == 'author'",
                  ns = ns,
                  "Author Total Royalty = sum over books of (Sales × Retail Price × Royalty Rate)"
                )
            ),
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

      # Author surnames (for author royalty summary)
      author_choices <- safe_query(function() {
        query <- "
          SELECT
            be.author_surname,
            COUNT(DISTINCT be.book_id) AS book_count,
            COALESCE(SUM(bs.total_sales), 0) AS total_sales
          FROM book_entries be
          LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
          WHERE be.author_surname IS NOT NULL
          GROUP BY be.author_surname
          HAVING COUNT(*) >= 1
          ORDER BY book_count DESC, total_sales DESC, be.author_surname
          LIMIT 200
        "
        df <- safe_db_query(query)
        if (!is.null(df) && nrow(df) > 0) {
          labels <- paste0(df$author_surname, " (", df$book_count,
                           ifelse(df$book_count == 1, " book", " books"), ")")
          choices <- stats::setNames(df$author_surname, labels)
          return(choices)
        }
        return(character(0))
      }, default_value = character(0))
      updateSelectizeInput(session, "royalty_author_name", choices = author_choices, server = TRUE)

      # Clear author ID when surname cleared; populate when selected
      observeEvent(input$royalty_author_name, {
        surname <- input$royalty_author_name
        if (is.null(surname) || identical(surname, "")) {
          updateSelectizeInput(session, "royalty_author_id", choices = character(0), selected = NULL, server = TRUE)
          return()
        }
        id_df <- safe_query(function() {
          q <- "
            SELECT DISTINCT be.author_id, be.author_surname, COUNT(DISTINCT be.book_id) AS book_count
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
          updateSelectizeInput(session, "royalty_author_id", choices = choices, selected = NULL, server = TRUE)
        } else {
          updateSelectizeInput(session, "royalty_author_id", choices = character(0), selected = NULL, server = TRUE)
        }
      }, ignoreInit = TRUE)
    })

    # Combined royalty calculation reactive for both book and author queries
    royalty_results <- eventReactive(input$calculate_royalty, {
      # Check if we're doing an author query or book query
      if (input$query_type == "author") {
        # Author query logic
        req(input$royalty_year_range)
        if (is.null(input$royalty_author_name) || identical(input$royalty_author_name, "")) {
          return(data.frame())
        }

        waiter <- waiter::Waiter$new(html = waiter::spin_ellipsis(), color = "rgba(255,255,255,0.6)")
        waiter$show()
        on.exit(waiter$hide(), add = TRUE)

        safe_query(function() {
          get_total_royalty_income_by_author(
            author_surname = input$royalty_author_name %||% "",
            start_year = input$royalty_year_range[1],
            end_year = input$royalty_year_range[2],
            author_id = (if (is.null(input$royalty_author_id) || input$royalty_author_id == "") NULL else input$royalty_author_id)
          )
        }, default_value = data.frame())
      } else {
        # Book query logic
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
      }
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
          `Total Sales` = ifelse(book_id == "TOTAL", format_number(total_sales), format_number(total_sales)),
          `Retail Price` = ifelse(is.na(retail_price), "", paste0("$", sprintf("%.2f", retail_price))),
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

      # For author queries, we want to show the total
      if (input$query_type == "author") {
        # Prefer TOTAL row if present
        total_income <- NA_real_
        if ("book_id" %in% names(results) && any(results$book_id == "TOTAL")) {
          total_income <- results$royalty_income[results$book_id == "TOTAL"][1]
        } else if ("royalty_income" %in% names(results)) {
          total_income <- sum(results$royalty_income, na.rm = TRUE)
        } else {
          return("")
        }

        years <- input$royalty_year_range
        author <- input$royalty_author_name %||% "the selected author"
        paste0(
          "From ", years[1], "–", years[2], ", the total royalty income from the sale of ",
          author, "'s books was $", sprintf("%.2f", as.numeric(total_income)),
          " (sum of sales × retail price × royalty rate, with tiers applied where present)."
        )
      } else {
        # Book query summary
        total_income <- sum(results$royalty_income, na.rm = TRUE)
        total_sales <- sum(results$total_sales, na.rm = TRUE)
        book_count <- nrow(results)

        paste0("Found ", book_count, " book(s) with ", format_number(total_sales),
               " total sales generating $", sprintf("%.2f", total_income), " in royalty income")
      }
    })

    # Calculation details
    output$calculation_details <- renderUI({
      results <- royalty_results()
      if (is.null(results) || nrow(results) == 0) {
        return(div("Run a query to see calculation details."))
      }

      # For author queries, show different information
      if (input$query_type == "author") {
        # Show total information
        total_row <- results[results$book_id == "TOTAL", ]
        if (nrow(total_row) > 0) {
          div(
            h5("Author Total Calculation:"),
            p(strong("Author:"), total_row$author_surname[1]),
            p(strong("Books:"), nrow(results) - 1, "titles"),
            p(strong("Total Sales:"), format_number(total_row$total_sales[1]), "copies"),
            p(strong("Total Royalty Income:"), paste0("$", sprintf("%.2f", total_row$royalty_income[1]))),
            p(em("Note: This is the sum of royalties from all books by this author."))
          )
        } else {
          div(
            h5("Author Summary:"),
            p(strong("Author:"), results$author_surname[1]),
            p(strong("Books:"), nrow(results), "titles"),
            p(strong("Total Royalty Income:"), paste0("$", sprintf("%.2f", sum(results$royalty_income, na.rm = TRUE)))),
            p(em("Note: This is the sum of royalties from all books by this author."))
          )
        }
      } else {
        # Show details for the first result (book query)
        result <- results[1, ]
        
        # Skip the TOTAL row if it exists (shouldn't for book queries, but just in case)
        if (result$book_id == "TOTAL") {
          if (nrow(results) > 1) {
            result <- results[2, ]
          } else {
            return(div("No calculation details available."))
          }
        }

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
      }
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
