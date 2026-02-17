# paperfetch

**The full-text acquisition layer for systematic reviews in R**

`paperfetch` provides transparent, reproducible PDF retrieval for systematic reviews and meta-analyses. Unlike general-purpose scrapers, `paperfetch` generates **structured acquisition logs**, **PRISMA-compliant reports**, and **validates every downloaded file** — documenting the entire process for your methods section.

---

## Why paperfetch?

### No other R package provides:

✅ **Structured download logs** — Every attempt documented with timestamps, methods, and HTTP status  
✅ **Reproducible acquisition reports** — Auto-generated Markdown reports for your manuscript  
✅ **PDF integrity validation** — Detects HTML error pages and corrupt files disguised as PDFs  
✅ **PRISMA compliance** — Evidence of systematic retrieval attempts for full transparency  
✅ **Multi-source fallback** — Unpaywall → PMC → DOI resolution → Citation scraping  

### Perfect for:

- 📋 Systematic reviews and meta-analyses
- 🔬 Literature reviews requiring audit trails
- 📊 Research requiring reproducible workflows
- 💰 Grant applications needing methodological rigor

---

## Features

| Feature | Description |
|---------|-------------|
| 📊 **Batch processing** | Download hundreds of papers with progress tracking and ETA |
| 📋 **Acquisition logging** | Structured CSV logs with timestamps, methods, HTTP status |
| 📄 **Auto-generated reports** | PRISMA-compliant Markdown summaries for manuscripts |
| 🔍 **PDF integrity validation** | Detects corrupt files and HTML error pages disguised as PDFs |
| 🔄 **Smart caching** | Skips already-downloaded files to resume interrupted sessions |
| ⏱️ **Timeout protection** | Configurable timeouts prevent hanging on slow servers |
| 🧠 **Intelligent routing** | Auto-detects input type (DOI, PMID, PMC ID, or CSV) |
| 🎯 **Consistent identity** | Honest User-Agent and Referer headers throughout |

---

## Installation

```r
# Install devtools if you haven't already
install.packages("devtools")

# Install paperfetch
devtools::install_github("misrak/paperfetch")
```

**Core dependencies:**
```r
install.packages(c("httr2", "rvest", "xml2", "readr", "dplyr", "cli", "progress"))
```

**Optional — for advanced PDF validation:**
```r
install.packages("pdftools")
```

---

## Quick Start

```r
library(paperfetch)

# Automatic detection — works with CSV files or vectors of IDs
fetch_pdfs(
  input = "my_references.csv",
  email = "you@institution.edu",
  log_file = "download_log.csv",
  report_file = "acquisition_report.md"
)
```

After completion you will have:

1. ✅ **Downloaded PDFs** in `downloads/`
2. 📋 **`download_log.csv`** — Complete acquisition audit trail
3. 📄 **`acquisition_report.md`** — PRISMA-ready summary for your manuscript

---

## Core Workflow

This is the recommended workflow for systematic reviews:

```r
library(paperfetch)

# ── Step 1: Download with automatic validation ─────────────────────────────────
# validate_pdfs = TRUE and remove_invalid = TRUE are on by default.
# Invalid files (HTML error pages, corrupt PDFs, files < 10KB) are
# detected, removed, and logged automatically.

fetch_pdfs_from_doi(
  csv_file_path = "systematic_review_dois.csv",
  output_folder = "papers",
  email         = "yourname@institution.edu",
  delay         = 2,
  log_file      = "download_log.csv",
  report_file   = "acquisition_report.md"
  # validate_pdfs  = TRUE  (default)
  # remove_invalid = TRUE  (default)
)

# ── Step 2: Review the acquisition report ─────────────────────────────────────
# Open the auto-generated PRISMA-compliant report.
# Paste the relevant sections directly into your manuscript methods section.

file.show("acquisition_report.md")

# ── Step 3 (Optional): Advanced validation with pdftools ──────────────────────
# Performs deep validation: page count, text extraction, corruption checks.
# Only runs if pdftools is installed.

if (requireNamespace("pdftools", quietly = TRUE)) {
  validate_pdfs_after_download(
    output_folder = "papers",
    log_file      = "download_log.csv",
    report_file   = "acquisition_report.md",
    email         = "yourname@institution.edu",
    use_advanced  = TRUE
  )
}
```

