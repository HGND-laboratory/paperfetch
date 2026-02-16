# paperfetch

**Automated PDF retrieval for systematic reviews and meta-analyses**

`paperfetch` streamlines the acquisition of academic PDFs from multiple sources, enabling researchers to efficiently build literature databases for systematic reviews. The package intelligently combines open-access APIs with web scraping fallbacks to maximize successful retrieval rates.

---

## Features

✨ **Multi-source retrieval**: Attempts Unpaywall API (with PMC AWS indexing), DOI resolution, and citation metadata scraping  
📊 **Batch processing**: Download hundreds of papers from CSV files with progress tracking  
🔄 **Smart caching**: Automatically skips already-downloaded files  
⏱️ **Timeout protection**: Configurable timeouts prevent hanging on slow servers  
🎯 **Publication-ready**: Designed for reproducible research workflows  
🧠 **Intelligent wrapper**: Auto-detects input type (DOI, PMID, PMC ID, or CSV) and routes accordingly

---

## Installation

Install the development version from GitHub:

```r
# Install devtools if you haven't already
install.packages("devtools")

# Install paperfetch package
devtools::install_github("misrak/paperfetch")
```

**Dependencies:**
```r
install.packages(c("httr2", "rvest", "xml2", "readr", "dplyr", "cli", "progress"))
```

---

## Quick Start

```r
library(paperfetch)

# Simplest usage: automatic detection
fetch_pdfs("my_references.csv", email = "you@institution.edu")

# Works with vectors too
fetch_pdfs(
  c("10.1038/nature12373", "30670877", "PMC5176308"),
  email = "you@institution.edu"
)

# Or use specific functions for batch processing
fetch_pdfs_from_doi("dois.csv", "papers", email = "you@edu")
fetch_pdfs_from_pmids("pmids.csv", "papers", email = "you@edu")
```

---

## Main Functions

### `fetch_pdfs()` - Intelligent Wrapper (Recommended)

**Automatically detects input type and routes to the appropriate function.**

```r
fetch_pdfs(
  input = "my_references.csv",  # CSV file, vector of IDs, or single ID
  output_folder = "downloads",
  delay = 2,
  email = "yourname@institution.edu",
  timeout = 15,
  unfetched_file = "unfetched.txt"
)
```

**What it does:**
- 📁 **CSV input**: Detects column type (`doi`, `pmid`, `pubmed_id`) and routes to appropriate function
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
  c("10.1038/nature12373", "30670877", "PMC5176308", "10.1016/j.cell.2020.01.001"),
  output_folder = "papers",
  email = "you@edu",
  delay = 3
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
- `unfetched_file`: Log file for failed downloads (default: `"unfetched.txt"`)

---

### `fetch_pdfs_from_doi()` - DOI-Specific Batch Download

**The gold standard for systematic reviews with DOIs** - downloads PDFs for multiple DOIs from a CSV file with intelligent fallback strategies.

```r
fetch_pdfs_from_doi(
  csv_file_path = "systematic_review_dois.csv",
  output_folder = "downloaded_papers",
  delay = 2,
  email = "yourname@institution.edu",
  timeout = 15
)
```

