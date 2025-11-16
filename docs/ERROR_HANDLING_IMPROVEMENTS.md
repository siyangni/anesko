# Error Handling Improvements - Book Comparison Feature

**Date**: November 16, 2025  
**Modified Files**: 
- `shiny-app/modules/book_explorer_module.R`
- `shiny-app/modules/genre_content_analysis_module.R`

## Problem

The book comparison feature was experiencing data dimension mismatch errors when comparing titles with missing or incomplete data:

```
Error: replacement has 1 row, data has 0
```

This error occurred when:
1. One book had sales data but the other didn't
2. Attempting to add a "selection" column to an empty dataframe
3. Using `rbind()` on dataframes with different structures

## Solution

Implemented robust error handling with the following improvements:

### 1. **Consistent Data Frame Structure**

Modified the aggregation helper function to always return a consistent structure:

```r
agg <- function(df, title) {
  if (is.null(df) || nrow(df) == 0) {
    return(data.frame(
      book_title = character(0),
      binding = character(0),
      total_sales = numeric(0),
      selection = character(0),
      stringsAsFactors = FALSE
    ))
  }
  result <- aggregate(total_sales ~ book_title + binding, df, sum)
  result$selection <- title
  return(result)
}
```

**Benefits**:
- Empty dataframes have the same column structure as populated ones
- Prevents dimension mismatch errors
- Selection column added within the function, not after

### 2. **Safe Data Combination Logic**

Replaced unsafe `rbind()` with conditional logic:

```r
# Check for data availability
has_a <- nrow(a) > 0
has_b <- nrow(b) > 0

# Safely combine results
tryCatch({
  if (has_a && has_b) {
    out <- rbind(a, b)
  } else if (has_a) {
    out <- a
  } else {
    out <- b
  }
  return(out)
}, error = function(e) {
  showNotification(
    paste("Error combining comparison results:", e$message),
    type = "error",
    duration = 10
  )
  return(data.frame())
})
```

**Benefits**:
- Handles cases where only one book has data
- Provides meaningful results even with partial data
- Wraps in `tryCatch` for additional safety

### 3. **Informative User Notifications**

Enhanced notifications with specific context:

```r
if (!has_a && !has_b) {
  showNotification(
    paste0("No sales data found for either book in the selected year range (", 
           start_year, "-", end_year, ") with ", b, " binding."),
    type = "warning",
    duration = 7
  )
}

if (!has_a) {
  showNotification(
    paste0("No sales data found for '", t1, "' (", b, " binding) in ", 
           start_year, "-", end_year, ". Showing results for '", t2, "' only."),
    type = "message",
    duration = 7
  )
}
```

**Benefits**:
- Users understand exactly what data is missing
- Includes book title, binding type, and year range in message
- Different notification types (warning vs. message) based on severity
- Longer duration (7 seconds) for important messages

### 4. **Enhanced Query Error Messages**

Added specific error context to `safe_query` calls:

```r
res_a <- safe_query(
  function() get_book_sales_by_title_binding(t1, b, start_year, end_year),
  default_value = data.frame(),
  error_message = paste0("Error retrieving data for '", t1, "'")
)
```

**Benefits**:
- Users know which book's data failed to load
- Easier debugging and troubleshooting
- More professional error handling

## Testing Recommendations

To test these improvements:

1. **Both books with no data**:
   - Select two books with no sales in the filtered year range
   - Should see warning: "No sales data found for either book..."

2. **One book with data, one without**:
   - Select one popular book and one obscure book
   - Should see message indicating which book has no data
   - Chart and table should show data for the available book only

3. **Both books with data**:
   - Select two popular books in an active year range
   - Should see normal comparison chart and table

4. **Database connection error**:
   - Simulate database disconnection
   - Should see specific error messages for each book query

## Impact

### Before
- Generic error messages: "Error: replacement has 1 row, data has 0"
- Application crash or blank results
- No indication of which book had issues
- Poor user experience

### After
- Specific, actionable error messages
- Graceful handling of partial data
- Clear indication of data availability
- Application continues to function
- Professional user experience

## Additional Notes

### Related Functions

These improvements leverage the existing `safe_query` function defined in `global.R`:

```r
safe_query <- function(query_func, default_value = NULL, error_message = "Data unavailable") {
  tryCatch({
    query_func()
  }, error = function(e) {
    showNotification(
      paste("Error:", error_message),
      type = "error",
      duration = 5
    )
    return(default_value)
  })
}
```

### Future Improvements

Consider implementing:
1. **Retry logic**: Automatically retry failed queries 2-3 times
2. **Logging**: Log all errors to a file for troubleshooting
3. **Performance monitoring**: Track query execution times
4. **Cache**: Cache frequently accessed comparison data
5. **User preferences**: Remember last successful comparison parameters

### Code Quality

- ✅ No linter errors
- ✅ Follows R style guide
- ✅ Consistent with existing codebase patterns
- ✅ Comprehensive error handling
- ✅ User-friendly notifications

## Known Issues & Fixes

### Issue: "Text to be written must be a length-one character vector"

**Root Cause**: `showNotification()` requires a single character string, but variables from reactive inputs (`input$book_title_1`, `input$binding_filter`, etc.) can sometimes be vectors.

**Solution**: Wrap all variables in notifications with `as.character()[1]` to ensure single-value strings:

```r
# Before (problematic)
showNotification(
  paste0("No data for '", t1, "' with ", b, " binding."),
  type = "warning"
)

# After (fixed)
msg <- paste0(
  "No data for '", as.character(t1)[1], "' with ", 
  as.character(b)[1], " binding."
)
showNotification(msg, type = "warning", duration = 7)
```

**Applied to**:
- All `showNotification()` calls in comparison logic
- Error messages passed to `safe_query()`
- Error handler messages in `tryCatch()` blocks

## References

- **Safe Query Pattern**: `shiny-app/global.R` (lines 209-220)
- **Error Handling Utils**: `shiny-app/utils/error_handling.R`
- **Shiny Notifications**: [shiny::showNotification documentation](https://shiny.rstudio.com/reference/shiny/latest/showNotification.html)

---

**Author**: Claude (AI Assistant)  
**Reviewer**: [Pending]  
**Status**: Implemented (Updated: Nov 16, 2025 - Fixed notification vector issue)

