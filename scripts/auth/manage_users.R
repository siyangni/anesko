#!/usr/bin/env Rscript
# User Management Script for American Authorship Database Authentication
# Interactive CLI tool for managing user accounts

# Load required libraries
if (!requireNamespace("bcrypt", quietly = TRUE)) {
  stop("bcrypt package required. Install with: install.packages('bcrypt')")
}

# Configuration
CREDENTIALS_FILE <- "shiny-app/config/users.rds"

# Colors for output
RED <- "\033[0;31m"
GREEN <- "\033[0;32m"
YELLOW <- "\033[1;33m"
BLUE <- "\033[0;34m"
NC <- "\033[0m"  # No Color

# Helper function to print colored output
print_colored <- function(text, color = NC) {
  cat(paste0(color, text, NC, "\n"))
}

# Load existing credentials or create new data frame
load_credentials <- function() {
  if (file.exists(CREDENTIALS_FILE)) {
    readRDS(CREDENTIALS_FILE)
  } else {
    data.frame(
      user = character(0),
      password = character(0),
      admin = logical(0),
      start = as.Date(character(0)),
      expire = as.Date(character(0)),
      stringsAsFactors = FALSE
    )
  }
}

# Save credentials
save_credentials <- function(credentials) {
  dir.create(dirname(CREDENTIALS_FILE), showWarnings = FALSE, recursive = TRUE)
  saveRDS(credentials, CREDENTIALS_FILE)
  Sys.chmod(CREDENTIALS_FILE, mode = "0600")  # Restrict permissions
  print_colored("✓ Credentials saved successfully", GREEN)
}

# List all users
list_users <- function() {
  credentials <- load_credentials()

  if (nrow(credentials) == 0) {
    print_colored("No users found", YELLOW)
    return()
  }

  print_colored("\n=== Current Users ===", BLUE)
  for (i in 1:nrow(credentials)) {
    user <- credentials[i, ]
    admin_status <- if (user$admin) "[ADMIN]" else "[USER]"
    status <- if (Sys.Date() > user$expire) "[EXPIRED]" else "[ACTIVE]"

    cat(sprintf(
      "%d. %s %s %s\n   Start: %s | Expire: %s\n",
      i, user$user, admin_status, status,
      user$start, user$expire
    ))
  }
  cat("\n")
}

# Add new user
add_user <- function() {
  print_colored("\n=== Add New User ===", BLUE)

  # Get username
  cat("Username: ")
  username <- trimws(readLines(con = "stdin", n = 1))

  if (username == "" || grepl("[^a-zA-Z0-9._-]", username)) {
    print_colored("✗ Invalid username. Use only letters, numbers, dots, underscores, hyphens", RED)
    return()
  }

  # Check if user exists
  credentials <- load_credentials()
  if (username %in% credentials$user) {
    print_colored("✗ User already exists", RED)
    return()
  }

  # Get password
  cat("Password (min 8 characters): ")
  password <- trimws(readLines(con = "stdin", n = 1))

  if (nchar(password) < 8) {
    print_colored("✗ Password must be at least 8 characters", RED)
    return()
  }

  # Confirm password
  cat("Confirm password: ")
  password_confirm <- trimws(readLines(con = "stdin", n = 1))

  if (password != password_confirm) {
    print_colored("✗ Passwords do not match", RED)
    return()
  }

  # Admin status
  cat("Admin privileges? (y/N): ")
  admin_input <- tolower(trimws(readLines(con = "stdin", n = 1)))
  is_admin <- admin_input == "y" || admin_input == "yes"

  # Expiration date
  cat("Expiration date (YYYY-MM-DD, or press Enter for 1 year): ")
  expire_input <- trimws(readLines(con = "stdin", n = 1))

  if (expire_input == "") {
    expire_date <- Sys.Date() + 365
  } else {
    expire_date <- tryCatch(
      as.Date(expire_input),
      error = function(e) {
        print_colored("✗ Invalid date format, using 1 year from now", YELLOW)
        Sys.Date() + 365
      }
    )
  }

  # Hash password
  print_colored("Hashing password...", YELLOW)
  password_hash <- bcrypt::hashpw(password)

  # Create new user
  new_user <- data.frame(
    user = username,
    password = password_hash,
    admin = is_admin,
    start = Sys.Date(),
    expire = expire_date,
    stringsAsFactors = FALSE
  )

  # Add to credentials
  credentials <- rbind(credentials, new_user)
  save_credentials(credentials)

  print_colored(sprintf("✓ User '%s' created successfully", username), GREEN)
  cat(sprintf("  Admin: %s | Expires: %s\n", is_admin, expire_date))
}

