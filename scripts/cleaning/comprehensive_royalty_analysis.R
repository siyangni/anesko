# Comprehensive analysis of ALL royalty data rows
library(pacman)
p_load(readxl, dplyr, tidyr, stringr)

# Read the data
excel_file <- "~/anesko/data/original/anesko_db_original.xlsx"
book_sales <- read_excel(excel_file, sheet = "Book_Sales_Table")

cat("=== COMPREHENSIVE ROYALTY DATA ANALYSIS ===\n")
cat("Total rows:", nrow(book_sales), "\n\n")

# 1. Examine ALL unique combinations of royalty variables
cat("1. ALL UNIQUE COMBINATIONS of r1, r2, r3, r4, limit1, limit2, limit3, limit4, Sliding Scale:\n")
royalty_combos <- book_sales %>%
  select(r1, r2, r3, r4, limit1, limit2, limit3, limit4, `Sliding Scale?`) %>%
  distinct() %>%
  arrange(`Sliding Scale?`, r1, r2, r3, r4)

cat("Number of unique combinations:", nrow(royalty_combos), "\n")
print(royalty_combos)

cat("\n===========================================\n")

# 2. Analyze each combination type
cat("2. DETAILED ANALYSIS BY SLIDING SCALE:\n")

# Sliding Scale = 0
sliding_0 <- book_sales %>%
  filter(`Sliding Scale?` == 0) %>%
  select(book_ID, r1, r2, r3, r4, limit1, limit2, limit3, limit4, `Sliding Scale?`) %>%
  distinct()

cat("\nSliding Scale = 0 (", nrow(sliding_0), " unique combinations):\n")
print(sliding_0)

# Sliding Scale = 1  
sliding_1 <- book_sales %>%
  filter(`Sliding Scale?` == 1) %>%
  select(book_ID, r1, r2, r3, r4, limit1, limit2, limit3, limit4, `Sliding Scale?`) %>%
  distinct()

cat("\nSliding Scale = 1 (", nrow(sliding_1), " unique combinations):\n")
print(sliding_1)

cat("\n===========================================\n")

# 3. Check for patterns in the data
cat("3. PATTERN VERIFICATION:\n")

# Check if r=0 always pairs with limit=0
cat("\nA. When r2=0, what are limit2 values?\n")
r2_zero_patterns <- book_sales %>%
  filter(!is.na(r2) & r2 == 0) %>%
  select(r2, limit2) %>%
  distinct()
print(r2_zero_patterns)

cat("\nB. When r3=0, what are limit3 values?\n")
r3_zero_patterns <- book_sales %>%
  filter(!is.na(r3) & r3 == 0) %>%
  select(r3, limit3) %>%
  distinct()
print(r3_zero_patterns)

cat("\nC. When r4=0, what are limit4 values?\n")
r4_zero_patterns <- book_sales %>%
  filter(!is.na(r4) & r4 == 0) %>%
  select(r4, limit4) %>%
  distinct()
print(r4_zero_patterns)

cat("\nD. When limit=0, what are the corresponding r values?\n")
limit_zero_patterns <- book_sales %>%
  filter((!is.na(limit2) & limit2 == 0) | (!is.na(limit3) & limit3 == 0) | (!is.na(limit4) & limit4 == 0)) %>%
  select(r2, r3, r4, limit2, limit3, limit4) %>%
  distinct()
print(limit_zero_patterns)

cat("\n===========================================\n")

# 4. Examine problematic cases
cat("4. EDGE CASES AND ANOMALIES:\n")

# Cases where rate > 0 but limit = 0
cat("\nA. Cases where rate > 0 but limit = 0:\n")
anomaly1 <- book_sales %>%
  filter(
    (!is.na(r2) & r2 > 0 & !is.na(limit2) & limit2 == 0) |
    (!is.na(r3) & r3 > 0 & !is.na(limit3) & limit3 == 0) |
    (!is.na(r4) & r4 > 0 & !is.na(limit4) & limit4 == 0)
  ) %>%
  select(book_ID, r1, r2, r3, r4, limit1, limit2, limit3, limit4, `Sliding Scale?`)
print(anomaly1)

# Cases where rate = 0 but limit > 0
cat("\nB. Cases where rate = 0 but limit > 0:\n")
anomaly2 <- book_sales %>%
  filter(
    (!is.na(r2) & r2 == 0 & !is.na(limit2) & limit2 > 0) |
    (!is.na(r3) & r3 == 0 & !is.na(limit3) & limit3 > 0) |
    (!is.na(r4) & r4 == 0 & !is.na(limit4) & limit4 > 0)
  ) %>%
  select(book_ID, r1, r2, r3, r4, limit1, limit2, limit3, limit4, `Sliding Scale?`)
print(anomaly2)

# Cases where later tiers exist but earlier ones don't
cat("\nC. Cases where later tiers exist but earlier ones are missing:\n")
anomaly3 <- book_sales %>%
  filter(
    (is.na(r2) & !is.na(r3)) |
    (is.na(r3) & !is.na(r4)) |
    (is.na(limit2) & !is.na(limit3)) |
    (is.na(limit3) & !is.na(limit4))
  ) %>%
  select(book_ID, r1, r2, r3, r4, limit1, limit2, limit3, limit4, `Sliding Scale?`)
print(anomaly3)

cat("\n===========================================\n")

# 5. Summary statistics
cat("5. SUMMARY STATISTICS:\n")
cat("Books with Sliding Scale = 0:", sum(book_sales$`Sliding Scale?` == 0, na.rm = TRUE), "\n")
cat("Books with Sliding Scale = 1:", sum(book_sales$`Sliding Scale?` == 1, na.rm = TRUE), "\n")
cat("Books with NA Sliding Scale:", sum(is.na(book_sales$`Sliding Scale?`)), "\n")

cat("\nRate distributions:\n")
cat("r1 non-zero:", sum(!is.na(book_sales$r1) & book_sales$r1 > 0), "\n")
cat("r2 non-zero:", sum(!is.na(book_sales$r2) & book_sales$r2 > 0), "\n")
cat("r3 non-zero:", sum(!is.na(book_sales$r3) & book_sales$r3 > 0), "\n")
cat("r4 non-zero:", sum(!is.na(book_sales$r4) & book_sales$r4 > 0), "\n")

cat("\nLimit distributions:\n")
cat("limit1 > 0:", sum(!is.na(book_sales$limit1) & book_sales$limit1 > 0), "\n")
cat("limit2 > 0:", sum(!is.na(book_sales$limit2) & book_sales$limit2 > 0), "\n")
cat("limit3 > 0:", sum(!is.na(book_sales$limit3) & book_sales$limit3 > 0), "\n")
cat("limit4 > 0:", sum(!is.na(book_sales$limit4) & book_sales$limit4 > 0), "\n") 