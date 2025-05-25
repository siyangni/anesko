# Book Explorer Module
# Interactive book browsing and filtering interface

# Book Explorer UI
bookExplorerUI <- function(id) {
  ns <- NS(id)
  
  fluidPage(
    fluidRow(
      # Filters sidebar
      column(3,
        box(
          title = "Filters", status = "primary", solidHeader = TRUE,
          width = NULL,
          
          # Search box
          textInput(ns("search_term"), "Search Books/Authors:", 
                   placeholder = "Enter title or author name..."),
          
          # Genre filter
          selectInput(ns("genre_filter"), "Genre:",
                     choices = NULL, multiple = TRUE),
          
          # Gender filter
          checkboxGroupInput(ns("gender_filter"), "Author Gender:",
                           choices = list("Male" = "M", "Female" = "F"),
                           selected = c("M", "F")),
          
          # Year range
          sliderInput(ns("year_range"), "Publication Year Range:",
                     min = MIN_YEAR, max = MAX_YEAR,
                     value = DEFAULT_YEAR_RANGE, step = 1,
                     sep = ""),
          
          # Publisher filter
          selectInput(ns("publisher_filter"), "Publisher:",
                     choices = NULL, multiple = TRUE),
          
          br(),
          actionButton(ns("reset_filters"), "Reset Filters", 
                      class = "btn-warning", width = "100%")
        )
      ),
      
      # Main content
      column(9,
        # Results summary
        fluidRow(
          column(12,
            uiOutput(ns("results_summary"))
          )
        ),
        
        # Books table
        fluidRow(
          column(12,
            box(
              title = "Books", status = "primary", solidHeader = TRUE,
              width = NULL,
              DT::dataTableOutput(ns("books_table"))
            )
          )
        )
      )
    )
  )
}

# Book Explorer Server
bookExplorerServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    
    # Initialize filter options
    observe({
      filter_options <- safe_query(get_filter_options, 
                                  default_value = list(genres = data.frame(), 
                                                      publishers = data.frame(),
                                                      genders = data.frame()))
      
      # Update genre choices
      if (nrow(filter_options$genres) > 0) {
        genre_choices <- setNames(filter_options$genres$genre, 
                                 sapply(filter_options$genres$genre, clean_genre))
        updateSelectInput(session, "genre_filter", choices = genre_choices)
      }
      
      # Update publisher choices
      if (nrow(filter_options$publishers) > 0) {
        publisher_choices <- setNames(filter_options$publishers$publisher,
                                    filter_options$publishers$publisher)
        updateSelectInput(session, "publisher_filter", choices = publisher_choices)
      }
    })
    
    # Reactive filtered data
    filtered_books <- reactive({
      safe_query(function() {
        search_books(
          search_term = input$search_term %||% "",
          genre_filter = input$genre_filter,
          gender_filter = input$gender_filter,
          year_range = input$year_range %||% c(MIN_YEAR, MAX_YEAR),
          publisher_filter = input$publisher_filter
        )
      },
      default_value = data.frame(),
      error_message = "Failed to load book data")
    })
    
    # Results summary
    output$results_summary <- renderUI({
      data <- filtered_books()
      total_books <- nrow(data)
      total_sales <- sum(data$total_sales, na.rm = TRUE)
      
      div(
        class = "alert alert-info",
        style = "margin-bottom: 20px;",
        h4(paste("Found", format_number(total_books), "books")),
        p(paste("Total sales:", format_number(total_sales), "copies"))
      )
    })
    
    # Books table
    output$books_table <- DT::renderDataTable({
      data <- filtered_books()
      
      if (nrow(data) == 0) {
        return(DT::datatable(
          data.frame(Message = "No books found matching your criteria"),
          options = list(dom = 't')
        ))
      }
      
      # Prepare display data
      display_data <- data %>%
        select(
          Author = author_surname,
          Title = book_title,
          Genre = genre,
          Gender = gender,
          Publisher = publisher,
          `Pub. Year` = publication_year,
          Binding = binding,
          `Retail Price` = retail_price,
          `Royalty Rate` = royalty_rate,
          `Total Sales` = total_sales,
          `Sales Years` = years_with_sales
        ) %>%
        mutate(
          Genre = clean_genre(Genre),
          Gender = clean_gender(Gender),
          `Retail Price` = ifelse(is.na(`Retail Price`), "N/A", 
                                 paste0("$", sprintf("%.2f", `Retail Price`))),
          `Royalty Rate` = ifelse(is.na(`Royalty Rate`), "N/A",
                                 paste0(round(`Royalty Rate` * 100, 1), "%")),
          `Total Sales` = format_number(`Total Sales`)
        )
      
      DT::datatable(
        display_data,
        options = list(
          pageLength = 25,
          scrollX = TRUE,
          order = list(list(5, 'desc')),  # Sort by Pub. Year desc
          columnDefs = list(
            list(className = "dt-center", targets = c(3, 5, 6, 7, 8, 9, 10)),
            list(width = "150px", targets = 1),  # Title column
            list(width = "100px", targets = c(4, 5))  # Publisher, Year
          )
        ),
        rownames = FALSE,
        filter = 'top'
      ) %>%
        DT::formatStyle(
          'Total Sales',
          backgroundColor = DT::styleInterval(
            cuts = c(1000, 5000, 20000),
            values = c('white', '#d4edda', '#c3e6cb', '#b7dfbb')
          )
        )
    })
    
    # Reset filters
    observeEvent(input$reset_filters, {
      updateTextInput(session, "search_term", value = "")
      updateSelectInput(session, "genre_filter", selected = character(0))
      updateCheckboxGroupInput(session, "gender_filter", selected = c("M", "F"))
      updateSliderInput(session, "year_range", value = DEFAULT_YEAR_RANGE)
      updateSelectInput(session, "publisher_filter", selected = character(0))
    })
    
  })
} 