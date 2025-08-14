# Test Migration Files
# This script tests if the cleaned CSV files can be read and processed correctly
# for the database migration

library(dplyr)
library(stringr)
library(here)

cat("🧪 Testing migration file compatibility...\n")
cat(paste(rep("=", 50), collapse = ""), "\n")

# Test file paths
book_entries_file <- here::here("data/cleaned/book_entry_cleaned.csv")
book_sales_file <- here::here("data/cleaned/book_sales_cleaned.csv")
royalty_tiers_file <- here::here("data/cleaned/royalty_tiers_cleaned.csv")

# Check if files exist
cat("\n📁 Checking file existence...\n")
files_exist <- c(
  book_entries = file.exists(book_entries_file),
  book_sales = file.exists(book_sales_file),
  royalty_tiers = file.exists(royalty_tiers_file)
)

for (i in seq_along(files_exist)) {
  status <- if (files_exist[i]) "✅" else "❌"
  cat(status, names(files_exist)[i], "\n")
}

if (!all(files_exist)) {
  stop("❌ Missing files. Please run scripts/cleaning/pre_migration_cleaning.R first")
}

# Test reading book entries
cat("\n📚 Testing book entries...\n")
book_entries <- read.csv(book_entries_file, stringsAsFactors = FALSE)
cat("Rows:", nrow(book_entries), "\n")
cat("Columns:", paste(names(book_entries), collapse = ", "), "\n")

# Test column mapping for book entries (R converts spaces to dots in column names)
test_mapping <- tryCatch({
  sample_entry <- book_entries[1, ] %>%
    mutate(
      publication_year = as.integer(stringr::str_extract(Book.ID, "\\d{4}")),
      book_id = Book.ID,
      author_surname = Author.Surname,
      gender = Gender,
      book_title = Book.Title,
      genre = Genre,
      binding = Binding,
      notes = Notes,
      retail_price = as.numeric(Retail.Price),
      royalty_rate = as.numeric(Royalty.Rate),
      contract_terms = Contract.Terms,
      publisher = Publisher
    )
  
  cat("✅ Column mapping successful\n")
  cat("Sample: Book ID =", sample_entry$book_id, 
      ", Year =", sample_entry$publication_year, "\n")
  TRUE
}, error = function(e) {
  cat("❌ Column mapping failed:", e$message, "\n")
  FALSE
})

# Test reading book sales
cat("\n💰 Testing book sales...\n")
book_sales <- read.csv(book_sales_file, stringsAsFactors = FALSE)
cat("Rows:", nrow(book_sales), "\n")
cat("Columns:", paste(names(book_sales), collapse = ", "), "\n")

# Test sales data processing
sales_test <- tryCatch({
  sample_sales <- book_sales[1:5, ] %>%
    mutate(
      book_id = as.character(book_ID),
      year = as.integer(year),
      sales_count = as.integer(sales)
    ) %>%
    filter(!is.na(book_id) & !is.na(year) & !is.na(sales_count))
  
  cat("✅ Sales data processing successful\n")
  cat("Sample sales records:", nrow(sample_sales), "\n")
  TRUE
}, error = function(e) {
  cat("❌ Sales data processing failed:", e$message, "\n")
  FALSE
})

# Test reading royalty tiers
cat("\n📊 Testing royalty tiers...\n")
royalty_tiers <- read.csv(royalty_tiers_file, stringsAsFactors = FALSE)
cat("Rows:", nrow(royalty_tiers), "\n")
cat("Columns:", paste(names(royalty_tiers), collapse = ", "), "\n")

# Test royalty data processing
royalty_test <- tryCatch({
  sample_royalty <- royalty_tiers[1:5, ] %>%
    mutate(
      book_id = as.character(book_ID),
      tier = as.integer(tier),
      rate = as.numeric(rate),
      lower_limit = as.integer(lower_limit),
      upper_limit = ifelse(is.infinite(upper_limit), NA_integer_, as.integer(upper_limit)),
      sliding_scale = as.logical(as.character(sliding_scale))
    ) %>%
    filter(!is.na(book_id) & !is.na(tier) & !is.na(rate))
  
  cat("✅ Royalty data processing successful\n")
  cat("Sample royalty records:", nrow(sample_royalty), "\n")
  TRUE
}, error = function(e) {
  cat("❌ Royalty data processing failed:", e$message, "\n")
  FALSE
})

# Summary
cat("\n📋 Test Summary:\n")
cat(paste(rep("=", 30), collapse = ""), "\n")
all_tests <- c(
  "File existence" = all(files_exist),
  "Book entries mapping" = test_mapping,
  "Sales data processing" = sales_test,
  "Royalty data processing" = royalty_test
)

for (i in seq_along(all_tests)) {
  status <- if (all_tests[i]) "✅" else "❌"
  cat(status, names(all_tests)[i], "\n")
}

if (all(all_tests)) {
  cat("\n🎉 All tests passed! Migration files are ready.\n")
  cat("You can now run the database migration scripts.\n")
} else {
  cat("\n❌ Some tests failed. Please check the issues above.\n")
  stop("Migration file tests failed")
}
