#' Fetch PDFs from DOIs with Logging and Reporting
#'
#' Downloads PDFs for multiple DOIs from a CSV file with intelligent fallback strategies.
#' Generates structured logs and PRISMA-compliant reports.
#'
#' @param csv_file_path Path to CSV file containing a 'doi' column
#' @param output_folder Directory for saving PDFs (created if doesn't exist)
#' @param delay Seconds to wait between requests (default: 2)
#' @param email Your email for Unpaywall API identification (required)
#' @param timeout Maximum seconds to wait per request (default: 15)
#' @param log_file Path for structured CSV log (default: "download_log.csv")
#' @param report_file Path for Markdown report (default: "acquisition_report.md")
#'
#' @return Invisibly returns the log dataframe
#' @export
#'
#' @examples
#' \dontrun{
#' fetch_pdfs_from_doi(
#'   csv_file_path = "dois.csv",
#'   output_folder = "papers",
#'   email = "you@institution.edu"
#' )
#' }

fetch_pdfs_from_doi <- function(csv_file_path, 
                                output_folder = "downloads", 
                                delay = 2, 
                                email = "your@email.com", 
                                timeout = 15,
                                log_file = "download_log.csv",
                                report_file = "acquisition_report.md",
                                validate_pdfs = TRUE, 
                                remove_invalid = TRUE) {
  
  # Load required libraries
  require(httr2)
  require(rvest)
  require(xml2)
  require(readr)
  require(dplyr)
  require(cli)
  require(progress)
  
  # Read the CSV file
  doi_data <- read_csv(csv_file_path, show_col_types = FALSE)
  
  # Ensure DOI column exists
  if (!"doi" %in% colnames(doi_data)) {
    stop("The CSV file does not contain a 'doi' column.")
  }
  
  # Ensure the output folder exists
  if (!dir.exists(output_folder)) {
    dir.create(output_folder, recursive = TRUE)
  }
  
  # Define consistent User-Agent
  user_agent <- paste0("Academic PDF Scraper/1.0 (Contact: ", email, "; R package paperfetch for systematic reviews)")
  
  # Initialize log dataframe
  log_data <- data.frame(
    id = character(),
    id_type = character(),
    timestamp = character(),
    method = character(),
    status = character(),
    success = logical(),
    failure_reason = character(),
    pdf_url = character(),
    file_path = character(),
    file_size_kb = numeric(),
    stringsAsFactors = FALSE
  )
  
  # Create a progress bar
  pb <- progress_bar$new(
    total = nrow(doi_data), 
    format = " [:bar] :percent :eta | :current/:total"
  )
  
  # Loop through each DOI
  for (doi in doi_data$doi) {
    pb$tick()
    
    # Extract file name from DOI
    clean_doi <- gsub("[^a-zA-Z0-9]", "_", doi)
    file_name <- paste0(clean_doi, ".pdf")
    file_path <- file.path(output_folder, file_name)
    
    # Initialize tracking variables
    pdf_url <- NULL
    article_url <- NULL
    download_success <- FALSE
    current_method <- NA_character_
    http_status <- NA_character_
    failure_reason <- NA_character_
    start_time <- Sys.time()
    
    # Skip if file already exists
    if (file.exists(file_path)) {
      cli_alert_info("Skipped (exists): {doi}")
      
      log_entry <- create_log_entry(
        id = doi,
        id_type = "doi",
        timestamp = format(start_time, "%Y-%m-%dT%H:%M:%SZ"),
        method = "skipped",
        status = "exists",
        success = TRUE,
        failure_reason = NA_character_,
        pdf_url = NA_character_,
        file_path = file_path,
        file_size_kb = file.size(file_path) / 1024
      )
      log_data <- rbind(log_data, log_entry)
      next
    }
    
    # STEP 1: Try Unpaywall API first
    tryCatch({
      unpaywall_response <- request(paste0("https://api.unpaywall.org/v2/", doi, "?email=", email)) %>%
        req_timeout(timeout) %>%
        req_retry(max_tries = 3) %>%
        req_perform() %>%
        resp_body_json()
      
      if (!is.null(unpaywall_response$best_oa_location)) {
        pdf_url <- unpaywall_response$best_oa_location$url_for_pdf
        article_url <- unpaywall_response$best_oa_location$url_for_landing_page
        current_method <- "unpaywall"
        http_status <- "200"
      }
    }, error = function(e) {
      current_method <<- "unpaywall"
      http_status <<- "error"
    })
    
    # STEP 2: If Unpaywall fails, try resolving DOI and scraping
    if (is.null(pdf_url)) {
      doi_url <- paste0("https://doi.org/", doi)
      
      tryCatch({
        response <- request(doi_url) %>%
          req_user_agent(user_agent) %>%
          req_timeout(timeout) %>%
          req_perform()
        
        article_url <- resp_url(response)
        http_status <- as.character(response$status_code)
        
        # Check if the article_url ends with .pdf
        if (grepl("\\.pdf$", article_url)) {
          pdf_url <- article_url
          current_method <- "doi_resolution"
        } else {
          # Attempt to find PDF link from the resolved URL
          page <- request(article_url) %>%
            req_user_agent(user_agent) %>%
            req_timeout(timeout) %>%
            req_perform() %>%
            resp_body_html()
          
          # Method 1: Try citation_pdf_url meta tag
          pdf_url <- page %>% 
            html_node("meta[name='citation_pdf_url']") %>% 
            html_attr("content")
          
          if (!is.na(pdf_url)) {
            current_method <- "citation_metadata"
          } else {
            # Method 2: Search for PDF links
            pdf_link <- page %>%
              html_nodes("a") %>%
              html_attr("href") %>%
              .[grepl("\\.pdf$", .)][1]
            
            if (!is.na(pdf_link)) {
              if (!grepl("^http", pdf_link)) {
                pdf_url <- xml2::url_absolute(pdf_link, article_url)
              } else {
                pdf_url <- pdf_link
              }
              current_method <- "scrape"
            }
          }
        }
      }, error = function(e) {
        if (is.na(current_method)) current_method <<- "doi_resolution"
        if (grepl("timeout|timed out", e$message, ignore.case = TRUE)) {
          http_status <<- "timeout"
          failure_reason <<- "timeout"
        } else {
          http_status <<- "error"
          failure_reason <<- conditionMessage(e)
        }
      })
    }
    
    # STEP 3: Download the PDF if a URL was found
    if (!is.null(pdf_url) && !is.na(pdf_url)) {
      tryCatch({
        download_req <- request(pdf_url) %>%
          req_user_agent(user_agent) %>%
          req_timeout(timeout)
        
        if (!is.null(article_url)) {
          download_req <- download_req %>% req_headers("Referer" = article_url)
        }
        
        download_response <- download_req %>% req_perform(path = file_path)
        http_status <- as.character(download_response$status_code)
        
        # VALIDATION: Check if downloaded file is actually a valid PDF
        validation_result <- validate_pdf(file_path, min_size_kb = 10, verbose = FALSE)
        
        if (validation_result$valid) {
          download_success <- TRUE
          cli_alert_success("Downloaded: {doi}")
        } else {
          # File is invalid - remove it and mark as failed
          unlink(file_path)
          download_success <- FALSE
          failure_reason <- paste0("invalid_pdf_", validation_result$reason)
          
          if (validation_result$is_html) {
            cli_alert_danger("Downloaded HTML error page (not PDF): {doi}")
          } else {
            cli_alert_danger("Downloaded corrupt/invalid PDF: {doi} - {validation_result$reason}")
          }
        }
        
      }, error = function(e) {
        if (grepl("403", e$message)) {
          http_status <<- "403"
          failure_reason <<- "paywalled"
        } else if (grepl("404", e$message)) {
          http_status <<- "404"
          failure_reason <<- "not_found"
        } else if (grepl("500|502|503", e$message)) {
          http_status <<- "500"
          failure_reason <<- "server_error"
        } else if (grepl("timeout|timed out", e$message, ignore.case = TRUE)) {
          http_status <<- "timeout"
          failure_reason <<- "timeout"
        } else {
          http_status <<- "error"
          failure_reason <<- conditionMessage(e)
        }
        cli_alert_danger("Download failed: {doi} - {failure_reason}")
      })
    } else {
      if (is.na(failure_reason)) {
        failure_reason <- "no_pdf_found"
      }
      cli_alert_danger("No PDF found: {doi}")
    }
    
    # Log the attempt
    log_entry <- create_log_entry(
      id = doi,
      id_type = "doi",
      timestamp = format(start_time, "%Y-%m-%dT%H:%M:%SZ"),
      method = current_method,
      status = http_status,
      success = download_success,
      failure_reason = if (!download_success) failure_reason else NA_character_,
      pdf_url = if (!is.null(pdf_url) && !is.na(pdf_url)) pdf_url else NA_character_,
      file_path = if (download_success) file_path else NA_character_,
      file_size_kb = if (download_success) file.size(file_path) / 1024 else NA_real_
    )
    
    log_data <- rbind(log_data, log_entry)
    
    # Wait for delay
    Sys.sleep(delay)
  }
  
  # Save log
  write_csv(log_data, log_file)
  cli_alert_success("Download log saved to {log_file}")
  
  # Validate PDFs if requested
  if (validate_pdfs) {
    cli_h2("Validating Downloaded PDFs")
    
    validation_results <- check_pdf_integrity(
      output_folder = output_folder,
      log_file = log_file,
      remove_invalid = remove_invalid,
      use_advanced = FALSE
    )
    
    # Update log_data with validation results
    log_data <- read_csv(log_file, show_col_types = FALSE)
  }
  
  # Generate report (now includes validation data if available)
  generate_acquisition_report(log_data, report_file, email, "doi")
  cli_alert_success("Acquisition report saved to {report_file}")
  
  cli_alert_info("Download process completed!")
  
  invisible(log_data)
}