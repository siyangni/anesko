# Load anesko_db_original.xlsx
library(pacman)
p_load(readxl, dplyr, tidyr, stringr)

# Set working directory to project root if not already there
if (!file.exists("data/original/anesko_db_original.xlsx")) {
  # Try to find project root by looking for the data directory
  if (file.exists("../../data/original/anesko_db_original.xlsx")) {
    setwd("../..")
  } else if (file.exists("../data/original/anesko_db_original.xlsx")) {
    setwd("..")
  } else {
    stop("Cannot find project root. Please run this script from the project root directory or ensure data/original/anesko_db_original.xlsx exists")
  }
}

# Path to Excel file (relative to project root)
excel_file <- "data/original/anesko_db_original.xlsx"

# Check if file exists
if (!file.exists(excel_file)) {
  stop("Excel file not found. Please ensure the file is in the data/original/ directory")
}

# Read Excel sheets
book_entries <- read_excel(excel_file, sheet = "Book_Entry_Table")
book_sales <- read_excel(excel_file, sheet = "Book_Sales_Table")

cat("Found", nrow(book_entries), "book entries\n")
cat("Found", nrow(book_sales), "sales records\n")

# Create cleaned data directory if it doesn't exist
if (!dir.exists("data/cleaned")) {
  dir.create("data/cleaned", recursive = TRUE)
}

# Export the original data frames to CSV files (before cleaning)
write.csv(book_entries, "data/cleaned/book_entries_original.csv", row.names = FALSE)
write.csv(book_sales, "data/cleaned/book_sales.csv", row.names = FALSE)

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
table(book_sales$`r4`, useNA = "ifany")
table(book_sales$`limit1`, useNA = "ifany")
table(book_sales$`limit2`, useNA = "ifany")
table(book_sales$`limit3`, useNA = "ifany")
table(book_sales$`limit4`, useNA = "ifany")
table(book_sales$`Sliding Scale?`, useNA = "ifany")

# ===============================================================================
# PUBLISHER RECODING
# ===============================================================================

# First, handle the special case: move "All copyrights assigned..." text to Notes
special_publisher_text <- "All copyrights assigned to Houghton, Mifflin after 1878; Harte paid lump sums of $300 for all rights in each fut\nure work"

# Find rows with this special publisher text
special_rows <- which(book_entries$Publisher == special_publisher_text)

if (length(special_rows) > 0) {
  # Move the text to Notes column
  for (i in special_rows) {
    if (is.na(book_entries$Notes[i]) || book_entries$Notes[i] == "") {
      book_entries$Notes[i] <- special_publisher_text
    } else {
      book_entries$Notes[i] <- paste(book_entries$Notes[i], special_publisher_text, sep = "; ")
    }
  }
  # Set publisher to Houghton Mifflin variant
  book_entries$Publisher[special_rows] <- "Houghton Mifflin (and predecessor / joint imprints)"
}

# Now recode publishers according to specifications
book_entries <- book_entries %>%
  mutate(Publisher = case_when(
    # Harper and Brothers (and variants) -> "Harper & Brothers"
    Publisher %in% c("Harper", "Harper and Brothers", "Harper &Brothers", "Harper and Bros.") ~ "Harper & Brothers",
    Publisher == "Harper & Brothers" ~ "Harper & Brothers", # Keep existing
    
    # Houghton Mifflin (and predecessor / joint imprints)
    Publisher %in% c("Houghton Mifflin", "Houghton-Mifflin", "Houghton, Mifflin", 
                     "Hougton, Mifflin", "Houhgton, Mifflin", "Houghton", "Hougthon") ~ "Houghton Mifflin (and predecessor / joint imprints)",
    
    # Keep "Hurd & Houghton (pre-1878 predecessor)" as is
    Publisher == "Hurd & Houghton" ~ "Hurd & Houghton (pre-1878 predecessor)",
    
    # Keep "Fields, Osgood" as is
    Publisher == "Fields, Osgood" ~ "Fields, Osgood",
    
    # Scribner's variants -> "Scribner's"
    Publisher %in% c("Scribner's", "Scibner's") ~ "Scribner's",
    
    # Keep these as is
    Publisher == "Ticknor & Co." ~ "Ticknor & Co.",
    Publisher == "Century Co." ~ "Century Co.",
    Publisher == "Macmillan (NY)" ~ "Macmillan (NY)",
    Publisher == "Grosset & Dunlap" ~ "Grosset & Dunlap",
    Publisher == "Herbert S. Stone" ~ "Herbert S. Stone",
    Publisher == "R.H. Russell" ~ "R. H. Russell", # Standardize spacing
    Publisher == "Houghton, Osgood" ~ "Houghton, Osgood",
    Publisher == "J. R. Osgood & Co." ~ "J. R. Osgood & Co.",
    Publisher == "Osgood, McIlvaine" ~ "Osgood, McIlvaine",
    
    # Keep all other values as they are
    TRUE ~ Publisher
  ))

