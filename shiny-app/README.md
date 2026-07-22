# American Authorship Database - Shiny Dashboard

Interactive dashboard for exploring the American Authorship Database (1860-1920).

## Application Structure

```
shiny-app/
├── app.R                    # Main application entry point
├── global.R                 # Global setup, libraries, and functions
├── ui.R                     # Main UI definition
├── server.R                 # Main server logic
├── modules/                 # Modular UI and server components
│   ├── dashboard_module.R       # Overview dashboard
│   ├── book_explorer_module.R   # Book browsing and filtering
│   ├── sales_analysis_module.R  # Sales trend analysis (placeholder)
│   ├── author_analysis_module.R # Author demographics (placeholder)
│   └── genre_analysis_module.R  # Genre trends (placeholder)
├── utils/                   # Utility functions
│   ├── database.R              # Database connection and queries
│   ├── data_processing.R       # Data transformation functions
│   └── plotting.R              # Plotting and visualization functions
├── config/                  # Configuration files
│   └── app_config.R            # Application settings and constants
├── www/                     # Static web assets
│   └── style.css               # Custom CSS styling
└── README.md               # This file
```

## Features

### Dashboard Overview
- **Summary Statistics**: Total books, authors, sales, and date range
- **Sales Trends**: Interactive time series of annual sales
- **Gender Distribution**: Author gender breakdown
- **Genre Performance**: Top-selling genres
- **Publisher Rankings**: Leading publishers by sales volume
- **Top Books Table**: Best-selling titles with details

### Book Explorer
- **Advanced Filtering**: Search by title/author, genre, gender, year range, publisher
- **Interactive Tables**: Sortable, searchable data tables with pagination
- **Real-time Results**: Dynamic filtering with instant updates
- **Export Capabilities**: Download filtered results
- **Visual Indicators**: Color-coded sales performance

### Analysis Modules (Expandable)
- **Sales Analysis**: Time series and trend analysis
- **Author Analysis**: Gender disparities and career patterns
- **Genre Analysis**: Literary genre evolution and market dynamics

## Prerequisites

### R Packages Required
The application automatically loads these packages (install if needed):

```r
# Core Shiny packages
install.packages(c("shiny", "shinydashboard", "shinydashboardPlus"))

# Database connectivity
install.packages(c("DBI", "RPostgreSQL", "pool"))

# Data manipulation and visualization
install.packages(c("dplyr", "tidyr", "ggplot2", "plotly", "DT"))

# UI enhancements
install.packages(c("shinyWidgets", "waiter", "fresh", "htmltools"))

# Utilities
install.packages(c("stringr", "scales", "markdown"))
```

### Database Setup
- PostgreSQL server running
- American Authorship database populated (see migration scripts)
- Database credentials configured

## Configuration

### Database Connection
The app looks for database credentials in this order:

1. **Parent config file**: `../scripts/config/database_config.R`
2. **Environment variables**: `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
3. **Fallback defaults**: localhost with standard settings

### App Settings
Modify `config/app_config.R` to customize:

- Database connection settings
- UI appearance and behavior
- Performance parameters
- Feature flags

## Running the Application

### Option 1: Run from R/RStudio
```r
# From the project root (recommended)
shiny::runApp("shiny-app/")

# Or from inside shiny-app/
setwd("path/to/anesko/shiny-app")
shiny::runApp()
```

The app always binds to **http://127.0.0.1:3838** (set in `app.R` via
`shinyApp(options = list(host = "127.0.0.1", port = 3838, ...))`).
Free that port first if something else is already listening there.

### Option 2: Command Line
```bash
cd /path/to/anesko
R -e 'shiny::runApp("shiny-app/")'
```

### Option 3: Explicit host/port override
```r
# Override defaults if needed
shiny::runApp("shiny-app/", host = "0.0.0.0", port = 8080)
```

## Customization

### Adding New Modules
1. Create new module file in `modules/` directory
2. Follow the naming pattern: `module_name_module.R`
3. Include both UI and Server functions
4. Add module to `global.R` source list
5. Register in `ui.R` and `server.R`

### Styling
- Modify `www/style.css` for custom styling
- Update `global.R` for theme changes
- Color schemes defined in global constants

### Database Queries
- Add new query functions to `utils/database.R`
- Follow the `safe_db_query()` pattern for error handling
- Use parameterized queries for security

## Data Structure

The dashboard expects these database tables:
- `book_entries`: Book metadata and author information
- `book_sales`: Sales records by year
- `book_sales_summary`: Pre-aggregated view for performance

## Security Notes

- Database credentials should never be committed to version control
- Use environment variables for production deployments
- The app includes SQL injection protection via parameterized queries
- Connection pooling is implemented for better performance

## Troubleshooting

### Common Issues

**Database Connection Failed / App Only Works Once**
This is usually caused by database connection pool issues. Try these steps:

1. **Test database connection independently**:
   ```r
   setwd("shiny-app")
   source("test_connection.R")
   ```

2. **Restart PostgreSQL service**:
   ```bash
   sudo service postgresql restart
   ```

3. **Check database credentials in `config/app_config.R`**

4. **Clear R session and restart**:
   ```r
   # In R console
   rm(list = ls())  # Clear workspace
   .rs.restartR()   # Restart R session (RStudio)
   ```

**Missing Packages**
- Run package installation commands above
- Check R version compatibility

**Performance Issues**
- Adjust `POOL_SIZE_MAX` in config
- Modify `CACHE_REFRESH_MINUTES` for data updates
- Consider database indexing for large datasets

**Styling Issues**
- Clear browser cache
- Check `www/style.css` is being loaded
- Verify CSS syntax

### Debug Mode

To run the app with detailed error messages:

```r
# Set debug options
options(shiny.error = browser)
options(shiny.trace = TRUE)

# Run app
shiny::runApp("shiny-app/")
```

## Future Enhancements

### Planned Features
- **Advanced Sales Analysis**: Seasonal patterns, market cycles
- **Author Demographics**: Career trajectories, geographic analysis
- **Genre Evolution**: Market share trends, cross-genre analysis
- **Publisher Analytics**: Market concentration, strategy analysis
- **Export Functionality**: PDF reports, data downloads
- **User Preferences**: Saved filters, bookmarks

### Technical Improvements
- **Caching Layer**: Redis integration for better performance
- **Real-time Updates**: WebSocket connections for live data
- **Mobile Optimization**: Responsive design improvements
- **Accessibility**: WCAG compliance features

## Contributing

To extend or modify the dashboard:

1. Follow the modular architecture
2. Use consistent naming conventions
3. Include error handling in all functions
4. Document new features and functions
5. Test thoroughly before deployment

## Support

For technical issues or feature requests:
- Check the troubleshooting section above
- Review the codebase documentation
- Contact the development team

---

**Version**: 1.0.0  
**Last Updated**: May 2025  
**Principal Investigator**: Dr. Michael Anesko, Penn State University 