---

## Main Functions

### `fetch_pdfs()` — Intelligent Wrapper (Recommended)

Automatically detects input type (CSV, vector, single ID) and routes to the correct strategy.

```r
fetch_pdfs(
  input          = "my_references.csv",  # CSV, vector of IDs, or single ID
  output_folder  = "downloads",
  delay          = 2,
  email          = "yourname@institution.edu",
  timeout        = 15,
  log_file       = "download_log.csv",
  report_file    = "acquisition_report.md",
  unfetched_file = "unfetched.txt",
  validate_pdfs  = TRUE,
  remove_invalid = TRUE
)
```

**Input auto-detection:**

- 📁 **CSV file** — Detects column type (`doi`, `pmid`, `pubmed_id`) and routes automatically
- 🔢 **Vector of IDs** — Classifies each ID as DOI, PMID, or PMC and processes by type
- 🎯 **Single ID** — Detects type and fetches accordingly
- 🔄 **PMC IDs** — Automatically converted to PMIDs via NCBI API

**Examples:**

```r
# CSV file (column type auto-detected)
fetch_pdfs("my_references.csv", email = "you@edu")

# Vector of DOIs
fetch_pdfs(
  c("10.1038/nature12373", "10.1126/science.1234567"),
  email = "you@edu"
)

# Mixed IDs — DOIs, PMIDs, and PMC IDs all at once
fetch_pdfs(
  c("10.1038/nature12373", "30670877", "PMC5176308"),
  output_folder = "papers",
  email         = "you@edu",
  log_file      = "download_log.csv",
  report_file   = "acquisition_report.md"
)

# Single ID
fetch_pdfs("10.1038/nature12373", email = "you@edu")
```

---

### `fetch_pdfs_from_doi()` — DOI Batch Download

Optimised for systematic reviews with DOI lists.

```r
fetch_pdfs_from_doi(
  csv_file_path  = "systematic_review_dois.csv",
  output_folder  = "downloaded_papers",
  delay          = 2,
  email          = "yourname@institution.edu",
  timeout        = 15,
  log_file       = "download_log.csv",
  report_file    = "acquisition_report.md",
  validate_pdfs  = TRUE,
  remove_invalid = TRUE
)
```

**Arguments:**

| Argument | Default | Description |
|----------|---------|-------------|
| `csv_file_path` | — | Path to CSV with a `doi` column (**required**) |
| `output_folder` | `"downloads"` | Directory for PDFs (created if missing) |
| `delay` | `2` | Seconds between requests (be polite) |
| `email` | — | Your email for Unpaywall API (**required**) |
| `timeout` | `15` | Max seconds per request |
| `log_file` | `"download_log.csv"` | Structured acquisition log |
| `report_file` | `"acquisition_report.md"` | PRISMA-ready Markdown report |
| `validate_pdfs` | `TRUE` | Validate every downloaded file |
| `remove_invalid` | `TRUE` | Remove invalid files automatically |

**CSV format:**
```csv
doi
10.1038/s41586-020-2649-2
10.1126/science.abc1234
10.1016/j.cell.2020.01.001
```

**Retrieval strategy (in order):**
1. ✅ **Unpaywall API** — Uses `best_oa_location` including PMC AWS (~50% OA success)
2. ✅ **Citation metadata** — Checks `citation_pdf_url` meta tag on publisher page
3. ✅ **HTML scraping** — Searches for PDF links as last resort

---

### `fetch_pdfs_from_pmids()` — PMID Batch Download

Optimised for PubMed-based systematic reviews.

