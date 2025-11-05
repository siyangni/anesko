# American Authorship Database (1860-1920)

![R CI](https://github.com/siyangni/anesko/workflows/R%20CI/badge.svg)

Interactive dashboard for exploring American literary marketplace data from the transformative period of 1860-1920. This project provides empirical evidence for studying publishing trends, authorial earnings, and market dynamics across gender, genre, and publisher dimensions.

## Quick Start

### Docker (Recommended)

```bash
# Clone and configure
git clone https://github.com/siyangni/anesko.git
cd anesko
cp config/credentials.example.env .env
# Edit .env with your credentials

# Start services
docker-compose up -d

# Access at http://localhost:3838
```

### Local Development

```bash
# Install dependencies
R -e 'install.packages("renv"); renv::restore()'

# Configure environment
export R_CONFIG_ACTIVE=development
export DB_HOST=localhost DB_NAME=american_authorship
export DB_USER=app_user DB_PASSWORD=your_password

# Run migrations (first time only)
Rscript scripts/migration/00_run_full_migration.R

# Start app
R -e 'shiny::runApp("app")'
```

See [docs/RUNBOOK.md](docs/RUNBOOK.md) for detailed instructions.

## Features

- **Interactive Dashboard**: Explore 630+ books with 63 years of sales data
- **Author Analysis**: Network visualizations and earnings comparisons
- **Genre & Gender Studies**: Quantitative analysis of market trends
- **Royalty Analysis**: Track authorial earnings and publisher relationships
- **Sales Trends**: Time-series analysis with interactive visualizations

## Repository Structure

```
├── app/                    # Shiny application
│   ├── app.R              # Main entry point
│   ├── modules/           # Shiny modules
│   └── www/               # Static assets
├── R/                     # Shared utilities
│   ├── database.R         # Connection management
│   ├── queries_*.R        # Database queries
│   └── db_pool.R          # Connection pool factory
├── config/                # Configuration
│   ├── config.yml         # Environment-aware settings
│   └── credentials.example.env
├── scripts/               # Operational scripts
│   ├── migration/         # Database setup
│   └── analysis/          # Data analysis
├── docs/                  # Documentation
│   ├── RUNBOOK.md        # Operations guide
│   └── data_dictionary.md
└── tests/                 # Test suite
```

## Technology Stack

- **R 4.3+** with Shiny for interactive dashboards
- **PostgreSQL 12+** for data storage
- **Docker** for containerization
- **GitHub Actions** for CI/CD

## Database Contents

- **630+ book entries** with comprehensive metadata
- **27,771 sales records** spanning 1858-1920
- **Publisher archives** from Harvard, Princeton, Penn, and Chadwyck-Healey
- **Royalty data** including contract terms and payment records

## Development

### Code Style

- Line length: 100 characters max
- Style: [tidyverse](https://style.tidyverse.org/)
- Linting: `lintr::lint_dir("app"); lintr::lint_dir("R")`

### Testing

```r
testthat::test_dir("tests/testthat")
covr::package_coverage()
```

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Development workflow
- Pull request process
- Code style guidelines

## Research Context

This dashboard contributes to **book history** and **digital humanities** by providing:
- Empirical foundation for literary marketplace studies
- Quantitative methods for analyzing historical publishing data
- Open-source tools for similar research projects

### Key Research Questions

1. **Gender Disparities**: How did opportunities differ between male and female authors?
2. **Genre Evolution**: Which genres dominated, and how did performance change over time?
3. **Economic Patterns**: What were typical earning patterns and royalty structures?
4. **Market Transformation**: How did the marketplace evolve from 1860-1920?

## Documentation

- **[RUNBOOK.md](docs/RUNBOOK.md)** - Operations, deployment, troubleshooting
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Development guidelines
- **[data_dictionary.md](docs/data_dictionary.md)** - Schema documentation

## Contributors

**Principal Investigator**: Dr. Michael Anesko (Penn State University)
**Data Team**: Siyang Ni, Nick McLean, Jennifer Isasi, Steve Maczuga, Mason Slingerland
**Research Assistants**: Stephen Szaraz (Harvard), Matthew Inman (Penn State)

## Funding

- College of the Liberal Arts, Penn State University
- Center for the Study of Data Analytics (C-SoDA)
- CHI Digital Humanities Grant (2023)

## Citation

```bibtex
@misc{anesko2025authorship,
  title={Database of American Authorship, 1860-1920},
  author={Anesko, Michael and Ni, Siyang and others},
  year={2025},
  publisher={GitHub},
  url={https://github.com/siyangni/anesko}
}
```

## License

MIT License - see [License.md](License.md)

## Contact

**Dr. Michael Anesko**: mwa2@psu.edu
**Repository**: https://github.com/siyangni/anesko

---

*Version 1.0.0 | Last updated: November 5, 2025*
