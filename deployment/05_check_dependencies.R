# Dependency Checker for Shiny Application Deployment
# This script checks and prepares dependencies for shinyapps.io deployment

library(tools)

cat("📦 Checking Dependencies for Shiny Application Deployment\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

# 1. Scan R files for package dependencies
cat("🔍 Scanning R files for package dependencies...\n")

# Get all R files in the shiny-app directory
r_files <- list.files("../shiny-app", pattern = "\\.R$", recursive = TRUE, full.names = TRUE)

# Extract library/require calls
dependencies <- c()
for (file in r_files) {
  content <- readLines(file, warn = FALSE)
  
  # Find library() and require() calls
  lib_calls <- grep("library\\(|require\\(", content, value = TRUE)
  
  for (call in lib_calls) {
    # Extract package name
    pkg_match <- regmatches(call, regexpr("(?<=library\\(|require\\()[^)]+", call, perl = TRUE))
    if (length(pkg_match) > 0) {
      # Clean up the package name
      pkg_name <- gsub("[\"']", "", pkg_match)
      dependencies <- c(dependencies, pkg_name)
    }
  }
}

# Remove duplicates and sort
dependencies <- sort(unique(dependencies))

cat("📋 Found dependencies:\n")
for (dep in dependencies) {
  cat("   -", dep, "\n")
}

# 2. Check if packages are installed and available on CRAN
cat("\n🔍 Checking package availability...\n")

package_status <- data.frame(
  package = character(),
  installed = logical(),
  on_cran = logical(),
  version = character(),
  status = character(),
  stringsAsFactors = FALSE
)

available_packages <- available.packages()

for (pkg in dependencies) {
  # Check if installed
  is_installed <- pkg %in% rownames(installed.packages())
  
  # Check if on CRAN
  on_cran <- pkg %in% rownames(available_packages)
  
  # Get version if installed
  version <- if (is_installed) {
    as.character(packageVersion(pkg))
  } else {
    "Not installed"
  }
  
  # Determine status
  status <- if (is_installed && on_cran) {
    "✅ OK"
  } else if (!is_installed && on_cran) {
    "⚠️  Not installed"
  } else if (is_installed && !on_cran) {
    "⚠️  Not on CRAN"
  } else {
    "❌ Missing"
  }
  
  package_status <- rbind(package_status, data.frame(
    package = pkg,
    installed = is_installed,
    on_cran = on_cran,
    version = version,
    status = status,
    stringsAsFactors = FALSE
  ))
  
  cat("  ", pkg, ":", status, "\n")
}

# 3. Create DESCRIPTION file for shinyapps.io
cat("\n📝 Creating DESCRIPTION file...\n")

description_content <- paste0(
  "Title: American Authorship Database Dashboard\n",
  "Author: American Authorship Project\n",
  "AuthorEmail: your-email@example.com\n",
  "License: MIT\n",
  "DisplayMode: Showcase\n",
  "Tags: literature, publishing, history, data-analysis\n",
  "Type: Shiny\n",
  "\n",
  "Depends:\n",
  paste("    ", dependencies, collapse = ",\n"),
  "\n"
)

writeLines(description_content, "../shiny-app/DESCRIPTION")
cat("✅ Created DESCRIPTION file\n")

# 4. Check for potential deployment issues
cat("\n🔍 Checking for potential deployment issues...\n")

issues <- c()

# Check file sizes
cat("  Checking file sizes...\n")
all_files <- list.files("../shiny-app", recursive = TRUE, full.names = TRUE)
large_files <- c()

for (file in all_files) {
  if (file.exists(file) && !file.info(file)$isdir) {
    size_mb <- file.info(file)$size / (1024 * 1024)
    if (size_mb > 10) {  # Files larger than 10MB
      large_files <- c(large_files, paste(file, "-", round(size_mb, 2), "MB"))
    }
  }
}

if (length(large_files) > 0) {
  issues <- c(issues, "Large files detected:")
  issues <- c(issues, large_files)
}

# Check for data files that might be too large
cat("  Checking for data files...\n")
data_files <- list.files("../shiny-app", pattern = "\\.(csv|xlsx|rds|rda)$", recursive = TRUE, full.names = TRUE)
if (length(data_files) > 0) {
  issues <- c(issues, "Data files found (consider using database instead):")
  issues <- c(issues, data_files)
}

# Check for absolute paths
cat("  Checking for absolute paths...\n")
for (file in r_files) {
  content <- readLines(file, warn = FALSE)
  abs_paths <- grep("^[/~]|^[A-Za-z]:", content, value = TRUE)
  if (length(abs_paths) > 0) {
    issues <- c(issues, paste("Absolute paths in", file))
  }
}

# 5. Create .gitignore for sensitive files
cat("\n📝 Creating .gitignore...\n")
gitignore_content <- '# Sensitive files
.env
*.log

# R specific
.Rhistory
.RData
.Ruserdata
*.Rproj

# Deployment
rsconnect/

# Database exports
database_export/
*.sql

# Temporary files
*.tmp
*.temp
'

writeLines(gitignore_content, "../shiny-app/.gitignore")
cat("✅ Created .gitignore\n")

# 6. Test package loading
cat("\n🧪 Testing package loading...\n")
loading_issues <- c()

for (pkg in dependencies) {
  tryCatch({
    library(pkg, character.only = TRUE)
    cat("  ✅", pkg, "loaded successfully\n")
  }, error = function(e) {
    loading_issues <- c(loading_issues, paste(pkg, "-", e$message))
    cat("  ❌", pkg, "failed to load:", e$message, "\n")
  })
}

# Summary
cat("\n📊 Dependency Check Summary\n")
cat(paste(rep("-", 40), collapse = ""), "\n")

total_packages <- nrow(package_status)
ok_packages <- sum(package_status$status == "✅ OK")
warning_packages <- sum(grepl("⚠️", package_status$status))
error_packages <- sum(package_status$status == "❌ Missing")

cat("Total packages:", total_packages, "\n")
cat("Ready for deployment:", ok_packages, "\n")
cat("Warnings:", warning_packages, "\n")
cat("Errors:", error_packages, "\n")

if (length(issues) > 0) {
  cat("\n⚠️  Potential issues:\n")
  for (issue in issues) {
    cat("   ", issue, "\n")
  }
}

if (length(loading_issues) > 0) {
  cat("\n❌ Package loading issues:\n")
  for (issue in loading_issues) {
    cat("   ", issue, "\n")
  }
}

# Recommendations
cat("\n💡 Recommendations:\n")

if (error_packages > 0) {
  cat("   1. Install missing packages:\n")
  missing_pkgs <- package_status$package[package_status$status == "❌ Missing"]
  cat("      install.packages(c(", paste0('"', missing_pkgs, '"', collapse = ", "), "))\n")
}

if (warning_packages > 0) {
  cat("   2. Review packages with warnings - they may cause deployment issues\n")
}

if (length(large_files) > 0) {
  cat("   3. Consider reducing file sizes or moving large files to external storage\n")
}

if (length(data_files) > 0) {
  cat("   4. Consider removing local data files since you're using a database\n")
}

# Final assessment
if (ok_packages == total_packages && length(loading_issues) == 0 && length(issues) == 0) {
  cat("\n🎉 ✅ Dependency check PASSED!\n")
  cat("Your application appears ready for deployment.\n")
  cat("\n💡 Next step: Run 06_deploy_to_shinyapps.R\n")
} else {
  cat("\n⚠️  Dependency check found issues.\n")
  cat("Please address the issues above before deploying.\n")
  
  if (error_packages > 0 || length(loading_issues) > 0) {
    cat("\n🔧 Critical issues that must be fixed:\n")
    cat("   - Missing or non-loading packages\n")
  }
  
  if (warning_packages > 0 || length(issues) > 0) {
    cat("\n🔧 Issues that should be reviewed:\n")
    cat("   - Package warnings or deployment concerns\n")
  }
}

# Save detailed report
cat("\n📄 Saving detailed dependency report...\n")
report_content <- c(
  "# Dependency Check Report",
  paste("Generated:", Sys.time()),
  "",
  "## Package Status",
  ""
)

for (i in 1:nrow(package_status)) {
  row <- package_status[i, ]
  report_content <- c(report_content, paste0(
    "- **", row$package, "**: ", row$status, 
    " (Version: ", row$version, ")"
  ))
}

if (length(issues) > 0) {
  report_content <- c(report_content, "", "## Issues Found", "")
  report_content <- c(report_content, paste("-", issues))
}

if (length(loading_issues) > 0) {
  report_content <- c(report_content, "", "## Loading Issues", "")
  report_content <- c(report_content, paste("-", loading_issues))
}

writeLines(report_content, "dependency_report.md")
cat("✅ Saved dependency_report.md\n")
