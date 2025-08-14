# Author Networks Module
# Enhanced module for analyzing author relationships using author_id

# UI function
authorNetworksUI <- function(id) {
  ns <- NS(id)
  
  fluidPage(
    fluidRow(
      column(12,
        box(
          title = "Author Network Analysis", 
          status = "primary", 
          solidHeader = TRUE,
          width = NULL,
          p("Explore relationships between authors based on shared publishers, 
            publication periods, and collaboration patterns using the new author_id field.")
        )
      )
    ),
    
    fluidRow(
      # Controls
      column(4,
        box(
          title = "Network Controls", 
          status = "info", 
          solidHeader = TRUE,
          width = NULL,
          
          selectInput(
            ns("network_type"),
            "Network Type:",
            choices = list(
              "Shared Publishers" = "publishers",
              "Similar Publication Years" = "years",
              "Genre Overlap" = "genres"
            ),
            selected = "publishers"
          ),
          
          sliderInput(
            ns("min_books"),
            "Minimum Books per Author:",
            min = 1, max = 10, value = 2, step = 1
          ),
          
          sliderInput(
            ns("year_range"),
            "Publication Year Range:",
            min = 1860, max = 1920, 
            value = c(1860, 1920),
            step = 1, sep = ""
          ),
          
          checkboxGroupInput(
            ns("gender_filter"),
            "Include Genders:",
            choices = list("Male" = "Male", "Female" = "Female"),
            selected = c("Male", "Female")
          ),
          
          actionButton(
            ns("update_network"),
            "Update Network",
            class = "btn-primary",
            style = "width: 100%;"
          )
        ),
        
        # Network Statistics
        box(
          title = "Network Statistics", 
          status = "success", 
          solidHeader = TRUE,
          width = NULL,
          
          tableOutput(ns("network_stats"))
        )
      ),
      
      # Network Visualization
      column(8,
        box(
          title = "Author Network", 
          status = "primary", 
          solidHeader = TRUE,
          width = NULL,
          height = "600px",
          
          plotlyOutput(ns("network_plot"), height = "550px")
        )
      )
    ),
    
    fluidRow(
      # Author Details Table
      column(12,
        box(
          title = "Author Details", 
          status = "info", 
          solidHeader = TRUE,
          width = NULL,
          
          DT::dataTableOutput(ns("author_table"))
        )
      )
    )
  )
}

# Server function
authorNetworksServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    
    # Reactive data
    network_data <- eventReactive(input$update_network, {
      req(input$gender_filter)
      
      # Get author data with filters
      author_query <- "
        SELECT 
          be.author_id,
          be.author_surname,
          be.gender,
          be.publisher,
          be.genre,
          be.publication_year,
          COALESCE(bs.total_sales, 0) as total_sales
        FROM book_entries be
        LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
        WHERE be.author_id IS NOT NULL
          AND be.gender = ANY($1)
          AND be.publication_year BETWEEN $2 AND $3
      "
      
      book_data <- safe_db_query(
        author_query, 
        params = list(
          input$gender_filter,
          input$year_range[1],
          input$year_range[2]
        )
      )
      
      if (nrow(book_data) == 0) return(NULL)
      
      # Filter authors with minimum books
      author_counts <- book_data %>%
        group_by(author_id) %>%
        summarise(book_count = n(), .groups = "drop") %>%
        filter(book_count >= input$min_books)
      
      filtered_data <- book_data %>%
        filter(author_id %in% author_counts$author_id)
      
      # Create network based on type
      create_author_network(filtered_data)
    }, ignoreNULL = FALSE)
    
    # Network plot
    output$network_plot <- renderPlotly({
      net_data <- network_data()
      if (is.null(net_data) || nrow(net_data$nodes) == 0) {
        return(plotly_empty("No network data available"))
      }
      
      nodes <- net_data$nodes
      edges <- net_data$edges
      
      # Create network visualization
      p <- plot_ly() %>%
        add_markers(
          data = nodes,
          x = ~runif(nrow(nodes)), 
          y = ~runif(nrow(nodes)),
          size = ~node_size,
          color = ~gender,
          colors = c("Male" = "#1f77b4", "Female" = "#ff7f0e"),
          text = ~paste(
            "Author:", author_surname,
            "<br>ID:", author_id,
            "<br>Gender:", gender,
            "<br>Books:", book_count,
            "<br>Total Sales:", scales::comma(total_sales)
          ),
          hovertemplate = "%{text}<extra></extra>",
          name = "Authors"
        ) %>%
        layout(
          title = "Author Network",
          xaxis = list(showgrid = FALSE, showticklabels = FALSE, title = ""),
          yaxis = list(showgrid = FALSE, showticklabels = FALSE, title = ""),
          showlegend = TRUE
        )
      
      p
    })
    
    # Network statistics
    output$network_stats <- renderTable({
      net_data <- network_data()
      if (is.null(net_data)) return(data.frame())
      
      nodes <- net_data$nodes
      edges <- net_data$edges
      
      data.frame(
        Metric = c(
          "Total Authors",
          "Male Authors", 
          "Female Authors",
          "Connections",
          "Avg Books per Author",
          "Total Sales"
        ),
        Value = c(
          nrow(nodes),
          sum(nodes$gender == "Male", na.rm = TRUE),
          sum(nodes$gender == "Female", na.rm = TRUE),
          nrow(edges),
          round(mean(nodes$book_count, na.rm = TRUE), 1),
          scales::comma(sum(nodes$total_sales, na.rm = TRUE))
        )
      )
    })
    
    # Author details table
    output$author_table <- DT::renderDataTable({
      net_data <- network_data()
      if (is.null(net_data)) return(data.frame())
      
      nodes <- net_data$nodes %>%
        select(
          `Author ID` = author_id,
          `Author Name` = author_surname,
          Gender = gender,
          `Book Count` = book_count,
          `Total Sales` = total_sales,
          `Avg Year` = avg_year
        ) %>%
        mutate(
          `Total Sales` = scales::comma(`Total Sales`),
          `Avg Year` = round(`Avg Year`, 0)
        )
      
      DT::datatable(
        nodes,
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
