# Load and configure
library(pacman)
p_load(readxl, dplyr, tidyr, stringr, here)

# Flags
verbose <- FALSE             # Set to FALSE to reduce console output
export_royalty_tiers <- TRUE # Set to FALSE to skip exporting royalty tiers

# Paths (robust to working directory)
excel_file <- here::here("data/original/anesko_db_original.xlsx")
cleaned_dir <- here::here("data/cleaned")

# Check paths
if (!file.exists(excel_file)) {
  stop("Excel file not found. ",
       "Please ensure the file is in the data/original/ directory")
}
if (!dir.exists(cleaned_dir)) {
  dir.create(cleaned_dir, recursive = TRUE)
}

# Read Excel sheets
book_entries <- read_excel(excel_file, sheet = "Book_Entry_Table")
book_sales <- read_excel(excel_file, sheet = "Book_Sales_Table")

if (verbose) {
  cat("Found", nrow(book_entries), "book entries\n")
  cat("Found", nrow(book_sales), "sales records\n")
}


# Clean and prepare book_entries data

if (verbose) {
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
}

# =============================================================================
# PUBLISHER NORMALIZATION, NOTES AUGMENTATION, AND CANONICALIZATION
# =============================================================================

# Unambiguous special note text (single line)
special_publisher_text <- paste0(
  "All copyrights assigned to Houghton, Mifflin after 1878; ",
  "Harte paid lump sums of $300 for all rights in each future work"
)
# Common raw markers and note texts
hm_raw <- "Houghton Mifflin (and predecessor / joint imprints)"
hurd_raw <- "Hurd & Houghton (pre-1878 predecessor)"
hm_note <- "Published under Houghton Mifflin and predecessor/joint imprints"
hurd_note <- "Pre-1878 predecessor to Houghton Mifflin"

# Preserve raw publisher for note logic, then normalize and canonicalize
book_entries <- book_entries %>%
  mutate(
    pub_raw = Publisher,
    # Normalize formatting
    Publisher = str_trim(Publisher),
    Publisher = str_squish(Publisher),
    Publisher = str_replace_all(Publisher, "’", "'"),
    Publisher = str_replace_all(Publisher, "\\s*&\\s*", " & "),
    Publisher = str_replace_all(Publisher, " and ", " & "),
    Publisher = str_replace_all(Publisher, "\\s*,\\s*", ", "),
    Publisher = str_remove(Publisher, "\\.$")
  ) %>%
  mutate(
    # Augment notes for specific raw cases
    Notes = case_when(
      pub_raw == special_publisher_text & (is.na(Notes) | Notes == "") ~
        special_publisher_text,
      pub_raw == special_publisher_text & !(is.na(Notes) | Notes == "") ~
        paste(Notes, special_publisher_text, sep = "; "),
      pub_raw == hm_raw & (is.na(Notes) | Notes == "") ~
        hm_note,
      pub_raw == hm_raw & !(is.na(Notes) | Notes == "") ~
        paste(Notes, hm_note, sep = "; "),
      pub_raw == hurd_raw & (is.na(Notes) | Notes == "") ~
        hurd_note,
      pub_raw == hurd_raw & !(is.na(Notes) | Notes == "") ~
        paste(Notes, hurd_note, sep = "; "),
      TRUE ~ Notes
    ),
    # Canonicalize publisher names
    Publisher = case_when(
      pub_raw == special_publisher_text ~ "Houghton Mifflin",
      Publisher %in% c(
        "Harper", "Harper & Brothers", "Harper & Bros", "Harper & Bros.",
        "Harper and Brothers", "Harper and Bros.", "Harper Brothers"
      ) ~ "Harper & Brothers",
      Publisher %in% c(
        "Houghton Mifflin", "Houghton-Mifflin", "Houghton, Mifflin",
        "Hougton, Mifflin", "Houhgton, Mifflin", "Houghton", "Hougthon"
      ) ~ "Houghton Mifflin",
      Publisher == "Hurd & Houghton" ~ "Hurd & Houghton",
      Publisher == "Fields, Osgood" ~ "Fields, Osgood",
      Publisher %in% c(
        "Scribner's", "Scibner's", "Scribners", "Scribner’s", "Scibner’s"
      ) ~ "Scribner's",
      Publisher %in% c("Ticknor & Co.", "Ticknor & Co") ~ "Ticknor & Co.",
      Publisher %in% c("Century Co.", "The Century Co.", "Century Company") ~ "Century Co.",
      Publisher %in% c("Macmillan (NY)", "Macmillan") ~ "Macmillan (NY)",
      Publisher == "Grosset & Dunlap" ~ "Grosset & Dunlap",
      Publisher %in% c("R.H. Russell", "R. H. Russell", "R H Russell", "R.H.Russell") ~ "R. H. Russell",
      Publisher == "Herbert S. Stone" ~ "Herbert S. Stone",
      Publisher %in% c("Houghton, Osgood", "Houghton, Osgood & Co.") ~ "Houghton, Osgood",
      Publisher %in% c("J. R. Osgood & Co.", "J.R. Osgood & Co.") ~ "J. R. Osgood & Co.",
      Publisher == "Osgood, McIlvaine" ~ "Osgood, McIlvaine",
      TRUE ~ Publisher
    )
  ) %>%
  select(-pub_raw)

