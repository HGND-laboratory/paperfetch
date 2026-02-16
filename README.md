# paperfetch

**The full-text acquisition layer for systematic reviews in R**

`paperfetch` provides transparent, reproducible PDF retrieval for systematic reviews and meta-analyses. Unlike general-purpose scrapers, `paperfetch` generates **structured acquisition logs** and **PRISMA-compliant reports**, documenting every download attempt for your methods section.

---

## Why paperfetch?

### No other R package provides:

✅ **Structured download logs** - Every attempt documented with timestamps, methods, and HTTP status  
✅ **Reproducible acquisition reports** - Auto-generated Markdown reports for your manuscript  
✅ **PRISMA compliance** - Evidence of systematic retrieval attempts for transparency  
✅ **Multi-source fallback** - Unpaywall → PMC → DOI resolution → Citation scraping  

### Perfect for:

- 📋 Systematic reviews and meta-analyses
- 🔬 Literature reviews requiring audit trails
- 📊 Research requiring reproducible workflows
- 💰 Grant applications needing methodological rigor

---

## Key Features

| Feature | Description |
|---------|-------------|
| 📊 **Batch processing** | Download hundreds of papers with progress tracking |
| 📋 **Acquisition logging** | Structured CSV logs with timestamps, methods, HTTP status |
| 📄 **Auto-generated reports** | PRISMA-compliant Markdown reports for manuscripts |
| 🔄 **Smart caching** | Skips already-downloaded files to resume interrupted sessions |
| ⏱️ **Timeout protection** | Configurable timeouts prevent hanging on slow servers |
| 🧠 **Intelligent routing** | Auto-detects input type (DOI, PMID, PMC, CSV) |
| 🎯 **Publication-ready** | Designed for reproducible research workflows |

---

## Installation

```r
# Install devtools if you haven't already
install.packages("devtools")

# Install paperfetch package
devtools::install_github("HGND-laboratory/paperfetch")
```

**Dependencies:**
```r
install.packages(c("httr2", "rvest", "xml2", "readr", "dplyr", "cli", "progress"))
```

---

## Quick Start

```r
library(paperfetch)

# Automatic detection with full logging and reporting
fetch_pdfs(
  input = "my_references.csv", 
  email = "you@institution.edu",
  log_file = "download_log.csv",        # Structured acquisition log
  report_file = "acquisition_report.md"  # PRISMA-ready report
)
```

### What you get:

1. ✅ **Downloaded PDFs** in `downloads/` folder
2. 📋 **`download_log.csv`** - Complete acquisition audit trail
3. 📄 **`acquisition_report.md`** - PRISMA-ready summary for your manuscript

---

## Example Output

After running `paperfetch`, you'll have everything needed for transparent reporting:

### 1. Downloaded PDFs
```
downloads/
├── 10_1038_nature12373.pdf
├── 10_1126_science_abc1234.pdf
├── PMID_30670877.pdf
└── ...
```

### 2. Structured Download Log (`download_log.csv`)

| id | id_type | timestamp | method | status | success | failure_reason | pdf_url | file_path | file_size_kb |
|----|---------|-----------|--------|--------|---------|----------------|---------|-----------|--------------|
| 10.1038/nature12373 | doi | 2025-02-16T14:23:45Z | unpaywall | 200 | TRUE | NA | https://nature.com/... | downloads/10_1038_nature12373.pdf | 2048.3 |
| 10.1126/science.abc | doi | 2025-02-16T14:23:48Z | doi_resolution | 403 | FALSE | paywalled | https://science.org/... | NA | NA |
| 30670877 | pmid | 2025-02-16T14:23:51Z | pmc | 200 | TRUE | NA | https://ncbi.nlm.nih.gov/... | downloads/PMID_30670877.pdf | 1536.7 |

### 3. Auto-Generated Acquisition Report (`acquisition_report.md`)

