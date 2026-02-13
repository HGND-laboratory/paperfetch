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

# Batch download from DOIs (recommended for systematic reviews)
fetch_pdfs_from_doi(
  csv_file_path = "my_review_dois.csv",
  output_folder = "papers",
  email = "yourname@institution.edu",  # Required for Unpaywall API
  delay = 2  # Polite delay between requests
)

# Batch download from PubMed IDs
fetch_pdfs_from_pmids(
  csv_file_path = "my_review_pmids.csv",
  output_folder = "papers",
  email = "yourname@institution.edu",
  delay = 2
)
```

---

## Functions

### `fetch_pdfs_from_doi()`
**The gold standard for systematic reviews** - downloads PDFs for multiple DOIs from a CSV file with intelligent fallback strategies.

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
- `delay`: Seconds to wait between requests (default: 2, be polite!)
- `email`: Your email for Unpaywall API identification (required)
- `timeout`: Maximum seconds to wait per request (default: 15)

**CSV Format:**
```csv
doi
10.1038/s41586-020-2649-2
10.1126/science.abc1234
10.1016/j.cell.2020.01.001
```

**Retrieval Strategy:**
1. **Unpaywall API** (fastest, ~50% success for OA papers) → Uses `best_oa_location` including PMC AWS
2. **DOI resolution + citation metadata** → Checks `citation_pdf_url` meta tags
3. **HTML scraping** → Searches for PDF links as last resort

---

### `fetch_pdfs_from_pmids()`
Downloads PDFs for multiple PubMed IDs from a CSV file.

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
- `csv_file_path`: Path to CSV file containing a `pmid` column
- `output_folder`: Directory for saving PDFs (created if doesn't exist)
- `delay`: Seconds to wait between requests (default: 2)
- `email`: Your email for identification
- `timeout`: Maximum seconds to wait per request (default: 15)

**CSV Format:**
```csv
pmid
30670877
28445112
31768060
```

---

## Features of Both Functions

- ✅ **Progress bar with ETA** - See how long your download will take
- ✅ **Skip existing files** - Resume interrupted downloads seamlessly
- ✅ **Colored console alerts** - Clear success/failure/info messages
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
```

### 2. **Use Institutional Email**
Unpaywall requires a valid email and works better with institutional addresses:

```r
fetch_pdfs_from_doi(
  csv_file_path = "dois.csv",
  output_folder = "papers",
  email = "j.smith@university.edu"  # Use your real institutional email
)
```

### 3. **Respect Rate Limits**
For large systematic reviews (>500 papers), increase the delay:

```r
fetch_pdfs_from_doi(
  csv_file_path = "large_review.csv",
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

Manually obtain failed papers through your library's interlibrary loan service.

### 5. **Organize Your Workflow**

```r
# Step 1: Create project structure
dir.create("systematic_review")
dir.create("systematic_review/pdfs")
dir.create("systematic_review/data")

# Step 2: Prepare ID list
write.csv(my_dois, "systematic_review/data/dois.csv", row.names = FALSE)

# Step 3: Fetch PDFs
fetch_pdfs_from_doi(
  csv_file_path = "systematic_review/data/dois.csv",
  output_folder = "systematic_review/pdfs",
  email = "yourname@institution.edu"
)

# Step 4: Check success rate
pdf_files <- list.files("systematic_review/pdfs", pattern = "\\.pdf$")
success_rate <- length(pdf_files) / nrow(my_dois) * 100
cat(sprintf("Success rate: %.1f%%\n", success_rate))
```

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
fetch_pdfs_from_doi(..., timeout = 30)
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
fetch_pdfs_from_doi(
  csv_file_path = "C:/Users/YourName/Documents/my_dois.csv",
  ...
)
```

---

## Advanced Usage

### Custom User-Agent
The package uses an honest User-Agent by default, but you can customize it if needed by modifying the source code.

### Parallel Downloads
For very large systematic reviews, consider splitting your CSV and running multiple R sessions:

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
fetch_pdfs_from_doi("chunk_1.csv", "papers", email = "you@edu")
# Session 2:
fetch_pdfs_from_doi("chunk_2.csv", "papers", email = "you@edu")
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
- Additional publisher-specific scrapers
- Support for PMC IDs, arXiv IDs, bioRxiv
- CAPTCHA handling strategies
- Institutional repository support
- Better error recovery strategies

---

## Citation

If you use `paperfetch` in your research, please cite:


---

## Roadmap

**Version 0.2.0 (planned):**
- [ ] Support for arXiv and bioRxiv preprints
- [ ] PMC ID direct downloads
- [ ] Automatic DOI/PMID conversion
- [ ] Parallel download support
- [ ] Enhanced logging and error reports

**Version 0.3.0 (planned):**
- [ ] Integration with reference managers (Zotero API)
- [ ] PDF metadata extraction and verification
- [ ] Support for institutional repositories
- [ ] GUI for non-R users

---

## License

MIT License - see `LICENSE` file for details.

---

## Contact

**Maintainer:** Kaalindi Misra  
**Email:** misra.kaalindi@hsr.it  
**Issues:** https://github.com/misrak/paperfetch/issues

---

## Acknowledgments

Built with:
- [httr2](https://httr2.r-lib.org/) - Modern HTTP client
- [rvest](https://rvest.tidyverse.org/) - Web scraping framework  
- [Unpaywall](https://unpaywall.org/) - Open access discovery API
- [NCBI E-utilities](https://www.ncbi.nlm.nih.gov/books/NBK25501/) - PubMed API

Special thanks to the open science community for making research more accessible.

---

**Star ⭐ this repo if `paperfetch` helps your research!**