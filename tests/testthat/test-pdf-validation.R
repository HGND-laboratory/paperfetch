# tests/testthat/test-pdf-validation.R
# Tests for validate_pdf() and check_pdf_integrity()

# ── Helpers ───────────────────────────────────────────────────────────────────

# Create a minimal but valid PDF file for testing
create_minimal_pdf <- function(path) {
  pdf_content <- paste0(
    "%PDF-1.4\n",
    "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
    "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\n",
    "xref\n0 4\n0000000000 65535 f\n",
    "trailer\n<< /Size 4 /Root 1 0 R >>\n",
    "startxref\n0\n%%EOF"
  )
  writeLines(pdf_content, path)
  invisible(path)
}

# Create an HTML error page disguised as a PDF
create_fake_pdf_html <- function(path) {
  html_content <- paste0(
    "<!DOCTYPE html>\n<html>\n<head><title>Access Denied</title></head>\n",
    "<body><h1>403 Forbidden</h1><p>You don't have permission.</p></body>\n",
    "</html>"
  )
  writeLines(html_content, path)
  invisible(path)
}

# Create a tiny (corrupt) file
create_tiny_file <- function(path) {
  writeLines("tiny", path)
  invisible(path)
}

# ── validate_pdf ──────────────────────────────────────────────────────────────

test_that("validate_pdf returns FALSE for non-existent file", {
  result <- validate_pdf("definitely_does_not_exist.pdf")
  expect_false(result$valid)
  expect_equal(result$reason, "file_not_found")
})

test_that("validate_pdf detects valid PDF by magic number", {
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp))
  create_minimal_pdf(tmp)
  
  result <- validate_pdf(tmp)
  expect_true(result$is_pdf)
  expect_false(result$is_html)
})

test_that("validate_pdf detects HTML error page", {
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp))
  create_fake_pdf_html(tmp)
  
  result <- validate_pdf(tmp)
  expect_false(result$valid)
  expect_true(result$is_html)
  expect_equal(result$reason, "html_error_page")
})

test_that("validate_pdf fails for file below minimum size", {
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp))
  create_tiny_file(tmp)
  
  result <- validate_pdf(tmp, min_size_kb = 10)
  expect_false(result$valid)
  expect_equal(result$reason, "file_too_small")
})

test_that("validate_pdf reports correct file size", {
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp))
  create_minimal_pdf(tmp)
  
  result <- validate_pdf(tmp, min_size_kb = 0)  # size = 0 to avoid size failure
  expect_true(!is.na(result$file_size_kb))
  expect_gt(result$file_size_kb, 0)
})

# ── check_pdf_integrity ───────────────────────────────────────────────────────

test_that("check_pdf_integrity handles empty folder gracefully", {
  tmp_dir <- tempdir()
  empty_dir <- file.path(tmp_dir, "empty_pdfs")
  dir.create(empty_dir, showWarnings = FALSE)
  on.exit(unlink(empty_dir, recursive = TRUE))
  
  result <- check_pdf_integrity(empty_dir)
  expect_equal(nrow(result), 0L)
})

test_that("check_pdf_integrity validates multiple files", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))
  
  create_minimal_pdf(file.path(tmp_dir, "valid.pdf"))
  create_fake_pdf_html(file.path(tmp_dir, "fake.pdf"))
  
  result <- check_pdf_integrity(tmp_dir, remove_invalid = FALSE)
  
  expect_equal(nrow(result), 2L)
  expect_equal(sum(result$valid),  1L)
  expect_equal(sum(!result$valid), 1L)
})

test_that("check_pdf_integrity removes invalid files when remove_invalid = TRUE", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))
  
  valid_path <- file.path(tmp_dir, "valid.pdf")
  fake_path  <- file.path(tmp_dir, "fake.pdf")
  
  create_minimal_pdf(valid_path)
  create_fake_pdf_html(fake_path)
  
  check_pdf_integrity(tmp_dir, remove_invalid = TRUE)
  
  expect_true(file.exists(valid_path))
  expect_false(file.exists(fake_path))
})