if (verbose) {
  cat("\n=== PUBLISHER SUMMARY (after canonicalization) ===\n")
  print(utils::head(sort(table(book_entries$Publisher), decreasing = TRUE), 10))
}


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


# Export cleaned book entries (canonicalized)
write.csv(
  book_entries,
  file.path(cleaned_dir, "book_entry_cleaned.csv"),
  row.names = FALSE
)

# ===============================================================================
# RESHAPE BOOK_SALES TO LONG FORMAT
# ===============================================================================

cat("\n=== RESHAPING BOOK_SALES TO LONG FORMAT ===\n")
cat("Original book_sales dimensions:", dim(book_sales), "\n")

# Coerce numeric types for sales
book_sales <- book_sales %>%
  mutate(across(starts_with("y"), ~ suppressWarnings(as.numeric(.))))

# Reshape book_sales from wide to long format
book_sales_long <- book_sales %>%
  pivot_longer(
    cols = starts_with("y"),
    names_to = "year",
    values_to = "sales",
    names_prefix = "y"
  ) %>%
  mutate(
    year = suppressWarnings(as.numeric(year)),
    sales = suppressWarnings(as.numeric(sales))
  ) %>%
  filter(!is.na(sales))

if (verbose) {
  cat("Reshaped book_sales_long dimensions:", dim(book_sales_long), "\n")
  cat(
    "Year range:",
    min(book_sales_long$year, na.rm = TRUE),
    "to",
    max(book_sales_long$year, na.rm = TRUE),
    "\n"
  )
  cat("Sample of reshaped data:\n")
  print(head(book_sales_long, 10))
}

# Export the reshaped book_sales_long data
write.csv(
  book_sales_long,
  file.path(cleaned_dir, "book_sales_cleaned.csv"),
  row.names = FALSE
)

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

# Coerce royalty-related numeric fields safely
book_sales <- book_sales %>%
  mutate(
    r1 = suppressWarnings(as.numeric(r1)),
    r2 = suppressWarnings(as.numeric(r2)),
    r3 = suppressWarnings(as.numeric(r3)),
    r4 = suppressWarnings(as.numeric(r4)),
    limit1 = suppressWarnings(as.numeric(limit1)),
    limit2 = suppressWarnings(as.numeric(limit2)),
    limit3 = suppressWarnings(as.numeric(limit3)),
    limit4 = suppressWarnings(as.numeric(limit4))
  )

