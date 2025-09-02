# Author summary statistics
output$author_summary_stats &lt;- renderUI({
  # Only render for author queries
  if (input$query_type != "author") {
    return(NULL)
  }
  
  results &lt;- royalty_results()
  if (is.null(results) || nrow(results) == 0) {
    return(NULL)
  }
  
  # Remove the TOTAL row for calculations
  book_data &lt;- results[results$book_id != "TOTAL", ]
  
  if (nrow(book_data) == 0) {
    return(NULL)
  }
  
  # Calculate statistics
  book_count &lt;- nrow(book_data)
  total_income &lt;- sum(book_data$royalty_income, na.rm = TRUE)
  total_sales &lt;- sum(book_data$total_sales, na.rm = TRUE)
  years &lt;- input$royalty_year_range
  year_count &lt;- years[2] - years[1] + 1
  avg_income_per_book &lt;- ifelse(book_count &gt; 0, total_income / book_count, 0)
  avg_income_per_year &lt;- ifelse(year_count &gt; 0, total_income / year_count, 0)
  
  # Find top earning book
  top_book_info &lt;- "N/A"
  if (book_count &gt; 0) {
    top_book &lt;- book_data[which.max(book_data$royalty_income), ]
    top_book_info &lt;- paste0(
      tags$b(top_book$book_title), " ($", sprintf("%.2f", top_book$royalty_income), ")"
    )
  }
  
  # Create the summary HTML
  tagList(
    tags$div(
      style = "display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px;",
      tags$div(
        style = "text-align: center; padding: 10px; background-color: #f8f9fa; border-radius: 5px;",
        tags$h5("Average per Book", style = "margin-top: 0; color: #495057;"),
        tags$p(paste0("$", sprintf("%.2f", avg_income_per_book)), 
              style = "font-size: 1.2em; font-weight: bold; color: #0d6efd; margin: 5px 0;")
      ),
      tags$div(
        style = "text-align: center; padding: 10px; background-color: #f8f9fa; border-radius: 5px;",
        tags$h5("Average per Year", style = "margin-top: 0; color: #495057;"),
        tags$p(paste0("$", sprintf("%.2f", avg_income_per_year)), 
              style = "font-size: 1.2em; font-weight: bold; color: #0d6efd; margin: 5px 0;")
      ),
      tags$div(
        style = "text-align: center; padding: 10px; background-color: #f8f9fa; border-radius: 5px;",
        tags$h5("Top Earning Book", style = "margin-top: 0; color: #495057;"),
        tags$p(HTML(top_book_info), 
              style = "font-size: 1.1em; font-weight: bold; color: #0d6efd; margin: 5px 0;")
      )
    ),
    tags$hr(style = "margin: 15px 0;"),
    tags$p(
      tags$b("Total Royalty Income:"), 
      paste0(" $", sprintf("%.2f", total_income)),
      " from ", book_count, " book", ifelse(book_count == 1, "", "s"),
      " over ", year_count, " year", ifelse(year_count == 1, "", "s"),
      " (", years[1], "–", years[2], ")",
      style = "font-size: 1.1em;"
    )
  )
})