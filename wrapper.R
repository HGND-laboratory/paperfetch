#' paperfetch: Automated PDF Retrieval Wrapper
#' 
#' This script provides a unified interface for fetching PDFs using DOIs, PMIDs, or PMC IDs

# Load all required packages
required_packages <- c("httr2", "rvest", "xml2", "readr", "dplyr", "cli", "progress")

# Install missing packages
missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if(length(missing_packages)) {
  install.packages(missing_packages)
}

# Load all packages
invisible(lapply(required_packages, library, character.only = TRUE))

#' Intelligent Wrapper Function for PDF Fetching
#' 
#' Automatically detects input type (DOI, PMID, PMC ID, or CSV file) and fetches PDFs
#'
#' @param input Either a CSV file path, a vector of IDs, or a single ID string
#' @param output_folder Directory to save downloaded PDFs (default: "downloads")
#' @param delay Seconds between requests (default: 2)
#' @param email Your email for API identification (required)
#' @param timeout Maximum seconds per request (default: 15)
#' @param unfetched_file File to log failed downloads (default: "unfetched.txt")
#' 
#' @return Invisibly returns a list with success and failure counts
#' 
#' @examples
#' # Fetch from a vector of DOIs
#' fetch_pdfs(c("10.1038/nature12373", "10.1126/science.1234567"), 
#'            email = "you@institution.edu")
#' 
#' # Fetch from a CSV file
#' fetch_pdfs("my_references.csv", email = "you@institution.edu")
#' 
#' # Fetch from mixed IDs (auto-detect type)
#' fetch_pdfs(c("10.1038/nature12373", "30670877", "PMC5176308"),
#'            email = "you@institution.edu")

fetch_pdfs <- function(input, 
                       output_folder = "downloads", 
                       delay = 2, 
                       email = "your@email.com",
                       timeout = 15,
                       unfetched_file = "unfetched.txt") {
  
  # Validate email
  if (email == "your@email.com") {
    cli_alert_warning("Please provide your real email address for API identification")
  }
  
  # Create output folder if needed
  if (!dir.exists(output_folder)) {
    dir.create(output_folder, recursive = TRUE)
  }
  
  # CASE 1: Input is a CSV file
  if (length(input) == 1 && file.exists(input) && grepl("\\.csv$", input, ignore.case = TRUE)) {
    cli_alert_info("Detected CSV file input")
    
    # Read CSV and detect column type
    data <- read_csv(input, show_col_types = FALSE)
    
    if ("doi" %in% tolower(colnames(data))) {
      cli_alert_info("Found DOI column - using fetch_pdfs_from_doi()")
      fetch_pdfs_from_doi(input, output_folder, delay, email, timeout)
      
    } else if (any(c("pmid", "pubmed_id") %in% tolower(colnames(data)))) {
      cli_alert_info("Found PMID column - using fetch_pdfs_from_pmids()")
      fetch_pdfs_from_pmids(input, output_folder, delay, email, timeout)
      
    } else {
      stop("CSV must contain a 'doi', 'pmid', or 'pubmed_id' column")
    }
    
    return(invisible(NULL))
  }
  
  # CASE 2: Input is a vector of IDs (mixed or single type)
  cli_alert_info("Detected vector input with {length(input)} items")
  
  # Classify each input
  input_types <- sapply(input, classify_id)
  
  # Split by type
  dois <- input[input_types == "doi"]
  pmids <- input[input_types == "pmid"]
  pmc_ids <- input[input_types == "pmc"]
  unknown <- input[input_types == "unknown"]
  
  # Report what was found
  if (length(dois) > 0) cli_alert_info("Found {length(dois)} DOI(s)")
  if (length(pmids) > 0) cli_alert_info("Found {length(pmids)} PMID(s)")
  if (length(pmc_ids) > 0) cli_alert_info("Found {length(pmc_ids)} PMC ID(s)")
  if (length(unknown) > 0) cli_alert_warning("Found {length(unknown)} unrecognized ID(s)")
  
  unfetched <- character()
  
  # Process DOIs
  if (length(dois) > 0) {
    temp_csv <- tempfile(fileext = ".csv")
    write_csv(data.frame(doi = dois), temp_csv)
    tryCatch({
      fetch_pdfs_from_doi(temp_csv, output_folder, delay, email, timeout)
    }, error = function(e) {
      unfetched <<- c(unfetched, dois)
    })
    unlink(temp_csv)
  }
  
  # Process PMIDs
  if (length(pmids) > 0) {
    temp_csv <- tempfile(fileext = ".csv")
    write_csv(data.frame(pmid = pmids), temp_csv)
    tryCatch({
      fetch_pdfs_from_pmids(temp_csv, output_folder, delay, email, timeout)
    }, error = function(e) {
      unfetched <<- c(unfetched, pmids)
    })
    unlink(temp_csv)
  }
  
  # Process PMC IDs (convert to PMID first, then fetch)
  if (length(pmc_ids) > 0) {
    cli_alert_info("Converting PMC IDs to PMIDs...")
    pmids_from_pmc <- convert_pmc_to_pmid(pmc_ids)
    
    if (length(pmids_from_pmc) > 0) {
      temp_csv <- tempfile(fileext = ".csv")
      write_csv(data.frame(pmid = pmids_from_pmc), temp_csv)
      tryCatch({
        fetch_pdfs_from_pmids(temp_csv, output_folder, delay, email, timeout)
      }, error = function(e) {
        unfetched <<- c(unfetched, pmc_ids)
      })
      unlink(temp_csv)
    } else {
      unfetched <- c(unfetched, pmc_ids)
    }
  }
  
  # Add unknown IDs to unfetched
  unfetched <- c(unfetched, unknown)
  
  # Write unfetched IDs to file
  if (length(unfetched) > 0) {
    writeLines(unfetched, unfetched_file)
    cli_alert_warning("Failed to fetch {length(unfetched)} item(s) - see {unfetched_file}")
  } else {
    cli_alert_success("All items processed successfully!")
  }
  
  # Return summary
  invisible(list(
    total = length(input),
    successful = length(input) - length(unfetched),
    failed = length(unfetched)
  ))
}


