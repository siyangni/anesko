# UI Tests for Dashboard Module
# These tests verify that the dashboard loads correctly and displays data

# NOTE: shinytest2 requires a running Shiny app
# Run these tests with: testthat::test_file("tests/testthat/test-ui-dashboard.R")

test_that("Dashboard loads without errors", {
  skip_if_not_installed("shinytest2")

  # Create app object
  app <- shinytest2::AppDriver$new(
    app_dir = "../../shiny-app",
    name = "dashboard-load",
    height = 800,
    width = 1200
  )

  # Wait for app to load
  app$wait_for_idle(duration = 5000)

  # Check that no errors are displayed
  expect_false(grepl("error", tolower(app$get_text("body"))))

  # Check that value boxes are present
  expect_true(app$get_value("dashboard_module-value_boxes") != "")

  # Take screenshot for visual regression testing
  app$expect_screenshot(name = "dashboard-loaded")
})

test_that("Dashboard displays summary statistics", {
  skip_if_not_installed("shinytest2")

  app <- shinytest2::AppDriver$new(
    app_dir = "../../shiny-app",
    name = "dashboard-stats"
  )

  app$wait_for_idle()

  # Check that value boxes contain numbers
  value_boxes_html <- app$get_html("dashboard_module-value_boxes")

  # Should contain formatted numbers (with K or M suffix)
  expect_true(grepl("[0-9]+(\\.?[0-9]*)?[KM]?", value_boxes_html))
})

test_that("Dashboard navigation works", {
  skip_if_not_installed("shinytest2")

  app <- shinytest2::AppDriver$new(
    app_dir = "../../shiny-app",
    name = "dashboard-navigation"
  )

  app$wait_for_idle()

  # Click on "Sales Trends" menu item
  app$click("main_menu")
  app$set_inputs(main_menu = "sales_trends")
  app$wait_for_idle()

  # Check that Sales Trends module is displayed
  expect_true(grepl("sales_trends", tolower(app$get_url())))

  # Navigate back to dashboard
  app$set_inputs(main_menu = "dashboard")
  app$wait_for_idle()

  # Check we're back on dashboard
  expect_true(grepl("dashboard", tolower(app$get_url())))
})
