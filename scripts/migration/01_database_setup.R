# Database Setup and Configuration
# This file sets up PostgreSQL database for the American Authorship project

# Database configuration (TEMPLATE - do not commit actual credentials)
db_config <- list(
  host = "localhost",
  dbname = "american_authorship", 
  user = "your_username",        # Replace with actual username
  password = "your_password"     # Replace with actual password  
)

# Save the actual configuration in a file that's gitignored:
# scripts/config/database_config.R (not tracked by git)
