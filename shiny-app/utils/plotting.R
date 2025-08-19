# Plotting Utility Functions
# Functions for creating consistent, interactive plots throughout the app

# Custom ggplot theme for the app
theme_authorship <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(size = base_size + 2, face = "bold", hjust = 0.5),
      plot.subtitle = element_text(size = base_size, color = "gray60", hjust = 0.5),
      plot.caption = element_text(size = base_size - 2, color = "gray50"),
      strip.text = element_text(face = "bold"),
      legend.title = element_text(face = "bold"),
      axis.title = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "gray90", size = 0.3)
    )
}

# Create time series plot
create_timeseries_plot <- function(data, x_col, y_col, group_col = NULL, 
                                  title = "Time Series", subtitle = NULL) {
  
  if (nrow(data) == 0) {
    return(ggplot() + 
           theme_void() + 
           geom_text(aes(x = 0.5, y = 0.5, label = "No data available"), 
                    size = 6, color = "gray60"))
  }
  
  p <- ggplot(data, aes(x = .data[[x_col]], y = .data[[y_col]]))
  
  if (!is.null(group_col) && group_col %in% names(data)) {
    p <- p + 
      geom_line(aes(color = .data[[group_col]], group = .data[[group_col]]),
                size = 1, alpha = 0.85) +
      geom_point(aes(color = .data[[group_col]]), size = 2) +
      scale_color_manual(values = AMBIENT_COLORS, name = str_to_title(group_col))
  } else {
    p <- p + 
      geom_line(color = "#2a4365", size = 1.2) +
      geom_point(color = "#1e3a5f", size = 2.5)
  }
  
  p <- p +
    labs(title = title, subtitle = subtitle, 
         x = str_to_title(x_col), y = str_to_title(gsub("_", " ", y_col))) +
    theme_authorship() +
    theme(legend.position = "bottom")
  
  # Format y-axis based on values
  max_val <- max(data[[y_col]], na.rm = TRUE)
  if (max_val > 1000) {
    p <- p + scale_y_continuous(labels = scales::comma_format())
  }
  
  ggplotly(p, tooltip = c("x", "y", "colour")) %>%
    layout(showlegend = !is.null(group_col))
}

# Create bar plot
create_bar_plot <- function(data, x_col, y_col, fill_col = NULL, 
                           title = "Bar Chart", orientation = "vertical") {
  
  if (nrow(data) == 0) {
    return(ggplot() + theme_void() + 
           geom_text(aes(x = 0.5, y = 0.5, label = "No data available"), 
                    size = 6, color = "gray60"))
  }
  
  # Limit to top 15 categories for readability
  if (nrow(data) > 15) {
    data <- data %>%
      arrange(desc(.data[[y_col]])) %>%
      slice_head(n = 15)
  }
  
  p <- ggplot(data, aes(x = reorder(.data[[x_col]], .data[[y_col]]), 
                       y = .data[[y_col]]))
  
  if (!is.null(fill_col) && fill_col %in% names(data)) {
    p <- p + geom_col(aes(fill = .data[[fill_col]]), alpha = 0.9) +
      scale_fill_manual(values = AMBIENT_COLORS)
  } else {
    p <- p + geom_col(fill = "#2a4365", alpha = 0.9)
  }
  
  p <- p +
    labs(title = title,
         x = stringr::str_to_title(gsub("_", " ", x_col)),
         y = stringr::str_to_title(gsub("_", " ", y_col))) +
    theme_authorship()
  
  if (orientation == "horizontal") {
    p <- p + coord_flip()
  }
  
  # Format y-axis
  max_val <- max(data[[y_col]], na.rm = TRUE)
  if (max_val > 1000) {
    p <- p + scale_y_continuous(labels = scales::comma_format())
  }
  
  ggplotly(p, tooltip = c("x", "y"))
}

