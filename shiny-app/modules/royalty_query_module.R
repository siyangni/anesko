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
            condition = paste0("input['", ns("query_type"), "'] == 'book'"),
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
            condition = paste0("input['", ns("query_type"), "'] == 'author'"),
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
            br(), br()
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
              condition = paste0("input['", ns("query_type"), "'] == 'author' && output['", ns("royalty_results_available"), "']"),
              wellPanel(
                h4("Author Summary Statistics"),
                htmlOutput(ns("author_summary_stats"))
              )
            ),
            conditionalPanel(
              condition = paste0("input['", ns("query_type"), "'] == 'author' && output['", ns("royalty_results_available"), "']"),
              plotOutput(ns("author_royalty_plot"), height = "300px")
            ),
            conditionalPanel(
              condition = paste0("input['", ns("query_type"), "'] == 'book' && output['", ns("royalty_results_available"), "']"),
              wellPanel(
                h4("Book Royalty Analysis"),
                htmlOutput(ns("book_royalty_stats"))
              )
            ),
            conditionalPanel(
              condition = paste0("input['", ns("query_type"), "'] == 'book' && output['", ns("royalty_results_available"), "']"),
              plotOutput(ns("book_royalty_plot"), height = "300px")
            ),
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
                  condition = paste0("input['", ns("query_type"), "'] == 'book'"),
                  "Book Royalty Income = Sales Count × Retail Price × Royalty Rate"
                ),
                conditionalPanel(
                  condition = paste0("input['", ns("query_type"), "'] == 'author'"),
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

    # Track which query type produced the current results so we don't
    # display stale summaries when the user switches tabs without recalculating
    last_results_query_type <- reactiveVal(NULL)

    # Initialize inputs

    # Clear last results type when the user switches query type so stale results
    # don't drive the summary/plots for the other mode
    observeEvent(input$query_type, {
      last_results_query_type(NULL)
    })

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
      # Remember which query type produced these results
      last_results_query_type(input$query_type)
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

      # For author queries, we want to show all books by the author
      if (input$query_type == "author") {
        # Remove the TOTAL row for display in the table
        display_results <- results[results$book_id != "TOTAL", ]

        # Format the results for display - show all books by the author
        display_results <- display_results %>%
          dplyr::mutate(
            `Total Sales` = format_number(total_sales),
            `Retail Price` = ifelse(is.na(retail_price), "", paste0("$", sprintf("%.2f", retail_price))),
            `Royalty Income` = paste0("$", sprintf("%.2f", royalty_income))
          ) %>%
          dplyr::select(
            `Book Title` = book_title,
            `Total Sales`,
            `Retail Price`,
            `Royalty Income`
          )
      } else {
        # Format the results for display - book-specific query
        display_results <- results %>%
          dplyr::mutate(
            `Total Sales` = format_number(total_sales),
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
      }

      DT::datatable(display_results,
                   options = list(pageLength = 10, scrollX = TRUE, dom = 'Bfrtip',
                                 buttons = c('copy','csv','excel')),
                   rownames = FALSE)
    })

    # Result summary - REMOVED as per requirements
    output$royalty_result_summary <- renderText({
      return("")
    })

    # Calculation details
    output$calculation_details <- renderUI({
      results <- royalty_results()
      if (is.null(results) || nrow(results) == 0) {
        return(div("Run a query to see calculation details."))
      }

      # For author queries, show comprehensive statistics
      if (input$query_type == "author") {
        div(
          h5("Author Royalty Calculation Details:"),
          p("The total royalty income for an author is calculated by summing the royalty income from each of their books:"),
          tags$pre("Author Total = Σ(Book Royalty Incomes)", style = "background-color: #f8f9fa; padding: 10px; border-radius: 5px;"),
          br(),
          p("For each book, the royalty income is calculated as:"),
          tags$ul(
            tags$li("If the book has a simple royalty rate (no tiers):"),
            tags$pre("Book Royalty = Sales × Retail Price × Royalty Rate", style = "background-color: #f8f9fa; padding: 10px; border-radius: 5px; margin-left: 20px;"),
            tags$li("If the book has tiered royalty rates (sliding scale):"),
            tags$pre("Book Royalty = Σ(Tier Sales × Retail Price × Tier Rate)", style = "background-color: #f8f9fa; padding: 10px; border-radius: 5px; margin-left: 20px;")
          ),
          p("In the tiered calculation:"),
          tags$ul(
            tags$li("Each tier applies a different royalty rate to a specific range of sales"),
            tags$li("Sales are applied to tiers in order (1st tier, then 2nd tier, etc.)"),
            tags$li("The calculation stops when all sales are allocated to tiers")
          ),
          br(),
          p(em("Note: These formulas account for all books by the selected author within the specified date range."))
        )
      } else {
        # Show details for the first result (book query) with enhanced information
        result <- results[1, ]

        # Skip the TOTAL row if it exists (shouldn't for book queries, but just in case)
        if (result$book_id == "TOTAL") {
          if (nrow(results) > 1) {
            result <- results[2, ]
          } else {
            return(div("No calculation details available."))
          }
        }

        # Get book details to show tier information
        book_details <- safe_query(function() get_book_details(result$book_id),
                                  default_value = list(royalty_tiers = data.frame()))
        royalty_tiers <- book_details$royalty_tiers

        details_content <- div(
          h5("Book Royalty Calculation Details:"),
          p(strong("Book:"), result$book_title),
          p(strong("Binding:"), result$binding),
          p(strong("Sales:"), format_number(result$total_sales), "copies"),
          p(strong("Retail Price:"), paste0("$", sprintf("%.2f", result$retail_price))),
          br()
        )

        # Add tier information if available
        if (!is.null(royalty_tiers) && nrow(royalty_tiers) > 0) {
          details_content <- tagAppendChild(details_content,
            h5("Tiered Royalty Calculation:"),
            p("This book has ", nrow(royalty_tiers), " royalty tier(s):")
          )

          # Add tier details
          tier_explanation <- ""
          for (i in 1:nrow(royalty_tiers)) {
            tier <- royalty_tiers[i, ]
            tier_lower <- tier$lower_limit
            tier_upper <- if (is.na(tier$upper_limit)) "∞" else tier$upper_limit
            tier_explanation <- paste0(tier_explanation,
              "Tier ", tier$tier, ": Sales ", format_number(tier_lower), " to ", tier_upper,
              " at rate ", sprintf("%.1f", tier$rate * 100), "%\n")
          }

          details_content <- tagAppendChild(details_content,
            tags$pre(tier_explanation, style = "background-color: #f8f9fa; padding: 10px; border-radius: 5px;")
          )

          details_content <- tagAppendChild(details_content,
            p("The tiered calculation works as follows:"),
            tags$ul(
              tags$li("Sales are applied to tiers in order (Tier 1 first, then Tier 2, etc.)"),
              tags$li("Each tier's sales count is multiplied by the retail price and tier rate"),
              tags$li("The results are summed to get the total royalty income")
            ),
            br(),
            p(strong("Total Royalty Income:"), paste0("$", sprintf("%.2f", result$royalty_income)))
          )
        } else {
          # Simple calculation details
          details_content <- tagAppendChild(details_content,
            h5("Simple Royalty Calculation:"),
            tags$pre(
              paste0(
                "Royalty Income = Sales × Retail Price × Royalty Rate\n",
                "= ", format_number(result$total_sales), " × $", sprintf("%.2f", result$retail_price),
                " × ", sprintf("%.1f", result$royalty_rate * 100), "%\n",
                "= $", sprintf("%.2f", result$royalty_income)
              ),
              style = "background-color: #f8f9fa; padding: 10px; border-radius: 5px;"
            )
          )
        }

        # Add general formula information
        details_content <- tagAppendChild(details_content,
          br(),
          h5("General Formulas:"),
          tags$ul(
            tags$li("Simple Rate: ", tags$code("Sales × Retail Price × Royalty Rate")),
            tags$li("Tiered Rates: ", tags$code("Σ(Tier Sales × Retail Price × Tier Rate)"))
          ),
          p(em("Note: Tiered calculations apply different rates to different sales volume ranges."))
        )

        if (nrow(results) > 1) {
          details_content <- tagAppendChild(details_content,
            p(em("Note: Multiple binding formats found. Each row shows separate calculations."))
          )
        }

        details_content
      }
    })

    # Check if results are available for the CURRENT query type only
    output$royalty_results_available <- reactive({
      results <- royalty_results()
      has_rows <- !is.null(results) && nrow(results) > 0
      same_type <- identical(last_results_query_type(), input$query_type)
      has_rows && same_type
    })
    outputOptions(output, "royalty_results_available", suspendWhenHidden = FALSE)

        # Author royalty visualization
    output$author_royalty_plot <- renderPlot({
      # Only render for author queries and when the current results were produced by an author query
      if (input$query_type != "author" || !identical(last_results_query_type(), "author")) {
        return(NULL)
      }

      results <- royalty_results()
      if (is.null(results) || nrow(results) == 0) {
        return(NULL)
      }

      # Remove the TOTAL row for plotting
      plot_data <- results[results$book_id != "TOTAL", ]

      if (nrow(plot_data) == 0) {
        return(NULL)
      }

      # Create a bar chart of royalty income by book
      plot_data <- plot_data[order(plot_data$royalty_income, decreasing = TRUE), ]

      # Limit to top 10 books for better visualization
      if (nrow(plot_data) > 10) {
        other_income <- sum(plot_data$royalty_income[-(1:10)])
        plot_data <- plot_data[1:10, ]
        other_row <- data.frame(
          book_title = "Other Books",
          royalty_income = other_income,
          stringsAsFactors = FALSE
        )
        plot_data <- rbind(plot_data, other_row)
      }

      # Create the plot
      par(mar = c(5, 8, 4, 2))  # Increase left margin for book titles
      barplot(
        plot_data$royalty_income,
        names.arg = plot_data$book_title,
        horiz = TRUE,
        las = 1,  # Horizontal labels
        main = "Royalty Income by Book",
        xlab = "Royalty Income ($)",
        col = "lightblue",
        border = "darkblue"
      )
      box()
    })

    # Author summary statistics
    output$author_summary_stats <- renderUI({
      # Only render for author queries and when the current results were produced by an author query
      if (input$query_type != "author" || !identical(last_results_query_type(), "author")) {
        return(NULL)
      }

      results <- royalty_results()
      total_books_for_author <- 0
      if (is.null(results) || nrow(results) == 0) {
        return(NULL)
      }

      # Remove the TOTAL row for calculations
      book_data <- results[results$book_id != "TOTAL", ]

      if (nrow(book_data) == 0) {
        return(NULL)
      }

      # Calculate statistics
      book_count <- nrow(book_data)
      total_income <- sum(book_data$royalty_income, na.rm = TRUE)
      total_sales <- sum(book_data$total_sales, na.rm = TRUE)
      years <- input$royalty_year_range
      year_count <- years[2] - years[1] + 1
      avg_income_per_book <- ifelse(book_count > 0, total_income / book_count, 0)
      avg_income_per_year <- ifelse(year_count > 0, total_income / year_count, 0)

      # Find top earning book
      top_book_info <- "N/A"
      if (book_count > 0) {
        top_book <- book_data[which.max(book_data$royalty_income), ]
        top_book_info <- paste0(
          tags$b(top_book$book_title), " ($", sprintf("%.2f", top_book$royalty_income), ")"
        )
      }

      # Also get the total book count for this author (from the dropdown labels)
      author_label <- input$royalty_author_name
      if (!is.null(author_label) && author_label != "") {
        # Extract book count from the author label (format: "Author Name (X book(s))")
        label_match <- regmatches(author_label, regexec("\\((\\d+) book", author_label))
        if (length(label_match) > 1 && length(label_match[[1]]) > 1) {
          total_books_for_author <- as.numeric(label_match[[1]][2])
        }
      }

      # Create the summary HTML
      tags$div(
        class = "author-summary-stats",
        tags$div(
          class = "row",
          tags$div(
            class = "col-md-3",
            tags$div(
              style = "text-align: center; padding: 10px; background-color: #f8f9fa; border-radius: 5px;",
              tags$h5("Books Analyzed", style = "margin-top: 0; color: #495057;"),
              tags$p(book_count,
                    style = "font-size: 1.2em; font-weight: bold; color: #0d6efd; margin: 5px 0;")
            )
          ),
          tags$div(
            class = "col-md-3",
            tags$div(
              style = "text-align: center; padding: 10px; background-color: #f8f9fa; border-radius: 5px;",
              tags$h5("Average per Book", style = "margin-top: 0; color: #495057;"),
              tags$p(paste0("$", sprintf("%.2f", avg_income_per_book)),
                    style = "font-size: 1.2em; font-weight: bold; color: #0d6efd; margin: 5px 0;")
            )
          ),
          tags$div(
            class = "col-md-3",
            tags$div(
            style = "text-align: center; padding: 10px; background-color: #f8f9fa; border-radius: 5px;",
            tags$h5("Average per Year", style = "margin-top: 0; color: #495057;"),
            tags$p(paste0("$", sprintf("%.2f", avg_income_per_year)),
                  style = "font-size: 1.2em; font-weight: bold; color: #0d6efd; margin: 5px 0;")
          )
          ),
          tags$div(
            class = "col-md-3",
            tags$div(
            style = "text-align: center; padding: 10px; background-color: #f8f9fa; border-radius: 5px;",
            tags$h5("Top Earning Book", style = "margin-top: 0; color: #495057;"),
            tags$p(HTML(top_book_info),
                  style = "font-size: 1.1em; font-weight: bold; color: #0d6efd; margin: 5px 0;")
          )
          )
        ),
        tags$hr(style = "margin: 15px 0;"),
        tags$p(
          tags$b("Total Royalty Income:"),
          paste0(" $", sprintf("%.2f", total_income)),
          " from ", book_count, " book", ifelse(book_count == 1, "", "s"),
          if (total_books_for_author > 0 && total_books_for_author != book_count) {
            paste0(" (out of ", total_books_for_author, " total books by this author)")
          } else {
            ""
          },
          " over ", year_count, " year", ifelse(year_count == 1, "", "s"),
          " (", years[1], "–", years[2], ")",
          style = "font-size: 1.1em;"
        )
      )
    })

    # Book royalty statistics (shown under "Book Royalty Analysis")
    output$book_royalty_stats <- renderUI({
      # Only render for book queries and when the current results were produced by a book query
      if (input$query_type != "book" || !identical(last_results_query_type(), "book")) {
        return(NULL)
      }

      results <- royalty_results()
      if (is.null(results) || nrow(results) == 0) {
        return(NULL)
      }

      # Calculate statistics for book query (may have multiple bindings)
      book_count <- nrow(results)
      total_income <- sum(results$royalty_income, na.rm = TRUE)
      total_sales <- sum(results$total_sales, na.rm = TRUE)
      years <- input$royalty_year_range
      year_count <- years[2] - years[1] + 1
      avg_income_per_book <- ifelse(book_count > 0, total_income / book_count, 0)
      avg_income_per_year <- ifelse(year_count > 0, total_income / year_count, 0)

      # Create the summary HTML
      tagList(
        tags$div(
          style = "display: grid; grid-template-columns: repeat(4, 1fr); gap: 15px;",
          tags$div(
            style = "text-align: center; padding: 10px; background-color: #f8f9fa; border-radius: 5px;",
            tags$h5("Bindings Analyzed", style = "margin-top: 0; color: #495057;"),
            tags$p(book_count,
                  style = "font-size: 1.2em; font-weight: bold; color: #0d6efd; margin: 5px 0;")
          ),
          tags$div(
            style = "text-align: center; padding: 10px; background-color: #f8f9fa; border-radius: 5px;",
            tags$h5("Average per Binding", style = "margin-top: 0; color: #495057;"),
            tags$p(paste0("$", sprintf("%.2f", avg_income_per_book)),
                  style = "font-size: 1.2em; font-weight: bold; color: #0d6efd; margin: 5px 0;")
          ),
          tags$div(
            style = "text-align: center; padding: 10px; background-color: #f8f9fa; border-radius: 5px;",
            tags$h5("Average per Year", style = "margin-top: 0; color: #495057;"),
            tags$p(paste0("$", sprintf("%.2f", avg_income_per_year)),
                  style = "font-size: 1.2em; font-weight: bold; color: #0d6efd; margin: 5px 0;")
          ),
          tags$div(
            style = "text-align: center; padding: 10px; background-color: #f8f9fa; border-radius: 5px;",
            tags$h5("Total Sales", style = "margin-top: 0; color: #495057;"),
            tags$p(format_number(total_sales),
                  style = "font-size: 1.2em; font-weight: bold; color: #0d6efd; margin: 5px 0;")
          )
        ),
        tags$hr(style = "margin: 15px 0;"),
        tags$p(
          tags$b("Total Royalty Income:"),
          paste0(" $", sprintf("%.2f", total_income)),
          " over ", year_count, " year", ifelse(year_count == 1, "", "s"),
          " (", years[1], "–", years[2], ")",
          style = "font-size: 1.1em;"
        )
      )
    })

    # Book royalty visualization
    output$book_royalty_plot <- renderPlot({
      # Only render for book queries and when the current results were produced by a book query
      if (input$query_type != "book" || !identical(last_results_query_type(), "book")) {
        return(NULL)
      }

      results <- royalty_results()
      if (is.null(results) || nrow(results) == 0) {
        return(NULL)
      }

      # If we have multiple bindings, show them in a bar chart
      if (nrow(results) > 1) {
        # Order by royalty income
        plot_data <- results[order(results$royalty_income, decreasing = TRUE), ]

        # Create the plot
        par(mar = c(5, 8, 4, 2))  # Increase left margin for binding names
        barplot(
          plot_data$royalty_income,
          names.arg = plot_data$binding,
          horiz = TRUE,
          las = 1,  # Horizontal labels
          main = "Royalty Income by Binding",
          xlab = "Royalty Income ($)",
          col = "lightgreen",
          border = "darkgreen"
        )
        box()
      } else {
        # Single binding - show a simple bar for total income
        total_income <- results$royalty_income[1]

        # Create a simple bar chart
        par(mar = c(5, 8, 4, 2))
        barplot(
          total_income,
          names.arg = "Total",
          horiz = TRUE,
          main = "Royalty Income",
          xlab = "Royalty Income ($)",
          col = "lightgreen",
          border = "darkgreen"
        )
        box()
      }
    })

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
