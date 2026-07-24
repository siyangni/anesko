# Append June 2026 Book ID update to book_entries only.
#
# Default mode is a dry run. Use --commit to insert into PostgreSQL.

book_entry_columns <- c(
  "book_id", "author_surname", "gender", "book_title", "genre", "binding",
  "notes", "retail_price", "royalty_rate", "contract_terms", "publisher",
  "publication_year", "author_id"
)

expected_docx_header <- c(
  "Book ID", "Royalty Rate", "Author Surname", "Gender", "Book Title",
  "Genre", "Unlabeled", "Binding", "Notes", "Retail Price",
  "Contract Terms", "Publisher"
)

find_project_root <- function(start = getwd()) {
  current <- normalizePath(start, winslash = "/", mustWork = TRUE)

  repeat {
    if (
      file.exists(file.path(current, "DESCRIPTION")) &&
        dir.exists(file.path(current, "db", "migrations"))
    ) {
      return(current)
    }

    parent <- dirname(current)
    if (identical(parent, current)) {
      stop("Could not find project root from ", start, call. = FALSE)
    }
    current <- parent
  }
}

parse_args <- function(args) {
  value_after <- function(flag, default = NULL) {
    index <- match(flag, args)
    if (is.na(index)) {
      return(default)
    }
    if (index == length(args)) {
      stop("Missing value after ", flag, call. = FALSE)
    }
    args[[index + 1]]
  }

  list(
    commit = "--commit" %in% args,
    no_db = "--no-db" %in% args,
    require_db = "--require-db" %in% args,
    help = "--help" %in% args || "-h" %in% args,
    source = value_after("--source"),
    output_dir = value_after("--output-dir")
  )
}

print_usage <- function() {
  cat("Usage: Rscript db/migrations/04_import_june_2026_book_ids.R [options]\n")
  cat("\nOptions:\n")
  cat("  --commit       Insert new book_entries rows. Default is dry-run.\n")
  cat("  --no-db        Do not connect to PostgreSQL; use cleaned CSV fallback.\n")
  cat("  --require-db   Fail if PostgreSQL connection is unavailable.\n")
  cat("  --source PATH  Override the June 2026 DOCX path.\n")
  cat("  --output-dir PATH  Override output directory for reports.\n")
  cat("  --help         Show this message.\n")
}

require_package <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop("Required package not installed: ", package, call. = FALSE)
  }
}

cell_text <- function(cell, ns) {
  text_nodes <- xml2::xml_find_all(cell, ".//w:t", ns)
  paste(xml2::xml_text(text_nodes), collapse = "")
}

read_docx_table <- function(path) {
  require_package("xml2")

  if (!file.exists(path)) {
    stop("DOCX source not found: ", path, call. = FALSE)
  }

  doc <- xml2::read_xml(unz(path, "word/document.xml"))
  ns <- xml2::xml_ns(doc)
  if (!"w" %in% names(ns)) {
    stop("DOCX does not contain a WordprocessingML namespace", call. = FALSE)
  }

  tables <- xml2::xml_find_all(doc, ".//w:tbl", ns)
  if (length(tables) != 1) {
    stop("Expected exactly 1 DOCX table, found ", length(tables), call. = FALSE)
  }

  rows <- xml2::xml_find_all(tables[[1]], "./w:tr", ns)
  parsed_rows <- lapply(rows, function(row) {
    cells <- xml2::xml_find_all(row, "./w:tc", ns)
    vapply(cells, cell_text, character(1), ns = ns)
  })

  header <- parsed_rows[[1]]
  if (!identical(header, expected_docx_header)) {
    stop(
      "Unexpected DOCX header. Found: ",
      paste(header, collapse = " | "),
      call. = FALSE
    )
  }

  data_rows <- parsed_rows[-1]
  max_cells <- max(lengths(data_rows), length(header))
  if (max_cells > length(header)) {
    stop("Found a DOCX row with more cells than the header", call. = FALSE)
  }

  padded <- lapply(data_rows, function(row) {
    length(row) <- length(header)
    row[is.na(row)] <- ""
    row
  })

  out <- as.data.frame(do.call(rbind, padded), stringsAsFactors = FALSE)
  names(out) <- header
  out$source_row <- seq_len(nrow(out)) + 1L

  list(
    table_count = length(tables),
    total_rows = length(rows),
    header = header,
    data = out
  )
}

