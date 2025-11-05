# Test script to verify the royalty query module fixes

# Load required libraries
library(shiny)
library(testthat)

# Source the royalty query module
source("shiny-app/modules/royalty_query_module.R")

# Test that the UI function exists and is properly defined
test_that("Royalty query UI function exists", {
  expect_true(exists("royaltyQueryUI"))
  expect_true(is.function(royaltyQueryUI))
})

# Test that the server function exists and is properly defined
test_that("Royalty query server function exists", {
  expect_true(exists("royaltyQueryServer"))
  expect_true(is.function(royaltyQueryServer))
})

cat("All basic tests passed!\n")