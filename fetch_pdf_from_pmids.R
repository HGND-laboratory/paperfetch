#' Fetch PDFs from PubMed IDs with Logging and Reporting
#'
#' Downloads PDFs for multiple PubMed IDs from a CSV file.
#' Generates structured logs and PRISMA-compliant reports.
#'
#' @param csv_file_path Path to CSV file containing a 'pmid', 'PMID', or 'pubmed_id' column
#' @param output_folder Directory for saving PDFs (created if doesn't exist)
#' @param delay Seconds to wait between requests (default: 2)
#' @param email Your email for identification (required)
#' @param timeout Maximum seconds to wait per request (default: 15)
#' @param log_file Path for structured CSV log (default: "download_log.csv")
#' @param report_file Path for Markdown report (default: "acquisition_report.md")
#'
#' @return Invisibly returns the log dataframe
#' @export
#'
#' @examples
#' \dontrun{
#' fetch_pdfs_from_pmids(
#'   csv_file_path = "pmids.csv",
#'   output_folder = "papers",
#'   email = "you@institution.edu"
#' )
#' }

fetch_pdfs_from_pmids <- function(csv_file_path, 
                                  output_folder = "downloads", 
                                  delay = 2, 
                                  email = "your@email.com", 
                                  timeout = 15,
                                  log_file = "download_log.csv",
                                  report_file = "acquisition_report.md") {
  
  # Load required libraries
  require(httr2)
  require(rvest)
  require(xml2)
  require(readr)
  require(dplyr)
  require(cli)
  require(progress)
  
  # Read the CSV file
  pmid_data <- read_csv(csv_file_path, show_col_types = FALSE)
  
  # Ensure PMID column exists
  pmid_col <- NULL
  if ("pmid" %in% colnames(pmid_data)) {
    pmid_col <- "pmid"
  } else if ("PMID" %in% colnames(pmid_data)) {
    pmid_col <- "PMID"
  } else if ("pubmed_id" %in% colnames(pmid_data)) {
    pmid_col <- "pubmed_id"
  } else {
    stop("The CSV file must contain a 'pmid', 'PMID', or 'pubmed_id' column.")
  }
  
  pmids <- pmid_data[[pmid_col]]
  
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
    total = length(pmids), 
    format = " [:bar] :percent :eta | :current/:total"
  )
  
  # Loop through each PMID
  for (pmid in pmids) {
    pb$tick()
    
    # Clean PMID
    clean_pmid <- gsub("[^0-9]", "", as.character(pmid))
    
    # Create filename
    file_name <- paste0("PMID_", clean_pmid, ".pdf")
    file_path <- file.path(output_folder, file_name)
    
    # Initialize tracking variables
    pdf_url <- NULL
    article_url <- NULL
    doi <- NULL
    download_success <- FALSE
    current_method <- NA_character_
    http_status <- NA_character_
    failure_reason <- NA_character_
    start_time <- Sys.time()
    page <- NULL
    
    # Skip if file already exists
    if (file.exists(file_path)) {
      cli_alert_info("Skipped (exists): PMID {clean_pmid}")
      
      log_entry <- create_log_entry(
        id = clean_pmid,
        id_type = "pmid",
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
    
    # STEP 1: Get DOI from PubMed and try Unpaywall
    tryCatch({
      pubmed_url <- paste0("https://pubmed.ncbi.nlm.nih.gov/", clean_pmid, "/")
      
      page <- request(pubmed_url) %>%
        req_user_agent(user_agent) %>%
        req_timeout(timeout) %>%
        req_perform() %>%
        resp_body_html()
      
      # Extract DOI
      doi <- page %>%
        html_node("meta[name='citation_doi']") %>%
        html_attr("content")
      
      # If DOI found, try Unpaywall
      if (!is.na(doi) && !is.null(doi)) {
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
      }
    }, error = function(e) {
      if (is.na(current_method)) current_method <<- "unpaywall"
      http_status <<- "error"
    })
    
    # STEP 2: Try PubMed Central (PMC)
    if (is.null(pdf_url) && !is.null(page)) {
      tryCatch({
        pmc_id <- page %>%
          html_node("a.id-link[data-ga-action='PMC']") %>%
          html_attr("href") %>%
          gsub(".*/", "", .)
        
        if (!is.na(pmc_id) && !is.null(pmc_id)) {
          pmc_pdf_url <- paste0("https://www.ncbi.nlm.nih.gov/pmc/articles/", pmc_id, "/pdf/")
          
          test_response <- request(pmc_pdf_url) %>%
            req_user_agent(user_agent) %>%
            req_timeout(timeout) %>%
            req_perform()
          
          if (test_response$status_code == 200) {
            pdf_url <- pmc_pdf_url
            article_url <- paste0("https://www.ncbi.nlm.nih.gov/pmc/articles/", pmc_id, "/")
            current_method <- "pmc"
            http_status <- "200"
          }
        }
      }, error = function(e) {
        if (is.na(current_method)) current_method <<- "pmc"
      })
    }
    
    # STEP 3: Try scraping PDF link from PubMed page
    if (is.null(pdf_url) && !is.null(page)) {
      tryCatch({
        pdf_url <- page %>%
          html_node("meta[name='citation_pdf_url']") %>%
          html_attr("content")
        
        if (!is.na(pdf_url)) {
          current_method <- "citation_metadata"
          http_status <- "200"
        } else {
          pdf_links <- page %>%
            html_nodes("a") %>%
            html_attr("href") %>%
            .[grepl("\\.pdf$", ., ignore.case = TRUE)]
          
          if (length(pdf_links) > 0) {
            pdf_url <- pdf_links[1]
            
            if (!grepl("^http", pdf_url)) {
              pdf_url <- xml2::url_absolute(pdf_url, pubmed_url)
            }
            current_method <- "scrape"
            http_status <- "200"
          }
        }
        
        article_url <- pubmed_url
      }, error = function(e) {
        if (is.na(current_method)) current_method <<- "scrape"
      })
    }
    
    # STEP 4: If DOI found but no PDF yet, try DOI resolution
    if (is.null(pdf_url) && !is.na(doi) && !is.null(doi)) {
      tryCatch({
        doi_url <- paste0("https://doi.org/", doi)
        
        response <- request(doi_url) %>%
          req_user_agent(user_agent) %>%
          req_timeout(timeout) %>%
          req_perform()
        
        article_url <- resp_url(response)
        http_status <- as.character(response$status_code)
        
        if (grepl("\\.pdf$", article_url)) {
          pdf_url <- article_url
          current_method <- "doi_resolution"
        } else {
          publisher_page <- request(article_url) %>%
            req_user_agent(user_agent) %>%
            req_timeout(timeout) %>%
            req_perform() %>%
            resp_body_html()
          
          pdf_url <- publisher_page %>%
            html_node("meta[name='citation_pdf_url']") %>%
            html_attr("content")
          
          if (!is.na(pdf_url)) {
            current_method <- "citation_metadata"
          } else {
            pdf_link <- publisher_page %>%
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
    
    # STEP 5: Download the PDF if a URL was found
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
        download_success <- TRUE
        cli_alert_success("Downloaded: PMID {clean_pmid}")
        
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
        cli_alert_danger("Download failed: PMID {clean_pmid} - {failure_reason}")
      })
    } else {
      if (is.na(failure_reason)) {
        failure_reason <- "no_pdf_found"
      }
      cli_alert_danger("No PDF found: PMID {clean_pmid}")
    }
    
    # Log the attempt
    log_entry <- create_log_entry(
      id = clean_pmid,
      id_type = "pmid",
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
  
  # Generate report
  generate_acquisition_report(log_data, report_file, email, "pmid")
  cli_alert_success("Acquisition report saved to {report_file}")
  
  cli_alert_info("Download process completed!")
  
  invisible(log_data)
}