```r
fetch_pdfs_from_pmids(
  csv_file_path  = "pubmed_ids.csv",
  output_folder  = "papers",
  delay          = 2,
  email          = "yourname@institution.edu",
  timeout        = 15,
  log_file       = "download_log.csv",
  report_file    = "acquisition_report.md",
  validate_pdfs  = TRUE,
  remove_invalid = TRUE
)
```

**Arguments:** Same as `fetch_pdfs_from_doi()` but expects a `pmid`, `PMID`, or `pubmed_id` column.

**CSV format:**
```csv
pmid
30670877
28445112
31768060
```

**Retrieval strategy (in order):**
1. ✅ **Extract DOI from PubMed** → Unpaywall API
2. ✅ **PMC direct download** — If a PMC ID is found, download directly from PubMed Central
3. ✅ **Citation metadata** — Check `citation_pdf_url` on PubMed page
4. ✅ **DOI resolution** — Follow DOI to publisher page and scrape
5. ✅ **HTML scraping** — Last resort fallback

---

## PDF Integrity Validation

Scrapers frequently encounter **soft failures** — files named `.pdf` that are actually HTML error pages or corrupt downloads. `paperfetch` catches these automatically.

### What gets detected:

| Invalid Type | Description |
|-------------|-------------|
| `html_error_page` | HTML "Access Denied" or "403 Forbidden" page disguised as PDF |
| `file_too_small` | File under 10 KB — almost certainly an error response |
| `missing_eof_marker` | Corrupt PDF missing the `%%EOF` marker |
| `invalid_pdf_format` | File does not begin with `%PDF-` header |
| `corrupted_pdf` | PDF is damaged and unreadable (advanced validation only) |
| `password_protected` | PDF is password-protected (advanced validation only) |

### How validation works:

```r
# Validation is ON by default — nothing extra needed
fetch_pdfs_from_doi(
  csv_file_path = "dois.csv",
  output_folder = "papers",
  email         = "you@edu"
  # validate_pdfs  = TRUE  (default)
  # remove_invalid = TRUE  (default)
)

# Console output during validation:
# ══ Validating Downloaded PDFs ══════════════════════
# ✔ Valid PDFs: 387
# ✖ Invalid PDFs: 15
# ℹ Failure reasons:
#   - html_error_page: 12
#   - file_too_small:  2
#   - missing_eof_marker: 1
# ⚠ Removing 15 invalid PDF files...
```

### Validation options:

```r
# Default: validate and remove invalid files
fetch_pdfs_from_doi(..., validate_pdfs = TRUE, remove_invalid = TRUE)

# Validate but keep invalid files for manual inspection
fetch_pdfs_from_doi(..., validate_pdfs = TRUE, remove_invalid = FALSE)

# Skip validation (faster, but not recommended for systematic reviews)
fetch_pdfs_from_doi(..., validate_pdfs = FALSE)

# Advanced validation with pdftools (checks page count and text extraction)
if (requireNamespace("pdftools", quietly = TRUE)) {
  validate_pdfs_after_download(
    output_folder = "papers",
    log_file      = "download_log.csv",
    report_file   = "acquisition_report.md",
    email         = "you@edu",
    use_advanced  = TRUE
  )
}
```

---

## Structured Download Logs

Every attempt is logged to `download_log.csv`:

| Field | Description | Example |
|-------|-------------|---------|
| `id` | DOI, PMID, or PMC ID | `10.1038/nature12373` |
| `id_type` | Type of identifier | `doi`, `pmid`, `pmc` |
| `timestamp` | ISO 8601 timestamp | `2025-02-16T14:23:45Z` |
| `method` | Retrieval method used | `unpaywall`, `pmc`, `doi_resolution`, `scrape` |
| `status` | HTTP status code | `200`, `403`, `404`, `timeout` |
| `success` | Download succeeded | `TRUE`, `FALSE` |
| `failure_reason` | Why it failed | `paywalled`, `no_pdf_found`, `timeout` |
| `pdf_url` | Final PDF URL | `https://ncbi.nlm.nih.gov/pmc/...` |
| `file_path` | Local file path | `papers/10_1038_nature12373.pdf` |
| `file_size_kb` | File size in KB | `1024.5` |
| `pdf_valid` | Passed integrity check | `TRUE`, `FALSE` |
| `pdf_invalid_reason` | Why validation failed | `html_error_page` |

