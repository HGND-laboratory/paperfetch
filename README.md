# paperfetch

**The full-text acquisition layer for systematic reviews in R**

`paperfetch` provides transparent, reproducible PDF retrieval for systematic
reviews and meta-analyses. Unlike general-purpose scrapers, `paperfetch`
generates **structured acquisition logs**, **PRISMA-compliant reports**,
**validates every downloaded file**, and bridges directly into the
**PRISMA 2020 flow diagram** — documenting the entire process for your
methods section.

---

## 🆕 Recent Updates (v0.1.1)

### 🚀 Overview
This patch addresses a critical logical error in the PRISMA flowchart generation and ensures full compatibility with R's namespace requirements.

### 🛠 Fixes & Improvements
* **Fix Logic Error**: Resolved the `condition has length > 1` error in `PRISMA_get_height_` by ensuring the line count is evaluated as a single scalar value.
* **Namespace Resolution**: Added explicit imports for `utils::read.csv` and `utils::assignInNamespace` to satisfy `R CMD check` and improve package stability.
* **Data Handling**: Improved handling of multi-line labels in the PRISMA diagram boxes to prevent vectorization conflicts during coordinate calculation.

### 📦 Maintenance
* Updated repository remote URL to reflect the name change to `paperfetch`.
* Incremented version to `0.1.1`.

---

## Why paperfetch?

### No other R package provides:

✅ **Structured download logs** — Every attempt documented with timestamps, methods, and HTTP status  
✅ **Reproducible acquisition reports** — Auto-generated Markdown reports ready for your manuscript  
✅ **PDF integrity validation** — Detects HTML error pages and corrupt files disguised as PDFs  
✅ **PRISMA 2020 integration** — Direct bridge to `PRISMA2020` flow diagrams  
✅ **Multi-database import** — Works with Web of Science, Scopus, Cochrane, and more  
✅ **Multi-source fallback** — Unpaywall → PMC (Europe PMC) → Elsevier TDM API → DOI resolution → Citation scraping → Journal URL patterns (NEJM, Lancet)  

### How paperfetch compares

| Feature | paperfetch | metagear | Manual downloading |
|---------|-----------|----------|-------------------|
| Batch PDF download | ✅ | ✅ | ❌ |
| Multi-source fallback | ✅ | ❌ | ❌ |
| PDF integrity validation | ✅ | ❌ | ❌ |
| Structured download logs | ✅ | ❌ | ❌ |
| PRISMA 2020 integration | ✅ | ❌ | ❌ |
| Multi-database import | ✅ | ✅ | ❌ |
| Resume interrupted downloads | ✅ | ❌ | ❌ |
| Proxy / VPN support | ✅ | ❌ | ✅ |

---

## Installation
```r
install.packages("devtools")
devtools::install_github("HGND-laboratory/paperfetch")
```

**Core dependencies:**
```r
install.packages(c("httr2", "rvest", "xml2", "readr", "dplyr", "cli", "progress"))
```

**Optional — unlock additional features:**
```r
# Multi-database import and deduplication
install.packages("synthesisr")

# PRISMA 2020 flow diagrams
install.packages("PRISMA2020")

# Advanced PDF validation
install.packages("pdftools")
```

---

## Quick Start

