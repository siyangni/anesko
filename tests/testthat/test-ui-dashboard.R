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

test_that("Dashboard navigation syncs ?tab= in the URL", {
  skip_if_not_installed("shinytest2")

  app <- shinytest2::AppDriver$new(
    app_dir = "../../shiny-app",
    name = "dashboard-navigation"
  )

  app$wait_for_idle()

  # Sidebar navigation should update the query string for deep links / Back
  app$set_inputs(main_menu = "sales_trends")
  app$wait_for_idle()
  expect_true(grepl("[?&]tab=sales_trends", app$get_url()))

  app$set_inputs(main_menu = "books")
  app$wait_for_idle()
  expect_true(grepl("[?&]tab=books", app$get_url()))

  # Return via sidebar (simulates in-app path; browser Back uses same URL sync)
  app$set_inputs(main_menu = "dashboard")
  app$wait_for_idle()
  expect_true(grepl("[?&]tab=dashboard", app$get_url()))
})

test_that("Deep link style tab selection updates URL and menu state", {
  skip_if_not_installed("shinytest2")

  app <- shinytest2::AppDriver$new(
    app_dir = "../../shiny-app",
    name = "dashboard-deeplink"
  )

  app$wait_for_idle()
  app$set_inputs(main_menu = "about")
  app$wait_for_idle()
  expect_true(grepl("[?&]tab=about", app$get_url()))
  expect_equal(app$get_value(input = "main_menu"), "about")
})
