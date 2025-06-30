# Load anesko_db_original.xlsx
library(pacman)
p_load(readxl, dplyr, tidyr, stringr)

# Path to Excel file
excel_file <- "~/anesko/data/original/anesko_db_original.xlsx"

# Check if file exists
if (!file.exists(excel_file)) {
  stop("Excel file not found. Please ensure the file is in the data/ directory")
}

# Read Excel sheets
book_entries <- read_excel(excel_file, sheet = "Book_Entry_Table")
book_sales <- read_excel(excel_file, sheet = "Book_Sales_Table")

cat("Found", nrow(book_entries), "book entries\n")
cat("Found", nrow(book_sales), "sales records\n")

# Export the book_entries data frame to a CSV file
write.csv(book_entries, "~/anesko/data/cleaned/book_entries.csv", row.names = FALSE)
# Export the book_sales data frame to a CSV file
write.csv(book_sales, "~/anesko/data/cleaned/book_sales.csv", row.names = FALSE)

# Clean and prepare book_entries data

## Check the data frame
str(book_entries)
str(book_sales)

# Tabulate columns in book_entries
table(book_entries$`Book ID`, useNA = "ifany")
table(book_entries$`Royalty Rate`, useNA = "ifany")
table(book_entries$`Author Surname`, useNA = "ifany")
table(book_entries$Gender, useNA = "ifany")
table(book_entries$`Book Title`, useNA = "ifany")
table(book_entries$Genre, useNA = "ifany")
table(book_entries$Unlabled, useNA = "ifany")
table(book_entries$Binding, useNA = "ifany")
table(book_entries$Notes, useNA = "ifany")
table(book_entries$`Retail Price`, useNA = "ifany")
table(book_entries$`Contract Terms`, useNA = "ifany")
table(book_entries$Genre, useNA = "ifany")
table(book_entries$Publisher, useNA = "ifany")

# Tabulate columns in book_sales
table(book_sales$`book_ID`, useNA = "ifany")
table(book_sales$`y1858`, useNA = "ifany")
table(book_sales$`y1859`, useNA = "ifany")
table(book_sales$`y1899`, useNA = "ifany")
table(book_sales$`r1`, useNA = "ifany")
table(book_sales$`r2`, useNA = "ifany")
table(book_sales$`r3`, useNA = "ifany")
table(book_sales$`limit1`, useNA = "ifany")
table(book_sales$`limit2`, useNA = "ifany")
table(book_sales$`limit3`, useNA = "ifany")
table(book_sales$`Sliding Scale?`, useNA = "ifany")