# Print summary of recoding
cat("\n=== PUBLISHER RECODING SUMMARY ===\n")
cat("Publishers after recoding:\n")
print(table(book_entries$Publisher, useNA = "ifany"))

# Export the cleaned book_entries data frame to a new CSV file
write.csv(book_entries, "data/cleaned/book_entries_recoded.csv", row.names = FALSE)
cat("\nCleaned data exported to book_entries_recoded.csv\n")

# ===============================================================================
# GENRE RECODING
# ===============================================================================

cat("\n=== GENRE RECODING ===\n")
cat("Original Genre values:\n")
print(table(book_entries$Genre, useNA = "ifany"))

# Recode Genre column
book_entries <- book_entries %>%
  mutate(Genre = case_when(
    Genre == "A" ~ "Anthology",
    Genre == "C" ~ "Children's Literature/Juvenile",
    Genre == "D" ~ "Drama",
    Genre == "E" ~ "Essay/Other Non-Fiction",
    Genre == "N" ~ "Novel",
    Genre == "M" ~ "Memoir",
    Genre == "S" ~ "Short Story Collection/Novella",
    Genre == "T" ~ "Travel",
    Genre == "P" ~ "Poetry",  # Added poetry for P values
    TRUE ~ Genre  # Keep any other values as they are
  ))

cat("\nGenre values after recoding:\n")
print(table(book_entries$Genre, useNA = "ifany"))

# ===============================================================================
# BINDING RECODING
# ===============================================================================

cat("\n=== BINDING RECODING ===\n")
cat("Original Binding values:\n")
print(table(book_entries$Binding, useNA = "ifany"))

# Recode Binding column
book_entries <- book_entries %>%
  mutate(Binding = case_when(
    Binding == "C" ~ "Cloth",
    Binding == "P" ~ "Paper",
    Binding == "D" ~ "Deluxe",
    Binding == "I" ~ "Illustrated",
    Binding == "R" ~ "Reprint",
    TRUE ~ Binding  # Keep any other values as they are
  ))

cat("\nBinding values after recoding:\n")
print(table(book_entries$Binding, useNA = "ifany"))

# ===============================================================================
# GENDER RECODING
# ===============================================================================

cat("\n=== GENDER RECODING ===\n")
cat("Original Gender values:\n")
print(table(book_entries$Gender, useNA = "ifany"))

# Recode Gender column
book_entries <- book_entries %>%
  mutate(Gender = case_when(
    Gender == "M" ~ "Male",
    Gender == "F" ~ "Female",
    TRUE ~ Gender  # Keep any other values as they are
  ))

cat("\nGender values after recoding:\n")
print(table(book_entries$Gender, useNA = "ifany"))

# ===============================================================================
# PUBLISHER FIELD CLEANUP
# ===============================================================================

cat("\n=== PUBLISHER FIELD CLEANUP ===\n")
cat("Original Publisher values (showing long entries):\n")

# Show publishers longer than 50 characters before cleanup
long_publishers <- book_entries$Publisher[!is.na(book_entries$Publisher) & nchar(book_entries$Publisher) > 50]
if (length(long_publishers) > 0) {
  unique_long <- unique(long_publishers)
  for (i in seq_along(unique_long)) {
    pub <- unique_long[i]
    count <- sum(book_entries$Publisher == pub, na.rm = TRUE)
    cat("   ", i, ". (", nchar(pub), " chars, ", count, " books): '",
        substr(pub, 1, 80), if(nchar(pub) > 80) "..." else "", "'\n", sep = "")
  }
} else {
  cat("   No publishers longer than 50 characters found\n")
}