---

## Auto-Generated Acquisition Reports

`paperfetch` generates a **PRISMA-compliant Markdown report** after every download session. The report is structured for direct use in your manuscript's methods section.

### Report sections:

```
## Summary
  Total records, success rate, skipped files

## Retrieval Methods
  Success rates per method (Unpaywall, PMC, DOI resolution, scraping)

## Failure Analysis
  Categorised failure reasons with counts and percentages

## Failed Records
  Full ID lists organised by failure type (paywalled, no PDF, technical)

## PDF Integrity Validation       ← unique to paperfetch
  Valid/invalid counts, invalid PDF breakdown, IDs requiring manual retrieval

## Reproducibility Information
  R version, paperfetch version, parameters, data sources

## Recommendations
  Targeted next steps for each failure category

## Citation
  Ready-to-paste citation for your manuscript
```

### Example report excerpt:

```markdown
# Full-Text Acquisition Report

**Generated:** 2025-02-16 14:45:32
**Package:** paperfetch v0.1.0
**Analyst:** yourname@institution.edu

## Summary
- **Total records:** 528
- **Successfully downloaded:** 397 (75.2%)
- **Failed to retrieve:** 116 (22.0%)
- **Already existed (skipped):** 15 (2.8%)

## PDF Integrity Validation
- **PDFs validated:** 412
- **Valid PDFs:** 397 (96.4%)
- **Invalid PDFs detected and removed:** 15 (3.6%)

### Invalid PDF Breakdown
| Reason              | Count | Description                              |
|---------------------|-------|------------------------------------------|
| html_error_page     | 12    | HTML error page disguised as PDF         |
| file_too_small      | 2     | File too small (likely an error response)|
| missing_eof_marker  | 1     | Corrupt PDF missing %%EOF marker         |
```

---

## Best Practices for Systematic Reviews

### 1. Prepare your ID list

```r
# From a BibTeX file
library(bib2df)
refs <- bib2df("my_references.bib")
write.csv(data.frame(doi = refs$DOI), "dois.csv", row.names = FALSE)

# From a PubMed export
# PubMed → Send to → File → CSV → open in R
pmids <- read.csv("pubmed_results.csv")
write.csv(data.frame(pmid = pmids$PMID), "pmids.csv", row.names = FALSE)
```

### 2. Use your institutional email

Unpaywall requires a valid email and performs better with institutional addresses:

```r
fetch_pdfs_from_doi(
  csv_file_path = "dois.csv",
  output_folder = "papers",
  email         = "j.smith@university.edu"
)
```

### 3. Respect rate limits

For large reviews (>500 papers) increase the delay:

```r
fetch_pdfs_from_doi(
  csv_file_path = "large_review.csv",
  output_folder = "papers",
  delay         = 3,
  email         = "yourname@institution.edu"
)
```

### 4. Organise for PRISMA compliance

```r
# Create a structured project
dir.create("systematic_review/pdfs",  recursive = TRUE)
dir.create("systematic_review/logs",  recursive = TRUE)
dir.create("systematic_review/data",  recursive = TRUE)

# Download with full logging
fetch_pdfs_from_doi(
  csv_file_path = "systematic_review/data/dois.csv",
  output_folder = "systematic_review/pdfs",
  log_file      = "systematic_review/logs/download_log.csv",
  report_file   = "systematic_review/logs/acquisition_report.md",
  email         = "yourname@institution.edu"
)

# Review and archive the report
file.show("systematic_review/logs/acquisition_report.md")
```

### 5. Handle failures systematically

