library(httr2)
library(rvest)
library(xml2)  # Explicitly load for url_absolute()
library(readr)
library(dplyr)
library(cli)
library(progress)

download_pdfs_by_doi <- function(csv_file_path, output_folder, delay = 2, email = "your@email.com", timeout = 15) {
  # Read the CSV file
  doi_data <- read_csv(csv_file_path)
  
  # Ensure DOI column exists
  if (!"doi" %in% colnames(doi_data)) {
    stop("The CSV file does not contain a 'doi' column.")
  }
  
  # Ensure the output folder exists
  if (!dir.exists(output_folder)) {
    dir.create(output_folder, recursive = TRUE)
  }
  
  # Define consistent User-Agent (be honest about being a scraper)
  user_agent <- paste0("Academic PDF Scraper/1.0 (Contact: ", email, "; R package for systematic reviews)")
  
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
    
    # Skip if file already exists
    if (file.exists(file_path)) {
      cli_alert_info("Skipped (exists): {doi}")
      next
    }
    
    pdf_url <- NULL
    article_url <- NULL  # Track this for Referer header
    download_success <- FALSE
    
    # STEP 1: Try Unpaywall API first (Fast & Reliable for Open Access)
    # Unpaywall indexes PMC AWS locations via best_oa_location
    tryCatch({
      unpaywall_response <- request(paste0("https://api.unpaywall.org/v2/", doi, "?email=", email)) %>%
        req_timeout(timeout) %>%
        req_retry(max_tries = 3) %>%
        req_perform() %>%
        resp_body_json()
      
      # Use best_oa_location for most reliable OA source
      if (!is.null(unpaywall_response$best_oa_location)) {
        pdf_url <- unpaywall_response$best_oa_location$url_for_pdf
        article_url <- unpaywall_response$best_oa_location$url_for_landing_page
      }
    }, error = function(e) NULL)
    
    # STEP 2: If Unpaywall fails, try resolving DOI and scraping
    if (is.null(pdf_url)) {
      doi_url <- paste0("https://doi.org/", doi)
      
      tryCatch({
        response <- request(doi_url) %>%
          req_user_agent(user_agent) %>%
          req_timeout(timeout) %>%
          req_perform()
        article_url <- resp_url(response)
      }, error = function(e) NULL)
      
      if (!is.null(article_url)) {
        # Check if the article_url ends with .pdf
        if (grepl("\\.pdf$", article_url)) {
          pdf_url <- article_url
        } else {
          # Attempt to find PDF link from the resolved URL
          tryCatch({
            page <- request(article_url) %>%
              req_user_agent(user_agent) %>%
              req_timeout(timeout) %>%
              req_perform() %>%
              resp_body_html()
            
            # Method 1: Try citation_pdf_url meta tag (most reliable)
            pdf_url <- page %>% 
              html_node("meta[name='citation_pdf_url']") %>% 
              html_attr("content")
            
            # Method 2: If meta tag not found, try searching for PDF links
            if (is.na(pdf_url)) {
              pdf_link <- page %>%
                html_nodes("a") %>%
                html_attr("href") %>%
                .[grepl("\\.pdf$", .)][1]
              
              if (!is.na(pdf_link)) {
                # Convert relative link to absolute link if necessary
                if (!grepl("^http", pdf_link)) {
                  pdf_url <- xml2::url_absolute(pdf_link, article_url)
                } else {
                  pdf_url <- pdf_link
                }
              }
            }
          }, error = function(e) NULL)
        }
      }
    }
    
    # STEP 3: Download the PDF if a URL was found
    if (!is.null(pdf_url) && !is.na(pdf_url)) {
      tryCatch({
        # Build request with consistent user-agent and Referer header
        download_req <- request(pdf_url) %>%
          req_user_agent(user_agent) %>%
          req_timeout(timeout)
        
        # Add Referer header if we have the article URL (helps with server validation)
        if (!is.null(article_url)) {
          download_req <- download_req %>% req_headers("Referer" = article_url)
        }
        
        # Perform download
        download_req %>% req_perform(path = file_path)
        
        download_success <- TRUE
        cli_alert_success("Downloaded: {doi}")
      }, error = function(e) {
        cli_alert_danger("Download failed: {doi} - {conditionMessage(e)}")
      })
    } else {
      cli_alert_danger("No PDF found: {doi}")
    }
    
    # Wait for a specified delay before the next request
    Sys.sleep(delay)
  }
  
  cli_alert_info("Download process completed!")
}

# Example usage:
# download_pdfs_by_doi(
#   csv_file_path = "dois.csv", 
#   output_folder = "pdfs", 
#   delay = 2, 
#   email = "yourname@institution.edu",
#   timeout = 15
# )