# Clean up publisher field by moving note-like entries to notes
book_entries <- book_entries %>%
  mutate(
    # Create new notes by combining existing notes with publisher context
    Notes = case_when(
      # For the long Harte copyright note
      Publisher == "All copyrights assigned to Houghton, Mifflin after 1878; Harte paid lump sums of $300 for all rights in each future work" ~
        if_else(is.na(Notes) | Notes == "",
                "All copyrights assigned to Houghton, Mifflin after 1878; Harte paid lump sums of $300 for all rights in each future work",
                paste(Notes, "All copyrights assigned to Houghton, Mifflin after 1878; Harte paid lump sums of $300 for all rights in each future work", sep = "; ")),

      # For Houghton Mifflin predecessor note
      Publisher == "Houghton Mifflin (and predecessor / joint imprints)" ~
        if_else(is.na(Notes) | Notes == "",
                "Published under Houghton Mifflin and predecessor/joint imprints",
                paste(Notes, "Published under Houghton Mifflin and predecessor/joint imprints", sep = "; ")),

      # For Hurd & Houghton predecessor note
      Publisher == "Hurd & Houghton (pre-1878 predecessor)" ~
        if_else(is.na(Notes) | Notes == "",
                "Pre-1878 predecessor to Houghton Mifflin",
                paste(Notes, "Pre-1878 predecessor to Houghton Mifflin", sep = "; ")),

      # Keep existing notes for all other cases
      TRUE ~ Notes
    ),

    # Clean up publisher names
    Publisher = case_when(
      Publisher == "All copyrights assigned to Houghton, Mifflin after 1878; Harte paid lump sums of $300 for all rights in each future work" ~ "Houghton, Mifflin",
      Publisher == "Houghton Mifflin (and predecessor / joint imprints)" ~ "Houghton Mifflin",
      Publisher == "Hurd & Houghton (pre-1878 predecessor)" ~ "Hurd & Houghton",
      TRUE ~ Publisher
    )
  )

cat("\nPublisher cleanup completed:\n")

# Show publishers longer than 50 characters after cleanup
long_publishers_after <- book_entries$Publisher[!is.na(book_entries$Publisher) & nchar(book_entries$Publisher) > 50]
if (length(long_publishers_after) > 0) {
  cat("   ⚠️  Still found", length(unique(long_publishers_after)), "publishers longer than 50 characters\n")
} else {
  cat("   ✅ No publishers longer than 50 characters found\n")
}

# Show updated publisher distribution (top 10)
cat("\nTop 10 publishers after cleanup:\n")
publisher_dist <- table(book_entries$Publisher, useNA = "ifany")
publisher_sorted <- sort(publisher_dist, decreasing = TRUE)
top_publishers <- head(publisher_sorted, 10)
for (i in seq_along(top_publishers)) {
  cat("   ", i, ". ", names(top_publishers)[i], ": ", top_publishers[i], " books\n", sep = "")
}

# Export the final cleaned book_entries data frame
write.csv(book_entries, "data/cleaned/book_entries_final.csv", row.names = FALSE)
cat("\nFinal cleaned data exported to book_entries_final.csv\n")

# ===============================================================================
# RESHAPE BOOK_SALES TO LONG FORMAT
# ===============================================================================

cat("\n=== RESHAPING BOOK_SALES TO LONG FORMAT ===\n")
cat("Original book_sales dimensions:", dim(book_sales), "\n")

# Reshape book_sales from wide to long format
# Convert year columns (y1858, y1859, etc.) to long format
book_sales_long <- book_sales %>%
  pivot_longer(
    cols = starts_with("y"),  # Select all columns starting with "y"
    names_to = "year",        # New column name for the year values
    values_to = "sales",      # New column name for the sales values
    names_prefix = "y"        # Remove the "y" prefix from year values
  ) %>%
  mutate(year = as.numeric(year)) %>%  # Convert year to numeric
  filter(!is.na(sales))                # Remove rows where sales is NA

