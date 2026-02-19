#' Look up and download a PDF from PubMed Central via DOI
#'
#' Given a DOI, queries the NCBI E-utilities API to find a linked PMC article,
#' then returns a Europe PMC direct PDF URL for download. Uses the
#' Europe PMC ptpmcrender endpoint which serves PDFs as application/pdf
#' without requiring JS rendering or scraping.
#' Used as a fallback in fetch_pdfs_from_doi() when Unpaywall fails.
#'
#' @param doi A single DOI string
#' @param email Email for NCBI API identification
#' @param user_agent User-agent string for HTTP requests
#' @param timeout Timeout in seconds
#' @param proxy Proxy URL or NULL
#'
#' @return A list with fields:
#'   \item{pdf_url}{Europe PMC PDF URL, or NULL if not found}
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
    
    # ── Step 3: Construct Europe PMC PDF URL ──────────────────────────────────
    # Europe PMC's ptpmcrender endpoint serves the PDF directly as
    # application/pdf — no JS rendering, no scraping, fully constructable.
    # NCBI efetch (rettype=pdf) returns XML not PDF despite the parameter name.
    article_url <- paste0("https://pmc.ncbi.nlm.nih.gov/articles/", pmc_id, "/")
    pdf_url     <- paste0(
      "https://europepmc.org/backend/ptpmcrender.fcgi",
      "?accid=", pmc_id,
      "&blobtype=pdf"
    )
    
    result$pmc_id      <- pmc_id
    result$article_url <- article_url
    result$pdf_url     <- pdf_url
    
    result$pmc_id      <- pmc_id
    result$article_url <- article_url
    result$pdf_url     <- pdf_url
    
  }, error = function(e) {
    # Silently return NULL result — caller handles failure reporting
  })
  
  return(result)
}
