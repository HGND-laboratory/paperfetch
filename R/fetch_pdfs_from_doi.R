#' Fetch PDFs from DOIs with Logging and Reporting
#'
#' Downloads PDFs for multiple DOIs from a CSV file with intelligent fallback
#' strategies. Generates structured logs and PRISMA-compliant reports.
#'
#' @param csv_file_path Path to CSV file containing a 'doi' column
#' @param output_folder Directory for saving PDFs (default: "downloads")
#' @param delay Seconds between requests (default: 2)
#' @param email Your email for Unpaywall API. Can also be set via
#'   \code{PAPERFETCH_EMAIL} in \code{.Renviron}
#' @param timeout Maximum seconds per request (default: 15)
#' @param log_file Path for structured CSV log (default: "download_log.csv")
#' @param report_file Path for Markdown report (default: "acquisition_report.md")
#' @param validate_pdfs Validate downloaded files for integrity (default: TRUE)
#' @param remove_invalid Remove invalid files automatically (default: TRUE)
#' @param proxy Proxy URL string e.g. "http://proxy.univ.edu:8080". Can also
#'   be set via \code{PAPERFETCH_PROXY} in \code{.Renviron}. NULL uses
#'   system default (default: NULL)
#' @param elsevier_api_key Elsevier API key for TDM access. Can also be set via
#'   \code{ELSEVIER_API_KEY} in \code{.Renviron} (default: NULL)
#' @param elsevier_insttoken Elsevier institutional token for subscribed content.
#'   Can also be set via \code{ELSEVIER_INSTTOKEN} in \code{.Renviron} (default: NULL)
#'
#' @return Invisibly returns the log dataframe
#' @export

