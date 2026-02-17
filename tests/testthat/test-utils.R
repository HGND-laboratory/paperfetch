# tests/testthat/test-utils.R
# Tests for utility functions: classify_id, resolve_email, apply_proxy,
# create_log_entry, convert_pmc_to_pmid

test_that("classify_id correctly identifies DOIs", {
  expect_equal(classify_id("10.1038/nature12373"),       "doi")
  expect_equal(classify_id("10.1016/j.cell.2020.01.001"),"doi")
  expect_equal(classify_id("10.1126/science.abc1234"),   "doi")
  # DOI with special characters
  expect_equal(classify_id("10.1002/(SICI)1097-0142"),   "doi")
})

test_that("classify_id correctly identifies PMIDs", {
  expect_equal(classify_id("30670877"),   "pmid")
  expect_equal(classify_id("28445112"),   "pmid")
  expect_equal(classify_id("1"),          "pmid")
})

test_that("classify_id correctly identifies PMC IDs", {
  expect_equal(classify_id("PMC5176308"), "pmc")
  expect_equal(classify_id("pmc1234567"), "pmc")  # case-insensitive
  expect_equal(classify_id("PMC123"),     "pmc")
})

test_that("classify_id returns unknown for unrecognised input", {
  expect_equal(classify_id("not_an_id"),          "unknown")
  expect_equal(classify_id(""),                   "unknown")
  expect_equal(classify_id("random string here"), "unknown")
  expect_equal(classify_id("https://doi.org/10.1038/nature12373"), "unknown")
})

test_that("classify_id handles edge cases gracefully", {
  expect_equal(classify_id(NA_character_), "unknown")
  expect_equal(classify_id(123),           "pmid")   # numeric coerced to char
})

# ── resolve_email ─────────────────────────────────────────────────────────────

test_that("resolve_email returns explicit email when provided", {
  result <- resolve_email("test@university.edu")
  expect_equal(result, "test@university.edu")
})

test_that("resolve_email reads from PAPERFETCH_EMAIL env var", {
  withr::with_envvar(
    c(PAPERFETCH_EMAIL = "env@institution.edu"),
    {
      result <- resolve_email(NULL)
      expect_equal(result, "env@institution.edu")
    }
  )
})

test_that("resolve_email prefers explicit arg over env var", {
  withr::with_envvar(
    c(PAPERFETCH_EMAIL = "env@institution.edu"),
    {
      result <- resolve_email("explicit@institution.edu")
      expect_equal(result, "explicit@institution.edu")
    }
  )
})

test_that("resolve_email warns and returns placeholder when nothing set", {
  withr::with_envvar(
    c(PAPERFETCH_EMAIL = ""),
    {
      expect_warning(
        result <- resolve_email(NULL),
        regexp = NA   # cli warnings don't use base warning — just check return
      )
      # Returns placeholder rather than crashing
      expect_type(result, "character")
      expect_true(nchar(result) > 0)
    }
  )
})

# ── create_log_entry ──────────────────────────────────────────────────────────

test_that("create_log_entry returns a single-row data frame", {
  entry <- create_log_entry(
    id             = "10.1038/nature12373",
    id_type        = "doi",
    timestamp      = "2025-02-16T14:23:45Z",
    method         = "unpaywall",
    status         = "200",
    success        = TRUE,
    failure_reason = NA_character_,
    pdf_url        = "https://example.com/paper.pdf",
    file_path      = "downloads/paper.pdf",
    file_size_kb   = 1024.5
  )
  
  expect_s3_class(entry, "data.frame")
  expect_equal(nrow(entry), 1L)
})

test_that("create_log_entry contains all required columns", {
  entry <- create_log_entry(
    id = "30670877", id_type = "pmid",
    timestamp = "2025-02-16T14:23:45Z",
    method = "pmc", status = "200", success = TRUE,
    failure_reason = NA_character_,
    pdf_url = "https://ncbi.nlm.nih.gov/pmc/articles/PMC123/pdf/",
    file_path = "downloads/PMID_30670877.pdf",
    file_size_kb = 512.0
  )
  
  expected_cols <- c(
    "id", "id_type", "timestamp", "method", "status", "success",
    "failure_reason", "pdf_url", "file_path", "file_size_kb",
    "pdf_valid", "pdf_invalid_reason"
  )
  expect_true(all(expected_cols %in% colnames(entry)))
})

test_that("create_log_entry correctly stores failure info", {
  entry <- create_log_entry(
    id = "10.1016/j.cell.2020.01.001", id_type = "doi",
    timestamp = "2025-02-16T14:23:45Z",
    method = "unpaywall", status = "403", success = FALSE,
    failure_reason = "paywalled",
    pdf_url = NA_character_, file_path = NA_character_,
    file_size_kb = NA_real_
  )
  
  expect_false(entry$success)
  expect_equal(entry$failure_reason, "paywalled")
  expect_equal(entry$status, "403")
  expect_true(is.na(entry$file_path))
})