#' Classify ID Type
#' 
#' Helper function to detect if input is DOI, PMID, PMC ID, or unknown
#' 
#' @param id A single ID string
#' @return Character string: "doi", "pmid", "pmc", or "unknown"

classify_id <- function(id) {
  id <- as.character(id)
  
  # DOI pattern (e.g., 10.1038/nature12373)
  if (grepl("^10\\.\\d{4,9}/[-._;()/:A-Z0-9]+$", id, ignore.case = TRUE)) {
    return("doi")
  }
  
  # PMC ID pattern (e.g., PMC5176308)
  if (grepl("^PMC\\d+$", id, ignore.case = TRUE)) {
    return("pmc")
  }
  
  # PMID pattern (numeric only, e.g., 30670877)
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

convert_pmc_to_pmid <- function(pmc_ids) {
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

generate_acquisition_report <- function(log_data, report_file, email) {
  
  # Calculate statistics
  total <- nrow(log_data)
  successful <- sum(log_data$success, na.rm = TRUE)
  failed <- total - successful
  success_rate <- (successful / total) * 100
  
  # Method breakdown
  method_summary <- log_data %>%
    group_by(method) %>%
    summarise(
      attempts = n(),
      success = sum(success, na.rm = TRUE),
      success_rate = (success / attempts) * 100
    ) %>%
    arrange(desc(success_rate))
  
  # Failure analysis
  failure_summary <- log_data %>%
    filter(!success) %>%
    group_by(failure_reason) %>%
    summarise(count = n()) %>%
    mutate(percentage = (count / failed) * 100) %>%
    arrange(desc(count))
  
  # Failed records by reason
  paywalled <- log_data %>% filter(grepl("403|paywalled", failure_reason, ignore.case = TRUE)) %>% pull(id)
  no_pdf <- log_data %>% filter(grepl("no_pdf|not_found", failure_reason, ignore.case = TRUE)) %>% pull(id)
  technical <- log_data %>% filter(grepl("timeout|500|error", failure_reason, ignore.case = TRUE)) %>% pull(id)
  
  # Build report
  report <- paste0(
    "# Full-Text Acquisition Report\n\n",
    "**Generated:** ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n",
    "**Package:** paperfetch v0.1.0\n",
    "**Analyst:** ", email, "\n\n",
    "---\n\n",
    "## Summary\n\n",
    "- **Total records:** ", total, "\n",
    "- **Successfully downloaded:** ", successful, " (", sprintf("%.1f%%", success_rate), ")\n",
    "- **Failed to retrieve:** ", failed, " (", sprintf("%.1f%%", 100 - success_rate), ")\n\n",
    "---\n\n",
    "## Retrieval Methods\n\n",
    "| Method | Attempts | Success | Success Rate |\n",
    "|--------|----------|---------|-------------|\n"
  )
  
  for (i in 1:nrow(method_summary)) {
    report <- paste0(report,
                     "| ", method_summary$method[i], " | ",
                     method_summary$attempts[i], " | ",
                     method_summary$success[i], " | ",
                     sprintf("%.1f%%", method_summary$success_rate[i]), " |\n"
    )
  }
  
  report <- paste0(report,
                   "\n---\n\n",
                   "## Failure Analysis\n\n",
                   "| Reason | Count | Percentage |\n",
                   "|--------|-------|------------|\n"
  )
  
  for (i in 1:nrow(failure_summary)) {
    report <- paste0(report,
                     "| ", failure_summary$failure_reason[i], " | ",
                     failure_summary$count[i], " | ",
                     sprintf("%.1f%%", failure_summary$percentage[i]), " |\n"
    )
  }
  
  report <- paste0(report,
                   "\n---\n\n",
                   "## Failed Records\n\n",
                   "### Paywalled Content (n=", length(paywalled), ")\n```\n",
                   paste(head(paywalled, 20), collapse = "\n"), "\n",
                   if (length(paywalled) > 20) paste0("... and ", length(paywalled) - 20, " more") else "", "\n```\n\n",
                   "### No PDF Available (n=", length(no_pdf), ")\n```\n",
                   paste(head(no_pdf, 20), collapse = "\n"), "\n",
                   if (length(no_pdf) > 20) paste0("... and ", length(no_pdf) - 20, " more") else "", "\n```\n\n",
                   "### Technical Failures (n=", length(technical), ")\n```\n",
                   paste(head(technical, 20), collapse = "\n"), "\n",
                   if (length(technical) > 20) paste0("... and ", length(technical) - 20, " more") else "", "\n```\n\n",
                   "---\n\n",
                   "## Reproducibility Information\n\n",
                   "**System Information:**\n",
                   "- R version: ", R.version.string, "\n",
                   "- paperfetch version: 0.1.0\n",
                   "- Platform: ", R.version$platform, "\n\n",
                   "**Parameters:**\n",
                   "- Email: ", email, "\n",
                   "- Date: ", format(Sys.Date(), "%Y-%m-%d"), "\n\n",
                   "**Data Sources:**\n",
                   "- Unpaywall API (https://unpaywall.org)\n",
                   "- PubMed Central (https://www.ncbi.nlm.nih.gov/pmc/)\n",
                   "- Publisher websites via DOI resolution\n\n",
                   "---\n\n",
                   "## Recommendations\n\n",
                   "1. **Paywalled content:** Request via institutional library\n",
                   "2. **No PDF available:** Check if HTML-only or contact authors\n",
                   "3. **Technical failures:** Retry manually\n\n",
                   "---\n\n",
                   "**Note:** This report documents full-text retrieval procedures in accordance with PRISMA guidelines.\n"
  )
  
  writeLines(report, report_file)
}