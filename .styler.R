# Styler Configuration for American Authorship Database
# Defines automated code formatting rules

# Use tidyverse style guide with some modifications
tidyverse_style(
  scope = "line_breaks",
  strict = FALSE,
  indent_by = 2,
  start_comments_with_one_space = FALSE,
  reindention = tidyverse_reindention(),
  math_token_spacing = tidyverse_math_token_spacing()
)