```markdown
# Full-Text Acquisition Report

**Generated:** 2025-02-16 14:45:32  
**Analyst:** yourname@institution.edu

## Summary
- **Total records:** 528
- **Successfully downloaded:** 412 (78.0%)
- **Failed to retrieve:** 116 (22.0%)

## Retrieval Methods
| Method | Attempts | Success | Success Rate |
|--------|----------|---------|--------------|
| Unpaywall API | 528 | 267 | 50.6% |
| PubMed Central (PMC) | 143 | 98 | 68.5% |
| DOI Resolution | 261 | 34 | 13.0% |
| Citation Metadata Scraping | 118 | 13 | 11.0% |

## Failure Analysis
| Reason | Count | Percentage |
|--------|-------|------------|
| Paywalled (HTTP 403) | 67 | 57.8% |
| No PDF found | 31 | 26.7% |
| Timeout | 12 | 10.3% |

[Full report includes failed DOI lists, reproducibility info, and recommendations]
```

---

## Main Functions

All functions support **logging** and **reporting** for transparent, reproducible workflows:

### `fetch_pdfs()` - Intelligent Wrapper (Recommended)

**Automatically detects input type and routes to the appropriate retrieval strategy.**

```r
fetch_pdfs(
  input = "my_references.csv",       # CSV file, vector of IDs, or single ID
  output_folder = "downloads",
  delay = 2,
  email = "yourname@institution.edu",
  timeout = 15,
  log_file = "download_log.csv",        # NEW: Structured logging
  report_file = "acquisition_report.md", # NEW: Auto-generated report
  unfetched_file = "unfetched.txt"
)
```

**What it does:**
- 📁 **CSV input**: Detects column type (`doi`, `pmid`, `pubmed_id`) and routes automatically
- 🔢 **Vector input**: Classifies each ID (DOI/PMID/PMC) and processes by type
- 🎯 **Single ID**: Detects type and fetches accordingly
- 🔄 **PMC conversion**: Automatically converts PMC IDs to PMIDs using NCBI API

**Examples:**

```r
# CSV file (auto-detects if it contains DOIs or PMIDs)
fetch_pdfs("my_references.csv", email = "you@edu")

# Vector of DOIs only
fetch_pdfs(
  c("10.1038/nature12373", "10.1126/science.1234567"),
  email = "you@edu"
)

# Mixed IDs (DOIs + PMIDs + PMC IDs all together!)
fetch_pdfs(
  c("10.1038/nature12373", "30670877", "PMC5176308"),
  output_folder = "papers",
  email = "you@edu",
  log_file = "mixed_download_log.csv",
  report_file = "mixed_acquisition_report.md"
)

# Single ID
fetch_pdfs("10.1038/nature12373", email = "you@edu")
```

**Arguments:**
- `input`: CSV file path, vector of IDs, or single ID string
- `output_folder`: Directory for saving PDFs (default: `"downloads"`)
- `delay`: Seconds between requests (default: `2`)
- `email`: Your email for API identification (**required**)
- `timeout`: Maximum seconds per request (default: `15`)
- `log_file`: Path for structured CSV log (default: `"download_log.csv"`)
- `report_file`: Path for Markdown report (default: `"acquisition_report.md"`)
- `unfetched_file`: Log file for simple failed ID list (default: `"unfetched.txt"`)

---

### `fetch_pdfs_from_doi()` - DOI-Specific Batch Download

**Optimized for systematic reviews with DOI lists.**

```r
fetch_pdfs_from_doi(
  csv_file_path = "systematic_review_dois.csv",
  output_folder = "downloaded_papers",
  delay = 2,
  email = "yourname@institution.edu",
  timeout = 15,
  log_file = "doi_download_log.csv",
  report_file = "doi_acquisition_report.md"
)
```

