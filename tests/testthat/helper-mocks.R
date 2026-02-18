# tests/testthat/helper-mocks.R
# Shared mock helpers loaded automatically by testthat

# Create a minimal valid PDF that passes size check
write_minimal_pdf <- function(filename = NULL) {
  path <- if (is.null(filename)) tempfile(fileext = ".pdf") else filename
  
  # Create a PDF with enough content to exceed 10 KB minimum
  pdf_content <- paste0(
    "%PDF-1.4\n",
    "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
    "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\n",
    # Add padding to make file larger than 10 KB
    paste(rep("% Padding line to increase file size\n", 300), collapse = ""),
    "xref\n0 4\n0000000000 65535 f\n",
    "trailer\n<< /Size 4 /Root 1 0 R >>\n",
    "startxref\n0\n%%EOF"
  )
  
  writeLines(pdf_content, path)
  invisible(path)
}

# Create an HTML fake PDF (also needs to be > 10 KB to test properly)
write_fake_pdf <- function(filename = NULL) {
  path <- if (is.null(filename)) tempfile(fileext = ".pdf") else filename
  
  html_content <- paste0(
    "<!DOCTYPE html>\n<html>\n<head><title>Access Denied</title></head>\n",
    "<body>\n<h1>403 Forbidden</h1>\n<p>You don't have permission to access this resource.</p>\n",
    # Add padding
    paste(rep("<p>Padding text to make file larger.</p>\n", 300), collapse = ""),
    "</body>\n</html>"
  )
  
  writeLines(html_content, path)
  invisible(path)
}

# Create a tiny file (for testing file_too_small detection)
write_tiny_file <- function(filename = NULL) {
  path <- if (is.null(filename)) tempfile(fileext = ".pdf") else filename
  writeLines("tiny", path)
  invisible(path)
}

# Build a minimal paperfetch-format log data frame
make_log_df <- function(n_success = 3, n_fail = 1, n_invalid = 1) {
  n <- n_success + n_fail + n_invalid
  
  data.frame(
    id             = paste0("10.1000/test", seq_len(n)),
    id_type        = rep("doi", n),
    timestamp      = rep("2025-02-16T14:23:45Z", n),
    method         = c(
      rep("unpaywall", n_success),
      rep("unpaywall", n_fail),
      rep("scrape",    n_invalid)
    ),
    status         = c(rep("200", n_success), rep("403", n_fail), rep("200", n_invalid)),
    success        = c(rep(TRUE, n_success), rep(FALSE, n_fail), rep(TRUE, n_invalid)),
    failure_reason = c(rep(NA, n_success), rep("paywalled", n_fail), rep(NA, n_invalid)),
    pdf_url        = c(
      paste0("https://example.com/", seq_len(n_success), ".pdf"),
      rep(NA, n_fail),
      paste0("https://example.com/invalid", seq_len(n_invalid), ".pdf")
    ),
    file_path      = c(
      paste0("downloads/", seq_len(n_success), ".pdf"),
      rep(NA, n_fail),
      paste0("downloads/invalid", seq_len(n_invalid), ".pdf")
    ),
    file_size_kb   = c(rep(1024, n_success), rep(NA, n_fail), rep(2, n_invalid)),
    pdf_valid      = c(rep(TRUE, n_success), rep(NA, n_fail), rep(FALSE, n_invalid)),
    pdf_invalid_reason = c(
      rep(NA, n_success),
      rep(NA, n_fail),
      rep("html_error_page", n_invalid)
    ),
    stringsAsFactors = FALSE
  )
}