# Create scatter plot
create_scatter_plot <- function(data, x_col, y_col, color_col = NULL, size_col = NULL,
                               title = "Scatter Plot") {
  
  if (nrow(data) == 0) {
    return(ggplot() + theme_void() + 
           geom_text(aes(x = 0.5, y = 0.5, label = "No data available"), 
                    size = 6, color = "gray60"))
  }
  
  p <- ggplot(data, aes(x = .data[[x_col]], y = .data[[y_col]]))
  
  # Base aesthetics
  aes_list <- list(x = as.name(x_col), y = as.name(y_col))
  
  if (!is.null(color_col) && color_col %in% names(data)) {
    aes_list$color <- as.name(color_col)
  }
  
  if (!is.null(size_col) && size_col %in% names(data)) {
    aes_list$size <- as.name(size_col)
    p <- p + geom_point(do.call(aes, aes_list), alpha = 0.7) +
      scale_size_continuous(range = c(1, 8))
  } else {
    p <- p + geom_point(do.call(aes, aes_list), size = 3, alpha = 0.7)
  }
  
  if (!is.null(color_col) && color_col %in% names(data)) {
    if (color_col == "gender") {
      p <- p + scale_color_manual(values = AMBIENT_COLORS)
    } else if (color_col == "genre") {
      p <- p + scale_color_manual(values = AMBIENT_COLORS)
    }
  }
  
  p <- p +
    labs(title = title,
         x = str_to_title(gsub("_", " ", x_col)),
         y = str_to_title(gsub("_", " ", y_col))) +
    theme_authorship()
  
  # Add trend line if numeric
  if (is.numeric(data[[x_col]]) && is.numeric(data[[y_col]])) {
    p <- p + geom_smooth(method = "lm", se = TRUE, alpha = 0.2, color = "#e74c3c")
  }
  
  ggplotly(p, tooltip = c("x", "y", "colour", "size"))
}

# Create histogram
create_histogram <- function(data, x_col, fill_col = NULL, bins = 30, 
                           title = "Distribution") {
  
  if (nrow(data) == 0 || !x_col %in% names(data)) {
    return(ggplot() + theme_void() + 
           geom_text(aes(x = 0.5, y = 0.5, label = "No data available"), 
                    size = 6, color = "gray60"))
  }
  
  # Remove NA values
  plot_data <- data %>% filter(!is.na(.data[[x_col]]))
  
  if (nrow(plot_data) == 0) {
    return(ggplot() + theme_void() + 
           geom_text(aes(x = 0.5, y = 0.5, label = "No valid data"), 
                    size = 6, color = "gray60"))
  }
  
  p <- ggplot(plot_data, aes(x = .data[[x_col]]))
  
  if (!is.null(fill_col) && fill_col %in% names(plot_data)) {
    p <- p + 
      geom_histogram(aes(fill = .data[[fill_col]]), bins = bins, alpha = 0.8, 
                    position = "stack") +
      scale_fill_manual(values = GENRE_COLORS)
  } else {
    p <- p + geom_histogram(fill = "#3498db", bins = bins, alpha = 0.8, color = "white")
  }
  
  p <- p +
    labs(title = title, 
         x = str_to_title(gsub("_", " ", x_col)), 
         y = "Count") +
    theme_authorship()
  
  ggplotly(p, tooltip = c("x", "y"))
}

# Create box plot
create_box_plot <- function(data, x_col, y_col, title = "Box Plot") {
  
  if (nrow(data) == 0) {
    return(ggplot() + theme_void() + 
           geom_text(aes(x = 0.5, y = 0.5, label = "No data available"), 
                    size = 6, color = "gray60"))
  }
  
  p <- ggplot(data, aes(x = .data[[x_col]], y = .data[[y_col]])) +
    geom_boxplot(fill = "#3498db", alpha = 0.7, color = "#2980b9") +
    geom_jitter(width = 0.2, alpha = 0.5, color = "#34495e") +
    labs(title = title,
         x = str_to_title(gsub("_", " ", x_col)),
         y = str_to_title(gsub("_", " ", y_col))) +
    theme_authorship() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  ggplotly(p, tooltip = c("x", "y"))
}

