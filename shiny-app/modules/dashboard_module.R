# Dashboard Overview Module
# Main dashboard with summary statistics and key metrics

# Dashboard UI
dashboardUI <- function(id) {
  ns <- NS(id)
  
  fluidPage(
    # Value boxes row
    fluidRow(
      uiOutput(ns("value_boxes"))
    ),
    
    br(),
    
    # Charts row
    fluidRow(
      # Sales trend over time
      box(
        title = "Sales Trends Over Time", status = "primary", solidHeader = TRUE,
        width = 8, height = "400px",
        plotlyOutput(ns("sales_trend_plot"), height = "350px")
      ),
      
      # Gender distribution
      box(
        title = "Author Gender Distribution", status = "info", solidHeader = TRUE,
        width = 4, height = "400px",
        plotlyOutput(ns("gender_pie_chart"), height = "350px")
      )
    ),
    
    fluidRow(
      # Top genres
      box(
        title = "Top Genres by Sales", status = "success", solidHeader = TRUE,
        width = 6, height = "400px",
        plotlyOutput(ns("genre_bar_chart"), height = "350px")
      ),
      
      # Publisher performance
      box(
        title = "Top Publishers", status = "warning", solidHeader = TRUE,
        width = 6, height = "400px",
        plotlyOutput(ns("publisher_chart"), height = "350px")
      )
    ),
    
    fluidRow(
      # Recent activity / top books
      box(
        title = "Top Selling Books", status = "primary", solidHeader = TRUE,
        width = 12,
        DT::dataTableOutput(ns("top_books_table"))
      )
    )
  )
}

