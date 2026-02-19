#' Validate PDF File Integrity
#'
#' Checks if a downloaded file is a valid PDF or a corrupt/fake file
#' (e.g., HTML error page disguised as PDF)
#'
#' @param file_path Path to the PDF file to validate
#' @param min_size_kb Minimum file size in KB to be considered valid (default: 10)
#' @param verbose Print validation details (default: FALSE)
#'
#' @return List with validation results:
#'   \item{valid}{Logical, TRUE if PDF is valid}
#'   \item{reason}{Character, reason for failure (if invalid)}
#'   \item{file_size_kb}{Numeric, actual file size}
#'   \item{is_pdf}{Logical, TRUE if file has PDF magic number}
#'   \item{is_html}{Logical, TRUE if file appears to be HTML}
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Validate a single PDF
#' result <- validate_pdf("paper.pdf")
#' if (result$valid) {
#'   message("PDF is valid")
#' } else {
#'   message("Invalid: ", result$reason)
#' }
#' 
#' # Use a lower threshold for trusted sources
#' result <- validate_pdf("pmc_paper.pdf", min_size_kb = 1)
#' }

validate_pdf <- function(file_path, min_size_kb = 10, verbose = FALSE) {
  
  # Initialize result
  result <- list(
    valid = FALSE,
    reason = NA_character_,
    file_size_kb = NA_real_,
    is_pdf = FALSE,
    is_html = FALSE
  )
  
  # Check if file exists
  if (!file.exists(file_path)) {
    result$reason <- "file_not_found"
    return(result)
  }
  
  # Check file size
  file_size_bytes <- file.size(file_path)
  file_size_kb <- file_size_bytes / 1024
  result$file_size_kb <- file_size_kb
  
  if (verbose) {
    cat(sprintf("File size: %.2f KB\n", file_size_kb))
  }
  
  # Check minimum size
  if (file_size_kb < min_size_kb) {
    result$reason <- "file_too_small"
    if (verbose) {
      cat(sprintf("File too small: %.2f KB < %.2f KB minimum\n", file_size_kb, min_size_kb))
    }
    return(result)
  }
  
  # Read first 1024 bytes for magic number check
  con <- file(file_path, "rb")
  header <- readBin(con, "raw", n = 1024)
  close(con)
  
  # Safe raw-to-char conversion — rawToChar() crashes on null bytes in binary PDFs
  safe_raw_to_char <- function(raw_bytes) {
    tryCatch(
      rawToChar(raw_bytes),
      error = function(e) rawToChar(raw_bytes[raw_bytes != as.raw(0)])
    )
  }
  
  # Check PDF magic number (%PDF- at start)
  pdf_magic <- safe_raw_to_char(header[1:min(8, length(header))])
  result$is_pdf <- grepl("^%PDF-", pdf_magic)
  
  if (verbose) {
    cat(sprintf("Magic number: %s\n", substr(pdf_magic, 1, 20)))
    cat(sprintf("Is PDF: %s\n", result$is_pdf))
  }
  
  # Check for HTML content (common soft failure)
  header_text <- safe_raw_to_char(header[1:min(500, length(header))])
  
  # Only match patterns that unambiguously indicate an HTML error page.
  # Do NOT use generic words like "Error"/"ERROR" — these appear in normal
  # PDF metadata, font definitions, and object streams.
  html_patterns <- c(
    "<!DOCTYPE", "<!doctype",
    "<html", "<HTML",
    "<head>", "<HEAD>",
    "<body>", "<BODY>",
    "Access Denied",
    "403 Forbidden",
    "404 Not Found",
    "401 Unauthorized",
    "<title>Error</title>",
    "HTTP/1."
  )
  
  result$is_html <- any(sapply(html_patterns, function(pattern) {
    grepl(pattern, header_text, ignore.case = TRUE)
  }))
  
  if (verbose && result$is_html) {
    cat("Detected HTML content in file\n")
  }
  
  # Validate PDF structure
  if (result$is_pdf && !result$is_html) {
    # Check for %%EOF marker in the last 2048 bytes.
    # Some valid PDFs (e.g. from Europe PMC) have trailing data after %%EOF
    # or use non-standard line endings, so we search a larger window and
    # treat absence of %%EOF as a warning rather than a hard failure —
    # if the file has the correct magic number and is a reasonable size,
    # it is almost certainly a valid PDF.
    file_size <- file.size(file_path)
    con <- file(file_path, "rb")
    seek(con, where = max(0, file_size - 2048))
    footer <- readBin(con, "raw", n = 2048)
    close(con)
    
    footer_text <- safe_raw_to_char(footer)
    has_eof <- grepl("%%EOF", footer_text)
    
    if (verbose) {
      cat(sprintf("Has %%EOF marker: %s\n", has_eof))
    }
    
    # Accept the file if it has the PDF magic number and is not HTML.
    # A missing %%EOF on an otherwise valid-looking file is usually a
    # server truncation artefact or non-standard PDF writer — not corruption.
    result$valid  <- TRUE
    result$reason <- if (!has_eof) "missing_eof_marker_warned" else NA_character_
  } else if (result$is_html) {
    result$reason <- "html_error_page"
  } else {
    result$reason <- "invalid_pdf_format"
  }
  
  return(result)
}


