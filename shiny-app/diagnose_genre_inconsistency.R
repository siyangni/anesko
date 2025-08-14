# Diagnose Genre Categorization Inconsistency
# This script investigates genre data inconsistencies in the database

library(DBI)
library(RPostgreSQL)
library(dplyr)

cat("🔍 Diagnosing Genre Categorization Inconsistency\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

# Load configuration
source("config/cloud_config.R")

# Connect to database
con <- dbConnect(
  RPostgreSQL::PostgreSQL(),
  host = db_config$host,
  dbname = db_config$dbname,
  user = db_config$user,
  password = db_config$password
)

# 1. Get all unique genre values with counts
cat("\n📊 Current Genre Values in Database:\n")
current_genres <- dbGetQuery(con, "
  SELECT 
    genre,
    COUNT(*) as book_count,
    COALESCE(SUM(bs.total_sales), 0) as total_sales,
    MIN(be.publication_year) as earliest_year,
    MAX(be.publication_year) as latest_year
  FROM book_entries be
  LEFT JOIN book_sales_summary bs ON be.book_id = bs.book_id
  WHERE genre IS NOT NULL
  GROUP BY genre
  ORDER BY book_count DESC
")

print(current_genres)

# 2. Expected standardized mapping
cat("\n📋 Expected Genre Standardization:\n")
expected_mapping <- data.frame(
  code = c("A", "C", "D", "E", "N", "M", "S", "T"),
  expected_name = c(
    "Anthology",
    "Children's Literature/Juvenile", 
    "Drama",
    "Essays/Other Non-Fiction",
    "Novel",
    "Memoir",
    "Short Story Collection/Novella",
    "Travel"
  ),
  stringsAsFactors = FALSE
)

print(expected_mapping)

# 3. Identify inconsistencies
cat("\n🚨 Identifying Inconsistencies:\n")

# Check for single-letter codes that should be mapped
single_letter_codes <- current_genres %>%
  filter(nchar(genre) == 1) %>%
  arrange(genre)

if (nrow(single_letter_codes) > 0) {
  cat("❌ Found unmapped single-letter codes:\n")
  print(single_letter_codes)
} else {
  cat("✅ No single-letter codes found\n")
}

# Check for variations of expected categories
cat("\n🔍 Checking for category variations:\n")

# Essay variations
essay_variations <- current_genres %>%
  filter(grepl("essay|Essay", genre, ignore.case = TRUE)) %>%
  arrange(genre)

cat("Essay-related genres:\n")
print(essay_variations)

# Children's/Juvenile variations
children_variations <- current_genres %>%
  filter(grepl("child|juvenile|Child|Juvenile", genre, ignore.case = TRUE)) %>%
  arrange(genre)

cat("\nChildren's/Juvenile-related genres:\n")
print(children_variations)

# Short story variations
story_variations <- current_genres %>%
  filter(grepl("short|story|Short|Story", genre, ignore.case = TRUE)) %>%
  arrange(genre)

cat("\nShort story-related genres:\n")
print(story_variations)

# 4. Check for exact matches with expected names
cat("\n✅ Checking matches with expected standardized names:\n")
matched_genres <- current_genres %>%
  filter(genre %in% expected_mapping$expected_name)

cat("Genres matching expected standard:\n")
print(matched_genres[, c("genre", "book_count")])

unmatched_genres <- current_genres %>%
  filter(!genre %in% expected_mapping$expected_name)

cat("\nGenres NOT matching expected standard:\n")
print(unmatched_genres[, c("genre", "book_count")])

# 5. Sample books for each problematic genre
cat("\n📚 Sample books for problematic genres:\n")

for (genre_name in unmatched_genres$genre[1:min(5, nrow(unmatched_genres))]) {
  cat("\nSample books with genre '", genre_name, "':\n", sep = "")
  sample_books <- dbGetQuery(con, paste0("
    SELECT book_id, book_title, author_surname, publication_year
    FROM book_entries 
    WHERE genre = '", genre_name, "'
    LIMIT 3
  "))
  print(sample_books)
}

# 6. Check for potential data migration issues
cat("\n🔄 Checking for potential migration patterns:\n")

# Look for books that might have been partially migrated
migration_check <- dbGetQuery(con, "
  SELECT 
    genre,
    COUNT(*) as count,
    STRING_AGG(DISTINCT SUBSTRING(book_id, 1, 2), ', ') as book_id_prefixes
  FROM book_entries
  WHERE genre IS NOT NULL
  GROUP BY genre
  ORDER BY genre
")

cat("Genre distribution by book ID patterns:\n")
print(migration_check)

# 7. Recommendations
cat("\n💡 Analysis and Recommendations:\n")

total_books <- sum(current_genres$book_count)
problematic_books <- sum(unmatched_genres$book_count)
problematic_percentage <- round((problematic_books / total_books) * 100, 1)

cat("Total books with genres:", total_books, "\n")
cat("Books with non-standard genres:", problematic_books, "(", problematic_percentage, "%)\n")

if (problematic_percentage > 10) {
  cat("\n🚨 SIGNIFICANT INCONSISTENCY DETECTED\n")
  cat("Recommendation: Database update required\n")
} else {
  cat("\n✅ Minor inconsistency\n")
  cat("Recommendation: Dashboard mapping can handle this\n")
}

# 8. Proposed mapping for dashboard
cat("\n🛠️ Proposed Dashboard Mapping Solution:\n")
cat("genre_display = case_when(\n")
for (i in 1:nrow(unmatched_genres)) {
  genre <- unmatched_genres$genre[i]
  # Suggest mapping based on content
  suggested_mapping <- case_when(
    grepl("essay|Essay", genre, ignore.case = TRUE) ~ "Essays/Other Non-Fiction",
    grepl("child|juvenile", genre, ignore.case = TRUE) ~ "Children's Literature/Juvenile",
    grepl("short.*story|story.*collection", genre, ignore.case = TRUE) ~ "Short Story Collection/Novella",
    genre == "J" ~ "Children's Literature/Juvenile",
    TRUE ~ "Other"
  )
  cat("  genre == '", genre, "' ~ '", suggested_mapping, "',\n", sep = "")
}
cat("  TRUE ~ genre\n")
cat(")\n")

dbDisconnect(con)

cat("\n📋 Summary:\n")
cat("- Identified", nrow(current_genres), "unique genre values\n")
cat("- Found", nrow(unmatched_genres), "non-standard genre values\n")
cat("- Affecting", problematic_books, "books (", problematic_percentage, "% of total)\n")
cat("- Provided mapping solution for dashboard\n")
