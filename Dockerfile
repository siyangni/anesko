# American Authorship Database - Shiny App Dockerfile
# This creates a containerized version of the app that can be deployed anywhere

FROM rocker/shiny:4.3.0

# Set working directory
WORKDIR /srv/shiny-server/

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev \
    postgresql-client \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libmariadb-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c( \
    'shiny', \
    'shinydashboard', \
    'shinydashboardPlus', \
    'DT', \
    'plotly', \
    'ggplot2', \
    'dplyr', \
    'tidyr', \
    'lubridate', \
    'DBI', \
    'RPostgreSQL', \
    'RSQLite', \
    'pool', \
    'shinyWidgets', \
    'waiter', \
    'fresh', \
    'htmltools', \
    'scales', \
    'stringr', \
    'readxl', \
    'purrr', \
    'glue', \
    'broom' \
  ), repos='https://cran.rstudio.com/')"

# Copy app files
COPY shiny-app/ /srv/shiny-server/american-authorship/

# Create data directory
RUN mkdir -p /srv/shiny-server/american-authorship/data

# Set permissions
RUN chown -R shiny:shiny /srv/shiny-server/

# Configure Shiny Server
RUN echo "server { \n\
  listen 3838; \n\
  location / { \n\
    site_dir /srv/shiny-server; \n\
    log_dir /var/log/shiny-server; \n\
    directory_index on; \n\
  } \n\
  location /american-authorship { \n\
    app_dir /srv/shiny-server/american-authorship; \n\
    log_dir /var/log/shiny-server; \n\
  } \n\
}" > /etc/shiny-server/shiny-server.conf

# Expose port
EXPOSE 3838

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3838/american-authorship || exit 1

# Start Shiny Server
CMD ["/usr/bin/shiny-server"] 