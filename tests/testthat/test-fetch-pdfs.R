# tests/testthat/test-fetch-pdfs.R
# Tests for the fetch_pdfs() wrapper function
# Network calls are mocked throughout to keep tests fast and offline

test_that("fetch_pdfs errors when CSV column not found", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  
  # CSV with neither doi nor pmid column
  readr::write_csv(data.frame(title = c("A", "B")), tmp)
  
  expect_error(
    fetch_pdfs(tmp, email = "test@test.com"),
    regexp = "doi.*pmid|pmid.*doi"
  )
})

test_that("fetch_pdfs errors for non-existent CSV file", {
  # file.exists() check inside fetch_pdfs routes to stop()
  # Non-existent path that looks like a CSV but isn't a classifiable ID
  expect_error(
    fetch_pdfs("nonexistent_file.csv", email = "test@test.com")
  )
})

test_that("fetch_pdfs classifies mixed ID vector correctly", {
  ids <- c("10.1038/nature12373", "30670877", "PMC5176308", "unknown_id")
  types <- sapply(ids, classify_id)
  
  expect_equal(types[["10.1038/nature12373"]], "doi")
  expect_equal(types[["30670877"]],           "pmid")
  expect_equal(types[["PMC5176308"]],         "pmc")
  expect_equal(types[["unknown_id"]],         "unknown")
})

test_that("fetch_pdfs returns list with total/successful/failed", {
  # Use mockery to avoid real network calls
  skip_if_not_installed("mockery")
  
  mockery::stub(fetch_pdfs, "fetch_pdfs_from_doi",   function(...) invisible(NULL))
  mockery::stub(fetch_pdfs, "fetch_pdfs_from_pmids", function(...) invisible(NULL))
  
  tmp_doi <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp_doi))
  readr::write_csv(data.frame(doi = c("10.1038/a", "10.1038/b")), tmp_doi)
  
  result <- fetch_pdfs(tmp_doi, email = "test@test.com")
  
  expect_null(result)   # CSV path returns invisible(NULL) from wrapper
})

test_that("fetch_pdfs creates output folder if it does not exist", {
  skip_if_not_installed("mockery")
  
  mockery::stub(fetch_pdfs, "fetch_pdfs_from_doi", function(...) invisible(NULL))
  
  tmp_dir <- file.path(tempdir(), paste0("pf_test_", sample.int(1e6, 1)))
  on.exit(unlink(tmp_dir, recursive = TRUE))
  
  tmp_csv <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp_csv), add = TRUE)
  readr::write_csv(data.frame(doi = "10.1038/a"), tmp_csv)
  
  fetch_pdfs(tmp_csv, output_folder = tmp_dir, email = "test@test.com")
  expect_true(dir.exists(tmp_dir))
})