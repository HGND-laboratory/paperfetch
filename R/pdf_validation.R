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
#'   - valid: Logical, TRUE if PDF is valid
#'   - reason: Character, reason for failure (if invalid)
#'   - file_size_kb: Numeric, actual file size
#'   - is_pdf: Logical, TRUE if file has PDF magic number
#'   - is_html: Logical, TRUE if file appears to be HTML
#'
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' validate_pdf("paper.pdf")
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
  
  # Check PDF magic number (%PDF- at start)
  # PDF files MUST start with %PDF-1.x
  pdf_magic <- rawToChar(header[1:min(8, length(header))])
  result$is_pdf <- grepl("^%PDF-", pdf_magic)
  
  if (verbose) {
    cat(sprintf("Magic number: %s\n", substr(pdf_magic, 1, 20)))
    cat(sprintf("Is PDF: %s\n", result$is_pdf))
  }
  
  # Check for HTML content (common soft failure)
  # Convert first 500 bytes to character
  header_text <- rawToChar(header[1:min(500, length(header))])
  
  # Check for HTML indicators
  html_patterns <- c(
    "<!DOCTYPE", "<!doctype", "<html", "<HTML",
    "<head>", "<HEAD>", "<body>", "<BODY>",
    "Access Denied", "403 Forbidden", "404 Not Found",
    "Error", "ERROR", "Unauthorized"
  )
  
  result$is_html <- any(sapply(html_patterns, function(pattern) {
    grepl(pattern, header_text, ignore.case = TRUE)
  }))
  
  if (verbose && result$is_html) {
    cat("Detected HTML content in file\n")
  }
  
  # Validate PDF structure
  if (result$is_pdf && !result$is_html) {
    # Additional validation: check for %%EOF at end
    # Read last 1024 bytes
    file_size <- file.size(file_path)
    con <- file(file_path, "rb")
    seek(con, where = max(0, file_size - 1024))
    footer <- readBin(con, "raw", n = 1024)
    close(con)
    
    footer_text <- rawToChar(footer)
    has_eof <- grepl("%%EOF", footer_text)
    
    if (verbose) {
      cat(sprintf("Has %%EOF marker: %s\n", has_eof))
    }
    
    if (has_eof) {
      result$valid <- TRUE
      result$reason <- NA_character_
    } else {
      result$valid <- FALSE
      result$reason <- "missing_eof_marker"
    }
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
#' }

check_pdf_integrity <- function(output_folder, 
                                log_file = NULL,
                                remove_invalid = FALSE,
                                use_advanced = FALSE) {
  
  require(cli)
  require(dplyr)
  require(readr)
  
  # Get all PDF files
  pdf_files <- list.files(output_folder, pattern = "\\.pdf$", full.names = TRUE)
  
  if (length(pdf_files) == 0) {
    cli_alert_warning("No PDF files found in {output_folder}")
    return(data.frame())
  }
  
  cli_alert_info("Validating {length(pdf_files)} PDF files...")
  
  # Validate each file
  validation_results <- lapply(pdf_files, function(file_path) {
    
    # Basic validation
    basic_result <- validate_pdf(file_path)
    
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