cat("Reshaped book_sales_long dimensions:", dim(book_sales_long), "\n")
cat("Year range:", min(book_sales_long$year, na.rm = TRUE), "to", max(book_sales_long$year, na.rm = TRUE), "\n")
cat("Sample of reshaped data:\n")
print(head(book_sales_long, 10))

# Export the reshaped book_sales_long data
write.csv(book_sales_long, "data/cleaned/book_sales_long.csv", row.names = FALSE)
cat("\nReshaped book sales data exported to book_sales_long.csv\n")

# ===============================================================================
# RESTRUCTURE ROYALTY DATA FOR INCOME CALCULATIONS
# ===============================================================================

cat("\n=== RESTRUCTURING ROYALTY DATA ===\n")

# Create royalty structure data in long format
# CORRECTED LOGIC based on comprehensive data analysis:
# - Process r1, r2, r3, r4 sequentially (sliding scale is just an indicator)
# - Tier is valid if: rate ≠ NA AND limit ≠ NA
# - limit > 0: tier spans (previous_limit + 1) to limit
# - limit = 0: tier spans (previous_limit + 1) to ∞ (INFINITE)
# - rate = 0 is VALID (means no royalty for that range)

royalty_structure <- book_sales %>%
  select(book_ID, r1, r2, r3, r4, limit1, limit2, limit3, limit4, `Sliding Scale?`) %>%
  mutate(
    # Determine which tiers exist (rate and limit both not NA)
    tier1_exists = !is.na(r1) & !is.na(limit1),
    tier2_exists = !is.na(r2) & !is.na(limit2), 
    tier3_exists = !is.na(r3) & !is.na(limit3),
    tier4_exists = !is.na(r4) & !is.na(limit4)
  ) %>%
  mutate(
    # Create tier 1 (always starts at copy 1)
    tier1_rate = case_when(tier1_exists ~ r1, TRUE ~ NA_real_),
    tier1_lower = case_when(tier1_exists ~ 1, TRUE ~ NA_real_),
    tier1_upper = case_when(
      tier1_exists & limit1 > 0 ~ limit1,
      tier1_exists & limit1 == 0 ~ Inf,  # limit1=0 means infinite
      TRUE ~ NA_real_
    ),
    
    # Create tier 2 (starts after limit1)
    tier2_rate = case_when(tier2_exists ~ r2, TRUE ~ NA_real_),
    tier2_lower = case_when(
      tier2_exists & tier1_exists & limit1 > 0 ~ limit1 + 1,
      tier2_exists & tier1_exists & limit1 == 0 ~ NA_real_,  # Can't have tier2 if tier1 is infinite
      tier2_exists & !tier1_exists ~ 1,  # If no tier1, tier2 starts at 1
      TRUE ~ NA_real_
    ),
    tier2_upper = case_when(
      tier2_exists & limit2 > 0 ~ limit2,
      tier2_exists & limit2 == 0 ~ Inf,  # limit2=0 means infinite
      TRUE ~ NA_real_
    ),
    
    # Create tier 3 (starts after limit2)
    tier3_rate = case_when(tier3_exists ~ r3, TRUE ~ NA_real_),
    tier3_lower = case_when(
      tier3_exists & tier2_exists & limit2 > 0 ~ limit2 + 1,
      tier3_exists & tier2_exists & limit2 == 0 ~ NA_real_,  # Can't have tier3 if tier2 is infinite
      tier3_exists & !tier2_exists & tier1_exists & limit1 > 0 ~ limit1 + 1,
      tier3_exists & !tier2_exists & tier1_exists & limit1 == 0 ~ NA_real_,
      tier3_exists & !tier2_exists & !tier1_exists ~ 1,
      TRUE ~ NA_real_
    ),
    tier3_upper = case_when(
      tier3_exists & limit3 > 0 ~ limit3,
      tier3_exists & limit3 == 0 ~ Inf,  # limit3=0 means infinite
      TRUE ~ NA_real_
    ),
    
    # Create tier 4 (starts after limit3)
    tier4_rate = case_when(tier4_exists ~ r4, TRUE ~ NA_real_),
    tier4_lower = case_when(
      tier4_exists & tier3_exists & limit3 > 0 ~ limit3 + 1,
      tier4_exists & tier3_exists & limit3 == 0 ~ NA_real_,  # Can't have tier4 if tier3 is infinite
      tier4_exists & !tier3_exists & tier2_exists & limit2 > 0 ~ limit2 + 1,
      tier4_exists & !tier3_exists & tier2_exists & limit2 == 0 ~ NA_real_,
      tier4_exists & !tier3_exists & !tier2_exists & tier1_exists & limit1 > 0 ~ limit1 + 1,
      tier4_exists & !tier3_exists & !tier2_exists & tier1_exists & limit1 == 0 ~ NA_real_,
      tier4_exists & !tier3_exists & !tier2_exists & !tier1_exists ~ 1,
      TRUE ~ NA_real_
    ),
    tier4_upper = case_when(
      tier4_exists & limit4 > 0 ~ limit4,
      tier4_exists & limit4 == 0 ~ Inf,  # limit4=0 means infinite
      TRUE ~ NA_real_
    )
  )

