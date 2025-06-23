# Reverse Publisher Name Standardization
# 
# This script reverses the publisher name standardization changes made in 02_data_cleaning.R
# WARNING: This will change standardized names back to their original variations

# Load necessary libraries
library(pacman)
p_load(DBI, RPostgreSQL, tidyverse, janitor, skimr, here)

# Source database configuration
source("scripts/config/database_config.R")

# Connect to database
con <- dbConnect(
  RPostgreSQL::PostgreSQL(),
  host = db_config$host,
  dbname = db_config$dbname,
  user = db_config$user,
  password = db_config$password
)

cat("🔄 REVERSING PUBLISHER NAME STANDARDIZATION\n")
cat("=" %>% rep(50) %>% paste(collapse=""), "\n")

# WARNING: This approach will change ALL standardized names back to ONE variation
# If you had multiple variations originally, they'll all become the same variation

# Get current distinct publishers to see what we're working with
cat("\n📊 CURRENT PUBLISHERS:\n")
current_publishers <- dbGetQuery(con, "SELECT DISTINCT publisher FROM book_entries ORDER BY publisher")
print(current_publishers)

cat("\n⚠️  WARNING: This will change standardized names back to original variations.\n")
cat("Do you want to proceed? (This is just a preview - you need to uncomment the dbExecute lines)\n\n")

# REVERSE Harper standardization (uncomment the line you want to use)
# dbExecute(con, "UPDATE book_entries SET publisher = 'Harper & Brothers' WHERE publisher = 'Harper and Brothers'")
# dbExecute(con, "UPDATE book_entries SET publisher = 'Harper &Brothers' WHERE publisher = 'Harper and Brothers'")
# dbExecute(con, "UPDATE book_entries SET publisher = 'Harper and Bros.' WHERE publisher = 'Harper and Brothers'")

# REVERSE Houghton standardization (uncomment the line you want to use)  
# dbExecute(con, "UPDATE book_entries SET publisher = 'Houghton, Mifflin' WHERE publisher = 'Houghton-Mifflin'")
# dbExecute(con, "UPDATE book_entries SET publisher = 'Houghton Mifflin' WHERE publisher = 'Houghton-Mifflin'")
# dbExecute(con, "UPDATE book_entries SET publisher = 'Hougton, Mifflin' WHERE publisher = 'Houghton-Mifflin'")

# REVERSE Osgood standardization
# dbExecute(con, "UPDATE book_entries SET publisher = 'Osgood, McIlvaine' WHERE publisher = 'Osgood-McIlvaine'")

# REVERSE Fields standardization  
# dbExecute(con, "UPDATE book_entries SET publisher = 'Fields, Osgood' WHERE publisher = 'Fields-Osgood'")

cat("\n📝 INSTRUCTIONS:\n")
cat("1. Uncomment the specific dbExecute lines above that you want to run\n")
cat("2. Note: This will change ALL standardized entries to ONE variation\n")
cat("3. If you had multiple original variations, they'll all become the same\n")
cat("4. Run this script again after uncommenting the desired lines\n")

# Always close connection
dbDisconnect(con) 