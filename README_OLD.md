# American Authorship Database (1860-1920)

## Project Overview

This repository contains the code and analysis for the "Database of American Authorship, 1860-1920" research project, led by Dr. Michael Anesko. The project aims to create a comprehensive statistical database of American authorship during the transformative period of the late 19th and early 20th centuries.

## Research Objectives

- **Quantitative Analysis**: Move beyond anecdotal evidence to empirical data analysis of the American literary marketplace
- **Gender Analysis**: Examine differences in publishing opportunities and success between male and female authors
- **Genre Studies**: Analyze performance trends across different literary genres
- **Market Evolution**: Track the transformation of the American literary marketplace (1860-1920)
- **Publisher Analysis**: Study the role of major publishing houses in shaping the market

## Database Contents

- **630+ book entries** with comprehensive metadata
- **63 years of sales data** (1858-1920)
- **Publisher information** from major archives including:
  - Houghton, Mifflin Co. and predecessors (Harvard University)
  - Harper & Brothers (Chadwyck-Healey Microfilm)
  - Scribner Archive (Princeton University)
  - J. B. Lippincott Deposit (University of Pennsylvania)

## Technology Stack

- **Database**: PostgreSQL (relational database for complex queries)
- **Analysis**: R with tidyverse for statistical analysis
- **Visualization**: ggplot2, plotly for publication-ready figures
- **Dashboard**: Shiny for interactive data exploration
- **Environment**: WSL2 on Windows 11

## Repository Structure

```
anesko/
├── data/                          # Raw and processed data files
├── scripts/                       # R scripts for analysis
│   ├── migration/                 # Database setup and migration
│   ├── analysis/                  # Statistical analysis scripts
│   └── validation/                # Data validation and quality checks
├── shiny-app/                     # Interactive Shiny dashboard
├── outputs/                       # Generated outputs
│   ├── plots/                     # Visualizations and figures
│   ├── tables/                    # Statistical tables
│   └── reports/                   # Generated reports
├── docs/                          # Documentation and presentations
└── README.md                      # This file
```

## Getting Started

### Prerequisites

- WSL2 with Ubuntu
- PostgreSQL 12+
- R 4.0+ with required packages
- Git for version control

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/anesko.git
   cd anesko
   ```

2. **Set up PostgreSQL database**:
   ```bash
   sudo service postgresql start
   ```

3. **Install R packages**:
   ```r
   source("scripts/migration/00_package_setup.R")
   ```

4. **Run database migration**:
   ```r
   source("scripts/migration/02_data_migration.R")
   ```

5. **Launch Shiny dashboard**:
   ```r
   shiny::runApp("shiny-app/")
   ```

## Key Research Questions

1. **Gender Disparities**: How did publishing opportunities and commercial success differ between male and female authors?

2. **Genre Evolution**: Which literary genres dominated different periods, and how did their market performance change over time?

3. **Publishing Concentration**: How did the consolidation of publishing houses affect author opportunities and market dynamics?

4. **Economic Patterns**: What were the typical earning patterns for authors, and how did royalty structures evolve?

5. **Market Transformation**: How did the literary marketplace transform from 1860 to 1920?

## Data Sources

All data has been carefully curated from archival sources:

- **Primary Sources**: Publisher archives, sales records, royalty statements
- **Methodology**: Hand-transcribed from original documents
- **Validation**: Cross-referenced across multiple sources where possible
- **Coverage**: Focus on major publishers and commercially successful works

## Academic Context

This project contributes to the field of **book history** and **digital humanities** by providing:

- Empirical foundation for literary marketplace studies
- Quantitative methods for analyzing historical publishing data
- Open-source tools for similar research projects
- Reproducible research methodology

## Publications and Presentations

*[This section will be updated as research progresses]*

## Contributors

- **Principal Investigator**: Dr. Michael Anesko (Penn State University)
- **Data Curator**: Dr. Michael Anesko
- **DLA Adviser**: Dr. Jennifer Isasi (Penn State University)
- **Data Analysts**: 
  - Siyang Ni (2025-)
  - Nick McLean (2023-2024)
- **Student Workers**: Matthew Inman

## Funding

- CHI Digital Humanities Grant (Summer 2023)
- C-SoDA Grant Application (Winter 2024)

## License

This project is licensed under the MIT License - see the [LICENSE](License.md) file for details.

## Citation

If you use this database in your research, please cite:

```
Anesko, Michael et al. (2025). Database of American Authorship, 1860-1920. 
GitHub repository: https://github.com/yourusername/anesko
```

## Contact

For questions about this research project, please contact:

- **Dr. Michael Anesko**: mwa2@psu.edu
- **Project Repository**: https://github.com/siyangni/anesko

---

*Last updated: May 23, 2025*