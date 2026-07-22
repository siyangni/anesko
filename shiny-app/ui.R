# Main UI for American Authorship Dashboard

ui <- dashboardPage(
  skin = "blue",

  # Header
  dashboardHeader(
    title = APP_TITLE,
    titleWidth = 400,
    .list = list(
      tags$li(class = "dropdown", style = "padding: 5px 15px; margin: 0;",
        tags$div(style = "display: flex; align-items: center; gap: 15px; height: 50px;",
          tags$a(href = "https://la.psu.edu/", target = "_blank",
            tags$img(src = "psu_cla_logo.png",
                     style = "height: 60px; width: auto; object-fit: contain;",
                     alt = "Penn State College of Liberal Arts")
          ),
          tags$a(href = "https://dla.psu.edu/", target = "_blank",
            tags$img(src = "psu_dla_logo.png",
                     style = "height: 38px; width: auto; object-fit: contain;",
                     alt = "Digital Liberal Arts Research Initiative")
          )
        )
      )
    )
  ),

  # Sidebar
  dashboardSidebar(
    width = SIDEBAR_WIDTH,
    sidebarMenu(
      id = "main_menu",
      menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
      menuItem("Explore Books", tabName = "books", icon = icon("book")),
      menuItem("Sales Trends", tabName = "sales_trends", icon = icon("chart-line")),
      menuItem("Author Analysis", tabName = "authors", icon = icon("users")),
      menuItem("Author Networks", tabName = "networks", icon = icon("project-diagram")),
      menuItem("Royalties", icon = icon("money-bill"), startExpanded = TRUE,
        menuSubItem("Royalty Analysis", tabName = "royalties", icon = icon("chart-bar")),
        menuSubItem("Royalty Income Query", tabName = "royalty_query", icon = icon("calculator"))
      ),
      menuItem("Genre Analysis", tabName = "genres", icon = icon("list")),
      br(),
      menuItem("About", tabName = "about", icon = icon("info-circle"))
    ),

    # Footer info
    br(), br(),
    div(
      style = "position: absolute; bottom: 20px; left: 20px; right: 20px;
               color: #4b5563; font-size: 16px; text-align: center;",
      p("American Authorship Database"),
      p("1860-1920"),
      p(paste("Version", APP_VERSION))
    )
  ),

  # Body
  dashboardBody(
    # Include custom CSS
    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "style.css"),
      tags$script(src = "browser_history.js"),
      tags$meta(name = 'viewport', content = 'width=device-width, initial-scale=1.0'),

      tags$style(HTML("
        .content-wrapper, .right-side {
          background-color: #f4f4f4;
        }
        .box {
          box-shadow: 0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.24);
        }
        .alert {
          border-radius: 5px;
        }
        .dt-center {
          text-align: center;
        }
      "))
    ),

    # Apply custom theme
    fresh::use_theme(app_theme),

    # Loading spinner
    waiter::use_waiter(),

    # Tab items
    tabItems(
      # Dashboard tab
      tabItem(
        tabName = "dashboard",
        dashboardUI("dashboard_module")
      ),

      # Books explorer tab
      tabItem(
        tabName = "books",
        bookExplorerUI("books_module")
      ),

      # Sales trends tab
      tabItem(
        tabName = "sales_trends",
        salesTrendsUI("sales_trends_module")
      ),

      # Author analysis tab
      tabItem(
        tabName = "authors",
        authorAnalysisUI("authors_module")
      ),

      # Author networks tab (NEW)
      tabItem(
        tabName = "networks",
        authorNetworksUI("networks_module")
      ),

      # Royalty analysis tab (NEW)
      tabItem(
        tabName = "royalties",
        royaltyAnalysisUI("royalties_module")
      ),

      # Royalty income query tab (NEW)
      tabItem(
        tabName = "royalty_query",
        royaltyQueryUI("royalty_query_module")
      ),

      # Genre analysis tab
      tabItem(
        tabName = "genres",
        genreAnalysisUI("genres_module")
      ),

      # About tab
      tabItem(
        tabName = "about",
        fluidPage(
          # Institutional branding section
          fluidRow(
            column(12,
              div(class = "about-logos-section",
                h4("Supported By"),
                div(class = "about-logos-container",
                  tags$a(href = "https://la.psu.edu/", target = "_blank",
                    tags$img(src = "psu_cla_logo.png", class = "about-logo about-logo-cla",
                             alt = "Penn State College of Liberal Arts")
                  ),
                  tags$a(href = "https://dla.psu.edu/", target = "_blank",
                    tags$img(src = "psu_dla_logo.png", class = "about-logo about-logo-dla",
                             alt = "Digital Liberal Arts Research Initiative")
                  )
                )
              )
            )
          ),
          fluidRow(
            column(8,
              box(
                title = "About This Dashboard", status = "primary", solidHeader = TRUE,
                width = NULL,
                div(
                  p("This dashboard enables interactive exploration of a \"Database of American Authorship, 1860-1920,\" drawing upon publishing and sales data from major American publishing houses during the transformative period of the late 19th and early 20th centuries."),
                  br(),
                  p("Wherever possible, the database includes actual sales figures (or informed estimates) and royalty information for a broad sample of authors and works, allowing for a much more accurate reconstruction of the literary marketplace and facilitating comparative analyses across specific periods and according to variables such as authorship gender, literary genre, binding states, and retail price."),
                  br(),
                  p("This dynamic, accessible data dashboard aggregates and visualizes economic data for American authorship, from book sales to authorial earnings. This resource will provide a robust foundation for scholars to investigate trends and disparities in the literary marketplace across variables like gender, genre, and historical periods. With this data, researchers will be able to perform longitudinal analyses that reveal shifts over time, offering a valuable perspective on the socio-economic landscape of American literature during this era."),
                  br(),
                  p("Existing scholarship on this period has often relied on anecdotal evidence from publishers' memoirs and \"official\" house histories, almost all lacking comprehensive quantitative data. This project, however, moves beyond these sources, building a database grounded in empirical evidence derived from prominent publishers' archives.")
                )
              ),

              box(
                title = "Acknowledgments", status = "info", solidHeader = TRUE,
                width = NULL,
                div(
                  p("Shortly after the inception of this project, two research assistants helped code data from the primary sources: Stephen Szaraz (at Harvard) and Matthew Inman (at Penn State).  Steve Maczuga at Penn State constructed a preliminary version of the database.  As platforms evolved, Mason Slingerland converted the original data files into a form now compatible with Microsoft Excel.  Since then, their work has been enhanced by new design possibilities incorporated by other Penn State affiliates: Jennifer Isasi, Nick Mclean, and Siyang Ni.  Funding to support this research has come from the College of the Liberal Arts and the Center for the Study of Data Analytics at Penn State.")
                )
              )
            ),

            column(4,
              box(
                title = "Project Information", status = "success", solidHeader = TRUE,
                width = NULL,
                tags$dl(
                  tags$dt("Principal Investigator:"),
                  tags$dd("Dr. Michael Anesko"),
                  tags$dd("Penn State University"),
                  br(),
                  tags$dt("Data Period:"),
                  tags$dd("1860-1920"),
                  br(),
                  tags$dt("Total Records:"),
                  tags$dd("627 books, 27,771 sales records"),
                  br(),
                  tags$dt("Version:"),
                  tags$dd(APP_VERSION),
                  br(),
                  tags$dt("Last Updated:"),
                  tags$dd(format(Sys.Date(), "%B %d, %Y"))
                )
              ),

              box(
                title = "Technical Details", status = "warning", solidHeader = TRUE,
                width = NULL,
                p("Built with:"),
                tags$ul(
                  tags$li("R Shiny"),
                  tags$li("PostgreSQL Database"),
                  tags$li("Interactive Plotly Charts"),
                  tags$li("Responsive Bootstrap UI")
                ),
                br(),
                p("For technical support or questions about this dashboard,
                  please contact the development team.")
              )
            )
          )
        )
      )
    ),

    # Footer with copyright and accessibility statement
    tags$footer(
      style = "margin-top: 30px; padding: 20px; background-color: #f8f9fa;
               border-top: 1px solid #dee2e6; text-align: center; font-size: 15px;
               color: #4b5563;",
      HTML("© 2025 The Pennsylvania State University. All rights reserved.
            Except where otherwise noted, this work is subject to a
            <a href='https://creativecommons.org/licenses/by-nc-sa/4.0/' target='_blank'
            style='color: #007bff;'>Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International</a>.
            <a href='https://www.psu.edu/accessibilitystatement' target='_blank'
            style='color: #007bff;'>Accessibility Statement</a>.")
    )
  )
)