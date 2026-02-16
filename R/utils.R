#' Classify ID Type
#'
#' Helper function to detect if input is DOI, PMID, PMC ID, or unknown
#'
#' @param id A single ID string
#' @return Character string: "doi", "pmid", "pmc", or "unknown"
#' @keywords internal

classify_id <- function(id) {
  id <- as.character(id)
  
  # DOI pattern
  if (grepl("^10\\.\\d{4,9}/[-._;()/:A-Z0-9]+$", id, ignore.case = TRUE)) {
    return("doi")
  }
  
  # PMC ID pattern
  if (grepl("^PMC\\d+$", id, ignore.case = TRUE)) {
    return("pmc")
  }
  
  # PMID pattern
  if (grepl("^\\d+$", id)) {
    return("pmid")
  }
  
  return("unknown")
}


#' Convert PMC IDs to PMIDs
#'
#' Uses NCBI E-utilities to convert PMC IDs to PubMed IDs
#'
#' @param pmc_ids Vector of PMC IDs (with or without "PMC" prefix)
#' @return Vector of PMIDs (same length, NA for failed conversions)
#' @keywords internal

convert_pmc_to_pmid <- function(pmc_ids) {
  require(httr2)
  
  # Ensure PMC prefix
  pmc_ids <- gsub("^(?!PMC)", "PMC", pmc_ids, perl = TRUE)
  
  pmids <- sapply(pmc_ids, function(pmc_id) {
    tryCatch({
      url <- paste0("https://www.ncbi.nlm.nih.gov/pmc/utils/idconv/v1.0/?ids=", pmc_id, "&format=json")
      response <- request(url) %>%
        req_timeout(10) %>%
        req_perform() %>%
        resp_body_json()
      
      if (length(response$records) > 0 && !is.null(response$records[[1]]$pmid)) {
        return(response$records[[1]]$pmid)
      } else {
        return(NA_character_)
      }
    }, error = function(e) {
      return(NA_character_)
    })
  })
  
  pmids[!is.na(pmids)]
}


#' Create Log Entry
#'
#' Helper function to create a standardized log entry
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
#' @return Data frame with one row
#' @keywords internal

create_log_entry <- function(id, id_type, timestamp, method, status, success, 
                             failure_reason, pdf_url, file_path, file_size_kb) {
  data.frame(
    id = id,
    id_type = id_type,
    timestamp = timestamp,
    method = method,
    status = status,
    success = success,
    failure_reason = failure_reason,
    pdf_url = pdf_url,
    file_path = file_path,
    file_size_kb = file_size_kb,
    stringsAsFactors = FALSE
  )
}