```
Package: paperfetch
Type: Package
Title: The Full-Text Acquisition Layer for Systematic Reviews in R
Version: 0.1.0
Authors@R: person(
    "Kaalindi", "Misra",
    role  = c("aut", "cre")
  )
Description: Provides transparent, reproducible PDF retrieval for systematic
    reviews and meta-analyses. Generates structured acquisition logs,
    PRISMA-compliant reports, validates downloaded files, and integrates
    with the PRISMA2020 package for flow diagram generation.
License: MIT + file LICENSE
Encoding: UTF-8
LazyData: true
Roxygen: list(markdown = TRUE)
RoxygenNote: 7.3.1
Imports:
    httr2,
    rvest,
    xml2,
    readr,
    dplyr,
    cli,
    progress
Suggests:
    synthesisr,
    PRISMA2020,
    pdftools  (>= 3.0.0),
    rmarkdown,
    knitr,
    testthat  (>= 3.0.0),
    withr,
    mockery,
    usethis
VignetteBuilder: knitr
URL: https://github.com/HGND-laboratory/paperfetch
BugReports: https://github.com/HGND-laboratory/paperfetch/issues
```