validate_source_rows <- function(parsed) {
  data <- parsed$data
  content_cols <- expected_docx_header
  nonblank <- data[rowSums(data[content_cols] != "") > 0, , drop = FALSE]

  blank_id_rows <- nonblank[trimws(nonblank[["Book ID"]]) == "", , drop = FALSE]
  id_rows <- nonblank[trimws(nonblank[["Book ID"]]) != "", , drop = FALSE]
  ids <- trimws(id_rows[["Book ID"]])

  checks <- list(
    table_count = parsed$table_count,
    total_rows = parsed$total_rows,
    data_rows = nrow(data),
    nonblank_data_rows = nrow(nonblank),
    blank_id_rows_dropped = nrow(blank_id_rows),
    blank_id_source_rows = paste(blank_id_rows$source_row, collapse = ", "),
    id_rows = nrow(id_rows),
    duplicate_id_count = length(unique(ids[duplicated(ids)])),
    invalid_id_count = sum(!grepl("^[A-Za-z]+[0-9]?-?[0-9]{4}[A-Za-z]?$", ids))
  )

  if (checks$total_rows != 239L) {
    stop("Expected 239 DOCX table rows, found ", checks$total_rows, call. = FALSE)
  }
  if (checks$nonblank_data_rows != 176L) {
    stop(
      "Expected 176 nonblank data rows, found ",
      checks$nonblank_data_rows,
      call. = FALSE
    )
  }
  if (
    nrow(blank_id_rows) != 1L ||
      !identical(as.integer(blank_id_rows$source_row), 23L)
  ) {
    stop(
      "Expected one nonblank blank-ID separator row at DOCX row 23",
      call. = FALSE
    )
  }
  if (checks$id_rows != 175L) {
    stop("Expected 175 rows with Book ID, found ", checks$id_rows, call. = FALSE)
  }
  if (checks$duplicate_id_count != 0L) {
    duplicate_ids <- unique(ids[duplicated(ids)])
    stop("Duplicate Book IDs in DOCX: ", paste(duplicate_ids, collapse = ", "),
         call. = FALSE)
  }
  if (checks$invalid_id_count != 0L) {
    invalid_ids <- ids[!grepl("^[A-Za-z]+[0-9]?-?[0-9]{4}[A-Za-z]?$", ids)]
    stop("Invalid Book ID values: ", paste(invalid_ids, collapse = ", "),
         call. = FALSE)
  }

  list(rows = id_rows, checks = checks)
}

null_if_empty <- function(x) {
  x[trimws(x) == ""] <- NA_character_
  x
}

append_note <- function(notes, addition) {
  has_notes <- !is.na(notes) & nzchar(trimws(notes))
  has_addition <- !is.na(addition) & nzchar(trimws(addition))

  out <- notes
  out[!has_notes & has_addition] <- addition[!has_notes & has_addition]
  out[has_notes & has_addition] <- paste(
    notes[has_notes & has_addition],
    addition[has_notes & has_addition],
    sep = "; "
  )
  out
}

extract_publisher_note <- function(publisher) {
  matches <- gregexpr("\\[[^][]+\\]", publisher)
  raw_notes <- regmatches(publisher, matches)
  vapply(raw_notes, function(values) {
    if (length(values) == 0L || identical(values, character(0))) {
      return(NA_character_)
    }
    cleaned <- gsub("^\\[|\\]$", "", values)
    paste(cleaned, collapse = "; ")
  }, character(1))
}

remove_publisher_note <- function(publisher) {
  trimws(gsub("\\s*\\[[^][]+\\]", "", publisher))
}