royalty_structure <- book_sales %>%
  select(
    book_ID, r1, r2, r3, r4,
    limit1, limit2, limit3, limit4,
    `Sliding Scale?`
  ) %>%
  mutate(
    # Determine which tiers exist (rate and limit both not NA)
    tier1_exists = !is.na(r1) & !is.na(limit1),
    tier2_exists = !is.na(r2) & !is.na(limit2),
    tier3_exists = !is.na(r3) & !is.na(limit3),
    tier4_exists = !is.na(r4) & !is.na(limit4)
  ) %>%
  mutate(
    # Create tier 1 (always starts at copy 1)
    tier1_rate = if_else(tier1_exists, r1, NA_real_),
    tier1_lower = if_else(tier1_exists, 1, NA_real_),
    tier1_upper = case_when(
      tier1_exists & limit1 > 0 ~ limit1,
      tier1_exists & limit1 == 0 ~ Inf,
      TRUE ~ NA_real_
    ),
    # Create tier 2 (starts after limit1)
    tier2_rate = if_else(tier2_exists, r2, NA_real_),
    tier2_lower = case_when(
      tier2_exists & tier1_exists & limit1 > 0 ~ limit1 + 1,
      tier2_exists & tier1_exists & limit1 == 0 ~ NA_real_,
      tier2_exists & !tier1_exists ~ 1,
      TRUE ~ NA_real_
    ),
    tier2_upper = case_when(
      tier2_exists & limit2 > 0 ~ limit2,
      tier2_exists & limit2 == 0 ~ Inf,
      TRUE ~ NA_real_
    ),
    # Create tier 3 (starts after limit2)
    tier3_rate = if_else(tier3_exists, r3, NA_real_),
    tier3_lower = case_when(
      tier3_exists & tier2_exists & limit2 > 0 ~ limit2 + 1,
      tier3_exists & tier2_exists & limit2 == 0 ~ NA_real_,
      tier3_exists & !tier2_exists & tier1_exists & limit1 > 0 ~ limit1 + 1,
      tier3_exists & !tier2_exists & tier1_exists & limit1 == 0 ~ NA_real_,
      tier3_exists & !tier2_exists & !tier1_exists ~ 1,
      TRUE ~ NA_real_
    ),
    tier3_upper = case_when(
      tier3_exists & limit3 > 0 ~ limit3,
      tier3_exists & limit3 == 0 ~ Inf,
      TRUE ~ NA_real_
    ),
    # Create tier 4 (starts after limit3)
    tier4_rate = if_else(tier4_exists, r4, NA_real_),
    tier4_lower = case_when(
      tier4_exists & tier3_exists & limit3 > 0 ~ limit3 + 1,
      tier4_exists & tier3_exists & limit3 == 0 ~ NA_real_,
      tier4_exists & !tier3_exists & tier2_exists & limit2 > 0 ~ limit2 + 1,
      tier4_exists & !tier3_exists & tier2_exists & limit2 == 0 ~ NA_real_,
      tier4_exists & !tier3_exists & !tier2_exists & tier1_exists & limit1 > 0 ~ limit1 + 1,
      tier4_exists & !tier3_exists & !tier2_exists & tier1_exists & limit1 == 0 ~ NA_real_,
      tier4_exists & !tier3_exists & !tier2_exists & !tier1_exists ~ 1,
      TRUE ~ NA_real_
    ),
    tier4_upper = case_when(
      tier4_exists & limit4 > 0 ~ limit4,
      tier4_exists & limit4 == 0 ~ Inf,
      TRUE ~ NA_real_
    )
  )

# Reshape to long format with one row per tier per book
# Each valid tier (where rate and limits are not NA) becomes a row

royalty_tiers <- royalty_structure %>%
  select(
    book_ID, `Sliding Scale?`,
    starts_with("tier1_"),
    starts_with("tier2_"),
    starts_with("tier3_"),
    starts_with("tier4_")
  ) %>%
  pivot_longer(
    cols = c(
      starts_with("tier1_"),
      starts_with("tier2_"),
      starts_with("tier3_"),
      starts_with("tier4_")
    ),
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

# Optional export of royalty tiers
if (isTRUE(export_royalty_tiers)) {
  write.csv(
    royalty_tiers,
    file.path(cleaned_dir, "royalty_tiers_cleaned.csv"),
    row.names = FALSE
  )
}
