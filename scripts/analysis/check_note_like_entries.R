#!/usr/bin/env Rscript

# Check for note-like entries in non-notes columns
# This script examines each column to identify entries that look like comments/notes
# and should potentially be moved to the notes column

library(DBI)
library(RPostgreSQL)
library(dplyr)

# Load database configuration
source("scripts/config/database_config.R")

# Connect to database
con <- dbConnect(RPostgreSQL::PostgreSQL(),
                 host = db_config$host,
                 dbname = db_config$dbname,
                 user = db_config$user,
                 password = db_config$password)

cat("🔍 CHECKING FOR NOTE-LIKE ENTRIES IN NON-NOTES COLUMNS\n")
cat(paste(rep("=", 60), collapse=""), "\n")

# Get all book entries
book_entries <- dbGetQuery(con, "SELECT * FROM book_entries")

cat("📊 Total books analyzed:", nrow(book_entries), "\n\n")

# Function to identify potentially note-like entries
is_note_like <- function(text, min_length = 20) {
  if (is.na(text) || is.null(text)) return(FALSE)
  
  # Convert to character and check length
  text <- as.character(text)
  if (nchar(text) < min_length) return(FALSE)
  
  # Check for note-like patterns
  note_patterns <- c(
    "\\d+@\\d+",           # Numbers with @ (like "109@10cents")
    "\\(",                 # Contains parentheses
    "cents",               # Contains "cents"
    "dollars?",            # Contains "dollar" or "dollars"
    "\\d{4}",             # Contains 4-digit year
    "see ",                # Contains "see "
    "note:",               # Contains "note:"
    "originally",          # Contains "originally"
    "published",           # Contains "published"
    "edition",             # Contains "edition"
    "volume",              # Contains "volume"
    "series",              # Contains "series"
    "copyright",           # Contains "copyright"
    "revised",             # Contains "revised"
    "reprint",             # Contains "reprint"
    "illustrated",         # Contains "illustrated"
    "binding",             # Contains "binding"
    "price",               # Contains "price"
    "cost",                # Contains "cost"
    "sold",                # Contains "sold"
    "sales",               # Contains "sales"
    "contract",            # Contains "contract"
    "agreement",           # Contains "agreement"
    "royalty",             # Contains "royalty"
    "advance",             # Contains "advance"
    "payment"              # Contains "payment"
  )
  
  # Check if any pattern matches (case insensitive)
  any(sapply(note_patterns, function(pattern) {
    grepl(pattern, text, ignore.case = TRUE)
  }))
}

# Check each non-notes column for note-like entries
columns_to_check <- c("author_surname", "book_title", "genre", "binding", 
                     "retail_price", "royalty_rate", "contract_terms", 
                     "publisher", "publication_year")

for (col in columns_to_check) {
  cat("🔍 Checking column:", col, "\n")
  
  # Get all non-NA values for this column
  values <- book_entries[[col]][!is.na(book_entries[[col]])]
  
  if (length(values) == 0) {
    cat("   ⚠️  No non-NA values found\n\n")
    next
  }
  
  # Check for note-like entries
  note_like_mask <- sapply(values, is_note_like)
  note_like_entries <- values[note_like_mask]
  
  if (length(note_like_entries) > 0) {
    cat("   ⚠️  Found", length(note_like_entries), "potentially note-like entries:\n")
    
    # Show unique note-like entries (limit to first 10)
    unique_entries <- unique(note_like_entries)
    show_entries <- head(unique_entries, 10)
    
    for (i in seq_along(show_entries)) {
      entry <- show_entries[i]
      # Find book_id(s) with this entry
      book_ids <- book_entries$book_id[book_entries[[col]] == entry & !is.na(book_entries[[col]])]
      cat("   ", i, ". '", entry, "' (Book ID(s): ", paste(head(book_ids, 3), collapse=", "), ")\n", sep="")
    }
    
    if (length(unique_entries) > 10) {
      cat("   ... and", length(unique_entries) - 10, "more unique entries\n")
    }
  } else {
    cat("   ✅ No note-like entries found\n")
  }
  cat("\n")
}

# Special check: Look for very long entries that might be notes
cat("🔍 CHECKING FOR UNUSUALLY LONG ENTRIES\n")
cat(paste(rep("=", 40), collapse = ""), "\n")

for (col in columns_to_check) {
  values <- book_entries[[col]][!is.na(book_entries[[col]])]
  if (length(values) == 0) next
  
  # Convert to character and get lengths
  char_values <- as.character(values)
  lengths <- nchar(char_values)
  
  # Find entries longer than 50 characters (except for book_title which can be long)
  threshold <- if (col == "book_title") 100 else 50
  long_entries <- char_values[lengths > threshold]
  
  if (length(long_entries) > 0) {
    cat("📏 Column '", col, "' has ", length(long_entries), " entries longer than ", threshold, " characters:\n", sep="")
    
    # Show first few long entries
    show_entries <- head(unique(long_entries), 5)
    for (i in seq_along(show_entries)) {
      entry <- show_entries[i]
      book_ids <- book_entries$book_id[book_entries[[col]] == entry & !is.na(book_entries[[col]])]
      cat("   ", i, ". (", nchar(entry), " chars) '", substr(entry, 1, 80), 
          if(nchar(entry) > 80) "..." else "", "' (Book ID: ", book_ids[1], ")\n", sep="")
    }
    cat("\n")
  }
}

# Check what's currently in the notes column
cat("📝 CURRENT NOTES COLUMN ANALYSIS\n")
cat(paste(rep("=", 35), collapse = ""), "\n")

notes_data <- book_entries$notes[!is.na(book_entries$notes)]
cat("📊 Books with notes:", length(notes_data), "out of", nrow(book_entries), "\n")

if (length(notes_data) > 0) {
  cat("📏 Notes length distribution:\n")
  lengths <- nchar(notes_data)
  cat("   Min length:", min(lengths), "\n")
  cat("   Max length:", max(lengths), "\n")
  cat("   Average length:", round(mean(lengths), 1), "\n")
  cat("   Median length:", median(lengths), "\n")
  
  cat("\n📋 Sample notes (first 5):\n")
  sample_notes <- head(notes_data, 5)
  for (i in seq_along(sample_notes)) {
    note <- sample_notes[i]
    cat("   ", i, ". '", substr(note, 1, 100), 
        if(nchar(note) > 100) "..." else "", "'\n", sep="")
  }
}

# Close database connection
dbDisconnect(con)

cat("\n✅ Analysis completed!\n")