normalize_publisher <- function(publisher) {
  publisher <- trimws(publisher)
  base <- remove_publisher_note(publisher)
  base <- gsub("[[:space:]]+", " ", base)
  base <- gsub("’", "'", base, fixed = TRUE)

  canonical <- ifelse(base %in% c("Scribner", "Scribner's", "Scribners"),
    "Scribner's",
    base
  )
  canonical <- ifelse(canonical == "Harper", "Harper & Brothers", canonical)
  canonical <- ifelse(
    canonical %in% c("JR Osgood", "J.R. Osgood", "J. R. Osgood"),
    "J. R. Osgood & Co",
    canonical
  )
  null_if_empty(canonical)
}

map_gender <- function(gender) {
  # Blank / whitespace-only → NULL (Unknown at app layer)
  gender <- trimws(as.character(gender))
  gender[is.na(gender) | !nzchar(gender)] <- NA_character_
  out <- ifelse(
    is.na(gender),
    NA_character_,
    ifelse(
      toupper(gender) %in% c("M", "MALE"),
      "Male",
      ifelse(toupper(gender) %in% c("F", "FEMALE"), "Female", NA_character_)
    )
  )
  # Unrecognized non-blank codes also become NULL (Unknown), not raw strings
  null_if_empty(out)
}

map_genre <- function(genre) {
  genre <- trimws(genre)
  mapped <- c(
    A = "Anthology",
    C = "Children's Literature/Juvenile",
    D = "Drama",
    E = "Essay/Other Non-Fiction",
    J = "Children's Literature/Juvenile",
    M = "Memoir",
    N = "Novel",
    P = "Poetry",
    S = "Short Story Collection/Novella",
    T = "Travel"
  )
  out <- ifelse(genre %in% names(mapped), unname(mapped[genre]), genre)
  null_if_empty(out)
}

map_binding <- function(binding) {
  binding <- trimws(binding)
  mapped <- c(
    C = "Cloth",
    P = "Paper",
    D = "Deluxe",
    I = "Illustrated",
    R = "Reprint"
  )
  out <- ifelse(binding %in% names(mapped), unname(mapped[binding]), binding)
  null_if_empty(out)
}

parse_royalty_rate <- function(rate) {
  rate <- trimws(rate)
  suppressWarnings(ifelse(rate == "" | toupper(rate) == "SS", NA_real_,
                          as.numeric(rate)))
}

parse_retail_price <- function(price) {
  price <- trimws(price)
  suppressWarnings(ifelse(price == "" | grepl("/", price, fixed = TRUE),
                          NA_real_, as.numeric(price)))
}

extract_publication_year <- function(book_id) {
  matches <- regexpr("[0-9]{4}", book_id)
  years <- rep(NA_integer_, length(book_id))
  has_year <- !is.na(matches) & matches > 0L
  years[has_year] <- as.integer(substr(
    book_id[has_year],
    matches[has_year],
    matches[has_year] + attr(matches, "match.length")[has_year] - 1L
  ))
  years
}

extract_author_id <- function(book_id) {
  prefix <- sub("[0-9]{4}.*$", "", book_id)
  sub("-$", "", prefix)
}

