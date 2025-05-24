# Database Schema Creation
# This file creates the PostgreSQL tables for the American Authorship project

library(DBI)
library(RPostgreSQL)

# Load database configuration
if (Sys.getenv("DB_USER") != "" && Sys.getenv("DB_PASSWORD") != "") {
  db_config <- list(
    host = ifelse(Sys.getenv("DB_HOST") != "", Sys.getenv("DB_HOST"), "localhost"),
    dbname = ifelse(Sys.getenv("DB_NAME") != "", Sys.getenv("DB_NAME"), "american_authorship"),
    user = Sys.getenv("DB_USER"),
    password = Sys.getenv("DB_PASSWORD")
  )
} else {
  source("scripts/config/database_config.R")
}

# Connect to database
con <- dbConnect(
  RPostgreSQL::PostgreSQL(),
  host = db_config$host,
  dbname = db_config$dbname,
  user = db_config$user,
  password = db_config$password
)

cat("🔗 Connected to database\n")

# Create book_entries table
cat("📚 Creating book_entries table...\n")
dbExecute(con, "
CREATE TABLE book_entries (
  book_id VARCHAR(50) PRIMARY KEY,
  author_surname VARCHAR(255),
  gender CHAR(1) CHECK (gender IN ('M', 'F')),
  book_title TEXT,
  genre VARCHAR(100),
  binding VARCHAR(50),
  notes TEXT,
  retail_price DECIMAL(10,2),
  royalty_rate DECIMAL(5,4),
  contract_terms TEXT,
  publisher VARCHAR(255),
  publication_year INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
")

# Create index on commonly queried fields
dbExecute(con, "CREATE INDEX idx_author_surname ON book_entries(author_surname)")
dbExecute(con, "CREATE INDEX idx_genre ON book_entries(genre)")
dbExecute(con, "CREATE INDEX idx_gender ON book_entries(gender)")
dbExecute(con, "CREATE INDEX idx_publisher ON book_entries(publisher)")
dbExecute(con, "CREATE INDEX idx_publication_year ON book_entries(publication_year)")

# Create book_sales table
cat("💰 Creating book_sales table...\n")
dbExecute(con, "
CREATE TABLE book_sales (
  sale_id SERIAL PRIMARY KEY,
  book_id VARCHAR(50) REFERENCES book_entries(book_id) ON DELETE CASCADE,
  year INTEGER NOT NULL,
  sales_count INTEGER,
  sales_limit INTEGER,
  sales_rate DECIMAL(10,2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT unique_book_year UNIQUE (book_id, year)
)
")

# Create index on book_id and year
dbExecute(con, "CREATE INDEX idx_book_year ON book_sales(book_id, year)")
dbExecute(con, "CREATE INDEX idx_sales_year ON book_sales(year)")

# Create update trigger for updated_at
cat("⚡ Creating update triggers...\n")
dbExecute(con, "
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';
")

dbExecute(con, "
CREATE TRIGGER update_book_entries_modtime 
BEFORE UPDATE ON book_entries 
FOR EACH ROW EXECUTE FUNCTION update_modified_column();
")

dbExecute(con, "
CREATE TRIGGER update_book_sales_modtime 
BEFORE UPDATE ON book_sales 
FOR EACH ROW EXECUTE FUNCTION update_modified_column();
")

# Create view for common queries
cat("👁️  Creating useful views...\n")
dbExecute(con, "
CREATE OR REPLACE VIEW book_sales_summary AS
SELECT 
  be.book_id,
  be.author_surname,
  be.gender,
  be.book_title,
  be.genre,
  be.publisher,
  be.publication_year,
  COUNT(DISTINCT bs.year) as years_with_sales,
  MIN(bs.year) as first_sale_year,
  MAX(bs.year) as last_sale_year,
  SUM(bs.sales_count) as total_sales
FROM book_entries be
LEFT JOIN book_sales bs ON be.book_id = bs.book_id
GROUP BY be.book_id, be.author_surname, be.gender, be.book_title, be.genre, be.publisher, be.publication_year
")

# Verify tables were created
tables <- dbListTables(con)
cat("\n✅ Tables created successfully:\n")
print(tables)

# Show table structures
cat("\n📊 Table structures:\n")
cat("\n--- book_entries ---\n")
book_entries_info <- dbGetQuery(con, "
  SELECT column_name, data_type, character_maximum_length, is_nullable
  FROM information_schema.columns
  WHERE table_name = 'book_entries'
  ORDER BY ordinal_position
")
print(book_entries_info)

cat("\n--- book_sales ---\n")
book_sales_info <- dbGetQuery(con, "
  SELECT column_name, data_type, character_maximum_length, is_nullable
  FROM information_schema.columns
  WHERE table_name = 'book_sales'
  ORDER BY ordinal_position
")
print(book_sales_info)

# Disconnect
dbDisconnect(con)
cat("\n✅ Schema creation complete!\n")



