#' Classify ID Type
#'
#' Helper function to detect if input is DOI, PMID, PMC ID, or unknown
#'
#' @param id A single ID string
#' @return Character string: "doi", "pmid", "pmc", or "unknown"
#' @keywords internal

classify_id <- function(id) {
  id <- as.character(id)
  
  if (grepl("^10\\.\\d{4,9}/[-._;()/:A-Z0-9]+$", id, ignore.case = TRUE)) return("doi")
  if (grepl("^PMC\\d+$", id, ignore.case = TRUE)) return("pmc")
  if (grepl("^\\d+$", id)) return("pmid")
  
  return("unknown")
}


#' Convert PMC IDs to PMIDs
#'
#' Uses NCBI E-utilities to convert PMC IDs to PubMed IDs
#'
#' @param pmc_ids Vector of PMC IDs (with or without "PMC" prefix)
#' @return Vector of PMIDs (NA for failed conversions)
#' @keywords internal

convert_pmc_to_pmid <- function(pmc_ids) {
  
  
  pmc_ids <- gsub("^(?!PMC)", "PMC", pmc_ids, perl = TRUE)
  
  pmids <- sapply(pmc_ids, function(pmc_id) {
    tryCatch({
      url <- paste0(
        "https://www.ncbi.nlm.nih.gov/pmc/utils/idconv/v1.0/?ids=",
        pmc_id, "&format=json"
      )
      response <- request(url) %>%
        req_timeout(10) %>%
        req_perform() %>%
        resp_body_json()
      
      if (length(response$records) > 0 && !is.null(response$records[[1]]$pmid)) {
        return(response$records[[1]]$pmid)
      }
      return(NA_character_)
    }, error = function(e) NA_character_)
  })
  
  pmids[!is.na(pmids)]
}


#' Create Log Entry
#'
#' Creates a standardized single-row log entry
#'
#' @param id DOI, PMID, or PMC ID
#' @param id_type Type of identifier ("doi", "pmid", "pmc")
#' @param timestamp ISO 8601 timestamp
#' @param method Retrieval method attempted
#' @param status HTTP status code or "timeout", "error", "exists"
#' @param success Logical indicating success
#' @param failure_reason Why it failed (if applicable)
#' @param pdf_url Final PDF URL (if found)
#' @param file_path Local file path
#' @param file_size_kb File size in KB
#' @param pdf_valid Logical indicating PDF validation result
#' @param pdf_invalid_reason Reason for PDF invalidation
#' @return Single-row data frame
#' @keywords internal

create_log_entry <- function(id, id_type, timestamp, method, status, success, 
                             failure_reason, pdf_url, file_path, file_size_kb,
                             pdf_valid = NA, pdf_invalid_reason = NA_character_) {
  data.frame(
    id                 = id,
    id_type            = id_type,
    timestamp          = timestamp,
    method             = method,
    status             = status,
    success            = success,
    failure_reason     = failure_reason,
    pdf_url            = pdf_url,
    file_path          = file_path,
    file_size_kb       = file_size_kb,
    pdf_valid          = pdf_valid,
    pdf_invalid_reason = pdf_invalid_reason,
    stringsAsFactors   = FALSE
  )
}


#' Resolve Email for Unpaywall API
#'
#' Checks for email in the following order:
#'   1. Explicitly passed `email` argument
#'   2. PAPERFETCH_EMAIL environment variable (set in .Renviron)
#'   3. Warning if neither is found
#'
#' @param email Email string passed by the user (or NULL)
#' @return Resolved email string
#'
#' @details
#' To avoid passing your email in every function call, add this line
#' to your `.Renviron` file:
#'
#' ```
#' PAPERFETCH_EMAIL="yourname@institution.edu"
#' ```
#'
#' Open `.Renviron` with:
#' ```r
#' usethis::edit_r_environ()
#' ```
#' Then restart R.
#'
#' @keywords internal

resolve_email <- function(email = NULL) {
  
  # Priority 1: Explicitly passed argument
  if (!is.null(email) && nchar(email) > 0 && email != "your@email.com") {
    return(email)
  }
  
  # Priority 2: Environment variable
  env_email <- Sys.getenv("PAPERFETCH_EMAIL", unset = "")
  if (nchar(env_email) > 0) {
    return(env_email)
  }
  
  # Priority 3: Warn and return placeholder
  cli::cli_alert_warning(c(
    "No email provided for Unpaywall API identification.",
    "i" = "Pass {.arg email} directly, or set {.envvar PAPERFETCH_EMAIL} in your {.file .Renviron}:",
    " " = "{.code usethis::edit_r_environ()}",
    " " = "Then add: {.code PAPERFETCH_EMAIL=\"yourname@institution.edu\"}",
    " " = "And restart R."
  ))
  
  return("anonymous@paperfetch.r")
}


#' Configure Proxy for httr2 Request
#'
#' Applies proxy settings to an httr2 request object. Supports:
#'   - Explicit proxy argument
#'   - PAPERFETCH_PROXY environment variable
#'   - System-wide proxy (HTTPS_PROXY / HTTP_PROXY env vars)
#'
#' @param req An httr2 request object
#' @param proxy Proxy URL string (e.g., "http://proxy.univ.edu:8080"), or NULL
#' @return Modified httr2 request object
#'
#' @details
#' Proxy resolution order:
#'   1. Explicit `proxy` argument
#'   2. `PAPERFETCH_PROXY` environment variable
#'   3. `HTTPS_PROXY` / `HTTP_PROXY` system environment variables
#'   4. System-wide VPN (httr2 picks this up automatically via OS)
#'
#' To set a persistent proxy, add to `.Renviron`:
#' ```
#' PAPERFETCH_PROXY="http://proxyserver.univ.edu:8080"
#' ```
#'
#' @keywords internal

apply_proxy <- function(req, proxy = NULL) {
  
  # Priority 1: Explicit argument
  resolved_proxy <- proxy
  
  # Priority 2: PAPERFETCH_PROXY env var
  if (is.null(resolved_proxy)) {
    env_proxy <- Sys.getenv("PAPERFETCH_PROXY", unset = "")
    if (nchar(env_proxy) > 0) {
      resolved_proxy <- env_proxy
    }
  }
  
  # Priority 3: Standard HTTPS_PROXY / HTTP_PROXY
  if (is.null(resolved_proxy)) {
    system_proxy <- Sys.getenv("HTTPS_PROXY", 
                               unset = Sys.getenv("HTTP_PROXY", unset = ""))
    if (nchar(system_proxy) > 0) {
      resolved_proxy <- system_proxy
    }
  }
  
  # Apply proxy if found
  if (!is.null(resolved_proxy) && nchar(resolved_proxy) > 0) {
    req <- req %>% httr2::req_proxy(url = resolved_proxy)
  }
  
  return(req)
}


#' Build Standard paperfetch Request
#'
#' Creates a base httr2 request with consistent user-agent,
#' proxy, and timeout applied. Use this instead of calling
#' request() directly throughout the package.
#'
#' @param url URL string
#' @param user_agent User-agent string
#' @param timeout Timeout in seconds
#' @param proxy Proxy URL string or NULL
#' @return Configured httr2 request object
#' @keywords internal

build_request <- function(url, user_agent, timeout, proxy = NULL) {
  httr2::request(url) %>%
    httr2::req_user_agent(user_agent) %>%
    httr2::req_timeout(timeout) %>%
    apply_proxy(proxy)
}