# Dashboard Server
dashboardServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    
    # Reactive data
    summary_stats <- reactive({
      safe_query(get_summary_stats, 
                default_value = data.frame(
                  total_books = 0, total_sales_records = 0, unique_authors = 0,
                  unique_publishers = 0, min_year = MIN_YEAR, max_year = MAX_YEAR,
                  total_copies_sold = 0
                ),
                error_message = "Failed to load summary statistics")
    })
    
    sales_trend_data <- reactive({
      safe_query(function() {
        get_sales_by_year_genre() %>%
          group_by(year) %>%
          summarise(total_sales = sum(total_sales, na.rm = TRUE), .groups = "drop")
      }, 
      default_value = data.frame(year = MIN_YEAR:MAX_YEAR, total_sales = 0),
      error_message = "Failed to load sales trend data")
    })
    
    gender_data <- reactive({
      safe_query(get_gender_analysis,
                default_value = data.frame(gender = c("M", "F"), book_count = c(0, 0)),
                error_message = "Failed to load gender analysis")
    })
    
    genre_data <- reactive({
      safe_query(function() {
        get_books_summary() %>%
          group_by(genre) %>%
          summarise(
            total_sales = sum(total_sales, na.rm = TRUE),
            book_count = n(),
            .groups = "drop"
          ) %>%
          filter(!is.na(genre), total_sales > 0) %>%
          arrange(desc(total_sales)) %>%
          slice_head(n = 10)
      },
      default_value = data.frame(genre = character(0), total_sales = numeric(0)),
      error_message = "Failed to load genre data")
    })
    
    publisher_data <- reactive({
      safe_query(function() get_publisher_performance(min_books = 3),
                default_value = data.frame(publisher = character(0), total_sales = numeric(0)),
                error_message = "Failed to load publisher data")
    })
    
    top_books_data <- reactive({
      safe_query(function() get_top_books(limit = 15),
                default_value = data.frame(),
                error_message = "Failed to load top books data")
    })
    
    # Value boxes
    output$value_boxes <- renderUI({
      stats <- summary_stats()
      
      list(
        column(3, create_value_box(
          value = stats$total_books[1] %||% 0,
          subtitle = "Total Books",
          icon = "book",
          color = "blue"
        )),
        column(3, create_value_box(
          value = stats$unique_authors[1] %||% 0,
          subtitle = "Unique Authors", 
          icon = "users",
          color = "green"
        )),
        column(3, create_value_box(
          value = stats$total_copies_sold[1] %||% 0,
          subtitle = "Total Copies Sold",
          icon = "shopping-cart",
          color = "orange"
        )),
        column(3, create_value_box(
          value = paste0(stats$min_year[1] %||% MIN_YEAR, "-", stats$max_year[1] %||% MAX_YEAR),
          subtitle = "Data Range",
          icon = "calendar",
          color = "purple"
        ))
      )
    })
    
    # Sales trend plot
    output$sales_trend_plot <- renderPlotly({
      data <- sales_trend_data()
      
      if (nrow(data) == 0) {
        return(create_timeseries_plot(data.frame(), "year", "total_sales"))
      }
      
      create_timeseries_plot(
        data = data,
        x_col = "year",
        y_col = "total_sales",
        title = "Annual Book Sales",
        subtitle = "Total copies sold per year across all publishers"
      )
    })
    
    # Gender pie chart
    output$gender_pie_chart <- renderPlotly({
      data <- gender_data()
      
      if (nrow(data) == 0) {
        return(create_pie_chart(data.frame(), "gender", "book_count"))
      }
      
      # Clean up gender labels
      plot_data <- data %>%
        mutate(gender_label = case_when(
          gender == "M" ~ "Male Authors",
          gender == "F" ~ "Female Authors",
          TRUE ~ "Unknown"
        )) %>%
        filter(book_count > 0)
      
      create_pie_chart(
        data = plot_data,
        category_col = "gender_label",
        value_col = "book_count",
        title = "Distribution by Author Gender"
      )
    })
    
    # Genre bar chart
    output$genre_bar_chart <- renderPlotly({
      data <- genre_data()
      
      if (is.null(data) || nrow(data) == 0) {
        return(create_bar_plot(data.frame(), "genre", "total_sales"))
      }
      
      # Clean genre names safely
      plot_data <- data %>%
        mutate(genre_clean = case_when(
          is.na(genre) | genre == "" ~ "Other",
          genre == "F" ~ "Fiction",
          genre == "N" ~ "Non-fiction",
          genre == "P" ~ "Poetry",
          genre == "D" ~ "Drama",
          genre == "J" ~ "Juvenile",
          genre == "S" ~ "Short Stories",
          genre == "B" ~ "Biography",
          TRUE ~ "Other"
        ))
      
      create_bar_plot(
        data = plot_data,
        x_col = "genre_clean",
        y_col = "total_sales",
        title = "Sales by Genre",
        orientation = "horizontal"
      )
    })
    
    # Publisher chart
    output$publisher_chart <- renderPlotly({
      data <- publisher_data()
      
      if (nrow(data) == 0) {
        return(create_bar_plot(data.frame(), "publisher", "total_sales"))
      }
      
      # Take top 10 publishers
      plot_data <- data %>%
        slice_head(n = 10)
      
      create_bar_plot(
        data = plot_data,
        x_col = "publisher",
        y_col = "total_sales", 
        title = "Top Publishers by Sales",
        orientation = "horizontal"
      )
    })
    
    # Top books table
    output$top_books_table <- DT::renderDataTable({
      tryCatch({
        data <- top_books_data()
        
        if (is.null(data) || nrow(data) == 0) {
          return(DT::datatable(
            data.frame(Message = "No data available"),
            options = list(dom = 't', pageLength = 5),
            rownames = FALSE
          ))
        }
        
        # Prepare display data with safe operations
        display_data <- data %>%
          select(
            Author = author_surname,
            Title = book_title,
            Genre = genre,
            Publisher = publisher,
            `Pub. Year` = publication_year,
            `Total Sales` = total_sales,
            `Sales Years` = years_with_sales,
            `Retail Price` = retail_price
          ) %>%
          mutate(
            Author = ifelse(is.na(Author) | Author == "", "Unknown", as.character(Author)),
            Title = ifelse(is.na(Title) | Title == "", "Unknown", as.character(Title)),
            Genre = ifelse(is.na(Genre) | Genre == "", "Other", 
                          case_when(
                            Genre == "F" ~ "Fiction",
                            Genre == "N" ~ "Non-fiction",
                            Genre == "P" ~ "Poetry",
                            Genre == "D" ~ "Drama",
                            Genre == "J" ~ "Juvenile",
                            Genre == "S" ~ "Short Stories",
                            Genre == "B" ~ "Biography",
                            TRUE ~ "Other"
                          )),
            Publisher = ifelse(is.na(Publisher) | Publisher == "", "Unknown", as.character(Publisher)),
            `Pub. Year` = ifelse(is.na(`Pub. Year`), "Unknown", as.character(`Pub. Year`)),
            `Total Sales` = ifelse(is.na(`Total Sales`) | !is.numeric(`Total Sales`) | as.numeric(`Total Sales`) == 0, 
                                  "0", 
                                  format_number(as.numeric(`Total Sales`))),
            `Sales Years` = ifelse(is.na(`Sales Years`), "0", as.character(`Sales Years`)),
            `Retail Price` = ifelse(is.na(`Retail Price`) | !is.numeric(`Retail Price`), "N/A", 
                                   paste0("$", sprintf("%.2f", as.numeric(`Retail Price`))))
          )
        
        DT::datatable(
          display_data,
          options = list(
            pageLength = 10,
            scrollX = TRUE,
            order = list(list(5, 'desc')),  # Sort by Total Sales desc
            columnDefs = list(
              list(className = "dt-center", targets = c(4, 5, 6, 7))
            )
          ),
          rownames = FALSE
        )
      }, error = function(e) {
        # Return error message in table format
        DT::datatable(
          data.frame(Error = paste("Data loading error:", e$message)),
          options = list(dom = 't', pageLength = 5),
          rownames = FALSE
        )
      })
    })
    
  })
} 