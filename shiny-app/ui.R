# Main UI for American Authorship Dashboard

ui <- dashboardPage(
  skin = "blue",
  
  # Header
  dashboardHeader(
    title = APP_TITLE,
    titleWidth = 400
  ),
  
  # Sidebar
  dashboardSidebar(
    width = 250,
    sidebarMenu(
      id = "main_menu",
      menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
      menuItem("Explore Books", tabName = "books", icon = icon("book")),
      menuItem("Sales Analysis", tabName = "sales", icon = icon("chart-line")),
      menuItem("Author Analysis", tabName = "authors", icon = icon("users")),
      menuItem("Genre Analysis", tabName = "genres", icon = icon("list")),
      br(),
      menuItem("About", tabName = "about", icon = icon("info-circle"))
    ),
    
    # Footer info
    br(), br(),
    div(
      style = "position: absolute; bottom: 20px; left: 20px; right: 20px; 
               color: #ccc; font-size: 11px; text-align: center;",
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
      
      # Sales analysis tab
      tabItem(
        tabName = "sales",
        salesAnalysisUI("sales_module")
      ),
      
      # Author analysis tab
      tabItem(
        tabName = "authors",
        authorAnalysisUI("authors_module")
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
          fluidRow(
            column(8,
              box(
                title = "About This Dashboard", status = "primary", solidHeader = TRUE,
                width = NULL,
                div(
                  p("This dashboard provides interactive exploration of the American Authorship Database (1860-1920), 
                    a comprehensive collection of publishing and sales data from major American publishers during 
                    the transformative period of the late 19th and early 20th centuries."),
                  br(),
                  h4("Data Sources:"),
                  tags$ul(
                    tags$li("Houghton, Mifflin Co. and predecessors (Harvard University)"),
                    tags$li("Harper & Brothers (Chadwyck-Healey Microfilm)"),
                    tags$li("Scribner Archive (Princeton University)"),
                    tags$li("J. B. Lippincott Deposit (University of Pennsylvania)")
                  ),
                  br(),
                  p(strong("Principal Investigator:"), "Dr. Michael Anesko (Penn State University)")
                )
              ),
              
              box(
                title = "Methodology", status = "info", solidHeader = TRUE,
                width = NULL,
                div(
                  h4("Data Collection:"),
                  p("All data has been hand-transcribed from original publisher archives, including sales records, 
                    royalty statements, and contract information."),
                  br(),
                  h4("Coverage:"),
                  tags$ul(
                    tags$li("630+ book entries with comprehensive metadata"),
                    tags$li("63 years of sales data (1858-1920)"),
                    tags$li("Focus on major publishers and commercially successful works")
                  ),
                  br(),
                  h4("Validation:"),
                  p("Data has been cross-referenced across multiple sources where possible to ensure accuracy.")
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
    )
  )
) 