# Reshape to long format with one row per tier per book
# Each valid tier (where rate and limits are not NA) becomes a row

royalty_tiers <- royalty_structure %>%
  select(book_ID, `Sliding Scale?`, 
         starts_with("tier1_"), starts_with("tier2_"), starts_with("tier3_"), starts_with("tier4_")) %>%
  pivot_longer(
    cols = c(starts_with("tier1_"), starts_with("tier2_"), starts_with("tier3_"), starts_with("tier4_")),
    names_to = c("tier", ".value"),
    names_pattern = "(tier1|tier2|tier3|tier4)_(.*)"
  ) %>%
  filter(!is.na(rate) & !is.na(lower) & !is.na(upper)) %>%  # Keep only valid tiers
  mutate(
    tier = case_when(
      tier == "tier1" ~ 1,
      tier == "tier2" ~ 2, 
      tier == "tier3" ~ 3,
      tier == "tier4" ~ 4
    ),
    sliding_scale = `Sliding Scale?`
  ) %>%
  select(book_ID, tier, rate, lower_limit = lower, upper_limit = upper, sliding_scale) %>%
  arrange(book_ID, tier)

cat("Royalty tiers structure:\n")
cat("Total royalty tiers:", nrow(royalty_tiers), "\n")
cat("Tiers with Sliding Scale = 0:", sum(royalty_tiers$sliding_scale == 0, na.rm = TRUE), "\n")
cat("Tiers with Sliding Scale = 1:", sum(royalty_tiers$sliding_scale == 1, na.rm = TRUE), "\n")

# Show examples of different tier types
cat("\nSample royalty tiers with various patterns:\n")

# Show examples with rate = 0 (valid, means no royalty)
zero_rate_examples <- royalty_tiers[royalty_tiers$rate == 0, ]
if(nrow(zero_rate_examples) > 0) {
  cat("Examples with rate = 0 (no royalty):\n")
  print(head(zero_rate_examples, 3))
}

# Show examples with infinite upper limit (from limit = 0)
infinite_examples <- royalty_tiers[is.infinite(royalty_tiers$upper_limit), ]
if(nrow(infinite_examples) > 0) {
  cat("\nExamples with infinite upper limit (from limit = 0):\n")
  print(head(infinite_examples, 5))
}

# Show examples of multi-tier books
multi_tier_books <- royalty_tiers %>%
  group_by(book_ID) %>%
  summarise(tier_count = n(), .groups = "drop") %>%
  filter(tier_count > 1) %>%
  slice_head(n = 3)

if(nrow(multi_tier_books) > 0) {
  cat("\nExamples of multi-tier books:\n")
  for(book_id in multi_tier_books$book_ID) {
    cat("\n", book_id, ":\n")
    book_tiers <- royalty_tiers[royalty_tiers$book_ID == book_id, ]
    print(book_tiers)
  }
}

# Export the corrected royalty structure
write.csv(royalty_tiers, "data/cleaned/royalty_tiers_corrected.csv", row.names = FALSE)
cat("\nCorrected royalty tiers data exported to royalty_tiers_corrected.csv\n")