fetch_pdfs_from_doi <- function(csv_file_path, 
                                output_folder      = "downloads", 
                                delay              = 2, 
                                email              = NULL,
                                timeout            = 15,
                                log_file           = "download_log.csv",
                                report_file        = "acquisition_report.md",
                                validate_pdfs      = TRUE,
                                remove_invalid     = TRUE,
                                proxy              = NULL,
                                elsevier_api_key   = NULL,
                                elsevier_insttoken = NULL) {
  
  # Resolve email (argument → .Renviron → warning)
  email <- resolve_email(email)
  
  # Read and validate CSV
  doi_data <- read_csv(csv_file_path, show_col_types = FALSE)
  if (!"doi" %in% colnames(doi_data)) {
    stop("The CSV file does not contain a 'doi' column.")
  }
  
  # Ensure output folder exists
  if (!dir.exists(output_folder)) dir.create(output_folder, recursive = TRUE)
  
  # Consistent user-agent
  user_agent <- paste0(
    "Academic PDF Scraper/1.0 (Contact: ", email,
    "; R package paperfetch for systematic reviews)"
  )
  
  # Initialize log
  log_data <- data.frame(
    id = character(), id_type = character(), timestamp = character(),
    method = character(), status = character(), success = logical(),
    failure_reason = character(), pdf_url = character(),
    file_path = character(), file_size_kb = numeric(),
    pdf_valid = logical(), pdf_invalid_reason = character(),
    stringsAsFactors = FALSE
  )
  
  # Progress bar
  pb <- progress_bar$new(
    total  = nrow(doi_data), 
    format = " [:bar] :percent :eta | :current/:total"
  )
  
  for (doi in doi_data$doi) {
    pb$tick()
    
    clean_doi   <- gsub("[^a-zA-Z0-9]", "_", doi)
    file_path   <- file.path(output_folder, paste0(clean_doi, ".pdf"))
    pdf_url     <- NULL
    article_url <- NULL
    download_success  <- FALSE
    current_method    <- NA_character_
    http_status       <- NA_character_
    failure_reason    <- NA_character_
    start_time        <- Sys.time()
    
    # ── Skip if exists ──────────────────────────────────────────────────────────
    if (file.exists(file_path)) {
      cli_alert_info("Skipped (exists): {doi}")
      log_data <- rbind(log_data, create_log_entry(
        id = doi, id_type = "doi",
        timestamp = format(start_time, "%Y-%m-%dT%H:%M:%SZ"),
        method = "skipped", status = "exists", success = TRUE,
        failure_reason = NA_character_, pdf_url = NA_character_,
        file_path = file_path, file_size_kb = file.size(file_path) / 1024
      ))
      next
    }
    
    # ── STEP 1: Unpaywall ───────────────────────────────────────────────────────
    tryCatch({
      resp <- build_request(
        url        = paste0("https://api.unpaywall.org/v2/", doi, "?email=", email),
        user_agent = user_agent,
        timeout    = timeout,
        proxy      = proxy
      ) %>%
        req_retry(max_tries = 3) %>%
        req_perform() %>%
        resp_body_json()
      
      if (!is.null(resp$best_oa_location)) {
        pdf_url     <- resp$best_oa_location$url_for_pdf
        article_url <- resp$best_oa_location$url_for_landing_page
        current_method <- "unpaywall"
        http_status    <- "200"
      }
    }, error = function(e) {
      current_method <<- "unpaywall"
      http_status    <<- "error"
    })
    
    # ── STEP 1b: PMC fallback ───────────────────────────────────────────────────
    # If Unpaywall found nothing, check if the article is in PubMed Central.
    # This catches paywalled journals (NEJM, JAMA, Lancet, OUP) that have a
    # freely available PMC version deposited by the authors.
    if (is.null(pdf_url) || is.na(pdf_url)) {
      cli_alert_info("Trying PMC fallback for: {doi}")
      pmc_result <- fetch_pmc_pdf_url(
        doi        = doi,
        email      = email,
        user_agent = user_agent,
        timeout    = timeout,
        proxy      = proxy
      )
      if (!is.null(pmc_result$pdf_url)) {
        pdf_url        <- pmc_result$pdf_url
        article_url    <- pmc_result$article_url
        current_method <- "pmc_fallback"
        http_status    <- "200"
        cli_alert_info("Found PMC version ({pmc_result$pmc_id}): {doi}")
      }
    }
    
    # ── STEP 1c: Elsevier TDM API ───────────────────────────────────────────────
    # For Elsevier journals (Lancet, Cell, EJCA, etc.) — skipped silently if
    # no API key is set, or if DOI prefix is not an Elsevier prefix.
    if (is.null(pdf_url) || is.na(pdf_url)) {
      els_result <- get_elsevier_pdf(
        doi        = doi,
        path       = file_path,
        user_agent = user_agent,
        timeout    = timeout,
        proxy      = proxy,
        api_key    = elsevier_api_key,
        insttoken  = elsevier_insttoken
      )
      if (els_result$success) {
        # File already saved by get_elsevier_pdf — log and move to next DOI
        download_success <- TRUE
        current_method   <- "elsevier_api"
        http_status      <- "200"
        cli_alert_success("Downloaded via Elsevier API: {doi}")
        log_data <- rbind(log_data, create_log_entry(
          id             = doi, id_type = "doi",
          timestamp      = format(start_time, "%Y-%m-%dT%H:%M:%SZ"),
          method         = current_method, status = http_status,
          success        = TRUE, failure_reason = NA_character_,
          pdf_url        = paste0("https://api.elsevier.com/content/article/doi/", doi),
          file_path      = file_path,
          file_size_kb   = file.size(file_path) / 1024
        ))
        Sys.sleep(delay)
        next
      } else if (!els_result$reason %in% c("no_api_key", "not_elsevier")) {
        cli_alert_info("Elsevier API failed ({els_result$reason}), trying other methods: {doi}")
      }
    }
    
    # ── STEP 2: DOI resolution + scraping ──────────────────────────────────────
    if (is.null(pdf_url)) {
      tryCatch({
        response <- build_request(
          url        = paste0("https://doi.org/", doi),
          user_agent = user_agent,
          timeout    = timeout,
          proxy      = proxy
        ) %>%
          req_perform()
        
        article_url <- resp_url(response)
        http_status <- as.character(response$status_code)
        
        if (grepl("\\.pdf$", article_url)) {
          pdf_url        <- article_url
          current_method <- "doi_resolution"
        } else {
          page <- build_request(
            url        = article_url,
            user_agent = user_agent,
            timeout    = timeout,
            proxy      = proxy
          ) %>%
            req_perform() %>%
            resp_body_html()
          
          # Method 1: citation_pdf_url meta tag (works for many journals)
          pdf_url <- page %>%
            html_node("meta[name='citation_pdf_url']") %>%
            html_attr("content")
          
          if (!is.na(pdf_url) && !is.null(pdf_url)) {
            current_method <- "citation_metadata"
          } else {
            # Method 2: href ending in .pdf
            pdf_link <- page %>%
              html_nodes("a") %>%
              html_attr("href") %>%
              .[grepl("\\.pdf$", ., ignore.case = TRUE)][1]
            
            if (!is.na(pdf_link) && !is.null(pdf_link)) {
              pdf_url <- if (!grepl("^http", pdf_link)) {
                xml2::url_absolute(pdf_link, article_url)
              } else {
                pdf_link
              }
              current_method <- "scrape"
            } else {
              # Method 3: OUP-style article-pdf links
              # OUP uses hrefs like /jbmr/article-pdf/39/9/1215/58994182/zjae112.pdf
              # These contain "article-pdf" in the path
              oup_link <- page %>%
                html_nodes("a[href*='article-pdf']") %>%
                html_attr("href") %>%
                .[1]
              
              if (!is.na(oup_link) && !is.null(oup_link)) {
                pdf_url <- if (!grepl("^http", oup_link)) {
                  # OUP links are relative to academic.oup.com
                  xml2::url_absolute(oup_link, article_url)
                } else {
                  oup_link
                }
                current_method <- "scrape_oup"
              } else {
                # Method 4: any link with /pdf/ in the path (covers many publishers)
                pdf_path_link <- page %>%
                  html_nodes("a[href*='/pdf/']") %>%
                  html_attr("href") %>%
                  .[1]
                
                if (!is.na(pdf_path_link) && !is.null(pdf_path_link)) {
                  pdf_url <- if (!grepl("^http", pdf_path_link)) {
                    xml2::url_absolute(pdf_path_link, article_url)
                  } else {
                    pdf_path_link
                  }
                  current_method <- "scrape_pdf_path"
                }
              }
            }
          }
        }
      }, error = function(e) {
        if (is.na(current_method)) current_method <<- "doi_resolution"
        http_status    <<- if (grepl("timeout", e$message, ignore.case = TRUE)) "timeout" else "error"
        failure_reason <<- if (grepl("timeout", e$message, ignore.case = TRUE)) "timeout" else conditionMessage(e)
      })
    }
    
    # ── STEP 2b: Journal-specific URL patterns ──────────────────────────────────
    # For journals with predictable PDF URLs that aren't exposed via Unpaywall
    # or standard meta tags (e.g. NEJM, JAMA, Lancet, Oxford journals)
    if (is.null(pdf_url) || is.na(pdf_url)) {
      pdf_url <- construct_journal_pdf_url(doi)
      if (!is.null(pdf_url)) {
        current_method <- "journal_url_pattern"
        cli_alert_info("Trying journal-specific URL for: {doi}")
      }
    }
    
    # ── STEP 3: Download ────────────────────────────────────────────────────────
    if (!is.null(pdf_url) && !is.na(pdf_url)) {
      tryCatch({
        dl_req <- build_request(
          url        = pdf_url,
          user_agent = user_agent,
          timeout    = timeout,
          proxy      = proxy
        )
        
        if (!is.null(article_url)) {
          dl_req <- dl_req %>% req_headers("Referer" = article_url)
        }
        
        dl_resp     <- dl_req %>% req_perform(path = file_path)
        http_status <- as.character(dl_resp$status_code)
        
        # ── Integrity validation ──────────────────────────────────────────────
        # PMC and Elsevier are trusted sources — skip immediate validation
        # They'll be validated in the post-loop check with appropriate thresholds
        trusted_source <- current_method %in% c("pmc_fallback", "elsevier_api")
        
        if (!trusted_source) {
          # Validate non-trusted sources immediately
          validation <- validate_pdf(file_path)
          
          if (validation$valid) {
            download_success <- TRUE
            cli_alert_success("Downloaded: {doi}")
          } else {
            unlink(file_path)
            download_success <- FALSE
            failure_reason   <- validation$reason
            
            if (validation$is_html) {
              cli_alert_danger("HTML error page (not PDF): {doi}")
            } else {
              cli_alert_danger("Corrupt/invalid PDF: {doi} [{validation$reason}]")
            }
          }
        } else {
          # Trust PMC/Elsevier — just mark as success
          download_success <- TRUE
          cli_alert_success("Downloaded via {gsub('_', ' ', current_method)}: {doi}")
        }
        
        http_status <<- dplyr::case_when(
          grepl("403", e$message)                        ~ "403",
          grepl("404", e$message)                        ~ "404",
          grepl("500|502|503", e$message)                ~ "500",
          grepl("timeout", e$message, ignore.case = TRUE) ~ "timeout",
          TRUE                                           ~ "error"
        )
        failure_reason <<- dplyr::case_when(
          grepl("403", e$message)                        ~ "paywalled",
          grepl("404", e$message)                        ~ "not_found",
          grepl("500|502|503", e$message)                ~ "server_error",
          grepl("timeout", e$message, ignore.case = TRUE) ~ "timeout",
          TRUE                                           ~ conditionMessage(e)
        )
        cli_alert_danger("Download failed: {doi} [{failure_reason}]")
      })
    } else {
      if (is.na(failure_reason)) failure_reason <- "no_pdf_found"
      cli_alert_danger("No PDF found: {doi}")
    }
    
    # ── Log entry ───────────────────────────────────────────────────────────────
    log_data <- rbind(log_data, create_log_entry(
      id             = doi,
      id_type        = "doi",
      timestamp      = format(start_time, "%Y-%m-%dT%H:%M:%SZ"),
      method         = current_method,
      status         = http_status,
      success        = download_success,
      failure_reason = if (!download_success) failure_reason else NA_character_,
      pdf_url        = if (!is.null(pdf_url) && !is.na(pdf_url)) pdf_url else NA_character_,
      file_path      = if (download_success) file_path else NA_character_,
      file_size_kb   = if (download_success) file.size(file_path) / 1024 else NA_real_
    ))
    
    Sys.sleep(delay)
  }
  
  # ── Post-loop: validate, save log, generate report ──────────────────────────
  
  write_csv(log_data, log_file)
  cli_alert_success("Download log saved to: {log_file}")
  
  if (validate_pdfs) {
    cli_h2("Validating Downloaded PDFs")
    
    # Use lenient threshold — PMC and Elsevier PDFs are often small but valid
    check_pdf_integrity(
      output_folder  = output_folder,
      log_file       = log_file,
      remove_invalid = remove_invalid,
      use_advanced   = FALSE,
      min_size_kb    = 1  # Much more lenient for post-validation
    )
    
    log_data <- read_csv(log_file, show_col_types = FALSE)
  }
  
  generate_acquisition_report(log_data, report_file, email, "doi")
  cli_alert_success("Acquisition report saved to: {report_file}")
  cli_alert_info("Download process completed!")
  
  invisible(log_data)
}