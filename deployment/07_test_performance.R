# Performance Testing Script for Deployed Application
# This script tests the performance of the deployed Shiny application

library(httr)
library(jsonlite)

cat("⚡ Performance Testing for American Authorship Dashboard\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

# Configuration
app_url <- Sys.getenv("APP_URL", "https://your-account.shinyapps.io/american-authorship-dashboard/")

if (app_url == "https://your-account.shinyapps.io/american-authorship-dashboard/") {
  cat("❌ Please set APP_URL environment variable with your actual app URL\n")
  cat("   Example: export APP_URL=https://youraccount.shinyapps.io/american-authorship-dashboard/\n")
  stop("APP_URL required")
}

cat("🌐 Testing app at:", app_url, "\n")

# Test 1: Basic Connectivity
cat("\n🔍 Test 1: Basic Connectivity\n")
start_time <- Sys.time()

tryCatch({
  response <- GET(app_url, timeout(30))
  end_time <- Sys.time()
  response_time <- as.numeric(end_time - start_time, units = "secs")
  
  if (status_code(response) == 200) {
    cat("✅ App is accessible\n")
    cat("⏱️  Response time:", round(response_time, 2), "seconds\n")
    
    # Check if it's actually a Shiny app
    content <- content(response, "text")
    if (grepl("shiny", content, ignore.case = TRUE)) {
      cat("✅ Shiny application detected\n")
    } else {
      cat("⚠️  Response doesn't appear to be a Shiny app\n")
    }
  } else {
    cat("❌ App not accessible - Status code:", status_code(response), "\n")
  }
  
}, error = function(e) {
  cat("❌ Connection failed:", e$message, "\n")
})

# Test 2: Load Testing (Simple)
cat("\n🔍 Test 2: Load Testing (Multiple Requests)\n")

n_requests <- 5
response_times <- numeric(n_requests)

cat("Making", n_requests, "requests...\n")

for (i in 1:n_requests) {
  start_time <- Sys.time()
  
  tryCatch({
    response <- GET(app_url, timeout(30))
    end_time <- Sys.time()
    response_times[i] <- as.numeric(end_time - start_time, units = "secs")
    
    cat("  Request", i, ":", round(response_times[i], 2), "seconds\n")
    
    # Small delay between requests
    Sys.sleep(1)
    
  }, error = function(e) {
    cat("  Request", i, ": Failed -", e$message, "\n")
    response_times[i] <- NA
  })
}

# Calculate statistics
valid_times <- response_times[!is.na(response_times)]
if (length(valid_times) > 0) {
  cat("\n📊 Load Test Results:\n")
  cat("   Successful requests:", length(valid_times), "of", n_requests, "\n")
  cat("   Average response time:", round(mean(valid_times), 2), "seconds\n")
  cat("   Min response time:", round(min(valid_times), 2), "seconds\n")
  cat("   Max response time:", round(max(valid_times), 2), "seconds\n")
  
  if (mean(valid_times) < 5) {
    cat("✅ Response times are acceptable\n")
  } else if (mean(valid_times) < 10) {
    cat("⚠️  Response times are slow but acceptable\n")
  } else {
    cat("❌ Response times are too slow\n")
  }
} else {
  cat("❌ No successful requests\n")
}

# Test 3: Database Connection Test (if API endpoints available)
cat("\n🔍 Test 3: Application Health Check\n")

# Since we can't directly test database connections from outside,
# we'll check if the app loads without errors by looking for error indicators
tryCatch({
  response <- GET(app_url, timeout(30))
  content <- content(response, "text")
  
  # Check for common error indicators
  error_indicators <- c(
    "error", "Error", "ERROR",
    "disconnected", "connection failed",
    "500", "503", "502"
  )
  
  errors_found <- sapply(error_indicators, function(x) grepl(x, content, ignore.case = TRUE))
  
  if (any(errors_found)) {
    cat("⚠️  Potential errors detected in app response\n")
    cat("   Error indicators found:", paste(names(errors_found)[errors_found], collapse = ", "), "\n")
  } else {
    cat("✅ No obvious errors detected in app response\n")
  }
  
  # Check for Shiny-specific elements
  shiny_elements <- c(
    "shiny-", "dashboard", "tabPanel", "plotOutput"
  )
  
  elements_found <- sapply(shiny_elements, function(x) grepl(x, content, ignore.case = TRUE))
  
  if (any(elements_found)) {
    cat("✅ Shiny UI elements detected\n")
  } else {
    cat("⚠️  Shiny UI elements not clearly detected\n")
  }
  
}, error = function(e) {
  cat("❌ Health check failed:", e$message, "\n")
})

# Test 4: Resource Usage Estimation
cat("\n🔍 Test 4: Resource Usage Estimation\n")

tryCatch({
  response <- GET(app_url, timeout(30))
  
  # Check response size
  response_size <- length(content(response, "raw"))
  response_size_kb <- round(response_size / 1024, 2)
  
  cat("📦 Response size:", response_size_kb, "KB\n")
  
  if (response_size_kb < 500) {
    cat("✅ Response size is reasonable\n")
  } else if (response_size_kb < 1000) {
    cat("⚠️  Response size is large but acceptable\n")
  } else {
    cat("❌ Response size is very large\n")
  }
  
  # Check headers for caching info
  headers <- headers(response)
  if ("cache-control" %in% names(headers)) {
    cat("📋 Cache control:", headers[["cache-control"]], "\n")
  }
  
}, error = function(e) {
  cat("❌ Resource usage test failed:", e$message, "\n")
})

# Test 5: Recommendations
cat("\n💡 Performance Recommendations\n")
cat(paste(rep("-", 40), collapse = ""), "\n")

recommendations <- c()

if (length(valid_times) > 0) {
  avg_time <- mean(valid_times)
  
  if (avg_time > 10) {
    recommendations <- c(recommendations, 
      "Consider optimizing database queries",
      "Review data processing efficiency",
      "Consider caching frequently accessed data"
    )
  }
  
  if (avg_time > 5) {
    recommendations <- c(recommendations,
      "Monitor application during peak usage",
      "Consider upgrading shinyapps.io plan if needed"
    )
  }
}

# General recommendations
recommendations <- c(recommendations,
  "Set up monitoring alerts in shinyapps.io",
  "Regularly check application logs",
  "Monitor database performance in NeonDB",
  "Consider implementing user analytics"
)

if (length(recommendations) > 0) {
  for (i in seq_along(recommendations)) {
    cat("   ", i, ".", recommendations[i], "\n")
  }
} else {
  cat("✅ No specific recommendations - performance looks good!\n")
}

# Test Summary
cat("\n📊 Performance Test Summary\n")
cat(paste(rep("=", 40), collapse = ""), "\n")

summary_items <- list(
  "App URL" = app_url,
  "Test Date" = as.character(Sys.time()),
  "Connectivity" = if (exists("response") && status_code(response) == 200) "✅ OK" else "❌ Failed",
  "Average Response Time" = if (length(valid_times) > 0) paste(round(mean(valid_times), 2), "seconds") else "N/A",
  "Successful Requests" = if (length(valid_times) > 0) paste(length(valid_times), "of", n_requests) else "0",
  "Overall Status" = if (length(valid_times) > 0 && mean(valid_times) < 10) "✅ Good" else "⚠️  Needs attention"
)

for (name in names(summary_items)) {
  cat(sprintf("%-20s: %s\n", name, summary_items[[name]]))
}

# Save performance report
cat("\n📄 Saving performance report...\n")

performance_report <- list(
  test_date = Sys.time(),
  app_url = app_url,
  connectivity_test = list(
    status = if (exists("response")) status_code(response) else "failed",
    accessible = exists("response") && status_code(response) == 200
  ),
  load_test = list(
    total_requests = n_requests,
    successful_requests = length(valid_times),
    response_times = valid_times,
    average_response_time = if (length(valid_times) > 0) mean(valid_times) else NA,
    min_response_time = if (length(valid_times) > 0) min(valid_times) else NA,
    max_response_time = if (length(valid_times) > 0) max(valid_times) else NA
  ),
  recommendations = recommendations
)

jsonlite::write_json(performance_report, "performance_report.json", pretty = TRUE)
cat("✅ Saved performance_report.json\n")

cat("\n🎉 Performance testing completed!\n")

if (length(valid_times) > 0 && mean(valid_times) < 10) {
  cat("✅ Overall performance looks good!\n")
} else {
  cat("⚠️  Performance issues detected - review recommendations above\n")
}