#' Validate PDF with pdftools (Advanced)
#'
#' Uses pdftools package to perform deep validation
#' Only called if pdftools is installed
#'
#' @param file_path Path to the PDF file to validate
#'
#' @return List with validation results
#' @keywords internal

validate_pdf_advanced <- function(file_path) {
  
  result <- list(
    valid = FALSE,
    reason = NA_character_,
    num_pages = NA_integer_,
    has_text = FALSE
  )
  
  # Check if pdftools is available
  if (!requireNamespace("pdftools", quietly = TRUE)) {
    result$reason <- "pdftools_not_installed"
    return(result)
  }
  
  tryCatch({
    # Try to get PDF info
    info <- pdftools::pdf_info(file_path)
    result$num_pages <- info$pages
    
    # Try to extract text from first page
    text <- pdftools::pdf_text(file_path)
    result$has_text <- nchar(text[1]) > 0
    
    # If we got here, PDF is valid
    result$valid <- TRUE
    result$reason <- NA_character_
    
  }, error = function(e) {
    result$valid <<- FALSE
    if (grepl("PDF file is damaged", e$message)) {
      result$reason <<- "corrupted_pdf"
    } else if (grepl("password", e$message, ignore.case = TRUE)) {
      result$reason <<- "password_protected"
    } else {
      result$reason <<- "unreadable_pdf"
    }
  })
  
  return(result)
}


#' Check and Clean Invalid PDFs
#'
#' Validates all PDFs in a directory and optionally removes invalid ones
#'
#' @param output_folder Directory containing downloaded PDFs
#' @param log_file Path to the download log CSV (will be updated)
#' @param remove_invalid Remove invalid PDFs (default: FALSE, just report)
#' @param use_advanced Use pdftools for deep validation (default: FALSE)
#' @param min_size_kb Minimum file size threshold in KB (default: 10)
#'
#' @return Data frame with validation results for each file
#' @export
#'
#' @examples
#' \dontrun{
#' # Check PDFs and report issues
#' validation_results <- check_pdf_integrity("downloads")
#'
#' # Check and remove invalid PDFs
#' validation_results <- check_pdf_integrity("downloads", remove_invalid = TRUE)
#' 
#' # Use lenient threshold for PMC/Elsevier PDFs
#' validation_results <- check_pdf_integrity("downloads", min_size_kb = 1)
#' }

