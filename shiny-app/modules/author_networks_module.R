# Author Networks Module
# Enhanced module for analyzing author relationships using author_id

# UI function
authorNetworksUI <- function(id) {
  ns <- NS(id)
  
  fluidPage(
    h3("Author Network Analysis"),
    p("Explore relationships between authors based on shared publishers, publication periods, and collaboration patterns using the new author_id field."),
    br(),
    
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
    
    # Reactive data with better initialization and error handling
    network_data <- reactive({
      # Ensure we have valid inputs
      gender_filter <- input$gender_filter
      if (is.null(gender_filter) || length(gender_filter) == 0) {
        gender_filter <- c("Male", "Female")  # Default to both genders
      }

      year_range <- input$year_range
      if (is.null(year_range) || length(year_range) != 2) {
        year_range <- c(1860, 1920)  # Default range
      }

      min_books <- input$min_books
      if (is.null(min_books) || !is.numeric(min_books)) {
        min_books <- 2  # Default minimum
      }

      # Get author data with filters
      # Create gender filter clause
      gender_placeholders <- paste0("$", 3:(2 + length(gender_filter)), collapse = ",")
      author_query <- paste0("
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
          AND be.gender IN (", gender_placeholders, ")
          AND be.publication_year BETWEEN $1 AND $2
      ")

      # Create parameter list with year range first, then gender values
      params <- c(list(year_range[1], year_range[2]), as.list(gender_filter))

      book_data <- safe_db_query(author_query, params = params)

      # Handle empty query results
      if (is.null(book_data) || nrow(book_data) == 0) {
        return(list(
          nodes = data.frame(),
          edges = data.frame(),
          message = "No books found matching the selected criteria."
        ))
      }

      # Filter authors with minimum books
      author_counts <- book_data %>%
        group_by(author_id) %>%
        summarise(book_count = n(), .groups = "drop") %>%
        filter(book_count >= min_books)

      if (nrow(author_counts) == 0) {
        return(list(
          nodes = data.frame(),
          edges = data.frame(),
          message = paste("No authors found with at least", min_books, "books in the selected criteria.")
        ))
      }

      filtered_data <- book_data %>%
        filter(author_id %in% author_counts$author_id)

      # Create network based on type
      network_result <- create_author_network(filtered_data)

      # Add success message if we have data
      if (!is.null(network_result) && nrow(network_result$nodes) > 0) {
        network_result$message <- paste("Network created with", nrow(network_result$nodes), "authors and", nrow(network_result$edges), "connections.")
      } else {
        network_result$message <- "No network connections found between authors with the selected criteria."
      }

      return(network_result)
    })
    
    # Network plot with improved error handling
    output$network_plot <- renderPlotly({
      net_data <- network_data()

      # Handle various error conditions
      if (is.null(net_data)) {
        return(plotly_empty("Unable to load network data. Please check your database connection."))
      }

      if (is.null(net_data$nodes) || nrow(net_data$nodes) == 0) {
        message <- if (!is.null(net_data$message)) net_data$message else "No network data available"
        return(plotly_empty(message))
      }

      nodes <- net_data$nodes
      edges <- net_data$edges

      # Validate required columns exist
      required_cols <- c("author_id", "author_surname", "gender", "book_count", "total_sales", "node_size")
      missing_cols <- setdiff(required_cols, names(nodes))
      if (length(missing_cols) > 0) {
        return(plotly_empty(paste("Missing required data columns:", paste(missing_cols, collapse = ", "))))
      }

      # Create network visualization
      tryCatch({
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
            hovertemplate = "%{text}<extra></extra>"
          ) %>%
          layout(
            title = "Author Network",
            xaxis = list(showgrid = FALSE, showticklabels = FALSE, title = ""),
            yaxis = list(showgrid = FALSE, showticklabels = FALSE, title = ""),
            showlegend = TRUE,
            legend = list(
              x = 1.02,
              y = 1,
              xanchor = 'left',
              yanchor = 'top'
            )
          )

        return(p)
      }, error = function(e) {
        return(plotly_empty(paste("Error creating network plot:", e$message)))
      })
    })
    
    # Network statistics with improved error handling
    output$network_stats <- renderTable({
      net_data <- network_data()

      # Handle null or empty data
      if (is.null(net_data) || is.null(net_data$nodes) || nrow(net_data$nodes) == 0) {
        return(data.frame(
          Metric = "Status",
          Value = if (!is.null(net_data$message)) net_data$message else "No data available"
        ))
      }

      nodes <- net_data$nodes
      edges <- net_data$edges

      # Validate required columns
      if (!"gender" %in% names(nodes) || !"book_count" %in% names(nodes) || !"total_sales" %in% names(nodes)) {
        return(data.frame(
          Metric = "Error",
          Value = "Missing required data columns for statistics"
        ))
      }

      tryCatch({
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
            if (!is.null(edges)) nrow(edges) else 0,
            round(mean(nodes$book_count, na.rm = TRUE), 1),
            scales::comma(sum(nodes$total_sales, na.rm = TRUE))
          )
        )
      }, error = function(e) {
        data.frame(
          Metric = "Error",
          Value = paste("Error calculating statistics:", e$message)
        )
      })
    })
    
    # Author details table with improved error handling
    output$author_table <- DT::renderDataTable({
      net_data <- network_data()

      # Handle null or empty data
      if (is.null(net_data) || is.null(net_data$nodes) || nrow(net_data$nodes) == 0) {
        empty_message <- if (!is.null(net_data$message)) net_data$message else "No author data available"
        return(DT::datatable(
          data.frame(Message = empty_message),
          options = list(dom = 't', ordering = FALSE),
          rownames = FALSE
        ))
      }

      nodes <- net_data$nodes

      # Validate required columns exist
      required_cols <- c("author_id", "author_surname", "gender", "book_count", "total_sales", "avg_year")
      missing_cols <- setdiff(required_cols, names(nodes))
      if (length(missing_cols) > 0) {
        return(DT::datatable(
          data.frame(Error = paste("Missing columns:", paste(missing_cols, collapse = ", "))),
          options = list(dom = 't', ordering = FALSE),
          rownames = FALSE
        ))
      }

      tryCatch({
        formatted_nodes <- nodes %>%
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
          formatted_nodes,
          options = list(
            pageLength = 15,
            scrollX = TRUE,
            dom = 'Bfrtip'
          ),
          rownames = FALSE
        )
      }, error = function(e) {
        DT::datatable(
          data.frame(Error = paste("Error formatting table:", e$message)),
          options = list(dom = 't', ordering = FALSE),
          rownames = FALSE
        )
      })
    })
  })
}
