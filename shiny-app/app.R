# American Authorship Database Dashboard
# Main application entry point

# Source all components
source("global.R")
source("ui.R") 
source("server.R")

# Launch the application
shinyApp(ui = ui, server = server)
