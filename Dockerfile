# American Authorship Database - Shiny App Dockerfile
# This creates a containerized version of the app that can be deployed anywhere

FROM rocker/r-ver:4.3.0

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev \
    postgresql-client \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libmariadb-dev \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy project files
COPY . /app/

# Install renv and restore packages
RUN R -e "install.packages('renv', repos='https://cran.rstudio.com/')" && \
    R -e "renv::restore()"

# Create data directories
RUN mkdir -p /app/data/raw /app/data/processed

# Expose port
EXPOSE 3838

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://0.0.0.0:3838/ || exit 1

# Set environment variables (override with docker run -e or docker-compose)
ENV R_CONFIG_ACTIVE=production

# Start Shiny app
CMD ["R", "-e", "shiny::runApp('app', host='0.0.0.0', port=3838)"] 