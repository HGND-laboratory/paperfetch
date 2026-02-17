#' Intelligent Wrapper for PDF Fetching
#'
#' Automatically detects input type (DOI, PMID, PMC ID, or CSV file) and fetches PDFs.
#' Generates structured logs and PRISMA-compliant reports.
#'
#' @param input Either a CSV file path, a vector of IDs, or a single ID string
#' @param output_folder Directory to save downloaded PDFs (default: "downloads")
#' @param delay Seconds between requests (default: 2)
#' @param email Your email for API identification (required)
#' @param timeout Maximum seconds per request (default: 15)
#' @param log_file File to log structured download attempts (default: "download_log.csv")
#' @param report_file File for Markdown acquisition report (default: "acquisition_report.md")
#' @param unfetched_file File to log failed downloads (default: "unfetched.txt")
#'
#' @return Invisibly returns a list with success and failure counts
#' @export
#'
#' @examples
#' \dontrun{
#' # CSV file
#' fetch_pdfs("my_references.csv", email = "you@edu")
#'
#' # Vector of DOIs
#' fetch_pdfs(c("10.1038/nature12373", "10.1126/science.1234567"), email = "you@edu")
#'
#' # Mixed IDs
#' fetch_pdfs(c("10.1038/nature12373", "30670877", "PMC5176308"), email = "you@edu")
#' }

fetch_pdfs <- function(input, 
                       output_folder = "downloads", 
                       delay = 2, 
                       email = "your@email.com",
                       timeout = 15,
                       log_file = "download_log.csv",
                       report_file = "acquisition_report.md",
                       unfetched_file = "unfetched.txt",
                       validate_pdfs = TRUE,
                       remove_invalid = TRUE,
                       proxy          = NULL) {
  
  # Load required libraries
  require(httr2)
  require(rvest)
  require(xml2)
  require(readr)
  require(dplyr)
  require(cli)
  require(progress)
  
  # Resolve email once here — subfunctions will re-resolve but
  # this gives early feedback to the user
  email <- resolve_email(email)
  
  # Validate email
  if (email == "your@email.com") {
    cli_alert_warning("Please provide your real email address for API identification")
  }
  
  # Create output folder if needed
  if (!dir.exists(output_folder)) {
    dir.create(output_folder, recursive = TRUE)
  }
  
  # CASE 1: CSV file
  if (length(input) == 1 && file.exists(input) && grepl("\\.csv$", input, ignore.case = TRUE)) {
    data <- read_csv(input, show_col_types = FALSE)
    
    if ("doi" %in% tolower(colnames(data))) {
      fetch_pdfs_from_doi(input, output_folder, delay, email, timeout,
                          log_file, report_file, validate_pdfs, remove_invalid,
                          proxy)                                       # passed through
    } else if (any(c("pmid", "pubmed_id") %in% tolower(colnames(data)))) {
      fetch_pdfs_from_pmids(input, output_folder, delay, email, timeout,
                            log_file, report_file, validate_pdfs, remove_invalid,
                            proxy)                                     # passed through
    } else {
      stop("CSV must contain a 'doi', 'pmid', or 'pubmed_id' column")
    }
    return(invisible(NULL))
  }
  
  
  # CASE 2: Input is a vector of IDs
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
    tryCatch(
      fetch_pdfs_from_doi(temp_csv, output_folder, delay, email, timeout,
                          log_file, report_file, validate_pdfs, remove_invalid,
                          proxy),                                      # passed through
      error = function(e) unfetched <<- c(unfetched, dois)
    )
    unlink(temp_csv)
  }
  
  # Process PMIDs
  if (length(pmids) > 0) {
    temp_csv <- tempfile(fileext = ".csv")
    write_csv(data.frame(pmid = pmids), temp_csv)
    tryCatch(
      fetch_pdfs_from_pmids(temp_csv, output_folder, delay, email, timeout,
                            log_file, report_file, validate_pdfs, remove_invalid,
                            proxy),                                    # passed through
      error = function(e) unfetched <<- c(unfetched, pmids)
    )
    unlink(temp_csv)
  }
  
  # Process PMC IDs
  if (length(pmc_ids) > 0) {
    pmids_from_pmc <- convert_pmc_to_pmid(pmc_ids)
    if (length(pmids_from_pmc) > 0) {
      temp_csv <- tempfile(fileext = ".csv")
      write_csv(data.frame(pmid = pmids_from_pmc), temp_csv)
      tryCatch(
        fetch_pdfs_from_pmids(temp_csv, output_folder, delay, email, timeout,
                              log_file, report_file, validate_pdfs, remove_invalid,
                              proxy),                                  # passed through
        error = function(e) unfetched <<- c(unfetched, pmc_ids)
      )
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