stage_book_entries <- function(rows) {
  book_id <- trimws(rows[["Book ID"]])
  notes <- rows[["Notes"]]
  notes[is.na(notes)] <- ""

  unlabeled <- trimws(rows[["Unlabeled"]])
  unlabeled_note <- ifelse(
    unlabeled == "",
    NA_character_,
    paste0("Unlabeled: ", unlabeled)
  )
  notes <- append_note(notes, unlabeled_note)

  retail_raw <- trimws(rows[["Retail Price"]])
  multi_price <- grepl("/", retail_raw, fixed = TRUE)
  retail_note <- ifelse(
    multi_price,
    paste0("Retail Price: ", retail_raw),
    NA_character_
  )
  notes <- append_note(notes, retail_note)

  publisher_raw <- trimws(rows[["Publisher"]])
  publisher_note <- extract_publisher_note(publisher_raw)
  publisher_note <- ifelse(
    is.na(publisher_note),
    NA_character_,
    paste0("Publisher note: ", publisher_note)
  )
  notes <- append_note(notes, publisher_note)

  data.frame(
    source_row = rows$source_row,
    book_id = book_id,
    author_surname = null_if_empty(trimws(rows[["Author Surname"]])),
    gender = map_gender(rows[["Gender"]]),
    book_title = null_if_empty(trimws(rows[["Book Title"]])),
    genre = map_genre(rows[["Genre"]]),
    binding = map_binding(rows[["Binding"]]),
    notes = null_if_empty(notes),
    retail_price = parse_retail_price(rows[["Retail Price"]]),
    royalty_rate = parse_royalty_rate(rows[["Royalty Rate"]]),
    contract_terms = null_if_empty(trimws(rows[["Contract Terms"]])),
    publisher = normalize_publisher(rows[["Publisher"]]),
    publication_year = extract_publication_year(book_id),
    author_id = extract_author_id(book_id),
    raw_royalty_rate = trimws(rows[["Royalty Rate"]]),
    raw_retail_price = trimws(rows[["Retail Price"]]),
    raw_unlabeled = unlabeled,
    raw_publisher = publisher_raw,
    stringsAsFactors = FALSE
  )
}

load_db_config <- function(root) {
  if (Sys.getenv("DB_USER") != "" && Sys.getenv("DB_PASSWORD") != "") {
    return(list(
      host = ifelse(Sys.getenv("DB_HOST") != "", Sys.getenv("DB_HOST"),
                    "localhost"),
      dbname = ifelse(Sys.getenv("DB_NAME") != "", Sys.getenv("DB_NAME"),
                      "american_authorship"),
      user = Sys.getenv("DB_USER"),
      password = Sys.getenv("DB_PASSWORD")
    ))
  }

  config_file <- file.path(root, "scripts", "config", "database_config.R")
  if (!file.exists(config_file)) {
    return(NULL)
  }

  env <- new.env(parent = baseenv())
  sys.source(config_file, envir = env)
  if (!exists("db_config", envir = env, inherits = FALSE)) {
    stop("Database config file does not define db_config: ", config_file,
         call. = FALSE)
  }
  get("db_config", envir = env, inherits = FALSE)
}

connect_database <- function(db_config) {
  require_package("DBI")
  require_package("RPostgreSQL")

  DBI::dbConnect(
    RPostgreSQL::PostgreSQL(),
    host = db_config$host,
    dbname = db_config$dbname,
    user = db_config$user,
    password = db_config$password
  )
}

quote_ids <- function(con, ids) {
  paste(DBI::dbQuoteString(con, ids), collapse = ", ")
}

load_existing_from_db <- function(con, ids) {
  if (length(ids) == 0L) {
    return(data.frame(book_id = character(0)))
  }

  query <- paste0(
    "SELECT ",
    paste(book_entry_columns, collapse = ", "),
    " FROM book_entries WHERE book_id IN (",
    quote_ids(con, ids),
    ")"
  )
  DBI::dbGetQuery(con, query)
}

load_existing_from_cleaned_csv <- function(path) {
  if (!file.exists(path)) {
    return(data.frame(book_id = character(0)))
  }

  raw <- read.csv(path, stringsAsFactors = FALSE, na.strings = c("", "NA"))
  out <- data.frame(
    book_id = raw$Book.ID,
    author_surname = raw$Author.Surname,
    gender = raw$Gender,
    book_title = raw$Book.Title,
    genre = raw$Genre,
    binding = raw$Binding,
    notes = raw$Notes,
    retail_price = suppressWarnings(as.numeric(raw$Retail.Price)),
    royalty_rate = suppressWarnings(as.numeric(raw$Royalty.Rate)),
    contract_terms = raw$Contract.Terms,
    publisher = raw$Publisher,
    publication_year = extract_publication_year(raw$Book.ID),
    author_id = raw$author_id,
    stringsAsFactors = FALSE
  )
  out[!duplicated(out$book_id), , drop = FALSE]
}