```r
# Read the log to analyse failures
log <- read.csv("download_log.csv")

# Export paywalled papers for library request
paywalled <- log[grepl("paywalled|403", log$failure_reason), ]
write.csv(paywalled["id"], "library_requests.csv", row.names = FALSE)

# Retry timeout failures
timed_out <- log[grepl("timeout", log$failure_reason), ]
write.csv(timed_out["id"], "retry.csv", row.names = FALSE)
fetch_pdfs("retry.csv", email = "you@edu", timeout = 30)

# Inspect invalid PDFs before removal
if (any(!log$pdf_valid, na.rm = TRUE)) {
  invalid <- log[!is.na(log$pdf_valid) & !log$pdf_valid, ]
  View(invalid)
}
```

---

## Function Comparison

| Scenario | Recommended | Why |
|----------|------------|-----|
| Mixed IDs or unknown input | `fetch_pdfs()` | Auto-detects and routes |
| CSV with DOIs | `fetch_pdfs_from_doi()` | Slightly faster, more explicit |
| CSV with PMIDs | `fetch_pdfs_from_pmids()` | Slightly faster, more explicit |
| Large review (>1000 papers) | Specific function | More control over parameters |
| Post-download deep check | `validate_pdfs_after_download()` | pdftools-based deep validation |

---

## Ethical Use & Legal Considerations

⚖️ **This package is designed for legal academic use:**

- ✅ Download papers you have **legitimate access to** (open access, subscriptions)
- ✅ Use for **personal research, systematic reviews, meta-analyses**
- ✅ Respect **publishers' Terms of Service**
- ✅ Rate-limit all requests (default 2-second delay)
- ❌ Do NOT download paywalled content you have no right to access
- ❌ Do NOT redistribute copyrighted PDFs

`paperfetch` identifies itself honestly as an academic scraper with your contact email. Most publishers permit automated retrieval for legitimate research when done respectfully.

---

## Troubleshooting

### Low success rate
- Verify your DOI/PMID list for typos or malformed IDs
- Many failures are expected for paywalled content — use your library for these
- Review `acquisition_report.md` for failure patterns
- Try increasing `timeout` for slow publishers

### High rate of invalid PDFs
- Common with Elsevier and Wiley — aggressive anti-bot measures return HTML pages
- Check `pdf_invalid_reason` column in `download_log.csv`
- Set `remove_invalid = FALSE` to inspect files before deletion

### Timeouts
```r
fetch_pdfs_from_doi(..., timeout = 30)
```

### CSV column not found
```r
# Check column names
colnames(read.csv("my_file.csv"))

# Use absolute path if needed
fetch_pdfs(input = file.choose(), email = "you@edu")
```

### "Please provide your real email" warning
```r
# Always pass your real institutional email
fetch_pdfs("dois.csv", email = "j.smith@university.edu")
```

---

## Advanced Usage

### Parallel downloads for large reviews

```r
library(dplyr)

# Split into chunks of 100
dois <- read.csv("all_dois.csv")
chunks <- split(dois, (seq(nrow(dois)) - 1) %/% 100)

for (i in seq_along(chunks)) {
  write.csv(chunks[[i]], paste0("chunk_", i, ".csv"), row.names = FALSE)
}

# Run in separate R sessions or terminals
# Session 1: fetch_pdfs("chunk_1.csv", output_folder = "papers", email = "you@edu")
# Session 2: fetch_pdfs("chunk_2.csv", output_folder = "papers", email = "you@edu")
# ...

# Merge logs afterwards
library(dplyr)
merged_log <- list.files(pattern = "download_log_chunk.*\\.csv") %>%
  lapply(read.csv) %>%
  bind_rows()
write.csv(merged_log, "complete_download_log.csv", row.names = FALSE)
```

### Integration with `targets` pipelines