> ⚠️ **Email is required.** Unpaywall and NCBI both require a valid email address by their terms of service. Without it, requests may be rate-limited or blocked. Set it once in `.Renviron` (see [Setup](#setup-recommended)) so you never have to type it again.

### Option A — From a database export CSV (recommended)
```r
library(paperfetch)

# Use the included example dataset from PubMed (pain and genetics literature)
import_refs("inst/extdata/csv-painANDgen-set.csv") |>
  fetch_refs_pdfs(email = Sys.getenv("PAPERFETCH_EMAIL"))
```

### Option B — From a CSV of DOIs directly
```r
library(paperfetch)

# Use the included example DOI list for testing
fetch_pdfs(
  input       = "inst/extdata/dois.csv",
  email       = "you@institution.edu",
  log_file    = "download_log.csv",
  report_file = "acquisition_report.md"
)
```

After completion you will have:

1. ✅ **Downloaded PDFs** in `downloads/`
2. 📋 **`download_log.csv`** — Complete acquisition audit trail
3. 📄 **`acquisition_report.md`** — PRISMA-ready summary with counts for your manuscript

### 🧪 Example Datasets Included

The package includes two example datasets for testing:

| File | Description | Use Case |
|------|-------------|----------|
| `inst/extdata/dois.csv` | Simple DOI list | Quick testing of `fetch_pdfs()` |
| `inst/extdata/csv/csv-painANDgen-set.csv` | PubMed export (pain & genetics) | Full workflow with `import_refs()` |

---

## Setup (Recommended)

Save your credentials once in `.Renviron` so you never have to type them again:
```r
# Open .Renviron for editing
usethis::edit_r_environ()
```

Add these lines and **restart R**:
```
PAPERFETCH_EMAIL="yourname@institution.edu"
PAPERFETCH_PROXY="http://proxyserver.univ.edu:8080"  # only if needed
ELSEVIER_API_KEY="your_api_key"                      # get free key at dev.elsevier.com
ELSEVIER_INSTTOKEN="your_insttoken"                  # request from your library
```

Now you can call all functions without repeating your email:
```r
# Email is picked up automatically from .Renviron
fetch_pdfs("dois.csv")
```

> ⚠️ Never commit `.Renviron` to version control. Add it to `.gitignore`.

---

## Core Workflow
```r
library(paperfetch)

# ── Step 1: Import from multiple databases ─────────────────────────────────────
refs <- import_refs(
  files    = c("wos_export.bib", "scopus_export.ris", "cochrane_results.txt"),
  match_by = "doi"
)

# ── Step 2: Download with automatic validation ─────────────────────────────────
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

# ── Step 3: Review the acquisition report ─────────────────────────────────────
file.show("acquisition_report.md")

# ── Step 4: Extract PRISMA 2020 counts ────────────────────────────────────────
prisma_stats <- as_prisma_counts("download_log.csv")

# ── Step 5: Generate PRISMA 2020 flow diagram ─────────────────────────────────
if (requireNamespace("PRISMA2020", quietly = TRUE)) {
  plot_prisma_fulltext(
    prisma_counts   = prisma_stats,
    previous_counts = list(
      database_results   = 892,   # From your database searches
      duplicates_removed = 238,   # Removed by import_refs()
      records_screened   = 654,   # Title/abstract screening
      records_excluded   = 126    # Excluded at screening
    ),
    save_path = "figures/prisma_diagram.png"
  )
}

# ── Step 6 (Optional): Advanced PDF validation ────────────────────────────────
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

## Importing from Multiple Databases

Systematic reviews draw from multiple databases. `paperfetch` integrates
with [`synthesisr`](https://github.com/mjwestgate/synthesisr) to import
and deduplicate before fetching.

### Recommended export formats

| Database | Format | Extension |
|----------|--------|-----------|
| Web of Science | BibTeX or Plain Text | `.bib`, `.txt` |
| Scopus | RIS or CSV | `.ris`, `.csv` |
| Cochrane | Plain Text or RIS | `.txt`, `.ris` |
| PubMed | PubMed format or CSV | `.txt`, `.csv` |
| Embase | RIS | `.ris` |
| PsycINFO | RIS | `.ris` |
| CINAHL | RIS | `.ris` |
| Google Scholar | BibTeX | `.bib` |
```r
# Standard import workflow
refs <- import_refs(
  files    = c("wos_export.bib", "scopus_export.ris", "cochrane_results.txt"),
  match_by = "doi"
)
# ✔ Imported 412 records from wos_export.bib
# ✔ Imported 287 records from scopus_export.ris
# ✔ Imported 193 records from cochrane_results.txt
# ℹ Duplicates removed: 238 (26.7%)
# ✔ Unique records: 654

# Pipe-friendly workflow
import_refs(c("wos_export.bib", "scopus_export.ris")) |>
  fetch_refs_pdfs(email = "you@institution.edu")
```

> 💡 **Pro-tip:** Dealing with messy exports from Web of Science or Scopus?
> Use `import_refs(deduplicate = TRUE, match_by = c("doi", "title"))` for
> the most thorough deduplication before fetching.

---

## PRISMA 2020 Integration

`paperfetch` is the only PDF retrieval package that bridges directly into
the PRISMA 2020 flow diagram via the
[`PRISMA2020`](https://github.com/MatthewBJane/PRISMA2020) package.

### Extract counts
```r
prisma_stats <- as_prisma_counts("download_log.csv")

# Output:
# ── PRISMA 2020 Full-Text Retrieval Counts ──────────────
#   Reports sought for retrieval:  528
#   Reports not retrieved:         116
#   Reports excluded (invalid PDF): 15
#   Reports acquired:              397
# ────────────────────────────────────────────────────────
```

### PRISMA field mapping

| PRISMA 2020 Field | paperfetch Source |
|-------------------|-------------------|
| Reports sought for retrieval | All active rows in log |
| Reports not retrieved | `success == FALSE` |
| Reports excluded (invalid PDF) | `pdf_valid == FALSE` |
| Reports acquired | `success == TRUE & pdf_valid == TRUE` |

### Generate flow diagram
```r
# Full-text section only
plot_prisma_fulltext(prisma_stats)

# Full diagram with all phases
plot_prisma_fulltext(
  prisma_counts   = prisma_stats,
  previous_counts = list(
    database_results   = 892,
    duplicates_removed = 238,
    records_screened   = 654,
    records_excluded   = 126
  ),
  save_path = "figures/prisma_diagram.png"
)
```

The acquisition report (`acquisition_report.md`) also includes a
pre-formatted PRISMA table and ready-to-run code for your methods section.

---

## PDF Integrity Validation

Scrapers frequently encounter **soft failures** — files named `.pdf`
that are actually HTML error pages or corrupt downloads. `paperfetch`
catches these automatically.

| Invalid type | Description |
|-------------|-------------|
| `html_error_page` | HTML "Access Denied" page disguised as PDF |
| `file_too_small` | File under 10 KB — almost certainly an error response |
| `missing_eof_marker` | Corrupt PDF missing the `%%EOF` marker |
| `invalid_pdf_format` | File does not begin with `%PDF-` header |
| `corrupted_pdf` | PDF is damaged (advanced validation only) |
| `password_protected` | PDF is password-protected (advanced validation only) |
```r
# Validation is ON by default
fetch_pdfs_from_doi(...) # validate_pdfs = TRUE, remove_invalid = TRUE

# Keep invalid files for inspection
fetch_pdfs_from_doi(..., validate_pdfs = TRUE, remove_invalid = FALSE)

# Advanced validation with pdftools
validate_pdfs_after_download("papers", use_advanced = TRUE)
```

---

## Main Functions

| Function | Description |
|----------|-------------|
| `fetch_pdfs()` | Intelligent wrapper — auto-detects CSV, vectors, single IDs |
| `fetch_pdfs_from_doi()` | DOI batch download with full logging |
| `fetch_pdfs_from_pmids()` | PMID batch download with full logging |
| `import_refs()` | Import + deduplicate from multiple databases |
| `fetch_refs_pdfs()` | Pipe-friendly wrapper for `import_refs()` output |
| `as_prisma_counts()` | Extract PRISMA 2020 counts from download log |
| `plot_prisma_fulltext()` | Generate PRISMA 2020 flow diagram |
| `check_pdf_integrity()` | Validate all PDFs in a folder |
| `validate_pdfs_after_download()` | Post-download validation with report update |

---

## Structured Download Logs

| Field | Description | Example |
|-------|-------------|---------|
| `id` | DOI, PMID, or PMC ID | `10.1038/nature12373` |
| `id_type` | Type of identifier | `doi`, `pmid`, `pmc` |
| `timestamp` | ISO 8601 timestamp | `2025-02-16T14:23:45Z` |
| `method` | Retrieval method used | `unpaywall`, `pmc_fallback`, `elsevier_api`, `journal_url_pattern`, `citation_metadata`, `scrape` |
| `status` | HTTP status code | `200`, `403`, `404`, `timeout` |
| `success` | Download succeeded | `TRUE`, `FALSE` |
| `failure_reason` | Why it failed | `paywalled`, `no_pdf_found`, `timeout`, `file_too_small`, `missing_eof_marker`, `elsevier_no_entitlement` |
| `pdf_url` | Final PDF URL | `https://ncbi.nlm.nih.gov/pmc/...` |
| `file_path` | Local file path | `papers/10_1038_nature12373.pdf` |
| `file_size_kb` | File size in KB | `1024.5` |
| `pdf_valid` | Passed integrity check | `TRUE`, `FALSE` |
| `pdf_invalid_reason` | Why validation failed | `html_error_page` |

---

## Proxy and VPN Support

### System-wide VPN (NordVPN, Cisco AnyConnect)

No configuration needed — `httr2` picks up system-wide VPN automatically.

### Manual proxy (corporate or institutional networks)
```r
# Pass proxy directly
fetch_pdfs("dois.csv", proxy = "http://proxyserver.univ.edu:8080")

# With authentication
fetch_pdfs("dois.csv", proxy = "http://user:password@proxy.univ.edu:8080")

# Or set permanently in .Renviron (recommended)
# PAPERFETCH_PROXY="http://proxyserver.univ.edu:8080"
```

Proxy resolution order:

1. Explicit `proxy` argument
2. `PAPERFETCH_PROXY` in `.Renviron`
3. `HTTPS_PROXY` / `HTTP_PROXY` system environment variables
4. System-wide VPN (automatic)

> 💡 **Pro-tip:** If your first 100 requests succeed but then you start
> getting 403 errors, your institutional IP may be rate-limited. Increase
> `delay = 3` or connect via your university VPN.

---

## Best Practices for Systematic Reviews

### 1. Save credentials in `.Renviron`
```r
usethis::edit_r_environ()
# Add: PAPERFETCH_EMAIL="yourname@institution.edu"
# Restart R
```

### 2. Prepare your ID list
```r
# From a BibTeX file
library(bib2df)
refs <- bib2df("my_references.bib")
write.csv(data.frame(doi = refs$DOI), "dois.csv", row.names = FALSE)

# From multiple databases (recommended)
refs <- import_refs(c("wos_export.bib", "scopus_export.ris"))
```

### 3. Respect rate limits
```r
# Default (2s) is fine for most publishers
fetch_pdfs("dois.csv", delay = 2)

# Increase for Elsevier / Wiley
fetch_pdfs("dois.csv", delay = 3)
```

### 4. Organise for PRISMA compliance
```r
dir.create("systematic_review/pdfs",    recursive = TRUE)
dir.create("systematic_review/logs",    recursive = TRUE)
dir.create("systematic_review/figures", recursive = TRUE)

fetch_pdfs_from_doi(
  csv_file_path = "systematic_review/data/dois.csv",
  output_folder = "systematic_review/pdfs",
  log_file      = "systematic_review/logs/download_log.csv",
  report_file   = "systematic_review/logs/acquisition_report.md",
  email         = "yourname@institution.edu"
)

prisma_stats <- as_prisma_counts("systematic_review/logs/download_log.csv")
plot_prisma_fulltext(prisma_stats, save_path = "systematic_review/figures/prisma.png")
```

### 5. Handle failures systematically
```r
log <- read.csv("download_log.csv")

# Export paywalled papers for library interlibrary loan request
write.csv(
  log[grepl("paywalled|elsevier_no_entitlement", log$failure_reason), "id", drop = FALSE],
  "library_requests.csv", row.names = FALSE
)
```

> 💡 See the [Troubleshooting](#troubleshooting) section for a full breakdown of failure codes and how to handle each one.

---

## Troubleshooting

### Low success rate
- Check DOIs/PMIDs for typos or malformed IDs
- Many failures expected for paywalled content without institutional credentials
- Review `acquisition_report.md` for failure patterns by journal/publisher

### Understanding failure codes in `download_log.csv`

| `failure_reason` | Meaning | What to do |
|-----------------|---------|------------|
| `paywalled` | Journal returned 403 — subscription required | Use institutional proxy or request via library |
| `no_pdf_found` | No PDF URL found by any method | Check DOI is correct; paper may be preprint-only |
| `file_too_small` | Downloaded file is too small to be a real PDF — likely an HTML redirect or login page | Usually resolves after PMC fix; otherwise paywalled |
| `missing_eof_marker` | PDF downloaded but `%%EOF` marker not found in last 2KB — common with Europe PMC and some repositories | File is accepted as valid with a warning; open manually to verify |
| `elsevier_no_entitlement` | Elsevier API key set but no institutional token | Request `ELSEVIER_INSTTOKEN` from your library |
| `elsevier_unauthorized` | Elsevier API key invalid or expired | Check `ELSEVIER_API_KEY` in `.Renviron` |
| `not_found` | URL returned 404 — article not at expected location | PMC record exists but no PDF deposited; paper will fall through to journal scraping |
| `timeout` | Request exceeded time limit | Retry with `timeout = 30` |
| `server_error` | Publisher server error (500/502/503) | Retry later |

### Handle failures systematically
```r
log <- read.csv("download_log.csv")

# Export paywalled papers for library request
write.csv(
  log[grepl("paywalled|elsevier_no_entitlement", log$failure_reason), "id", drop = FALSE],
  "library_requests.csv", row.names = FALSE
)

# Retry timeouts with a longer timeout
timeouts <- log[grepl("timeout|missing_eof", log$failure_reason), "id"]
fetch_pdfs(timeouts, timeout = 30)
```

### MDPI journals returning `paywalled` despite being open access
MDPI uses Akamai bot detection that blocks all automated HTTP requests — including headless browsers (`chromote`, `pagedown`) — because they lack the verified human telemetry (mouse movements, cookies, TLS fingerprint) that Akamai requires. This affects all MDPI journals (`10.3390/`) regardless of OA status.

**Workaround:** Use Zotero, which maintains a verified browser session that passes Akamai's checks. Zotero API integration is planned for v0.2.0. In the meantime, download MDPI papers manually or via your institutional library.

### `paywalled` on journals that should be open access
- Common with PMC when the server needs time to prepare the PDF — this is handled automatically with retries, but very new articles may not have their PDF ready yet
- Also common with Elsevier/Wiley anti-bot responses when no API key is set
- Check `pdf_invalid_reason` column in `download_log.csv`
- Set `remove_invalid = FALSE` to inspect files before deletion

### Timeouts
```r
fetch_pdfs_from_doi(..., timeout = 30)
```

### IP rate-limited after many requests
```r
# Increase delay and use VPN
fetch_pdfs("dois.csv", delay = 5, proxy = "http://vpn.univ.edu:8080")
```

### CSV column not found
```r
colnames(read.csv("my_file.csv"))   # Check column names
fetch_pdfs(input = file.choose())   # Or use interactive picker
```

---

## Contributing

1. Fork: https://github.com/HGND-laboratory/paperfetch
2. Branch: `git checkout -b feature/my-feature`
3. Commit: `git commit -m 'Add my feature'`
4. Push: `git push origin feature/my-feature`
5. Pull Request

**Priority areas:** publisher-specific scrapers, arXiv/bioRxiv support,
HTML report output, PDF metadata extraction, institutional repository support.

---

## Roadmap

**v0.1.1 (Current)** — Patch Release
- ✅ Fixed critical `PRISMA_get_height_` logic error (`condition has length > 1`)
- ✅ Added proper namespace imports for R CMD check compliance
- ✅ Improved multi-line label handling in PRISMA diagrams
- ✅ Repository name updated to `paperfetch`

**v0.1.0** — Initial Release
- ✅ `fetch_pdfs()`, `fetch_pdfs_from_doi()`, `fetch_pdfs_from_pmids()`
- ✅ Structured CSV logging and PRISMA-compliant reports
- ✅ PDF integrity validation (basic and advanced)
- ✅ Multi-database import via `synthesisr`
- ✅ PRISMA 2020 integration via `as_prisma_counts()` and `plot_prisma_fulltext()`
- ✅ Proxy and VPN support
- ✅ `.Renviron` credential management
- ✅ PMC fallback via NCBI E-utilities + Europe PMC direct PDF endpoint
- ✅ Elsevier TDM API support (Lancet, Cell, EJCA, and all Elsevier journals)
- ✅ Journal-specific URL patterns (NEJM, Lancet family)
- ✅ Graceful handling of `embedded nul` binary PDF downloads
- ✅ PMC 404 fallthrough — articles without a deposited PDF fall back to journal scraping
- ✅ PDF validation hardened — `%%EOF` absence no longer rejects valid PDFs

**v0.2.0 (Planned)**
- [ ] Zotero API integration — bridge for Akamai-protected publishers (MDPI, Wiley) that block all automated requests including headless browsers; Zotero's verified browser session can retrieve these
- [ ] arXiv and bioRxiv support
- [ ] Optional interactive HTML reports
- [ ] Built-in parallel downloads
- [ ] Automatic retry for failed downloads

**v0.3.0 (Planned)**
- [ ] Institutional repository support
- [ ] Shiny GUI
- [ ] Publisher-specific optimisations

---

## Package Structure
```
paperfetch/
├── R/
│   ├── fetch_pdfs.R
│   ├── fetch_pdfs_from_doi.R
│   ├── fetch_pdfs_from_pmids.R
│   ├── get_elsevier_pdf.R
│   ├── fetch_pmc_pdf.R
│   ├── construct_journal_pdf_url.R
│   ├── import_refs.R
│   ├── prisma.R
│   ├── pdf_validation.R
│   ├── reporting.R
│   └── utils.R
├── inst/
│   └── extdata/
│       ├── dois.csv                        # Example DOI list for testing
│       └── csv-painANDgen-set.csv          # Example PubMed export
├── tests/
│   ├── testthat.R
│   └── testthat/
│       ├── helper-mocks.R              # Shared helpers, auto-loaded
│       ├── test-utils.R                # classify_id, resolve_email, etc.
│       ├── test-pdf-validation.R       # validate_pdf, check_pdf_integrity
│       ├── test-prisma.R               # as_prisma_counts, plot_prisma_fulltext
│       ├── test-import-refs.R          # import_refs, fetch_refs_pdfs
│       └── test-fetch-pdfs.R           # fetch_pdfs wrapper
├── vignettes/
│   ├── systematic-review-workflow.Rmd  # End-to-end workflow
│   ├── importing-from-databases.Rmd    # Database export guides
│   └── prisma-integration.Rmd         # PRISMA 2020 flow diagrams
├── man/                                # Generated by roxygen2
├── DESCRIPTION
├── NAMESPACE
├── LICENSE
└── README.md
```

---


## License

MIT — see `LICENSE` for details.

---

## Contact

**Maintainer:** Kaalindi Misra 
**GitHub:** https://github.com/HGND-laboratory/paperfetch  
**Issues:** https://github.com/HGND-laboratory/paperfetch/issues

---

## Acknowledgments

Built with [httr2](https://httr2.r-lib.org/), [rvest](https://rvest.tidyverse.org/),
[xml2](https://xml2.r-lib.org/), [cli](https://cli.r-lib.org/),
[progress](https://github.com/r-lib/progress).

Data sources: [Unpaywall](https://unpaywall.org),
[PubMed Central](https://www.ncbi.nlm.nih.gov/pmc/),
[NCBI E-utilities](https://www.ncbi.nlm.nih.gov/books/NBK25501/),
[Europe PMC](https://europepmc.org),
[Elsevier TDM API](https://dev.elsevier.com).

Integrations: [synthesisr](https://github.com/mjwestgate/synthesisr),
[PRISMA2020](https://github.com/MatthewBJane/PRISMA2020).

---

**⭐ Star this repo if `paperfetch` helps your research!**  
**📢 Share with colleagues running systematic reviews!**