make_conflict_report <- function(staging, existing) {
  if (nrow(existing) == 0L) {
    return(data.frame(book_id = character(0)))
  }

  staging_conflicts <- staging[staging$book_id %in% existing$book_id, , drop = FALSE]
  existing_conflicts <- existing[existing$book_id %in% staging$book_id, , drop = FALSE]

  merge(
    staging_conflicts[, c("book_id", "source_row", book_entry_columns[-1],
                         "raw_royalty_rate", "raw_retail_price",
                         "raw_unlabeled", "raw_publisher")],
    existing_conflicts[, book_entry_columns],
    by = "book_id",
    suffixes = c("_incoming", "_existing"),
    all.x = TRUE,
    sort = TRUE
  )
}

get_table_counts <- function(con) {
  data.frame(
    table = c("book_entries", "book_sales", "royalty_tiers"),
    rows = c(
      DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM book_entries")$n,
      DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM book_sales")$n,
      DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM royalty_tiers")$n
    ),
    stringsAsFactors = FALSE
  )
}

insert_book_entries <- function(con, candidates) {
  insert_data <- candidates[, book_entry_columns, drop = FALSE]
  before_counts <- get_table_counts(con)
  inserted <- NA_integer_
  committed <- FALSE

  DBI::dbBegin(con)
  tryCatch({
    DBI::dbExecute(con, paste(
      "CREATE TEMP TABLE june_2026_book_entries_stage (",
      "book_id VARCHAR(50),",
      "author_surname VARCHAR(255),",
      "gender VARCHAR(10),",
      "book_title TEXT,",
      "genre VARCHAR(100),",
      "binding VARCHAR(50),",
      "notes TEXT,",
      "retail_price DECIMAL(10,2),",
      "royalty_rate DECIMAL(5,4),",
      "contract_terms TEXT,",
      "publisher VARCHAR(255),",
      "publication_year INTEGER,",
      "author_id VARCHAR(20)",
      ") ON COMMIT DROP"
    ))

    DBI::dbWriteTable(
      con,
      "june_2026_book_entries_stage",
      insert_data,
      append = TRUE,
      row.names = FALSE
    )

    inserted <<- DBI::dbExecute(con, paste0(
      "INSERT INTO book_entries (",
      paste(book_entry_columns, collapse = ", "),
      ") SELECT ",
      paste(book_entry_columns, collapse = ", "),
      " FROM june_2026_book_entries_stage ",
      "ON CONFLICT (book_id) DO NOTHING"
    ))

    after_counts <- get_table_counts(con)
    before_sales <- before_counts$rows[before_counts$table == "book_sales"]
    after_sales <- after_counts$rows[after_counts$table == "book_sales"]
    before_tiers <- before_counts$rows[before_counts$table == "royalty_tiers"]
    after_tiers <- after_counts$rows[after_counts$table == "royalty_tiers"]

    if (!identical(before_sales, after_sales) ||
        !identical(before_tiers, after_tiers)) {
      stop("book_sales or royalty_tiers row count changed during import",
           call. = FALSE)
    }

    DBI::dbCommit(con)
    committed <<- TRUE

    list(
      inserted = inserted,
      before_counts = before_counts,
      after_counts = after_counts
    )
  }, error = function(e) {
    if (!committed) {
      DBI::dbRollback(con)
    }
    stop(e)
  })
}

ids_or_none <- function(ids) {
  ids <- ids[!is.na(ids)]
  if (length(ids) == 0L) {
    return("none")
  }
  paste(ids, collapse = ", ")
}