**Arguments:**
- `csv_file_path`: Path to CSV file containing a `doi` column
- `output_folder`: Directory for saving PDFs (created if doesn't exist)
- `delay`: Seconds to wait between requests (default: `2`)
- `email`: Your email for Unpaywall API identification (**required**)
- `timeout`: Maximum seconds to wait per request (default: `15`)
- `log_file`: Path for structured CSV log (default: `"download_log.csv"`)
- `report_file`: Path for Markdown report (default: `"acquisition_report.md"`)

**CSV Format:**
```csv
doi
10.1038/s41586-020-2649-2
10.1126/science.abc1234
10.1016/j.cell.2020.01.001
```

**Retrieval Strategy:**
1. ✅ **Unpaywall API** (fastest, ~50% success for OA papers) → Uses `best_oa_location` including PMC AWS
2. ✅ **DOI resolution + citation metadata** → Checks `citation_pdf_url` meta tags
3. ✅ **HTML scraping** → Searches for PDF links as last resort

---

### `fetch_pdfs_from_pmids()` - PMID-Specific Batch Download

**Optimized for PubMed-based systematic reviews.**

```r
fetch_pdfs_from_pmids(
  csv_file_path = "pubmed_ids.csv",
  output_folder = "papers",
  delay = 2,
  email = "yourname@institution.edu",
  timeout = 15,
  log_file = "pmid_download_log.csv",
  report_file = "pmid_acquisition_report.md"
)
```

**Arguments:**
- `csv_file_path`: Path to CSV file containing a `pmid`, `PMID`, or `pubmed_id` column
- `output_folder`: Directory for saving PDFs (created if doesn't exist)
- `delay`: Seconds to wait between requests (default: `2`)
- `email`: Your email for identification
- `timeout`: Maximum seconds to wait per request (default: `15`)
- `log_file`: Path for structured CSV log (default: `"download_log.csv"`)
- `report_file`: Path for Markdown report (default: `"acquisition_report.md"`)

**CSV Format:**
```csv
pmid
30670877
28445112
31768060
```

**Retrieval Strategy:**
1. ✅ **Extract DOI from PubMed** → Use Unpaywall API if DOI found
2. ✅ **PMC direct download** → If article has PMC ID, download from PubMed Central
3. ✅ **Citation metadata** → Check `citation_pdf_url` on PubMed page
4. ✅ **DOI resolution** → Follow DOI to publisher and scrape
5. ✅ **HTML scraping** → Last resort fallback

---

## Structured Download Logs

Every download attempt is logged to `download_log.csv` with the following fields:

| Field | Description | Example |
|-------|-------------|---------|
| `id` | DOI, PMID, or PMC ID | `10.1038/nature12373` |
| `id_type` | Type of identifier | `doi`, `pmid`, `pmc` |
| `timestamp` | ISO 8601 timestamp | `2025-02-16T14:23:45Z` |
| `method` | Retrieval method attempted | `unpaywall`, `pmc`, `doi_resolution`, `scrape` |
| `status` | HTTP status code | `200`, `404`, `403`, `timeout` |
| `success` | Download succeeded | `TRUE`, `FALSE` |
| `failure_reason` | Why it failed (if applicable) | `paywalled`, `no_pdf_found`, `timeout`, `http_403` |
| `pdf_url` | Final PDF URL (if found) | `https://www.ncbi.nlm.nih.gov/pmc/...` |
| `file_path` | Local file path | `downloads/10_1038_nature12373.pdf` |
| `file_size_kb` | Downloaded file size in KB | `1024.5` |

### Why this matters for systematic reviews:

✅ **Reproducibility** - Other researchers can verify your retrieval process  
✅ **Transparency** - Reviewers can see exactly what happened with each paper  
✅ **Audit trail** - Document for ethics boards, funding agencies, journals  
✅ **Troubleshooting** - Identify patterns in failures (e.g., specific publishers)  

---

## Auto-Generated Acquisition Reports

`paperfetch` generates **PRISMA-compliant Markdown reports** documenting your full-text retrieval process. These reports can be copied directly into your manuscript's methods section.

### Report Contents:

1. **Summary Statistics**
   - Total records processed
   - Success/failure counts and percentages
   - Already-existing files (skipped)

2. **Retrieval Method Breakdown**
   - Which methods were attempted (Unpaywall, PMC, DOI resolution, scraping)
   - Success rates for each method
   - Method-specific statistics

3. **Failure Analysis**
   - Categorized failure reasons (paywalled, no PDF, timeout, server errors)
   - Counts and percentages for each failure type

4. **Failed Records Lists**
   - Complete lists of DOIs/PMIDs that failed
   - Organized by failure reason for targeted follow-up

5. **Reproducibility Information**
   - R version and system information
   - paperfetch version
   - All parameters used (email, delays, timeouts)
   - Data sources accessed

6. **Recommendations**
   - Next steps for obtaining failed records
   - Institutional library contact suggestions

### Example Report Excerpt:

```markdown
# Full-Text Acquisition Report

**Generated:** 2025-02-16 14:45:32  
**Package:** paperfetch v0.1.0  
**Analyst:** yourname@institution.edu

---

## Summary

- **Total records:** 528
- **Successfully downloaded:** 412 (78.0%)
- **Failed to retrieve:** 116 (22.0%)
- **Already existed (skipped):** 23 (4.4%)

---

## Retrieval Methods

| Method | Attempts | Success | Success Rate |
|--------|----------|---------|--------------|
| Unpaywall API | 528 | 267 | 50.6% |
| PubMed Central (PMC) | 143 | 98 | 68.5% |
| DOI Resolution | 261 | 34 | 13.0% |
| Citation Metadata Scraping | 118 | 13 | 11.0% |

---

## Failure Analysis

| Reason | Count | Percentage |
|--------|-------|------------|
| Paywalled (HTTP 403) | 67 | 57.8% |
| No PDF found | 31 | 26.7% |
| Timeout | 12 | 10.3% |
| Server error (HTTP 500) | 4 | 3.4% |
| Other | 2 | 1.7% |

---

## Failed Records

### Paywalled Content (n=67)
10.1016/j.cell.2020.01.001
10.1126/science.abc1234
10.1038/s41586-020-1234-5
...

*[Full lists provided in actual report]*

---

## Recommendations for Failed Records

1. **Paywalled content (n=67):** Request via institutional library or interlibrary loan
2. **No PDF available (n=31):** Check if articles are HTML-only or contact authors
3. **Technical failures (n=18):** Retry manually or contact publisher support
```
---

## Shared Features Across All Functions

All `paperfetch` functions include:

- ✅ **Progress bar with ETA** - See how long your download will take
- ✅ **Skip existing files** - Resume interrupted downloads seamlessly
- ✅ **Colored console alerts** - Clear success/failure/info messages
  - 🟢 `✔ Downloaded: ...` (success)
  - 🔴 `✖ No PDF found: ...` (failure)
  - 🔵 `ℹ Skipped (exists): ...` (already downloaded)
- ✅ **Structured logging** - CSV logs with timestamps, methods, status codes
- ✅ **Auto-generated reports** - PRISMA-ready Markdown summaries
- ✅ **Consistent User-Agent** - Honest identification for server compatibility
- ✅ **Referer headers** - Prevents anti-bot blocks
- ✅ **Automatic timeout handling** - Never hang on slow servers
- ✅ **Retry logic** - Attempts multiple strategies before giving up

---

## Best Practices for Systematic Reviews

### 1. **Prepare Your ID List**

Export DOIs or PMIDs from your reference manager (Zotero, Mendeley, EndNote) or bibliographic database:

```r
# Example: Extract DOIs from a BibTeX file
library(bib2df)
refs <- bib2df("my_references.bib")
write.csv(data.frame(doi = refs$DOI), "dois.csv", row.names = FALSE)

# Example: Export from PubMed search
# 1. Run your PubMed search
# 2. Click "Send to" → "File" → "CSV"
# 3. Save with PMID column

# Example: From Zotero
# 1. Select your collection
# 2. File → Export Library → CSV format
# 3. Ensure DOI or PMID column is present
```

### 2. **Use Institutional Email**

Unpaywall requires a valid email and works better with institutional addresses:

```r
fetch_pdfs(
  "dois.csv",
  email = "j.smith@university.edu"  # Use your real institutional email
)
```

### 3. **Respect Rate Limits**

For large systematic reviews (>500 papers), increase the delay:

```r
fetch_pdfs(
  "large_review.csv",
  output_folder = "papers",
  delay = 3,  # 3 seconds between requests
  email = "yourname@institution.edu"
)
```

### 4. **Document Everything for PRISMA**

Save your logs and reports with your systematic review protocol:

```r
# Organized workflow for PRISMA compliance
fetch_pdfs(
  input = "screening_included_studies.csv",
  output_folder = "full_text_pdfs",
  log_file = "PRISMA_full_text_retrieval_log.csv",
  report_file = "PRISMA_full_text_retrieval_report.md",
  email = "yourname@institution.edu"
)

# Archive everything
# full_text_pdfs/ → Your PDFs
# PRISMA_full_text_retrieval_log.csv → Complete audit trail
# PRISMA_full_text_retrieval_report.md → Methods section content
```

### 5. **Handle Failures Systematically**

```r
# After running paperfetch, analyze failures
log <- read.csv("download_log.csv")

# Count by failure reason
table(log$failure_reason[!log$success])

# Export paywalled papers for library request
paywalled <- log$id[grepl("403|paywalled", log$failure_reason)]
write.csv(data.frame(doi = paywalled), "library_request.csv", row.names = FALSE)

# Retry technical failures after a day
technical_failures <- log$id[grepl("timeout|500", log$failure_reason)]
write.csv(data.frame(doi = technical_failures), "retry_tomorrow.csv", row.names = FALSE)
```

### 6. **Complete Workflow Example**

```r
# Step 1: Create project structure
dir.create("systematic_review")
dir.create("systematic_review/pdfs")
dir.create("systematic_review/logs")
dir.create("systematic_review/data")

# Step 2: Prepare ID list
write.csv(my_dois, "systematic_review/data/dois.csv", row.names = FALSE)

# Step 3: Fetch PDFs with full logging
fetch_pdfs(
  input = "systematic_review/data/dois.csv",
  output_folder = "systematic_review/pdfs",
  log_file = "systematic_review/logs/download_log.csv",
  report_file = "systematic_review/logs/acquisition_report.md",
  email = "yourname@institution.edu"
)

# Step 4: Analyze results
log <- read.csv("systematic_review/logs/download_log.csv")
success_rate <- sum(log$success) / nrow(log) * 100
cat(sprintf("Success rate: %.1f%%\n", success_rate))

# Step 5: Review the auto-generated report
file.show("systematic_review/logs/acquisition_report.md")

# Step 6: Copy report content into your manuscript's methods section
```

---

## Function Comparison Guide

| Scenario | Recommended Function | Why |
|----------|---------------------|-----|
| Mixed IDs (DOIs + PMIDs + PMC) | `fetch_pdfs()` | Auto-detects and routes |
| CSV with unknown column type | `fetch_pdfs()` | Auto-detects column |
| Single ID of any type | `fetch_pdfs()` | Auto-detects ID type |
| Pure DOI list (CSV) | `fetch_pdfs_from_doi()` | Slightly faster (no detection) |
| Pure PMID list (CSV) | `fetch_pdfs_from_pmids()` | Slightly faster (no detection) |
| Large systematic review (>1000) | Specific function | More control, better performance |
| Need detailed logging | Any function | All support logging/reporting |

**General rule**: Use `fetch_pdfs()` for convenience, use specific functions for large-scale performance.

---

## Ethical Use & Legal Considerations

⚖️ **This package is designed for legal academic use:**

- ✅ Download papers you have **legitimate access to** (subscriptions, open access)
- ✅ Use for **personal research, systematic reviews, meta-analyses**
- ✅ Respect **publishers' Terms of Service**
- ✅ Rate-limit requests (default 2-second delays)
- ❌ Do NOT mass-download paywalled content you don't have rights to access
- ❌ Do NOT redistribute copyrighted PDFs publicly
- ❌ Do NOT circumvent authentication systems

**The package identifies itself honestly** as an academic scraper with your contact email. Most publishers permit automated retrieval for legitimate research purposes when done respectfully (rate-limited, identified).

### Legal Notice

Users are responsible for ensuring their use of `paperfetch` complies with:
- Publishers' Terms of Service
- Institutional policies
- Copyright laws in their jurisdiction
- Open access licenses (CC-BY, CC-BY-NC, etc.)

`paperfetch` facilitates access to content you already have rights to access—it does not grant additional rights.

---

## Troubleshooting

### "No PDF found" for Open Access Papers
- Verify the DOI/PMID is correct (typos are common)
- Check if the paper is truly open access (some "free to read" ≠ downloadable PDF)
- Some publishers block automated access even for OA content
- Try accessing the paper manually in a browser first
- Check the `download_log.csv` for specific failure reasons

### Timeouts on Slow Servers
Increase the timeout parameter:
```r
fetch_pdfs(..., timeout = 30)  # Increase to 30 seconds
```

### Inconsistent Download Success
- Check your internet connection
- Some journals (e.g., Elsevier, Wiley) have aggressive anti-bot measures
- Try reducing batch size and increasing delay
- Consider running downloads during off-peak hours (late night/weekend)
- Check if your institution's firewall is blocking requests

### CSV File Not Found
Ensure your CSV path is correct:
```r
# Check if file exists
file.exists("my_dois.csv")

# Use absolute path if needed
fetch_pdfs(
  input = "C:/Users/YourName/Documents/my_dois.csv",
  email = "you@edu"
)

# Or use file.choose() interactively
fetch_pdfs(
  input = file.choose(),
  email = "you@edu"
)
```

### "Please provide your real email address" Warning
The wrapper function reminds you to use a real email:
```r
# Wrong (triggers warning)
fetch_pdfs("dois.csv")  # Uses default "your@email.com"

# Correct
fetch_pdfs("dois.csv", email = "j.smith@university.edu")
```

### Low Success Rates (<40%)
- Check your DOI/PMID list for errors (malformed IDs)
- Verify papers are published (not just preprints or in-press)
- Many failures expected for paywalled content—this is normal
- Review `acquisition_report.md` for failure patterns
- Contact your institutional library for paywalled papers

### Download Log Shows "NA" for Methods
This indicates the download attempt failed before any method could be tried:
- Usually means invalid DOI/PMID format
- Could be network connectivity issues
- Check the `failure_reason` column for details

---

## Advanced Usage

### Custom Logging Paths

Organize logs by project or date:

```r
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")

fetch_pdfs(
  "dois.csv",
  email = "you@edu",
  log_file = paste0("logs/download_", timestamp, ".csv"),
  report_file = paste0("reports/acquisition_", timestamp, ".md")
)
```

### Parallel Downloads

For very large systematic reviews, split your CSV and run multiple R sessions:

```r
# Split into chunks
library(dplyr)
dois <- read.csv("all_dois.csv")
chunks <- split(dois, (seq(nrow(dois)) - 1) %/% 100)  # 100 DOIs per chunk

# Save chunks
for (i in seq_along(chunks)) {
  write.csv(chunks[[i]], paste0("chunk_", i, ".csv"), row.names = FALSE)
}

# Run each chunk in separate R sessions (different terminals/RStudio instances)
# Session 1:
fetch_pdfs("chunk_1.csv", output_folder = "papers", 
           log_file = "log_chunk1.csv", email = "you@edu")
# Session 2:
fetch_pdfs("chunk_2.csv", output_folder = "papers",
           log_file = "log_chunk2.csv", email = "you@edu")
# Session 3:
fetch_pdfs("chunk_3.csv", output_folder = "papers",
           log_file = "log_chunk3.csv", email = "you@edu")

# Merge logs afterward
library(dplyr)
all_logs <- list.files(pattern = "log_chunk.*\\.csv", full.names = TRUE) %>%
  lapply(read.csv) %>%
  bind_rows()
write.csv(all_logs, "complete_download_log.csv", row.names = FALSE)
```

### Programmatic Access to Results

The wrapper function returns a summary:

```r
results <- fetch_pdfs(my_ids, email = "you@edu")

# Returns:
# $total - Total number of IDs processed
# $successful - Number of successful downloads
# $failed - Number of failed downloads

cat(sprintf("Downloaded %d/%d papers (%.1f%% success)\n", 
            results$successful, 
            results$total,
            results$successful / results$total * 100))
```

### Integration with `targets` Pipeline

Use `paperfetch` in reproducible workflows:

```r
# _targets.R
library(targets)
library(paperfetch)

tar_plan(
  # Step 1: Define DOI list
  tar_target(doi_list, read.csv("data/dois.csv")),
  
  # Step 2: Fetch PDFs
  tar_target(
    pdf_download,
    fetch_pdfs(
      "data/dois.csv",
      output_folder = "pdfs",
      log_file = "logs/download_log.csv",
      report_file = "reports/acquisition_report.md",
      email = "you@edu"
    )
  ),
  
  # Step 3: Analyze download log
  tar_target(download_log, read.csv("logs/download_log.csv")),
  
  # Step 4: Generate summary
  tar_target(
    download_summary,
    data.frame(
      total = nrow(download_log),
      successful = sum(download_log$success),
      success_rate = sum(download_log$success) / nrow(download_log)
    )
  )
)
```

---

## Contributing

We welcome contributions! This package is under active development for the scientific community.

**How to contribute:**
1. Fork the repository: https://github.com/HGND-laboratory/paperfetch
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

**Priority areas:**
- 🔧 Additional publisher-specific scrapers (Springer, Nature, Cell Press)
- 📚 Support for arXiv IDs and bioRxiv DOIs
- 🤖 CAPTCHA handling strategies
- 🏛️ Institutional repository support (university repositories)
- 🔄 Better error recovery and retry logic
- ✅ PDF validation (ensure downloaded files are valid PDFs)
- 📊 Enhanced reporting (e.g., plots, HTML reports)
- 🧪 Unit tests and integration tests

**Found a bug?** Open an issue with:
- Your R version (`sessionInfo()`)
- Example IDs that failed
- Error messages from console
- Relevant log file entries

---

## Roadmap

**Version 0.1.0 (Current):**
- ✅ Intelligent wrapper function with auto-detection
- ✅ DOI and PMID batch downloading
- ✅ PMC ID to PMID conversion
- ✅ Structured logging with CSV output
- ✅ Auto-generated PRISMA-compliant reports
- ✅ Multi-source fallback (Unpaywall, PMC, DOI, scraping)

**Version 0.2.0 (Planned - Q2 2025):**
- [ ] Support for arXiv and bioRxiv preprints
- [ ] Enhanced reporting with HTML output and plots
- [ ] Parallel download support (built-in)
- [ ] PDF validation and metadata extraction
- [ ] Retry mechanism for failed downloads

**Version 0.3.0 (Planned - Q3 2025):**
- [ ] Integration with reference managers (Zotero API, Mendeley)
- [ ] Support for institutional repositories
- [ ] CAPTCHA detection and handling
- [ ] Shiny GUI for non-R users
- [ ] Publisher-specific optimizations (Elsevier, Springer, Wiley)

---

## Package Structure

```
paperfetch/
├── R/
│   ├── fetch_pdfs.R                # Intelligent wrapper function
│   ├── fetch_pdfs_from_doi.R       # DOI-specific function
│   ├── fetch_pdfs_from_pmids.R     # PMID-specific function
│   ├── logging.R                   # Log entry creation functions
│   ├── reporting.R                 # Report generation (generate_acquisition_report)
│   └── utils.R                     # Helper functions (classify_id, convert_pmc_to_pmid)
├── man/                            # Function documentation
├── tests/                          # Unit tests
│   └── testthat/
├── vignettes/
│   └── systematic_review_workflow.Rmd  # Tutorial
├── inst/
│   └── templates/
│       └── report_template.Rmd     # Report template
├── DESCRIPTION                     # Package metadata
├── NAMESPACE                       # Exported functions
├── LICENSE                         # MIT License
└── README.md                       # This file
```

---

## License

MIT License - see `LICENSE` file for details.

This means you can:
- ✅ Use commercially
- ✅ Modify
- ✅ Distribute
- ✅ Use privately

With conditions:
- Include original license
- Include copyright notice

---

## Contact

**Maintainer:** Kaalindi Misra  
**Email:** misra.kaalindi@hsr.it  
**GitHub:** https://github.com/HGND-laboratory/paperfetch  
**Issues:** https://github.com/HGND-laboratory/paperfetch/issues

For questions or support:
1. Check the [troubleshooting section](#troubleshooting)
2. Search [existing issues](https://github.com/HGND-laboratory/paperfetch/issues)
3. Open a new issue with details

For bug reports, please include:
- Your R version (`sessionInfo()`)
- Example IDs that failed
- Error messages from console
- Contents of `download_log.csv` (relevant rows)
- Operating system

---

## Acknowledgments

Built with:
- [httr2](https://httr2.r-lib.org/) - Modern HTTP client for R
- [rvest](https://rvest.tidyverse.org/) - Web scraping framework
- [xml2](https://xml2.r-lib.org/) - XML and HTML parsing
- [cli](https://cli.r-lib.org/) - Beautiful console output
- [progress](https://github.com/r-lib/progress) - Progress bars

Data sources:
- [Unpaywall](https://unpaywall.org/) - Open access discovery API (thank you!)
- [NCBI E-utilities](https://www.ncbi.nlm.nih.gov/books/NBK25501/) - PubMed/PMC APIs
- [PubMed Central](https://www.ncbi.nlm.nih.gov/pmc/) - Open access repository

Special thanks to:
- The open science community for making research more accessible
- All contributors who help improve this package
- Systematic review researchers who provided feedback on logging needs
- PRISMA developers for transparency standards

---

## Frequently Asked Questions

**Q: Why are some open access papers not downloading?**  
A: Not all "open access" papers have downloadable PDFs. Some are "read online only" or behind soft paywalls. The package tries Unpaywall, PMC, and scraping, but some publishers restrict automated access even for OA content.

**Q: Can I download paywalled papers if my institution has access?**  
A: Not automatically. The package doesn't handle institutional authentication (proxy/VPN). Download those papers manually through your library portal.

**Q: How fast can I download papers without getting blocked?**  
A: We recommend `delay = 2` seconds (default). For publishers with strict limits (Elsevier, Wiley), increase to `delay = 3` or `delay = 5`.

**Q: What success rate should I expect?**  
A: **Open access papers:** 60-80%. **Mixed (OA + paywalled):** 30-50%. **Purely paywalled:** <10%. Use your institution's library for the rest.

**Q: Can I use this for commercial purposes?**  
A: The package is MIT licensed (yes), but downloading copyrighted content for commercial use may violate publishers' ToS. Consult a lawyer.

**Q: How is paperfetch different from other PDF scrapers?**  
A: `paperfetch` is the only R package designed specifically for systematic reviews, with structured logging, PRISMA-compliant reports, and transparent audit trails. Other tools are general-purpose scrapers without reproducibility features.

**Q: Does paperfetch work with preprints?**  
A: Partial support. Works with DOIs from arXiv and bioRxiv if they resolve to PDFs. Full native support planned for v0.2.0.

**Q: Can I contribute publisher-specific scrapers?**  
A: Yes! We especially need help with Springer, Wiley, Taylor & Francis, and SAGE. See the [Contributing](#contributing) section.

**Q: How do I report bugs or request features?**  
A: Open an issue on [GitHub](https://github.com/misrak/paperfetch/issues) with details.

---

**⭐ Star this repo if `paperfetch` helps your research!**

**📢 Share with colleagues doing systematic reviews!**

**🐛 Report bugs and request features on GitHub!**

---

**paperfetch** - Making systematic reviews more transparent, reproducible, and efficient.