**Arguments:**
- `csv_file_path`: Path to CSV file containing a `doi` column
- `output_folder`: Directory for saving PDFs (created if doesn't exist)
- `delay`: Seconds to wait between requests (default: `2`)
- `email`: Your email for Unpaywall API identification (**required**)
- `timeout`: Maximum seconds to wait per request (default: `15`)

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

**Downloads PDFs for multiple PubMed IDs from a CSV file.**

```r
fetch_pdfs_from_pmids(
  csv_file_path = "pubmed_ids.csv",
  output_folder = "papers",
  delay = 2,
  email = "yourname@institution.edu",
  timeout = 15
)
```

**Arguments:**
- `csv_file_path`: Path to CSV file containing a `pmid`, `PMID`, or `pubmed_id` column
- `output_folder`: Directory for saving PDFs (created if doesn't exist)
- `delay`: Seconds to wait between requests (default: `2`)
- `email`: Your email for identification
- `timeout`: Maximum seconds to wait per request (default: `15`)

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

## Shared Features

All functions include:

- ✅ **Progress bar with ETA** - See how long your download will take
- ✅ **Skip existing files** - Resume interrupted downloads seamlessly
- ✅ **Colored console alerts** - Clear success/failure/info messages
  - 🟢 `✔ Downloaded: ...` (success)
  - 🔴 `✖ No PDF found: ...` (failure)
  - 🔵 `ℹ Skipped (exists): ...` (already downloaded)
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

# Example: Extract PMIDs from PubMed search results
# Download as CSV from PubMed, then:
pmids <- read.csv("pubmed_results.csv")
write.csv(data.frame(pmid = pmids$PMID), "pmids.csv", row.names = FALSE)

# Or use the wrapper with a mixed list
my_ids <- c("10.1038/nature12373", "30670877", "PMC5176308")
fetch_pdfs(my_ids, email = "you@edu")
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

### 4. **Handle Failures Gracefully**

Not all papers will download (paywalls, broken links). The functions log all attempts:

```r
# After running, check console output for:
# ✔ Downloaded: 10.1038/... (success)
# ✖ No PDF found: 10.1016/... (failure - likely paywalled)
# ℹ Skipped (exists): 10.1126/... (already downloaded)
```

Failed downloads are logged to `unfetched.txt`. Manually obtain these papers through your library's interlibrary loan service.

### 5. **Organize Your Workflow**

```r
# Step 1: Create project structure
dir.create("systematic_review")
dir.create("systematic_review/pdfs")
dir.create("systematic_review/data")

# Step 2: Prepare ID list
write.csv(my_dois, "systematic_review/data/dois.csv", row.names = FALSE)

# Step 3: Fetch PDFs (use wrapper for convenience)
fetch_pdfs(
  input = "systematic_review/data/dois.csv",
  output_folder = "systematic_review/pdfs",
  email = "yourname@institution.edu"
)

# Step 4: Check success rate
pdf_files <- list.files("systematic_review/pdfs", pattern = "\\.pdf$")
success_rate <- length(pdf_files) / nrow(my_dois) * 100
cat(sprintf("Success rate: %.1f%%\n", success_rate))

# Step 5: Handle unfetched papers
unfetched <- readLines("unfetched.txt")
cat(sprintf("Unfetched papers: %d\n", length(unfetched)))
```

---

## Comparison: Which Function Should I Use?

| Scenario | Recommended Function | Why |
|----------|---------------------|-----|
| Mixed IDs (DOIs + PMIDs + PMC) | `fetch_pdfs()` | Auto-detects and routes |
| CSV with unknown column type | `fetch_pdfs()` | Auto-detects column |
| Single ID of any type | `fetch_pdfs()` | Auto-detects ID type |
| Pure DOI list (CSV) | `fetch_pdfs_from_doi()` | Slightly faster (no detection overhead) |
| Pure PMID list (CSV) | `fetch_pdfs_from_pmids()` | Slightly faster (no detection overhead) |
| Large systematic review (>1000) | Specific function | More control over parameters |

**General rule**: Use `fetch_pdfs()` for convenience, use specific functions for performance-critical large batches.

---

## Ethical Use & Legal Considerations

⚖️ **This package is designed for legal academic use:**

- ✅ Download papers you have **legitimate access to** (subscriptions, open access)
- ✅ Use for **personal research, systematic reviews, meta-analyses**
- ✅ Respect **publishers' Terms of Service**
- ❌ Do NOT mass-download paywalled content you don't have rights to access
- ❌ Do NOT redistribute copyrighted PDFs publicly

**The package identifies itself honestly** as an academic scraper with your contact email. Most publishers permit automated retrieval for legitimate research purposes when done respectfully (rate-limited, identified).

---

## Troubleshooting

### "No PDF found" for Open Access Papers
- Verify the DOI/PMID is correct
- Check if the paper is truly open access (some "free to read" ≠ downloadable PDF)
- Some publishers block automated access even for OA content
- Try accessing the paper manually in a browser first

### Timeouts on Slow Servers
Increase the timeout parameter:
```r
fetch_pdfs(..., timeout = 30)
```

### Inconsistent Download Success
- Check your internet connection
- Some journals (e.g., Elsevier, Wiley) have aggressive anti-bot measures
- Try reducing batch size and increasing delay
- Consider running downloads during off-peak hours

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
```

### "Please provide your real email address" Warning
The wrapper function reminds you to use a real email:
```r
# Wrong (triggers warning)
fetch_pdfs("dois.csv")  # Uses default "your@email.com"

# Correct
fetch_pdfs("dois.csv", email = "j.smith@university.edu")
```

---

## Advanced Usage

### Using Specific Functions for Performance

For very large datasets where you know the ID type, using specific functions avoids detection overhead:

```r
# If you have 5000 DOIs, use the specific function
fetch_pdfs_from_doi(
  "massive_review.csv",
  output_folder = "papers",
  delay = 2,
  email = "you@edu"
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

# Run each chunk in separate R sessions
# Session 1:
fetch_pdfs("chunk_1.csv", email = "you@edu")
# Session 2:
fetch_pdfs("chunk_2.csv", email = "you@edu")
# Session 3:
fetch_pdfs("chunk_3.csv", email = "you@edu")
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

---

## Contributing

We welcome contributions! This package is under active development for the scientific community.

**How to contribute:**
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

**Priority areas:**
- Additional publisher-specific scrapers (Springer, Nature, Cell Press)
- Support for arXiv IDs and bioRxiv DOIs
- CAPTCHA handling strategies
- Institutional repository support (e.g., university repositories)
- Better error recovery and retry logic
- PDF validation (ensure downloaded files are valid PDFs)

---

## Citation

If you use `paperfetch` in your research, please cite:

```
Misra, K. (2025). paperfetch: Automated PDF Retrieval for Systematic Reviews. 
R package version 0.1.0. https://github.com/misrak/paperfetch
```

**BibTeX:**
```bibtex
@Manual{paperfetch,
  title = {paperfetch: Automated PDF Retrieval for Systematic Reviews},
  author = {Kaalindi Misra},
  year = {2025},
  note = {R package version 0.1.0},
  url = {https://github.com/misrak/paperfetch},
}
```

---

## Roadmap

**Version 0.2.0 (planned):**
- [x] Intelligent wrapper function with auto-detection
- [x] PMC ID to PMID conversion
- [ ] Support for arXiv and bioRxiv preprints
- [ ] Parallel download support
- [ ] Enhanced logging with download reports

**Version 0.3.0 (planned):**
- [ ] Integration with reference managers (Zotero API)
- [ ] PDF metadata extraction and validation
- [ ] Support for institutional repositories
- [ ] Batch retry mechanism for failed downloads
- [ ] GUI for non-R users (Shiny app)

---

## Package Structure

```
paperfetch/
├── R/
│   ├── fetch_pdfs.R                # Intelligent wrapper function
│   ├── fetch_pdfs_from_doi.R       # DOI-specific function
│   ├── fetch_pdfs_from_pmids.R     # PMID-specific function
│   └── utils.R                     # Helper functions
├── man/                            # Documentation
├── tests/                          # Unit tests
├── DESCRIPTION
├── NAMESPACE
├── LICENSE
└── README.md
```

---

## License

MIT License - see `LICENSE` file for details.

---

## Contact

**Maintainer:** Kaalindi Misra  
**Email:** misra.kaalindi@hsr.it, kaalindi.misra@gmail.com  
**GitHub:** https://github.com/misrak/paperfetch  
**Issues:** https://github.com/misrak/paperfetch/issues

For bug reports, please include:
- Your R version (`sessionInfo()`)
- Example IDs that failed
- Error messages from console
- Contents of `unfetched.txt`

---

## Acknowledgments

Built with:
- [httr2](https://httr2.r-lib.org/) - Modern HTTP client for R
- [rvest](https://rvest.tidyverse.org/) - Web scraping framework
- [xml2](https://xml2.r-lib.org/) - XML and HTML parsing
- [Unpaywall](https://unpaywall.org/) - Open access discovery API
- [NCBI E-utilities](https://www.ncbi.nlm.nih.gov/books/NBK25501/) - PubMed/PMC APIs
- [cli](https://cli.r-lib.org/) - Beautiful console output

Special thanks to the open science community for making research more accessible, and to all contributors who help improve this package.

---

## Frequently Asked Questions

**Q: Why are some open access papers not downloading?**  
A: Not all "open access" papers have downloadable PDFs. Some are "read online only" or behind soft paywalls. The package does its best with Unpaywall, PMC, and scraping.

**Q: Can I download paywalled papers if my institution has access?**  
A: Not automatically. The package doesn't handle institutional authentication. Use your library's proxy or VPN, then try accessing the papers manually.

**Q: How fast can I download papers without getting blocked?**  
A: We recommend `delay = 2` seconds (default). For publishers with strict limits (Elsevier, Wiley), increase to `delay = 3` or `delay = 5`.

**Q: What's the success rate I should expect?**  
A: For open access papers: 60-80%. For mixed (OA + paywalled): 30-50%. For purely paywalled: <10%. Use your institution's library for the rest.

**Q: Can I use this for commercial purposes?**  
A: The package is MIT licensed (yes), but downloading copyrighted content for commercial use may violate publishers' ToS. Consult a lawyer.

---

**⭐ Star this repo if `paperfetch` helps your research!**

**📢 Share with colleagues doing systematic reviews!**