build_validation_summary <- function(checks, staging, candidates, conflicts,
                                     reference_source, db_counts = NULL,
                                     insert_result = NULL) {
  blank_royalty <- candidates$book_id[candidates$raw_royalty_rate == ""]
  ss_royalty <- candidates$book_id[toupper(candidates$raw_royalty_rate) == "SS"]
  blank_retail <- candidates$book_id[candidates$raw_retail_price == ""]
  multi_retail <- candidates$book_id[
    grepl("/", candidates$raw_retail_price, fixed = TRUE)
  ]

  lines <- c(
    "June 2026 Book ID Import Validation Summary",
    paste("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    "",
    "Source checks:",
    paste("- DOCX table count:", checks$table_count),
    paste("- Total DOCX table rows:", checks$total_rows),
    paste("- Data rows after header:", checks$data_rows),
    paste("- Nonblank data rows:", checks$nonblank_data_rows),
    paste("- Dropped blank-ID separator rows:", checks$blank_id_rows_dropped),
    paste("- Blank-ID separator DOCX row:", checks$blank_id_source_rows),
    paste("- Rows with valid Book ID:", checks$id_rows),
    paste("- Duplicate Book IDs in DOCX:", checks$duplicate_id_count),
    paste("- Invalid Book IDs in DOCX:", checks$invalid_id_count),
    "",
    "Reference and import counts:",
    paste("- Existing-ID reference:", reference_source),
    paste("- Staged rows:", nrow(staging)),
    paste("- Insert candidates:", nrow(candidates)),
    paste("- Skipped existing-ID collisions:", nrow(conflicts)),
    paste("- Skipped IDs:", ids_or_none(conflicts$book_id)),
    "",
    "Data warnings for insert candidates:",
    paste("- Blank royalty rates:", length(blank_royalty)),
    paste("- SS royalty rates stored as NULL:", length(ss_royalty),
          ids_or_none(ss_royalty)),
    paste("- Database NULL royalty_rate total:",
          sum(is.na(candidates$royalty_rate))),
    paste("- Blank retail prices:", length(blank_retail)),
    paste("- Multi-price retail values stored as NULL:", length(multi_retail),
          ids_or_none(multi_retail)),
    paste("- Database NULL retail_price total:",
          sum(is.na(candidates$retail_price))),
    paste("- Missing contract terms:",
          sum(is.na(candidates$contract_terms))),
    paste("- Missing gender:",
          sum(is.na(candidates$gender)),
          ids_or_none(candidates$book_id[is.na(candidates$gender)])),
    paste("- Missing title:",
          sum(is.na(candidates$book_title)),
          ids_or_none(candidates$book_id[is.na(candidates$book_title)])),
    paste("- Missing genre:",
          sum(is.na(candidates$genre)),
          ids_or_none(candidates$book_id[is.na(candidates$genre)])),
    paste("- Missing publisher:",
          sum(is.na(candidates$publisher)),
          ids_or_none(candidates$book_id[is.na(candidates$publisher)]))
  )

  if (!is.null(db_counts)) {
    lines <- c(
      lines,
      "",
      "Database counts before dry-run/commit:",
      paste("- book_entries:", db_counts$rows[db_counts$table == "book_entries"]),
      paste("- book_sales:", db_counts$rows[db_counts$table == "book_sales"]),
      paste("- royalty_tiers:", db_counts$rows[db_counts$table == "royalty_tiers"])
    )
  }

  if (!is.null(insert_result)) {
    before <- insert_result$before_counts
    after <- insert_result$after_counts
    lines <- c(
      lines,
      "",
      "Commit verification:",
      paste("- Inserted rows:", insert_result$inserted),
      paste("- book_entries before:",
            before$rows[before$table == "book_entries"]),
      paste("- book_entries after:",
            after$rows[after$table == "book_entries"]),
      paste("- book_sales before:",
            before$rows[before$table == "book_sales"]),
      paste("- book_sales after:",
            after$rows[after$table == "book_sales"]),
      paste("- royalty_tiers before:",
            before$rows[before$table == "royalty_tiers"]),
      paste("- royalty_tiers after:",
            after$rows[after$table == "royalty_tiers"])
    )
  }

  paste(lines, collapse = "\n")
}

write_outputs <- function(staging, conflicts, summary, output_dir) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  staging_path <- file.path(output_dir, "june_2026_book_ids_staging.csv")
  conflict_path <- file.path(output_dir, "june_2026_book_ids_skipped_conflicts.csv")
  summary_path <- file.path(output_dir, "june_2026_book_ids_validation_summary.txt")

  write.csv(staging, staging_path, row.names = FALSE, na = "", fileEncoding = "UTF-8")
  write.csv(conflicts, conflict_path, row.names = FALSE, na = "",
            fileEncoding = "UTF-8")
  writeLines(summary, summary_path, useBytes = TRUE)

  list(
    staging = staging_path,
    conflicts = conflict_path,
    summary = summary_path
  )
}