```r
# _targets.R
library(targets)
library(paperfetch)

tar_plan(
  tar_target(doi_csv, "data/dois.csv", format = "file"),

  tar_target(
    pdf_downloads,
    fetch_pdfs_from_doi(
      csv_file_path = doi_csv,
      output_folder = "pdfs",
      log_file      = "logs/download_log.csv",
      report_file   = "logs/acquisition_report.md",
      email         = "you@edu"
    )
  ),

  tar_target(download_log, read.csv("logs/download_log.csv")),

  tar_target(
    success_rate,
    sum(download_log$success) / nrow(download_log) * 100
  )
)
```

---

## Contributing

Contributions are welcome! `paperfetch` is under active development for the scientific community.

1. Fork the repository: https://github.com/misrak/paperfetch
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

**Priority areas:**
- Publisher-specific scrapers (Springer, Wiley, Taylor & Francis)
- Support for arXiv and bioRxiv preprints
- HTML report output (optional via `rmarkdown`)
- PDF metadata extraction and verification
- Institutional repository support

**Bug reports** should include your R version (`sessionInfo()`), the IDs that failed, error messages, and relevant rows from `download_log.csv`.

---

## Roadmap

**v0.1.0 (Current)**
- ✅ `fetch_pdfs()` intelligent wrapper
- ✅ `fetch_pdfs_from_doi()` and `fetch_pdfs_from_pmids()`
- ✅ Structured CSV logging
- ✅ PRISMA-compliant Markdown reports
- ✅ PDF integrity validation (basic and advanced)
- ✅ PMC ID → PMID conversion

**v0.2.0 (Planned)**
- [ ] arXiv and bioRxiv support
- [ ] Optional interactive HTML reports
- [ ] Built-in parallel downloads
- [ ] Retry mechanism for failed downloads

**v0.3.0 (Planned)**
- [ ] Zotero API integration
- [ ] Institutional repository support
- [ ] Shiny GUI for non-R users
- [ ] Publisher-specific optimisations

---

## Package Structure

```
paperfetch/
├── R/
│   ├── fetch_pdfs.R                # Intelligent wrapper
│   ├── fetch_pdfs_from_doi.R       # DOI batch download
│   ├── fetch_pdfs_from_pmids.R     # PMID batch download
│   ├── pdf_validation.R            # Integrity validation
│   ├── reporting.R                 # Report generation
│   └── utils.R                     # classify_id, convert_pmc_to_pmid, create_log_entry
├── man/                            # roxygen2 documentation
├── tests/testthat/                 # Unit tests
├── vignettes/
│   └── systematic_review_workflow.Rmd
├── DESCRIPTION
├── NAMESPACE
├── LICENSE
└── README.md
```

---

## Citation

```
paperfetch: The full-text acquisition layer for systematic reviews in R.
R package version 0.1.0. https://github.com/HGND-laboratory/paperfetch
```

```bibtex
@Manual{paperfetch,
  title  = {paperfetch: The full-text acquisition layer for systematic reviews in R},
  author = {Kaalindi Misra},
  year   = {2025},
  note   = {R package version 0.1.0},
  url    = {https://github.com/HGND-laboratory/paperfetch}
}
```

---

## License

MIT — see `LICENSE` for details.

---

## Contact

**Maintainer:** Kaalindi Misra  
**Email:** misra.kaalindi@hsr.it  
**GitHub:** https://github.com/HGND-laboratory/paperfetch  
**Issues:** https://github.com/HGND-laboratory/paperfetch/issues

---

## Acknowledgments

Built with [httr2](https://httr2.r-lib.org/), [rvest](https://rvest.tidyverse.org/), [xml2](https://xml2.r-lib.org/), [cli](https://cli.r-lib.org/), and [progress](https://github.com/r-lib/progress).  
Data sources: [Unpaywall](https://unpaywall.org), [PubMed Central](https://www.ncbi.nlm.nih.gov/pmc/), and [NCBI E-utilities](https://www.ncbi.nlm.nih.gov/books/NBK25501/).

---

**⭐ Star this repo if `paperfetch` helps your research!**  
**📢 Share with colleagues running systematic reviews!**