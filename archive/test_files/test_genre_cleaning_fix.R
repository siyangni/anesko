# Test Genre Cleaning Fix
# This script tests the fixed genre cleaning logic

library(pacman)
p_load(readxl, dplyr, tidyr, stringr, here)

cat("🎭 Testing Fixed Genre Cleaning Logic\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Paths
excel_file <- here::here("data/original/anesko_db_original.xlsx")
excel_file_new <- here::here("data/original/anesko_db_original_aug_addition.xlsx")

# Check if files exist
if (!file.exists(excel_file)) {
  cat("❌ Original Excel file not found:", excel_file, "\n")
  cat("Skipping test - files not available\n")
  quit()
}

if (!file.exists(excel_file_new)) {
  cat("❌ New Excel file not found:", excel_file_new, "\n")
  cat("Skipping test - files not available\n")
  quit()
}

# Read data
cat("\n📊 Reading Excel data...\n")
book_entries_orig <- read_excel(excel_file, sheet = "Book_Entry_Table")
book_sales_orig <- read_excel(excel_file, sheet = "Book_Sales_Table")
book_entries_new <- read_excel(excel_file_new, sheet = "Book_Entry")
book_sales_new <- read_excel(excel_file_new, sheet = "Sales_Table")

# Combine data (simplified version of the cleaning script)
cat("📚 Combining datasets...\n")

# Standardize column names for new data
colnames(book_entries_new) <- c(
  "Book ID", "Royalty Rate", "Author Surname", "Gender", "Book Title", 
  "Genre", "Unlabled", "Binding", "Notes", "Retail Price", 
  "Contract Terms", "Publisher", "Publication Year"
)

# Combine book entries
book_entries <- bind_rows(book_entries_orig, book_entries_new)

cat("Combined data: ", nrow(book_entries), " book entries\n")

# Show BEFORE genre cleaning
cat("\n❌ BEFORE genre cleaning:\n")
genre_before <- table(book_entries$Genre, useNA = "ifany")
print(genre_before)

# Apply the FIXED genre cleaning logic
cat("\n✨ Applying FIXED genre cleaning logic...\n")

book_entries <- book_entries %>%
  mutate(Genre = case_when(
    Genre == "A" ~ "Anthology",
    Genre == "C" ~ "Children's Literature/Juvenile",
    Genre == "D" ~ "Drama",
    Genre == "E" ~ "Essay/Other Non-Fiction",
    Genre == "essays" ~ "Essay/Other Non-Fiction",  # FIXED: Map to same category as "E"
    Genre == "Essay" ~ "Essay/Other Non-Fiction",   # FIXED: Standardize existing "Essay" entries
    Genre == "N" ~ "Novel",
    Genre == "M" ~ "Memoir",
    Genre == "S" ~ "Short Story Collection/Novella",
    Genre == "T" ~ "Travel",
    Genre == "P" ~ "Poetry",
    Genre == "J" ~ "Children's Literature/Juvenile",  # FIXED: Map legacy "J" code
    TRUE ~ Genre  # Keep any other values as they are
  ))

# Show AFTER genre cleaning
cat("\n✅ AFTER genre cleaning:\n")
genre_after <- table(book_entries$Genre, useNA = "ifany")
print(genre_after)

# Check specific fixes
cat("\n🔍 Checking specific fixes:\n")

# Check Essay consolidation
essay_entries <- sum(grepl("Essay", names(genre_after)))
cat("Essay-related categories:", essay_entries, "(should be 1)\n")

# Check J mapping
j_entries <- sum(names(genre_after) == "J", na.rm = TRUE)
cat("'J' entries remaining:", j_entries, "(should be 0)\n")

# Check Children's Literature
children_entries <- sum(names(genre_after) == "Children's Literature/Juvenile", na.rm = TRUE)
cat("'Children's Literature/Juvenile' entries:", children_entries, "(should be 1)\n")

# Show the changes
cat("\n📊 Summary of changes:\n")
cat("BEFORE:\n")
if ("Essay" %in% names(genre_before)) {
  cat("  'Essay':", genre_before[["Essay"]], "entries\n")
}
if ("Essay/Other Non-Fiction" %in% names(genre_before)) {
  cat("  'Essay/Other Non-Fiction':", genre_before[["Essay/Other Non-Fiction"]], "entries\n")
}
if ("J" %in% names(genre_before)) {
  cat("  'J':", genre_before[["J"]], "entries\n")
}

cat("AFTER:\n")
if ("Essay/Other Non-Fiction" %in% names(genre_after)) {
  cat("  'Essay/Other Non-Fiction':", genre_after[["Essay/Other Non-Fiction"]], "entries (consolidated)\n")
}
if ("Children's Literature/Juvenile" %in% names(genre_after)) {
  cat("  'Children's Literature/Juvenile':", genre_after[["Children's Literature/Juvenile"]], "entries (includes former J)\n")
}

# Verify no inconsistencies remain
inconsistent_genres <- c("Essay", "J", "essays")
remaining_inconsistencies <- intersect(names(genre_after), inconsistent_genres)

if (length(remaining_inconsistencies) == 0) {
  cat("\n✅ SUCCESS: All genre inconsistencies have been fixed!\n")
  cat("No more 'Essay', 'J', or 'essays' entries remain.\n")
} else {
  cat("\n❌ WARNING: Some inconsistencies remain:\n")
  for (genre in remaining_inconsistencies) {
    cat("  '", genre, "':", genre_after[[genre]], "entries\n")
  }
}

cat("\n🚀 Next steps:\n")
cat("1. Run the full migration script to apply these fixes to the database\n")
cat("2. The dashboard will then show consistent genre categories\n")
cat("3. No more Essay/J inconsistencies in the Shiny application\n")