main <- function(args = commandArgs(trailingOnly = TRUE)) {
  opts <- parse_args(args)
  if (opts$help) {
    print_usage()
    return(invisible(NULL))
  }

  root <- find_project_root()
  source_path <- opts$source
  if (is.null(source_path)) {
    source_path <- file.path(root, "data", "update",
                             "New Book IDs - June 2026.docx")
  }
  output_dir <- opts$output_dir
  if (is.null(output_dir)) {
    output_dir <- file.path(root, "data", "update")
  }

  parsed <- read_docx_table(source_path)
  validated <- validate_source_rows(parsed)
  staging <- stage_book_entries(validated$rows)

  con <- NULL
  db_counts <- NULL
  db_config <- if (opts$no_db) NULL else load_db_config(root)
  reference_source <- "cleaned CSV fallback"
  existing <- data.frame(book_id = character(0))

  if (!is.null(db_config)) {
    con <- connect_database(db_config)
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    existing <- load_existing_from_db(con, staging$book_id)
    db_counts <- get_table_counts(con)
    reference_source <- "PostgreSQL book_entries"
  } else if (opts$commit || opts$require_db) {
    stop(
      "No database configuration found. Set DB_* environment variables or ",
      "create scripts/config/database_config.R.",
      call. = FALSE
    )
  } else {
    cleaned_csv <- file.path(root, "data", "cleaned", "book_entry_cleaned.csv")
    existing <- load_existing_from_cleaned_csv(cleaned_csv)
    existing <- existing[existing$book_id %in% staging$book_id, , drop = FALSE]
  }

  conflicts <- make_conflict_report(staging, existing)
  candidates <- staging[!staging$book_id %in% conflicts$book_id, , drop = FALSE]

  insert_result <- NULL
  if (opts$commit) {
    insert_result <- insert_book_entries(con, candidates)
  }

  summary <- build_validation_summary(
    checks = validated$checks,
    staging = staging,
    candidates = candidates,
    conflicts = conflicts,
    reference_source = reference_source,
    db_counts = db_counts,
    insert_result = insert_result
  )
  paths <- write_outputs(staging, conflicts, summary, output_dir)

  mode <- if (opts$commit) "commit" else "dry-run"
  cat("June 2026 Book ID import mode:", mode, "\n")
  cat("Rows with Book ID:", nrow(staging), "\n")
  cat("Insert candidates:", nrow(candidates), "\n")
  cat("Skipped existing-ID collisions:", nrow(conflicts), "\n")
  if (!opts$commit) {
    cat("Dry run only: no database rows inserted.\n")
  } else {
    cat("Inserted rows:", insert_result$inserted, "\n")
  }
  cat("Wrote staging CSV:", paths$staging, "\n")
  cat("Wrote conflict report:", paths$conflicts, "\n")
  cat("Wrote validation summary:", paths$summary, "\n")

  invisible(list(
    staging = staging,
    conflicts = conflicts,
    candidates = candidates,
    summary = summary,
    insert_result = insert_result
  ))
}

if (sys.nframe() == 0L) {
  main()
}