# Remove user
remove_user <- function() {
  credentials <- load_credentials()

  if (nrow(credentials) == 0) {
    print_colored("No users to remove", YELLOW)
    return()
  }

  list_users()
  cat("Enter username to remove (or 'cancel'): ")
  username <- trimws(readLines(con = "stdin", n = 1))

  if (username == "cancel" || username == "") {
    print_colored("Cancelled", YELLOW)
    return()
  }

  if (!username %in% credentials$user) {
    print_colored("✗ User not found", RED)
    return()
  }

  # Confirm removal
  cat(sprintf("Are you sure you want to remove user '%s'? (yes/no): ", username))
  confirm <- tolower(trimws(readLines(con = "stdin", n = 1)))

  if (confirm != "yes") {
    print_colored("Cancelled", YELLOW)
    return()
  }

  # Remove user
  credentials <- credentials[credentials$user != username, ]
  save_credentials(credentials)

  print_colored(sprintf("✓ User '%s' removed", username), GREEN)
}

# Change password
change_password <- function() {
  credentials <- load_credentials()

  if (nrow(credentials) == 0) {
    print_colored("No users found", YELLOW)
    return()
  }

  list_users()
  cat("Enter username: ")
  username <- trimws(readLines(con = "stdin", n = 1))

  if (!username %in% credentials$user) {
    print_colored("✗ User not found", RED)
    return()
  }

  # Get new password
  cat("New password (min 8 characters): ")
  password <- trimws(readLines(con = "stdin", n = 1))

  if (nchar(password) < 8) {
    print_colored("✗ Password must be at least 8 characters", RED)
    return()
  }

  # Confirm password
  cat("Confirm password: ")
  password_confirm <- trimws(readLines(con = "stdin", n = 1))

  if (password != password_confirm) {
    print_colored("✗ Passwords do not match", RED)
    return()
  }

  # Hash password
  print_colored("Hashing password...", YELLOW)
  password_hash <- bcrypt::hashpw(password)

  # Update password
  credentials$password[credentials$user == username] <- password_hash
  save_credentials(credentials)

  print_colored(sprintf("✓ Password updated for '%s'", username), GREEN)
}

# Extend expiration date
extend_expiration <- function() {
  credentials <- load_credentials()

  if (nrow(credentials) == 0) {
    print_colored("No users found", YELLOW)
    return()
  }

  list_users()
  cat("Enter username: ")
  username <- trimws(readLines(con = "stdin", n = 1))

  if (!username %in% credentials$user) {
    print_colored("✗ User not found", RED)
    return()
  }

  cat("New expiration date (YYYY-MM-DD): ")
  expire_input <- trimws(readLines(con = "stdin", n = 1))

  expire_date <- tryCatch(
    as.Date(expire_input),
    error = function(e) {
      print_colored("✗ Invalid date format", RED)
      return(NULL)
    }
  )

  if (is.null(expire_date)) return()

  # Update expiration
  credentials$expire[credentials$user == username] <- expire_date
  save_credentials(credentials)

  print_colored(sprintf("✓ Expiration updated for '%s' to %s", username, expire_date), GREEN)
}

# Main menu
show_menu <- function() {
  print_colored("\n=== American Authorship Database - User Management ===", BLUE)
  cat("\n")
  cat("1. List all users\n")
  cat("2. Add new user\n")
  cat("3. Remove user\n")
  cat("4. Change password\n")
  cat("5. Extend expiration date\n")
  cat("6. Exit\n")
  cat("\n")
  cat("Choice: ")
}

# Main loop
main <- function() {
  print_colored("American Authorship Database - User Management Tool", BLUE)
  print_colored(sprintf("Credentials file: %s", CREDENTIALS_FILE), YELLOW)

  repeat {
    show_menu()
    choice <- trimws(readLines(con = "stdin", n = 1))

    switch(choice,
      "1" = list_users(),
      "2" = add_user(),
      "3" = remove_user(),
      "4" = change_password(),
      "5" = extend_expiration(),
      "6" = {
        print_colored("Goodbye!", GREEN)
        break
      },
      print_colored("✗ Invalid choice", RED)
    )
  }
}

# Run if executed directly
if (!interactive()) {
  main()
} else {
  cat("User management functions loaded. Run main() to start interactive menu.\n")
}
