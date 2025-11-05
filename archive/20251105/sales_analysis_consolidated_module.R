# Sales Analysis Module
# Consolidated sales analytics across all dimensions (1860-1920)

salesAnalysisUI <- function(id) {
  ns <- NS(id)

  fluidPage(
    h3("Sales Analysis"),
    p("Comprehensive sales analytics across time, demographics, and content dimensions."),

    # Controls Row
    fluidRow(
      box(
        title = "Filters & Controls", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,

        fluidRow(
          column(3,
            selectInput(
              ns("analysis_type"), "Analysis Type:",
              choices = list(
                "Time Series Sales Analysis" = "time_series",
                "Sales by Author Gender" = "gender_sales",
                "Sales by Publisher" = "publisher_sales",
                "Sales by Genre" = "genre_sales",
                "Book & Binding Sales Analysis" = "book_binding",
                "Period-to-Period Sales Comparison" = "period_comparison",
                "Market Share Analysis" = "market_share"
              ),
              selected = "time_series"
            ),
            sliderInput(
              ns("year_range"), "Publication Year Range:",
              min = MIN_YEAR, max = MAX_YEAR, value = DEFAULT_YEAR_RANGE,
              step = 1, sep = ""
            ),
            conditionalPanel(
              condition = "input.analysis_type == 'time_series'",
              ns = ns,
              radioButtons(
                ns("group_dim"), "Primary Grouping:",
                choices = c(
                  "Author Gender" = "gender",
                  "Author" = "author",
                  "Publisher" = "publisher",
                  "Book" = "book",
                  "Genre" = "genre",
                  "Binding" = "binding"
                ),
                selected = "gender"
              )
            ),
            helpText("Tip: Select multiple values in the filters to compare multiple series (e.g., choose several authors or publishers)."),
            checkboxGroupInput(
              ns("gender_filter"), "Author Gender:",
              choices = c("Male", "Female", "Unknown"),
              selected = c("Male", "Female", "Unknown")
            )
          ),
          column(3,
            selectizeInput(
              ns("author_filter"), "Authors (search):",
              choices = NULL, multiple = TRUE,
              options = list(
                placeholder = "Type to search authors…",
                maxOptions = 200, create = FALSE, closeAfterSelect = TRUE
              )
            ),
            shinyWidgets::pickerInput(
              ns("publisher_filter"), "Publishers:",
              choices = NULL, multiple = TRUE,
              options = list(`actions-box` = TRUE, `live-search` = TRUE,
                             `live-search-placeholder` = "Search publishers…",
                             `selected-text-format` = "count > 2")
            )
          ),
          column(3,
            shinyWidgets::pickerInput(
              ns("genre_filter"), "Genres:",
              choices = NULL, multiple = TRUE,
              options = list(`actions-box` = TRUE, `live-search` = TRUE,
                             `live-search-placeholder` = "Search genres…",
                             `selected-text-format` = "count > 2")
            ),
            shinyWidgets::pickerInput(
              ns("binding_filter"), "Binding Types:",
              choices = NULL, multiple = TRUE,
              options = list(`actions-box` = TRUE, `live-search` = TRUE,
                             `live-search-placeholder` = "Search bindings…",
                             `selected-text-format` = "count > 2")
            )
          ),
          column(3,
            selectizeInput(
              ns("book_filter"), "Books (top performers):",
              choices = NULL, multiple = TRUE,
              options = list(placeholder = "Search top books…",
                             maxOptions = 200, create = FALSE, closeAfterSelect = TRUE)
            ),
            checkboxGroupInput(
              ns("secondary_options"), "Options:",
              choices = c(
                "Include Unknown Gender" = "include_unknown_gender",
                "Normalize to Index (Year 1 = 100)" = "normalize",
                "Average annual totals (divide by years with data)" = "normalize_years",
                "7-year Moving Average" = "smooth"
              ),
              selected = c("include_unknown_gender")
            ),
            div(style = "margin-top: 10px;",
              actionButton(ns("update"), "Update Analysis", class = "btn-primary"),
              actionButton(ns("reset"), "Reset Filters", class = "btn-warning", style = "margin-left: 8px;")
            )
          )
        )

      )
    ),



    # Visualizations
    fluidRow(
      column(8,
        box(title = "Sales Over Time", status = "success", solidHeader = TRUE,
            width = NULL,
            plotlyOutput(ns("timeseries_plot"), height = "420px"))
      ),
      column(4,
        box(title = "Totals by Selection", status = "info", solidHeader = TRUE,
            width = NULL,
            plotlyOutput(ns("totals_plot"), height = "420px"))
      )
    ),



    # Tables
    fluidRow(
      column(5,
        box(title = "Summary Statistics", status = "warning", solidHeader = TRUE,
            width = NULL,
            DT::dataTableOutput(ns("summary_table")))
      ),
      column(7,
        box(title = "Detailed Results", status = "primary", solidHeader = TRUE,
            width = NULL,
            DT::dataTableOutput(ns("detail_table")),
            br(),
            downloadButton(ns("download_detail"), "Download CSV", class = "btn-info")
        )
      )
    )
  )
}

salesAnalysisServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Initialize filters
    observe({
      # Authors
      authors <- safe_query(get_author_surnames, default_value = data.frame(author_surname = character(0)))
      if (!is.null(authors) && nrow(authors) > 0) {
        updateSelectizeInput(session, "author_filter", choices = authors$author_surname, server = TRUE)
      }

      # Publishers
      pubs <- safe_query(function() safe_db_query("SELECT DISTINCT publisher FROM book_entries WHERE publisher IS NOT NULL ORDER BY publisher"),
                         default_value = data.frame(publisher = character(0)))
      if (!is.null(pubs) && nrow(pubs) > 0) {
        shinyWidgets::updatePickerInput(session, "publisher_filter", choices = pubs$publisher)
      }

      # Genres
      genres <- safe_query(function() safe_db_query("SELECT DISTINCT genre FROM book_entries WHERE genre IS NOT NULL ORDER BY genre"),
                           default_value = data.frame(genre = character(0)))
      if (!is.null(genres) && nrow(genres) > 0) {
        shinyWidgets::updatePickerInput(session, "genre_filter", choices = genres$genre)
      }

      # Bindings
      binds <- safe_query(get_binding_states, default_value = data.frame(binding = character(0)))
      if (!is.null(binds) && nrow(binds) > 0) {
        shinyWidgets::updatePickerInput(session, "binding_filter", choices = sort(unique(stringr::str_to_title(trimws(binds$binding)))))
      }

      # Top books for selection
      top_books <- safe_query(function() get_top_books(limit = 200), default_value = data.frame())
      if (!is.null(top_books) && nrow(top_books) > 0) {
        labels <- paste0(top_books$book_title, " (", top_books$author_surname, ", ", top_books$publication_year, ")")
        choices <- stats::setNames(top_books$book_id, labels)
        updateSelectizeInput(session, "book_filter", choices = choices, server = TRUE)
      }

    })



    # Reset filters
    observeEvent(input$reset, {
      updateSliderInput(session, "year_range", value = DEFAULT_YEAR_RANGE)
      updateRadioButtons(session, "group_dim", selected = "gender")
      updateSelectizeInput(session, "author_filter", selected = character(0), server = TRUE)
      shinyWidgets::updatePickerInput(session, "publisher_filter", selected = character(0))
      shinyWidgets::updatePickerInput(session, "genre_filter", selected = character(0))
      shinyWidgets::updatePickerInput(session, "binding_filter", selected = character(0))
      updateSelectizeInput(session, "book_filter", selected = character(0), server = TRUE)
      updateCheckboxGroupInput(session, "secondary_options", selected = c("include_unknown_gender"))
    })

    # Build filters reactive
    filters <- reactive({
      list(
        years = input$year_range %||% c(MIN_YEAR, MAX_YEAR),
        group_dim = input$group_dim %||% "gender",
        authors = input$author_filter %||% character(0),
        publishers = input$publisher_filter %||% character(0),
        genres = input$genre_filter %||% character(0),
        bindings = input$binding_filter %||% character(0),
        books = input$book_filter %||% character(0),
        genders = input$gender_filter %||% c("Male","Female","Unknown"),
        include_unknown_gender = ("include_unknown_gender" %in% (input$secondary_options %||% character(0))),
        normalize = ("normalize" %in% (input$secondary_options %||% character(0))),
        normalize_years = ("normalize_years" %in% (input$secondary_options %||% character(0))),
        smooth = ("smooth" %in% (input$secondary_options %||% character(0)))
      )
    })

    # Data retrieval
    ts_data <- eventReactive(input$update, {
      f <- filters()
      waiter <- waiter::Waiter$new(html = waiter::spin_ellipsis(), color = "rgba(255,255,255,0.6)")
      waiter$show()
      on.exit(waiter$hide(), add = TRUE)

      safe_query(function() {
        get_sales_timeseries_filtered(
          start_year = f$years[1], end_year = f$years[2],
          group_by = f$group_dim,
          authors = f$authors, publishers = f$publishers, genres = f$genres,
          bindings = f$bindings, books = f$books,
          include_unknown_gender = f$include_unknown_gender,
          genders = f$genders
        )
      }, default_value = data.frame())
    })

    # Derived data for totals
    totals_data <- reactive({
      df <- ts_data()
      if (is.null(df) || nrow(df) == 0) return(data.frame())
      tmp <- df %>% dplyr::group_by(.data$group_label) %>%
        dplyr::summarise(
          total_sales = sum(.data$total_sales, na.rm = TRUE),
          years_with_data = dplyr::n_distinct(.data$year[.data$total_sales > 0]),
          book_count = sum(.data$book_count, na.rm = TRUE),
          .groups = "drop"
        )
      if (filters()$normalize_years) {
        tmp <- tmp %>% dplyr::mutate(total_sales = ifelse(years_with_data > 0, total_sales / years_with_data, total_sales))
      }
      tmp %>% dplyr::arrange(dplyr::desc(.data$total_sales))
    })

    # Timeseries plot
    output$timeseries_plot <- renderPlotly({
      df <- ts_data()
      if (is.null(df) || nrow(df) == 0) return(plotly_empty("No data for selected filters"))

      plot_df <- df
      # Normalize if requested
      if (filters()$normalize) {
        plot_df <- plot_df %>% dplyr::group_by(.data$group_label) %>%
          dplyr::mutate(total_sales = ifelse(dplyr::first(total_sales) > 0,
                                             100 * total_sales / dplyr::first(total_sales), total_sales)) %>%
          dplyr::ungroup()
      }

      # Optional smoothing (7-year moving average)
      if (filters()$smooth) {
        plot_df <- plot_df %>% dplyr::group_by(.data$group_label) %>%
          dplyr::arrange(.data$year) %>%
          dplyr::mutate(total_sales = as.numeric(stats::filter(total_sales, rep(1/7, 7), sides = 2))) %>%
          dplyr::ungroup()
      }

      plt <- plot_ly(plot_df, x = ~year, y = ~total_sales, color = ~group_label,
                     colors = AMBIENT_COLORS, type = "scatter", mode = "lines+markers",
                     text = ~paste0(
                       "Group: ", group_label,
                       "<br>Year: ", year,
                       "<br>Total Sales: ", scales::comma(total_sales),
                       "<br>Books: ", book_count
                     ),
                     hovertemplate = "%{text}<extra></extra>") %>%
        layout(title = "Sales Over Time",
               xaxis = list(title = "Year"), yaxis = list(title = if (filters()$normalize) "Index (Year 1=100)" else "Total Sales"),
               legend = list(orientation = "h"))
      plt
    })

    # Totals bar plot
    output$totals_plot <- renderPlotly({
      td <- totals_data()
      if (is.null(td) || nrow(td) == 0) return(plotly_empty("No totals available"))
      y_title <- if (filters()$normalize_years) "Avg Annual Sales" else "Total Sales"
      plot_ly(td, x = ~reorder(group_label, total_sales), y = ~total_sales,
              type = "bar", marker = list(color = "#2a4365"),
              text = ~paste0("Books: ", book_count, ifelse(!is.null(years_with_data), paste0(" | Years: ", years_with_data), "")),
              hovertemplate = paste0("Group: %{x}<br>", y_title, ": %{y:,}<br>%{text}<extra></extra>")) %>%
        layout(title = "Totals by Selected Dimension", xaxis = list(title = "Group"), yaxis = list(title = y_title)) %>%
        config(displayModeBar = TRUE)
    })

    # Summary table
    output$summary_table <- DT::renderDataTable({
      td <- totals_data()
      if (is.null(td) || nrow(td) == 0) {
        return(DT::datatable(data.frame(Message = "No data available"), options = list(dom = 't')))
      }
      disp <- td
      disp$Metric <- if (filters()$normalize_years) "Avg Annual Sales" else "Total Sales"
      disp$total_sales <- format_number(disp$total_sales)
      disp$book_count <- format_number(disp$book_count)
      if ("years_with_data" %in% names(disp)) disp$years_with_data <- format_number(disp$years_with_data)
      DT::datatable(disp, options = list(pageLength = 10, dom = 't', scrollX = TRUE), rownames = FALSE)
    })

    # Detailed table
    output$detail_table <- DT::renderDataTable({
      df <- ts_data()
      if (is.null(df) || nrow(df) == 0) {
        return(DT::datatable(data.frame(Message = "No data available"), options = list(dom = 't')))
      }
      disp <- df %>% dplyr::arrange(.data$group_label, .data$year)
      disp$total_sales <- format_number(disp$total_sales)
      disp$book_count <- format_number(disp$book_count)
      DT::datatable(disp, options = list(pageLength = 15, scrollX = TRUE, dom = 'Bfrtip', buttons = c('copy','csv','excel')), rownames = FALSE)
    })



    # Download
    output$download_detail <- downloadHandler(
      filename = function() paste0("sales_trends_", Sys.Date(), ".csv"),
      content = function(file) {
        df <- ts_data()
        if (!is.null(df) && nrow(df) > 0) utils::write.csv(df, file, row.names = FALSE)
      }
    )
  })
}

