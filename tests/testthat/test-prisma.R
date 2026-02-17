# tests/testthat/test-prisma.R
# Tests for as_prisma_counts() and plot_prisma_fulltext()

# ── Helpers ───────────────────────────────────────────────────────────────────

make_test_log <- function(tmp_path) {
  log_data <- data.frame(
    id             = c("10.1038/a", "10.1038/b", "10.1038/c",
                       "10.1038/d", "10.1038/e"),
    id_type        = rep("doi", 5),
    timestamp      = rep("2025-02-16T14:23:45Z", 5),
    method         = c("unpaywall", "pmc", "scrape", "unpaywall", "doi_resolution"),
    status         = c("200", "200", "200", "403", "200"),
    success        = c(TRUE, TRUE, TRUE, FALSE, TRUE),
    failure_reason = c(NA, NA, NA, "paywalled", NA),
    pdf_url        = c("https://a.com/a.pdf", "https://b.com/b.pdf",
                       "https://c.com/c.pdf", NA, "https://e.com/e.pdf"),
    file_path      = c("a.pdf", "b.pdf", "c.pdf", NA, "e.pdf"),
    file_size_kb   = c(1024, 512, 768, NA, 2048),
    pdf_valid      = c(TRUE, TRUE, FALSE, NA, TRUE),
    pdf_invalid_reason = c(NA, NA, "html_error_page", NA, NA),
    stringsAsFactors = FALSE
  )
  
  readr::write_csv(log_data, tmp_path)
  invisible(log_data)
}

# ── as_prisma_counts ──────────────────────────────────────────────────────────

test_that("as_prisma_counts returns a named list", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  make_test_log(tmp)
  
  result <- as_prisma_counts(tmp, verbose = FALSE)
  expect_type(result, "list")
})

test_that("as_prisma_counts contains all required fields", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  make_test_log(tmp)
  
  result <- as_prisma_counts(tmp, verbose = FALSE)
  
  expect_true("reports_sought_retrieval" %in% names(result))
  expect_true("reports_not_retrieved"    %in% names(result))
  expect_true("reports_excluded_invalid" %in% names(result))
  expect_true("reports_acquired"         %in% names(result))
  expect_true("reports_skipped"          %in% names(result))
})

test_that("as_prisma_counts calculates correct totals", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  make_test_log(tmp)
  
  result <- as_prisma_counts(tmp, verbose = FALSE)
  
  # 5 rows total, none skipped
  expect_equal(result$reports_sought_retrieval, 5L)
  
  # 1 failure (paywalled)
  expect_equal(result$reports_not_retrieved, 1L)
  
  # 1 invalid PDF (html_error_page)
  expect_equal(result$reports_excluded_invalid, 1L)
  
  # 3 successfully acquired and valid
  expect_equal(result$reports_acquired, 3L)
})

test_that("as_prisma_counts excludes skipped records from sought count", {
  log_data <- data.frame(
    id             = c("10.1038/a", "10.1038/b"),
    id_type        = c("doi", "doi"),
    timestamp      = rep("2025-02-16T14:23:45Z", 2),
    method         = c("unpaywall", "skipped"),
    status         = c("200", "exists"),
    success        = c(TRUE, TRUE),
    failure_reason = c(NA, NA),
    pdf_url        = c("https://a.com/a.pdf", NA),
    file_path      = c("a.pdf", "a.pdf"),
    file_size_kb   = c(1024, 1024),
    pdf_valid      = c(TRUE, NA),
    pdf_invalid_reason = c(NA, NA),
    stringsAsFactors = FALSE
  )
  
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  readr::write_csv(log_data, tmp)
  
  result <- as_prisma_counts(tmp, verbose = FALSE)
  
  # Only 1 active record, 1 skipped
  expect_equal(result$reports_sought_retrieval, 1L)
  expect_equal(result$reports_skipped, 1L)
})

test_that("as_prisma_counts accepts a data frame directly", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  log_df <- make_test_log(tmp)
  
  # Pass data frame instead of file path
  result <- as_prisma_counts(log_df, verbose = FALSE)
  expect_type(result, "list")
  expect_equal(result$reports_sought_retrieval, 5L)
})

test_that("as_prisma_counts errors cleanly for missing file", {
  expect_error(
    as_prisma_counts("nonexistent_log.csv"),
    regexp = "Log file not found"
  )
})

test_that("as_prisma_counts errors for log missing required columns", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  
  # Write log without 'success' column
  bad_log <- data.frame(id = c("a", "b"), id_type = c("doi", "doi"))
  readr::write_csv(bad_log, tmp)
  
  expect_error(
    as_prisma_counts(tmp),
    regexp = "missing required columns"
  )
})

test_that("as_prisma_counts handles log without pdf_valid column", {
  log_data <- data.frame(
    id             = c("10.1038/a", "10.1038/b"),
    id_type        = c("doi", "doi"),
    timestamp      = rep("2025-02-16T14:23:45Z", 2),
    method         = c("unpaywall", "unpaywall"),
    status         = c("200", "403"),
    success        = c(TRUE, FALSE),
    failure_reason = c(NA, "paywalled"),
    stringsAsFactors = FALSE
  )
  
  # Should not error — pdf_valid is optional
  result <- as_prisma_counts(log_data, verbose = FALSE)
  expect_equal(result$reports_sought_retrieval, 2L)
  expect_equal(result$reports_not_retrieved, 1L)
})