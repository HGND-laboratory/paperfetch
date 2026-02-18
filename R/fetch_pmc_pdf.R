#' Look up and download a PDF from PubMed Central via DOI
#'
#' Given a DOI, queries the NCBI E-utilities API to find a linked PMC article,
#' then constructs the PMC PDF URL. Returns the PMC PDF URL if found, or NULL.
#' This is used as a fallback in fetch_pdfs_from_doi() when Unpaywall and
#' journal scraping both fail.
#'
#' @param doi A single DOI string
#' @param email Email for NCBI API identification
#' @param user_agent User-agent string for HTTP requests
#' @param timeout Timeout in seconds
#' @param proxy Proxy URL or NULL
#'
#' @return A list with fields:
#'   \item{pdf_url}{PMC PDF URL string, or NULL if not found}
#'   \item{article_url}{PMC article landing page URL, or NULL}
#'   \item{pmc_id}{PMC ID string e.g. "PMC1234567", or NULL}

fetch_pmc_pdf_url <- function(doi, email, user_agent, timeout = 15, proxy = NULL) {
  
  result <- list(pdf_url = NULL, article_url = NULL, pmc_id = NULL)
  
  tryCatch({
    # ── Step 1: DOI → PMID via NCBI E-utilities ──────────────────────────────
    esearch_url <- paste0(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi",
      "?db=pubmed&term=", utils::URLencode(doi, reserved = TRUE),
      "[DOI]&retmode=json&email=", email
    )
    
    esearch_resp <- build_request(
      url        = esearch_url,
      user_agent = user_agent,
      timeout    = timeout,
      proxy      = proxy
    ) %>%
      req_retry(max_tries = 3) %>%
      req_perform() %>%
      resp_body_json()
    
    pmids <- esearch_resp$esearchresult$idlist
    
    if (length(pmids) == 0) {
      return(result)  # DOI not found in PubMed
    }
    
    pmid <- pmids[[1]]
    
    # ── Step 2: PMID → PMC ID via E-link ─────────────────────────────────────
    elink_url <- paste0(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi",
      "?dbfrom=pubmed&db=pmc&id=", pmid,
      "&retmode=json&email=", email
    )
    
    elink_resp <- build_request(
      url        = elink_url,
      user_agent = user_agent,
      timeout    = timeout,
      proxy      = proxy
    ) %>%
      req_retry(max_tries = 3) %>%
      req_perform() %>%
      resp_body_json()
    
    # Navigate the elink JSON structure to extract PMC IDs
    linksets <- elink_resp$linksets
    if (length(linksets) == 0) return(result)
    
    linksetdbs <- linksets[[1]]$linksetdbs
    if (is.null(linksetdbs) || length(linksetdbs) == 0) return(result)
    
    # Find the pubmed_pmc linkset
    pmc_links <- NULL
    for (lsdb in linksetdbs) {
      if (!is.null(lsdb$linkname) && lsdb$linkname == "pubmed_pmc") {
        pmc_links <- lsdb$links
        break
      }
    }
    
    if (is.null(pmc_links) || length(pmc_links) == 0) return(result)
    
    pmc_num  <- pmc_links[[1]]  # numeric PMC ID e.g. 9234567
    pmc_id   <- paste0("PMC", pmc_num)
    
    # ── Step 3: Resolve actual PDF filename via redirect ──────────────────────
    # PMC serves PDFs from pmc.ncbi.nlm.nih.gov (not www.ncbi.nlm.nih.gov).
    # The /pdf/ path redirects to the real filename e.g. /pdf/zjae112.pdf.
    # PMC may need a few seconds server-side to prepare the file, so we retry.
    article_url  <- paste0("https://pmc.ncbi.nlm.nih.gov/articles/", pmc_id, "/")
    pdf_base_url <- paste0("https://pmc.ncbi.nlm.nih.gov/articles/", pmc_id, "/pdf/")
    pdf_url      <- NULL
    
    for (attempt in seq_len(3)) {
      tryCatch({
        redirect_resp <- build_request(
          url        = pdf_base_url,
          user_agent = user_agent,
          timeout    = timeout,
          proxy      = proxy
        ) %>%
          req_perform()
        
        final_url <- resp_url(redirect_resp)
        
        # If redirect resolved to a real PDF filename, use it
        if (grepl("\\.pdf$", final_url, ignore.case = TRUE)) {
          pdf_url <- final_url
        } else {
          pdf_url <- pdf_base_url  # let downloader try the base URL anyway
        }
      }, error = function(e) {
        if (attempt < 3) Sys.sleep(5)  # wait for PMC to prepare the PDF
      })
      if (!is.null(pdf_url)) break
    }
    
    if (is.null(pdf_url)) pdf_url <- pdf_base_url  # last resort
    
    result$pmc_id      <- pmc_id
    result$article_url <- article_url
    result$pdf_url     <- pdf_url
    
  }, error = function(e) {
    # Silently return NULL result — caller handles failure reporting
  })
  
  return(result)
}
