# Data Dictionary - American Authorship Database

## Overview
This document describes the structure and contents of the American Authorship Database.

## Tables

### authors
- `author_id`: Unique identifier for each author
- `surname`: Author's last name
- `gender`: M (Male) or F (Female)

### books  
- `book_id`: Unique book identifier (format: AuthorInitials + Year + Sequence)
- `title`: Complete book title
- `publication_year`: Year of publication
- `genre_code`: Single letter genre classification
- `binding`: C (Cloth) or P (Paperback)
- `retail_price`: Original retail price in dollars

### annual_sales
- `book_id`: Links to books table
- `year`: Sales year
- `copies_sold`: Number of copies sold in that year

[Add more detailed descriptions on the go]
