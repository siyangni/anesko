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


[Add more detailed descriptions on the go]
