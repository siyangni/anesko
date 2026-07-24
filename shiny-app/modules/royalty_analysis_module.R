# Royalty Analysis Module
# Enhanced module for analyzing royalty structures and tiers

# UI function
royaltyAnalysisUI <- function(id) {
  ns <- NS(id)
  
  fluidPage(
    h3("Royalty Structure Analysis"),
    p("Analyze royalty rates, tier structures, and payment schemes across different books, authors, and publishers.", 
      style = "font-size: 17px;"),
    br(),
    
    tags$style(HTML("
      .royalty-controls label { font-size: 18px; font-weight: 500; }
      .royalty-controls .checkbox label { font-size: 17px; }
    ")),
    
    fluidRow(
      # Controls
      column(4,
        box(
          title = "Analysis Controls", 
          status = "info", 
          solidHeader = TRUE,
          width = NULL,
          
          tags$div(class = "royalty-controls",
            selectInput(
              ns("analysis_type"),
              "Analysis Type:",
              choices = list(
                "Royalty Tiers Overview" = "tiers",
                "Rate Distribution" = "rates",
                "Publisher Comparison" = "publishers",
                "Author Comparison" = "authors"
              ),
              selected = "tiers"
            ),
            
            conditionalPanel(
              condition = "input.analysis_type == 'publishers'",
              ns = ns,
              selectInput(
                ns("publisher_select"),
                "Select Publishers:",
                choices = NULL,
                multiple = TRUE
              )
            ),
            
            conditionalPanel(
              condition = "input.analysis_type == 'authors'",
              ns = ns,
              selectInput(
                ns("author_select"),
                "Select Authors:",
                choices = NULL,
                multiple = TRUE
              )
            ),
            
            sliderInput(
              ns("year_range"),
              "Publication Year Range:",
              min = publication_slider_min(),
              max = publication_slider_max(),
              value = publication_default_range(),
              step = 1, sep = ""
            ),
            helpText(
              "Filters by publication year (not sales years). Covers full observed range plus buffer for new data.",
              style = "font-size: 13px; margin-top: -6px;"
            ),
            
            tags$div(style = "font-size: 17px;",
              checkboxInput(
                ns("sliding_scale_only"),
                "Sliding Scale Only",
                value = FALSE
              )
            )
          ),

          # Add info about sliding scale filter
          conditionalPanel(
            condition = "input.sliding_scale_only == true",
            ns = ns,
            div(
              style = "background-color: #d1ecf1; border: 1px solid #bee5eb; border-radius: 4px; padding: 8px; margin-top: 5px;",
              icon("info-circle"),
              " Filtering for books with sliding scale royalty structures only."
            )
          ),
          
          actionButton(
            ns("update_analysis"),
            "Update Analysis",
            class = "btn-primary",
            style = "width: 100%; font-size: 16px; padding: 10px;"
          )
        ),
        
        # Summary Statistics
        box(
          title = "Summary Statistics", 
          status = "success", 
          solidHeader = TRUE,
          width = NULL,
          
          tableOutput(ns("summary_stats"))
        )
      ),
      
      # Main Visualization
      column(8,
        box(
          title = "Royalty Analysis", 
          status = "primary", 
          solidHeader = TRUE,
          width = NULL,
          height = "600px",
          
          plotlyOutput(ns("main_plot"), height = "550px")
        )
      )
    ),
    
    fluidRow(
      # Tier Details
      column(6,
        box(
          title = "Royalty Tier Details", 
          status = "info", 
          solidHeader = TRUE,
          width = NULL,
          
          DT::dataTableOutput(ns("tier_table"))
        )
      ),
      
      # Book Details
      column(6,
        box(
          title = "Book Royalty Details", 
          status = "warning", 
          solidHeader = TRUE,
          width = NULL,
          
          DT::dataTableOutput(ns("book_table"))
        )
      )
    )
  )
}

# Server function
royaltyAnalysisServer <- function(id) {
  moduleServer(id, function(input, output, session) {

    # UI has Update Analysis; previously the button was never read server-side.
    analysis_tick <- reactiveVal(0L)
    filters_seeded <- reactiveVal(FALSE)

    # Initialize filter choices (shared filter option helpers)
    observe({
      opts <- safe_query(get_filter_options, default_value = list(
        publishers = data.frame(publisher = character(0))
      ))
      pub_choices <- publisher_filter_choices(raw_df = opts$publishers)
      if (length(pub_choices) > 0) {
        updateSelectInput(session, "publisher_select", choices = pub_choices)
      }

      # Multi-book authors for network-style royalty comparison
      # (specialized filter: min 2 books; COUNT(DISTINCT book_id) for consistency)
      authors <- safe_db_query(
        "SELECT author_id, author_surname,
                COUNT(DISTINCT book_id) as book_count
         FROM book_entries
         WHERE author_id IS NOT NULL
         GROUP BY author_id, author_surname
         HAVING COUNT(DISTINCT book_id) >= 2
         ORDER BY author_surname
         LIMIT 50"
      )
      if (!is.null(authors) && nrow(authors) > 0) {
        author_choices <- setNames(
          clean_author_id(authors$author_id),
          paste0(
            format_author_label(authors$author_id, authors$author_surname),
            " (", authors$book_count, " books)"
          )
        )
        updateSelectInput(
          session, "author_select",
          choices = author_choices
        )
      }
      filters_seeded(TRUE)
    })

    observeEvent(filters_seeded(), {
      if (isTRUE(filters_seeded()) && isolate(analysis_tick()) == 0L) {
        analysis_tick(1L)
      }
    }, ignoreInit = FALSE)

    observeEvent(input$update_analysis, {
      analysis_tick(isolate(analysis_tick()) + 1L)
    }, ignoreInit = TRUE, ignoreNULL = TRUE)

    # Data loads on Update click and once after filters seed
    royalty_data <- eventReactive(analysis_tick(), {
      req(analysis_tick() > 0L)

      # Publication years (catalog metadata for which books to include)
      pub_years <- resolve_year_range(
        input$year_range,
        default = publication_default_range()
      )

      base_query <- "
        SELECT
          rt.*,
          be.book_title,
          be.author_surname,
          be.author_id,
          be.publisher,
          be.genre,
          be.publication_year,
          be.retail_price,
          COALESCE(bs.total_sales, 0) as total_sales
        FROM royalty_tiers rt
        JOIN book_entries be ON rt.book_id = be.book_id
        LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
        WHERE be.publication_year BETWEEN $1 AND $2
      "

      params <- list(pub_years$start, pub_years$end)

      # Add sliding scale filter
      if (!is.null(input$sliding_scale_only) && input$sliding_scale_only) {
        base_query <- paste(base_query, "AND rt.sliding_scale = TRUE")
      }

      # Add specific filters based on analysis type with proper parameter handling
      if (!is.null(input$analysis_type) && input$analysis_type == "publishers" &&
          !is.null(input$publisher_select) && length(input$publisher_select) > 0) {
        # Use IN clause instead of ANY for PostgreSQL compatibility
        publisher_placeholders <- paste0("$", 3:(2 + length(input$publisher_select)), collapse = ",")
        base_query <- paste0(base_query, " AND be.publisher IN (", publisher_placeholders, ")")
        params <- c(params, as.list(input$publisher_select))
      } else if (!is.null(input$analysis_type) && input$analysis_type == "authors" &&
                 !is.null(input$author_select) && length(input$author_select) > 0) {
        # Use IN clause instead of ANY for PostgreSQL compatibility
        author_placeholders <- paste0("$", 3:(2 + length(input$author_select)), collapse = ",")
        base_query <- paste0(base_query, " AND be.author_id IN (", author_placeholders, ")")
        params <- c(params, as.list(input$author_select))
      }

      tryCatch({
        result <- safe_db_query(base_query, params = params)
        if (is.null(result)) {
          return(data.frame())
        }
        return(result)
      }, error = function(e) {
        warning("Error in royalty data query: ", e$message)
        return(data.frame())
      })
    }, ignoreNULL = TRUE)
    
    # Main plot
    output$main_plot <- renderPlotly({
      data <- royalty_data()
      if (nrow(data) == 0) {
        return(plotly_empty("No royalty data available"))
      }
      
      switch(input$analysis_type,
        "tiers" = {
          # Tier analysis
          tier_summary <- data %>%
            group_by(tier) %>%
            summarise(
              avg_rate = mean(rate, na.rm = TRUE),
              book_count = n_distinct(book_id),
              .groups = "drop"
            )
          
          plot_ly(tier_summary, x = ~tier, y = ~avg_rate, type = "bar",
                  text = ~paste("Books:", book_count),
                  hovertemplate = "Tier: %{x}<br>Avg Rate: %{y:.1%}<br>%{text}<extra></extra>") %>%
            layout(
              title = "Average Royalty Rate by Tier",
              xaxis = list(title = "Royalty Tier"),
              yaxis = list(title = "Average Royalty Rate", tickformat = ".1%")
            )
        },
        
        "rates" = {
          # Rate distribution
          plot_ly(data, x = ~rate, type = "histogram", nbinsx = 30) %>%
            layout(
              title = "Distribution of Royalty Rates",
              xaxis = list(title = "Royalty Rate", tickformat = ".1%"),
              yaxis = list(title = "Frequency")
            )
        },
        
        "publishers" = {
          # Publisher comparison
          pub_summary <- data %>%
            group_by(publisher) %>%
            summarise(
              avg_rate = mean(rate, na.rm = TRUE),
              book_count = n_distinct(book_id),
              .groups = "drop"
            ) %>%
            arrange(desc(avg_rate))
          
          plot_ly(pub_summary, x = ~reorder(publisher, avg_rate), y = ~avg_rate, 
                  type = "bar", orientation = "v",
                  text = ~paste("Books:", book_count),
                  hovertemplate = "%{x}<br>Avg Rate: %{y:.1%}<br>%{text}<extra></extra>") %>%
            layout(
              title = "Average Royalty Rate by Publisher",
              xaxis = list(title = "Publisher"),
              yaxis = list(title = "Average Royalty Rate", tickformat = ".1%")
            )
        },
        
        "authors" = {
          # Author comparison
          auth_summary <- data %>%
            group_by(author_surname, author_id) %>%
            summarise(
              avg_rate = mean(rate, na.rm = TRUE),
              book_count = n_distinct(book_id),
              .groups = "drop"
            ) %>%
            arrange(desc(avg_rate))
          
          plot_ly(auth_summary, x = ~reorder(author_surname, avg_rate), y = ~avg_rate, 
                  type = "bar", orientation = "v",
                  text = ~paste("Books:", book_count),
                  hovertemplate = "%{x}<br>Avg Rate: %{y:.1%}<br>%{text}<extra></extra>") %>%
            layout(
              title = "Average Royalty Rate by Author",
              xaxis = list(title = "Author"),
              yaxis = list(title = "Average Royalty Rate", tickformat = ".1%")
            )
        }
      )
    })
    
    # Summary statistics
    output$summary_stats <- renderTable({
      data <- royalty_data()
      if (nrow(data) == 0) return(data.frame())
      
      data.frame(
        Metric = c(
          "Total Books",
          "Unique Authors",
          "Avg Royalty Rate",
          "Median Rate",
          "Min Rate",
          "Max Rate",
          "Sliding Scale %"
        ),
        Value = c(
          length(unique(data$book_id)),
          length(unique(data$author_id)),
          paste0(round(mean(data$rate, na.rm = TRUE) * 100, 1), "%"),
          paste0(round(median(data$rate, na.rm = TRUE) * 100, 1), "%"),
          paste0(round(min(data$rate, na.rm = TRUE) * 100, 1), "%"),
          paste0(round(max(data$rate, na.rm = TRUE) * 100, 1), "%"),
          paste0(round(mean(data$sliding_scale, na.rm = TRUE) * 100, 1), "%")
        )
      )
    })
    
    # Tier details table with comprehensive error handling
    output$tier_table <- DT::renderDataTable({
      tryCatch({
        data <- royalty_data()

        # Handle empty data
        if (is.null(data) || nrow(data) == 0) {
          return(DT::datatable(
            data.frame(Message = "No royalty tier data available for the selected criteria."),
            options = list(dom = 't', ordering = FALSE),
            rownames = FALSE
          ))
        }

        # Validate required columns exist
        required_cols <- c("tier", "book_id", "rate", "sliding_scale")
        missing_cols <- setdiff(required_cols, names(data))
        if (length(missing_cols) > 0) {
          return(DT::datatable(
            data.frame(Error = paste("Missing required columns:", paste(missing_cols, collapse = ", "))),
            options = list(dom = 't', ordering = FALSE),
            rownames = FALSE
          ))
        }

        # Analyze royalty patterns with error handling
        tier_analysis <- tryCatch({
          analyze_royalty_patterns(data)
        }, error = function(e) {
          warning("Error in analyze_royalty_patterns: ", e$message)
          return(NULL)
        })

        if (is.null(tier_analysis) || nrow(tier_analysis) == 0) {
          return(DT::datatable(
            data.frame(Message = "Unable to analyze royalty tier patterns."),
            options = list(dom = 't', ordering = FALSE),
            rownames = FALSE
          ))
        }

        # Format the tier details with error handling
        tier_details <- tryCatch({
          tier_analysis %>%
            select(
              Tier = tier,
              `Book Count` = book_count,
              `Avg Rate` = avg_rate,
              `Min Rate` = min_rate,
              `Max Rate` = max_rate,
              `Sliding Scale %` = sliding_scale_pct
            ) %>%
            mutate(
              `Avg Rate` = paste0(round(`Avg Rate` * 100, 1), "%"),
              `Rate Range` = paste0(round(`Min Rate` * 100, 1), "% - ", round(`Max Rate` * 100, 1), "%"),
              `Sliding Scale %` = paste0(round(`Sliding Scale %`, 1), "%")
            ) %>%
            select(Tier, `Book Count`, `Avg Rate`, `Rate Range`, `Sliding Scale %`)
        }, error = function(e) {
          warning("Error formatting tier details: ", e$message)
          return(data.frame(Error = paste("Error formatting data:", e$message)))
        })

        DT::datatable(
          tier_details,
          options = list(pageLength = 10, scrollX = TRUE),
          rownames = FALSE
        )

      }, error = function(e) {
        # Final catch-all error handler
        DT::datatable(
          data.frame(Error = paste("Unexpected error in tier table:", e$message)),
          options = list(dom = 't', ordering = FALSE),
          rownames = FALSE
        )
      })
    })
    
    # Book details table
    output$book_table <- DT::renderDataTable({
      data <- royalty_data()
      if (nrow(data) == 0) return(data.frame())
      
      book_details <- data %>%
        select(
          `Book ID` = book_id,
          Title = book_title,
          Author = author_surname,
          Publisher = publisher,
          Year = publication_year,
          Tier = tier,
          Rate = rate,
          `Lower Limit` = lower_limit,
          `Upper Limit` = upper_limit,
          `Sliding Scale` = sliding_scale
        ) %>%
        mutate(
          Title = format_title_catalog_style(Title),
          Rate = paste0(round(Rate * 100, 1), "%"),
          `Lower Limit` = scales::comma(`Lower Limit`),
          `Upper Limit` = ifelse(is.na(`Upper Limit`), "∞", scales::comma(`Upper Limit`)),
          `Sliding Scale` = ifelse(`Sliding Scale`, "Yes", "No")
        )
      
      DT::datatable(
        book_details,
        options = list(
          pageLength = 15,
          scrollX = TRUE,
          dom = 'Bfrtip'
        ),
        rownames = FALSE
      )
    })

    for (out_id in c("main_plot", "summary_stats", "tier_table", "book_table")) {
      try(outputOptions(output, out_id, suspendWhenHidden = FALSE), silent = TRUE)
    }
  })
}