check_pdf_integrity <- function(output_folder, 
                                log_file = NULL,
                                remove_invalid = FALSE,
                                use_advanced = FALSE,
                                min_size_kb = 10) {
  
  # Get all PDF files
  pdf_files <- list.files(output_folder, pattern = "\\.pdf$", full.names = TRUE)
  
  if (length(pdf_files) == 0) {
    cli_alert_warning("No PDF files found in {output_folder}")
    return(data.frame())
  }
  
  cli_alert_info("Validating {length(pdf_files)} PDF files...")
  
  # Validate each file
  validation_results <- lapply(pdf_files, function(file_path) {
    
    # Basic validation with adjustable threshold
    basic_result <- validate_pdf(file_path, min_size_kb = min_size_kb)
    
    # Advanced validation if requested and available
    if (use_advanced && basic_result$valid) {
      advanced_result <- validate_pdf_advanced(file_path)
      basic_result$valid <- advanced_result$valid
      if (!advanced_result$valid) {
        basic_result$reason <- advanced_result$reason
      }
      basic_result$num_pages <- advanced_result$num_pages
    }
    
    # Add file path
    basic_result$file_path <- file_path
    basic_result$file_name <- basename(file_path)
    
    return(basic_result)
  })
  
  # Convert to data frame
  validation_df <- do.call(rbind, lapply(validation_results, as.data.frame))
  
  # Summary
  n_valid <- sum(validation_df$valid)
  n_invalid <- sum(!validation_df$valid)
  
  cli_alert_success("Valid PDFs: {n_valid}")
  if (n_invalid > 0) {
    cli_alert_danger("Invalid PDFs: {n_invalid}")
    
    # Show reasons
    reason_summary <- validation_df %>%
      filter(!valid) %>%
      group_by(reason) %>%
      summarise(count = n(), .groups = "drop") %>%
      arrange(desc(count))
    
    cli_alert_info("Failure reasons:")
    for (i in 1:nrow(reason_summary)) {
      cli_alert_info("  - {reason_summary$reason[i]}: {reason_summary$count[i]}")
    }
  }
  
  # Remove invalid files if requested
  if (remove_invalid && n_invalid > 0) {
    invalid_files <- validation_df$file_path[!validation_df$valid]
    
    cli_alert_warning("Removing {length(invalid_files)} invalid PDF files...")
    
    for (file in invalid_files) {
      unlink(file)
      cli_alert_info("  Removed: {basename(file)}")
    }
  }
  
  # Update log file if provided
  if (!is.null(log_file) && file.exists(log_file)) {
    cli_alert_info("Updating download log with validation results...")
    
    log_data <- read_csv(log_file, show_col_types = FALSE)
    
    # Add validation columns
    log_data <- log_data %>%
      left_join(
        validation_df %>% select(file_path, valid, reason),
        by = "file_path",
        suffix = c("", "_validation")
      ) %>%
      mutate(
        pdf_valid = coalesce(valid, NA),
        pdf_invalid_reason = coalesce(reason, NA_character_)
      ) %>%
      select(-valid, -reason)
    
    # Update success status for invalid PDFs
    log_data <- log_data %>%
      mutate(
        success = ifelse(!is.na(pdf_valid) & !pdf_valid, FALSE, success),
        failure_reason = ifelse(
          !is.na(pdf_valid) & !pdf_valid & is.na(failure_reason),
          pdf_invalid_reason,
          failure_reason
        )
      )
    
    write_csv(log_data, log_file)
    cli_alert_success("Log file updated: {log_file}")
  }
  
  return(validation_df)
}


#' Validate PDFs After Download
#'
#' Convenience wrapper to validate PDFs and update logs after a download session
#'
#' @param output_folder Directory containing downloaded PDFs
#' @param log_file Path to the download log CSV
#' @param report_file Path to regenerate acquisition report
#' @param email Email for report regeneration
#' @param remove_invalid Remove invalid PDFs (default: TRUE)
#' @param use_advanced Use pdftools for deep validation (default: FALSE)
#'
#' @return Data frame with validation results
#' @export
#'
#' @examples
#' \dontrun{
#' # After downloading PDFs
#' fetch_pdfs_from_doi("dois.csv", email = "you@edu")
#'
#' # Validate and clean up
#' validate_pdfs_after_download(
#'   output_folder = "downloads",
#'   log_file = "download_log.csv",
#'   report_file = "acquisition_report.md",
#'   email = "you@edu",
#'   remove_invalid = TRUE
#' )
#' }

validate_pdfs_after_download <- function(output_folder = "downloads",
                                         log_file = "download_log.csv",
                                         report_file = "acquisition_report.md",
                                         email = "your@email.com",
                                         remove_invalid = TRUE,
                                         use_advanced = FALSE) {
  
  cli_h1("Post-Download PDF Validation")
  
  # Validate PDFs
  validation_results <- check_pdf_integrity(
    output_folder = output_folder,
    log_file = log_file,
    remove_invalid = remove_invalid,
    use_advanced = use_advanced
  )
  
  # Regenerate report with updated log
  if (file.exists(log_file)) {
    cli_alert_info("Regenerating acquisition report with validation results...")
    
    log_data <- read_csv(log_file, show_col_types = FALSE)
    
    # Determine ID type
    id_type <- if ("doi" %in% names(log_data) || all(log_data$id_type == "doi")) {
      "doi"
    } else if ("pmid" %in% names(log_data) || all(log_data$id_type == "pmid")) {
      "pmid"
    } else {
      "mixed"
    }
    
    generate_acquisition_report(log_data, report_file, email, id_type)
    cli_alert_success("Updated acquisition report: {report_file}")
  }
  
  return(validation_results)
}