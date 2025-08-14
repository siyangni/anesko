# Royalty Analysis Module
# Enhanced module for analyzing royalty structures and tiers

# UI function
royaltyAnalysisUI <- function(id) {
  ns <- NS(id)
  
  fluidPage(
    fluidRow(
      column(12,
        box(
          title = "Royalty Structure Analysis", 
          status = "primary", 
          solidHeader = TRUE,
          width = NULL,
          p("Analyze royalty rates, tier structures, and payment schemes 
            across different books, authors, and publishers.")
        )
      )
    ),
    
    fluidRow(
      # Controls
      column(4,
        box(
          title = "Analysis Controls", 
          status = "info", 
          solidHeader = TRUE,
          width = NULL,
          
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
            min = 1860, max = 1920, 
            value = c(1860, 1920),
            step = 1, sep = ""
          ),
          
          checkboxInput(
            ns("sliding_scale_only"),
            "Sliding Scale Only",
            value = FALSE
          ),
          
          actionButton(
            ns("update_analysis"),
            "Update Analysis",
            class = "btn-primary",
            style = "width: 100%;"
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
    
    # Initialize filter choices
    observe({
      # Update publisher choices
      publishers <- safe_db_query(
        "SELECT DISTINCT publisher FROM book_entries 
         WHERE publisher IS NOT NULL ORDER BY publisher"
      )
      updateSelectInput(
        session, "publisher_select",
        choices = setNames(publishers$publisher, publishers$publisher)
      )
      
      # Update author choices (top authors with multiple books)
      authors <- safe_db_query(
        "SELECT author_id, author_surname, COUNT(*) as book_count
         FROM book_entries 
         WHERE author_id IS NOT NULL 
         GROUP BY author_id, author_surname
         HAVING COUNT(*) >= 2
         ORDER BY book_count DESC, author_surname
         LIMIT 50"
      )
      author_choices <- setNames(
        authors$author_id, 
        paste(authors$author_surname, "(", authors$book_count, "books)")
      )
      updateSelectInput(
        session, "author_select",
        choices = author_choices
      )
    })
    
    # Reactive data
    royalty_data <- eventReactive(input$update_analysis, {
      
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
      
      params <- list(input$year_range[1], input$year_range[2])
      
      # Add sliding scale filter
      if (input$sliding_scale_only) {
        base_query <- paste(base_query, "AND rt.sliding_scale = TRUE")
      }
      
      # Add specific filters based on analysis type
      if (input$analysis_type == "publishers" && !is.null(input$publisher_select)) {
        base_query <- paste(base_query, "AND be.publisher = ANY($3)")
        params <- append(params, list(input$publisher_select))
      } else if (input$analysis_type == "authors" && !is.null(input$author_select)) {
        base_query <- paste(base_query, "AND be.author_id = ANY($3)")
        params <- append(params, list(input$author_select))
      }
      
      safe_db_query(base_query, params = params)
    }, ignoreNULL = FALSE)
    
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
    
    # Tier details table
    output$tier_table <- DT::renderDataTable({
      data <- royalty_data()
      if (nrow(data) == 0) return(data.frame())
      
      tier_details <- analyze_royalty_patterns(data) %>%
        select(
          Tier = tier,
          `Book Count` = book_count,
          `Avg Rate` = avg_rate,
          `Rate Range` = paste0(round(min_rate * 100, 1), "% - ", round(max_rate * 100, 1), "%"),
          `Sliding Scale %` = sliding_scale_pct
        ) %>%
        mutate(
          `Avg Rate` = paste0(round(`Avg Rate` * 100, 1), "%"),
          `Sliding Scale %` = paste0(round(`Sliding Scale %`, 1), "%")
        )
      
      DT::datatable(
        tier_details,
        options = list(pageLength = 10, scrollX = TRUE),
        rownames = FALSE
      )
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
  })
}
