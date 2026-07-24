# Data Dictionary - American Authorship Database

## Overview
This document describes the structure and contents of the American Authorship Database.

## Tables

### authors
- `author_id`: Unique identifier for each author
- `surname`: Author's last name
- `gender`: M (Male) or F (Female)

### books / `book_entries`
- `book_id`: Unique book identifier (format: AuthorInitials + Year + Sequence)
- `title` / `book_title`: Complete book title
- `publication_year`: **Publication year** — when the book was published (catalog/metadata). Used for book explorer lists, author career overview, author networks, and royalty-tier book selection.
- `genre_code` / `genre`: Genre classification
- `binding`: Binding state (e.g. Cloth, Paper)
- `retail_price`: Original retail price in dollars

### annual_sales / `book_sales`
- `book_id`: Links to book_entries
- `year`: **Sales year** — calendar year when copies were sold. Used for sales trends, genre/gender sales aggregations, royalty income windows, and title sales comparisons.
- `sales_count` / `copies_sold`: Number of copies sold in that year

### Year concepts (do not mix)
| Concept | Column | Typical UI label |
|---------|--------|------------------|
| Publication year | `book_entries.publication_year` | Publication Year Range |
| Sales year | `book_sales.year` | Sales Year Range |

**Publication filter bounds:** UI min/max = observed `MIN/MAX(publication_year)` from `book_entries`, plus `PUBLICATION_YEAR_BUFFER` years (default 5) on each side. Default selected range is the full observed span. This keeps all catalog years selectable and leaves headroom for newly imported books without redeploying hardcoded 1860–1920 limits.

**Sales filter bounds:** UI min/max = observed `MIN/MAX(year)` from `book_sales`, plus `SALES_YEAR_BUFFER` years (default 2) on each side. Initialized at app startup as `SALES_YEAR_BOUNDS` (see `refresh_sales_year_bounds()`). Modules must use the shared helpers rather than hardcoding 1860–1920:

| Helper | Purpose |
|--------|---------|
| `sales_slider_min()` / `sales_slider_max()` | Selectable min/max for sliders and date inputs |
| `sales_default_range()` | Full observed sales span (period analysis defaults) |
| `sales_preset_range()` | `DEFAULT_YEAR_RANGE` (1880–1910) clamped to available bounds (trends / royalty query / book comparisons) |
| `sales_date_range_args()` | Ready-made `dateRangeInput` start/end/min/max |

**Shared filter options:** Genre, binding, publisher, and gender dropdowns should be populated via `get_filter_options()` and the choice builders `genre_filter_choices()`, `binding_filter_choices()`, `publisher_filter_choices()`, and `gender_filter_choices()` so every module exposes the same option set.

**Shared author lookup SQL:** Author surname/ID pickers and career overview must use the helpers in `queries_basic.R` (`get_author_surname_options`, `get_author_ids_by_surname`, `author_surname_select_choices`, `author_id_select_choices`, `get_author_overview_books`). Book counts always use `COUNT(DISTINCT book_id)` — never re-embed divergent SQL in modules.

**Shared sales filter builders:** Sales-year WHERE clauses for time series and title/binding analyses live in `.build_sales_timeseries_where` and `.build_title_binding_sales_where` / `.build_genre_binding_gender_where` so filter semantics cannot drift between analyses.


[Add more detailed descriptions on the go]