# Create heatmap for correlation matrix
create_correlation_heatmap <- function(cor_matrix, title = "Correlation Matrix") {
  
  if (is.null(cor_matrix) || nrow(cor_matrix) < 2) {
    return(ggplot() + theme_void() + 
           geom_text(aes(x = 0.5, y = 0.5, label = "Insufficient data"), 
                    size = 6, color = "gray60"))
  }
  
  # Convert to long format
  cor_data <- cor_matrix %>%
    as.data.frame() %>%
    rownames_to_column("var1") %>%
    pivot_longer(-var1, names_to = "var2", values_to = "correlation")
  
  p <- ggplot(cor_data, aes(x = var1, y = var2, fill = correlation)) +
    geom_tile(color = "white") +
    scale_fill_gradient2(low = "#e74c3c", high = "#3498db", mid = "white", 
                        midpoint = 0, limit = c(-1, 1), space = "Lab",
                        name = "Correlation") +
    labs(title = title, x = "", y = "") +
    theme_authorship() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1),
          axis.text.y = element_text(hjust = 1)) +
    coord_fixed()
  
  ggplotly(p, tooltip = c("x", "y", "fill"))
}

# Create pie chart for categorical data
create_pie_chart <- function(data, category_col, value_col, title = "Distribution") {

  if (nrow(data) == 0) {
    return(ggplot() + theme_void() +
           geom_text(aes(x = 0.5, y = 0.5, label = "No data available"),
                    size = 6, color = "gray60"))
  }

  # Prepare data
  plot_data <- data %>%
    arrange(desc(.data[[value_col]])) %>%
    mutate(
      percentage = .data[[value_col]] / sum(.data[[value_col]]) * 100,
      label = paste0(.data[[category_col]], "\n",
                    round(percentage, 1), "%")
    )

  # Use plotly for interactive pie chart with ambient colors
  ambient_palette <- if (exists("PIE_COLORS")) PIE_COLORS else
    c("#2a4365", "#0f766e", "#6d28d9", "#9a3412", "#166534", "#374151", "#2563eb", "#7c3aed")
  ambient_cols <- rep_len(ambient_palette, nrow(plot_data))

  plot_ly(plot_data,
          labels = ~get(category_col),
          values = ~get(value_col),
          type = 'pie',
          textinfo = 'label+percent',
          marker = list(colors = ambient_cols)) %>%
    layout(title = title,
           showlegend = FALSE)
}

# Create empty plotly plot with message
plotly_empty <- function(message = "No data available") {
  plot_ly() %>%
    add_annotations(
      x = 0.5,
      y = 0.5,
      text = message,
      xref = "paper",
      yref = "paper",
      xanchor = "center",
      yanchor = "middle",
      showarrow = FALSE,
      font = list(size = 16, color = "gray60")
    ) %>%
    layout(
      xaxis = list(showgrid = FALSE, showticklabels = FALSE, zeroline = FALSE),
      yaxis = list(showgrid = FALSE, showticklabels = FALSE, zeroline = FALSE),
      plot_bgcolor = "rgba(0,0,0,0)",
      paper_bgcolor = "rgba(0,0,0,0)"
    )
}

# Create summary statistics table
create_summary_table <- function(data, title = "Summary Statistics") {
  
  if (nrow(data) == 0) {
    return(DT::datatable(data.frame(Message = "No data available"), 
                        options = list(dom = 't')))
  }
  
  # Select numeric columns
  numeric_data <- data %>% select_if(is.numeric)
  
  if (ncol(numeric_data) == 0) {
    return(DT::datatable(data.frame(Message = "No numeric data available"), 
                        options = list(dom = 't')))
  }
  
  # Calculate summary statistics
  summary_stats <- numeric_data %>%
    summarise_all(list(
      Count = ~sum(!is.na(.)),
      Mean = ~round(mean(., na.rm = TRUE), 2),
      Median = ~round(median(., na.rm = TRUE), 2),
      SD = ~round(sd(., na.rm = TRUE), 2),
      Min = ~round(min(., na.rm = TRUE), 2),
      Max = ~round(max(., na.rm = TRUE), 2)
    )) %>%
    pivot_longer(everything(), names_to = "Variable_Stat", values_to = "Value") %>%
    separate(Variable_Stat, into = c("Variable", "Statistic"), sep = "_") %>%
    pivot_wider(names_from = Statistic, values_from = Value)
  
  DT::datatable(summary_stats, 
                caption = title,
                options = list(
                  pageLength = 15,
                  scrollX = TRUE,
                  dom = 'Bfrtip',
                  buttons = c('copy', 'csv', 'excel')
                )) %>%
    DT::formatRound(columns = c("Mean", "Median", "SD", "Min", "Max"), digits = 2)
} 