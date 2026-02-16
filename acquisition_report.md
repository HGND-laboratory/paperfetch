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
  
The following records could not be retrieved:
  
### Paywalled Content (n=67)

```
10.1016/j.cell.2020.01.001
10.1126/science.abc1234
10.1038/s41586-020-1234-5
...
```

### No PDF Available (n=31)
```
10.1371/journal.pone.0123456
10.3389/fpsyg.2020.00789
...
```

### Technical Failures (n=18)
```
10.1002/jmri.26789 (timeout)
10.1093/brain/awz123 (http_500)
...
```

---
  
## Reproducibility Information
  
**System Information:**
- R version: 4.3.2
- paperfetch version: 0.1.0
- Platform: x86_64-pc-linux-gnu

**Parameters:**
- Email: yourname@institution.edu
- Delay between requests: 2 seconds
- Timeout per request: 15 seconds
- Date range: 2025-02-16 to 2025-02-16

**Data Sources:**
- Unpaywall API (https://unpaywall.org)
- PubMed Central (https://www.ncbi.nlm.nih.gov/pmc/)
- Publisher websites via DOI resolution

---
  
## Recommendations for Failed Records
  
1. **Paywalled content (n=67):** Request via institutional library or interlibrary loan
2. **No PDF available (n=31):** Check if articles are HTML-only or contact authors
3. **Technical failures (n=18):** Retry manually or contact publisher support

---
  
**Note:** This report is intended for inclusion in systematic review methodology sections to document full-text retrieval procedures in accordance with PRISMA guidelines.