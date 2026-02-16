library(httr2)
library(rvest)
library(xml2)
library(readr)
library(dplyr)
library(cli)
library(progress)

fetch_pdfs_from_pmids <- function(csv_file_path, output_folder, delay = 2, email = "your@email.com", timeout = 15) {
  # Read the CSV file
  pmid_data <- read_csv(csv_file_path)
  
  # Ensure PMID column exists (check common variations)
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
  
  # Create a progress bar
  pb <- progress_bar$new(
    total = length(pmids), 
    format = " [:bar] :percent :eta | :current/:total"
  )
  
  # Loop through each PMID
  for (pmid in pmids) {
    pb$tick()
    
    # Clean PMID (remove any non-numeric characters)
    clean_pmid <- gsub("[^0-9]", "", as.character(pmid))
    
    # Create filename
    file_name <- paste0("PMID_", clean_pmid, ".pdf")
    file_path <- file.path(output_folder, file_name)
    
    # Skip if file already exists
    if (file.exists(file_path)) {
      cli_alert_info("Skipped (exists): PMID {clean_pmid}")
      next
    }
    
    pdf_url <- NULL
    article_url <- NULL
    doi <- NULL
    download_success <- FALSE
    
    # STEP 1: Get DOI from PubMed and use Unpaywall
    tryCatch({
      # Fetch PubMed page to extract DOI
      pubmed_url <- paste0("https://pubmed.ncbi.nlm.nih.gov/", clean_pmid, "/")
      
      page <- request(pubmed_url) %>%
        req_user_agent(user_agent) %>%
        req_timeout(timeout) %>%
        req_perform() %>%
        resp_body_html()
      
      # Extract DOI from meta tag
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
        }
      }
    }, error = function(e) NULL)
    
    # STEP 2: Try PubMed Central (PMC) if available
    if (is.null(pdf_url)) {
      tryCatch({
        # Check if article has PMC ID
        pmc_id <- page %>%
          html_node("a.id-link[data-ga-action='PMC']") %>%
          html_attr("href") %>%
          gsub(".*/", "", .)
        
        if (!is.na(pmc_id) && !is.null(pmc_id)) {
          # Try PMC PDF URL
          pmc_pdf_url <- paste0("https://www.ncbi.nlm.nih.gov/pmc/articles/", pmc_id, "/pdf/")
          
          # Test if PMC PDF exists
          test_response <- request(pmc_pdf_url) %>%
            req_user_agent(user_agent) %>%
            req_timeout(timeout) %>%
            req_perform()
          
          if (test_response$status_code == 200) {
            pdf_url <- pmc_pdf_url
            article_url <- paste0("https://www.ncbi.nlm.nih.gov/pmc/articles/", pmc_id, "/")
          }
        }
      }, error = function(e) NULL)
    }
    
    # STEP 3: Try scraping PDF link from PubMed page
    if (is.null(pdf_url)) {
      tryCatch({
        # Look for citation_pdf_url meta tag
        pdf_url <- page %>%
          html_node("meta[name='citation_pdf_url']") %>%
          html_attr("content")
        
        # If not found, look for PDF links in the page
        if (is.na(pdf_url)) {
          pdf_links <- page %>%
            html_nodes("a") %>%
            html_attr("href") %>%
            .[grepl("\\.pdf$", ., ignore.case = TRUE)]
          
          if (length(pdf_links) > 0) {
            pdf_url <- pdf_links[1]
            
            # Convert relative to absolute URL
            if (!grepl("^http", pdf_url)) {
              pdf_url <- xml2::url_absolute(pdf_url, pubmed_url)
            }
          }
        }
        
        article_url <- pubmed_url
      }, error = function(e) NULL)
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
        
        # Check if redirected to PDF
        if (grepl("\\.pdf$", article_url)) {
          pdf_url <- article_url
        } else {
          # Try scraping the publisher page
          publisher_page <- request(article_url) %>%
            req_user_agent(user_agent) %>%
            req_timeout(timeout) %>%
            req_perform() %>%
            resp_body_html()
          
          # Look for citation_pdf_url
          pdf_url <- publisher_page %>%
            html_node("meta[name='citation_pdf_url']") %>%
            html_attr("content")
          
          # If not found, search for PDF links
          if (is.na(pdf_url)) {
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
            }
          }
        }
      }, error = function(e) NULL)
    }
    
    # STEP 5: Download the PDF if a URL was found
    if (!is.null(pdf_url) && !is.na(pdf_url)) {
      tryCatch({
        # Build request with consistent user-agent and Referer header
        download_req <- request(pdf_url) %>%
          req_user_agent(user_agent) %>%
          req_timeout(timeout)
        
        # Add Referer header if we have the article URL
        if (!is.null(article_url)) {
          download_req <- download_req %>% req_headers("Referer" = article_url)
        }
        
        # Perform download
        download_req %>% req_perform(path = file_path)
        
        download_success <- TRUE
        cli_alert_success("Downloaded: PMID {clean_pmid}")
      }, error = function(e) {
        cli_alert_danger("Download failed: PMID {clean_pmid} - {conditionMessage(e)}")
      })
    } else {
      cli_alert_danger("No PDF found: PMID {clean_pmid}")
    }
    
    # Wait for a specified delay before the next request
    Sys.sleep(delay)
  }
  
  cli_alert_info("Download process completed!")
}

# Example usage:
# fetch_pdfs_from_pmids(
#   csv_file_path = "pmids.csv",
#   output_folder = "papers",
#   delay = 2,
#   email = "yourname@institution.edu",
#   timeout = 15
# )