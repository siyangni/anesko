# Execute Reverse Publisher Name Changes
# 
# This script will reverse the publisher standardization changes

# Load necessary libraries
library(DBI)
library(RPostgreSQL)
library(magrittr)

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

cat("🔄 EXECUTING REVERSE CHANGES\n")
cat("=" %>% rep(50) %>% paste(collapse=""), "\n")

# Show current state
cat("\n📊 BEFORE REVERSAL:\n")
before <- dbGetQuery(con, "SELECT publisher, COUNT(*) as count FROM book_entries WHERE publisher IS NOT NULL GROUP BY publisher ORDER BY publisher")
print(before)

# Execute reverse changes
cat("\n🔄 Reversing changes...\n")

# Reverse Harper standardization -> Harper & Brothers
dbExecute(con, "UPDATE book_entries SET publisher = 'Harper & Brothers' WHERE publisher = 'Harper and Brothers'")
cat("✓ Harper reversed\n")

# Reverse Houghton standardization -> Houghton, Mifflin  
dbExecute(con, "UPDATE book_entries SET publisher = 'Houghton, Mifflin' WHERE publisher = 'Houghton-Mifflin'")
cat("✓ Houghton reversed\n")

# Reverse Osgood standardization
dbExecute(con, "UPDATE book_entries SET publisher = 'Osgood, McIlvaine' WHERE publisher = 'Osgood-McIlvaine'")
cat("✓ Osgood reversed\n")

# Reverse Fields standardization  
dbExecute(con, "UPDATE book_entries SET publisher = 'Fields, Osgood' WHERE publisher = 'Fields-Osgood'")
cat("✓ Fields reversed\n")

# Show final state
cat("\n📊 AFTER REVERSAL:\n")
after <- dbGetQuery(con, "SELECT publisher, COUNT(*) as count FROM book_entries WHERE publisher IS NOT NULL GROUP BY publisher ORDER BY publisher")
print(after)

cat("\n✅ All reversals completed!\n")

# Always close connection
dbDisconnect(con) 