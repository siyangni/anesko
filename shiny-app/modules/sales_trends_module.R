# Sales Trends Module
# Consolidated time-series sales analytics (1860-1920)

salesTrendsUI <- function(id) {
  ns <- NS(id)

  fluidPage(
    h3("Sales Trends"),
    p("Interactive time-series analysis of sales across years and dimensions.", 
      style = "font-size: 17px;"),
    
    tags$style(HTML("
      .control-group-large label,
      .control-group-large .radio label,
      .control-group-large .checkbox label {
        font-size: 18px;
        font-weight: 200;
      }
      .control-group-large .help-block { font-size: 16px; }
    ")),

    # Controls Row
    fluidRow(
      box(
        title = "Filters & Controls", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,

        fluidRow(
          column(3,
            tags$div(class = "control-group-large",
              sliderInput(
                ns("year_range"), "Sales Year Range:",
                min = sales_slider_min(),
                max = sales_slider_max(),
                value = sales_preset_range(),
                step = 1, sep = ""
              ),
              helpText(
                "Filters annual sales by the year copies were sold (book_sales.year), not publication year. Slider covers the full observed sales span plus a small buffer.",
                style = "font-size: 13px; margin-top: -6px;"
              ),
              tags$div(class = "control-group-large",
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
              helpText("Tip: Select multiple values in the filters to compare multiple series (e.g., choose several authors or publishers).", 
                       style = "font-size: 15px;"),
              tags$div(class = "control-group-large",
                checkboxGroupInput(
                  ns("gender_filter"), "Author Gender:",
                  choices = gender_filter_choices(mode = "multi"),
                  selected = gender_filter_choices(mode = "multi")
                )
              )
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
            shinyWidgets::pickerInput(
              ns("book_filter"), "Books (top performers):",
              choices = NULL, multiple = TRUE,
              options = list(`actions-box` = TRUE, `live-search` = TRUE,
                             `live-search-placeholder` = "Search top books…",
                             `selected-text-format` = "count > 2")
            ),
            tags$div(class = "control-group-large",
              checkboxGroupInput(
                ns("secondary_options"), "Options:",
                choices = c(
                  "Include Unknown Gender" = "include_unknown_gender",
                  "7-year Moving Average" = "smooth"
                ),
                selected = c("include_unknown_gender")
              )
            ),
            div(style = "margin-top: 10px;",
              actionButton(ns("update"), "Update Analysis", class = "btn-primary", 
                          style = "font-size: 16px; padding: 8px 16px;"),
              actionButton(ns("reset"), "Reset Filters", class = "btn-warning", 
                          style = "margin-left: 8px; font-size: 16px; padding: 8px 16px;")
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
        box(title = "Total Sales Summary", status = "info", solidHeader = TRUE,
            width = NULL,
            p("Total sales across all years for each group in your current selection.",
              style = "font-size: 18px; color: #666; margin-bottom: 10px;"),
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

salesTrendsServer <- function(id) {
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
      opts <- safe_query(get_filter_options, default_value = list(
        publishers = data.frame(publisher = character(0)),
        genres = data.frame(genre = character(0)),
        binding_states = data.frame(binding = character(0))
      ))

      # Publishers / genres / bindings from shared filter helpers
      pub_choices <- publisher_filter_choices(raw_df = opts$publishers)
      if (length(pub_choices) > 0) {
        shinyWidgets::updatePickerInput(session, "publisher_filter", choices = pub_choices)
      }

      genre_choices <- genre_filter_choices(include_all = FALSE, raw_df = opts$genres)
      if (length(genre_choices) > 0) {
        shinyWidgets::updatePickerInput(session, "genre_filter", choices = genre_choices)
      }

      bind_df <- if (is.null(opts$binding_states)) {
        data.frame(binding = character(0))
      } else {
        opts$binding_states
      }
      bind_choices <- binding_filter_choices(
        include_all = FALSE,
        raw_df = bind_df
      )
      if (length(bind_choices) > 0) {
        shinyWidgets::updatePickerInput(session, "binding_filter", choices = bind_choices)
      }

      # Top books for selection (catalog-style title labels; values stay book_id)
      top_books <- safe_query(function() get_top_books(limit = 200), default_value = data.frame())
      if (!is.null(top_books) && nrow(top_books) > 0) {
        catalog_titles <- format_title_catalog_style(top_books$book_title)
        labels <- paste0(catalog_titles, " (", top_books$author_surname, ", ", top_books$publication_year, ")")
        ord <- order(labels, top_books$book_id)
        choices <- stats::setNames(top_books$book_id[ord], labels[ord])
        shinyWidgets::updatePickerInput(session, "book_filter", choices = choices)
      }

    })



    # Reset filters
    observeEvent(input$reset, {
      updateSliderInput(
        session, "year_range",
        min = sales_slider_min(),
        max = sales_slider_max(),
        value = sales_preset_range()
      )
      updateRadioButtons(session, "group_dim", selected = "gender")
      updateSelectizeInput(session, "author_filter", selected = character(0), server = TRUE)
      shinyWidgets::updatePickerInput(session, "publisher_filter", selected = character(0))
      shinyWidgets::updatePickerInput(session, "genre_filter", selected = character(0))
      shinyWidgets::updatePickerInput(session, "binding_filter", selected = character(0))
      shinyWidgets::updatePickerInput(session, "book_filter", selected = character(0))
      updateCheckboxGroupInput(session, "gender_filter",
                              selected = gender_filter_choices(mode = "multi"))
      updateCheckboxGroupInput(session, "secondary_options", selected = c("include_unknown_gender"))
    })

    # Build filters reactive
    filters <- reactive({
      sales_years <- resolve_year_range(input$year_range, default = sales_preset_range())
      list(
        sales_start_year = sales_years$start,
        sales_end_year = sales_years$end,
        group_dim = input$group_dim %||% "gender",
        # Optional multi filters: sanitize blanks; empty = no restriction (all)
        authors = sanitize_filter_values(input$author_filter),
        publishers = sanitize_filter_values(input$publisher_filter),
        genres = sanitize_filter_values(input$genre_filter),
        bindings = sanitize_filter_values(input$binding_filter),
        books = sanitize_filter_values(input$book_filter),
        # Multi-select: do not expand empty selection to "all" via %||%
        genders = {
          g <- input$gender_filter
          if (is.null(g)) character(0) else as.character(g)
        },
        include_unknown_gender = ("include_unknown_gender" %in% (input$secondary_options %||% character(0))),
        smooth = ("smooth" %in% (input$secondary_options %||% character(0)))
      )
    })

    # Data retrieval
    ts_data <- eventReactive(input$update, {
      f <- filters()
      waiter <- waiter::Waiter$new(html = waiter::spin_ellipsis(), color = "rgba(255,255,255,0.6)")
      waiter$show()
      on.exit(waiter$hide(), add = TRUE)

      df <- safe_query(function() {
        get_sales_timeseries_filtered(
          sales_start_year = f$sales_start_year,
          sales_end_year = f$sales_end_year,
          group_by = f$group_dim,
          authors = f$authors, publishers = f$publishers, genres = f$genres,
          bindings = f$bindings, books = f$books,
          include_unknown_gender = f$include_unknown_gender,
          genders = f$genders
        )
      }, default_value = data.frame())

      # Defensive: RPostgres BIGINT can arrive as integer64; scales::comma fails on it.
      if (!is.null(df) && nrow(df) > 0) {
        if ("total_sales" %in% names(df)) df$total_sales <- as.numeric(df$total_sales)
        if ("book_count" %in% names(df)) df$book_count <- as.numeric(df$book_count)
      }
      df
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
        ) %>%
        dplyr::mutate(
          avg_annual_sales = ifelse(years_with_data > 0, total_sales / years_with_data, 0)
        )
      tmp %>% dplyr::arrange(dplyr::desc(.data$total_sales))
    })

    # Timeseries plot
    output$timeseries_plot <- renderPlotly({
      df <- ts_data()
      if (is.null(df) || nrow(df) == 0) return(plotly_empty("No data for selected filters"))

      plot_df <- df

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
        layout(
          title = list(text = "Sales Over Time", font = list(size = 18)),
          xaxis = list(
            title = list(text = "Year", font = list(size = 16)),
            tickfont = list(size = 14)
          ),
          yaxis = list(
            title = list(text = "Total Sales", font = list(size = 16)),
            tickfont = list(size = 14)
          ),
          legend = list(orientation = "h", font = list(size = 14)),
          margin = list(t = 80, b = 80, l = 80, r = 50)
        ) %>%
        config(
          displayModeBar = TRUE,
          modeBarButtonsToRemove = c('select2d', 'lasso2d', 'autoScale2d'),
          displaylogo = FALSE
        )
      plt
    })

    # Totals bar plot
    output$totals_plot <- renderPlotly({
      td <- totals_data()
      if (is.null(td) || nrow(td) == 0) return(plotly_empty("No totals available"))

      plot_ly(td, x = ~reorder(group_label, total_sales), y = ~total_sales,
              type = "bar", marker = list(color = "#2a4365"),
              hovertemplate = ~paste0(
                "Group: ", group_label,
                "<br>Total Sales: ", scales::comma(total_sales),
                "<br>Avg Annual Sales: ", scales::comma(round(avg_annual_sales, 0)),
                "<br>Books: ", book_count,
                "<br>Years with Data: ", years_with_data,
                "<extra></extra>"
              )) %>%
        layout(
          title = list(
            text = "Total Sales by Selected Groups",
            font = list(size = 18)
          ),
          xaxis = list(
            title = list(text = "Selected Groups", font = list(size = 16)),
            tickfont = list(size = 14)
          ),
          yaxis = list(
            title = list(text = "Total Sales", font = list(size = 16)),
            tickfont = list(size = 14)
          ),
          margin = list(t = 80, b = 80, l = 80, r = 20)
        ) %>%
        add_annotations(
          text = "Bars show total sales across all years for each group in your selection.",
          xref = "paper",
          yref = "paper",
          x = 0,
          y = 1.05,
          xanchor = "left",
          yanchor = "bottom",
          showarrow = FALSE,
          font = list(size = 13, color = "gray60")
        ) %>%
        config(
          displayModeBar = TRUE,
          modeBarButtonsToRemove = c('select2d', 'lasso2d', 'autoScale2d'),
          displaylogo = FALSE
        )
    })

    # Summary table
    output$summary_table <- DT::renderDataTable({
      td <- totals_data()
      if (is.null(td) || nrow(td) == 0) {
        return(DT::datatable(data.frame(Message = "No data available"), options = list(dom = 't')))
      }
      disp <- td %>%
        dplyr::select(
          Group = group_label,
          `Total Sales` = total_sales,
          `Avg Annual Sales` = avg_annual_sales,
          `Book Count` = book_count,
          `Years with Data` = years_with_data
        ) %>%
        dplyr::mutate(
          `Total Sales` = format_number(`Total Sales`),
          `Avg Annual Sales` = format_number(round(`Avg Annual Sales`, 0)),
          `Book Count` = format_number(`Book Count`),
          `Years with Data` = format_number(`Years with Data`)
        )
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

    for (out_id in c(
      "timeseries_plot", "totals_plot", "summary_table", "detail_table"
    )) {
      try(outputOptions(output, out_id, suspendWhenHidden = FALSE), silent = TRUE)
    }
  })
}

