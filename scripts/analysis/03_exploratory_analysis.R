# Exploratory Data Analysis for American Authorship Database
# 
# This script performs initial exploratory analysis of the migrated data

library(dplyr)
library(ggplot2)
library(DBI)
library(RPostgreSQL)

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

# Analyses will go here...

# Always close connection
dbDisconnect(con)
