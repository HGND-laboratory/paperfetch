#' Import and Deduplicate References from Multiple Databases
#'
#' Imports reference files from Web of Science, Scopus, Cochrane, PubMed,
#' and other databases, then deduplicates them ready for PDF fetching.
#' Requires the \code{synthesisr} package.
#'
#' @param files Character vector of file paths to import. Supports:
#'   \itemize{
#'     \item \code{.bib} - BibTeX (Web of Science, Google Scholar)
#'     \item \code{.ris} - RIS format (Scopus, Embase, PsycINFO)
#'     \item \code{.txt} - Plain text (Cochrane, PubMed)
#'     \item \code{.csv} - CSV exports (any database)
#'   }
#' @param deduplicate Deduplicate references after import (default: TRUE)
#' @param match_by Column to use for deduplication (default: "title")
#' @param id_col Which column to use for PDF fetching: \code{"doi"} (default)
#'   or \code{"pmid"}
#' @param verbose Print import and deduplication details (default: TRUE)
#'
#' @return A data frame of (deduplicated) references with a summary printed
#'   to the console. Ready to pass to \code{fetch_pdfs()}.
#'
#' @details
#' This function is a wrapper around \code{synthesisr::read_refs()} and
#' \code{synthesisr::deduplicate()} that adds informative console output
#' and validation for use with \code{paperfetch}.
#'
#' Supported database export formats:
#' \tabular{ll}{
#'   \strong{Database}  \tab \strong{Recommended export format} \cr
#'   Web of Science     \tab BibTeX (.bib) or plain text (.txt) \cr
#'   Scopus             \tab RIS (.ris) or CSV (.csv)           \cr
#'   Cochrane           \tab Plain text (.txt) or RIS (.ris)    \cr
#'   PubMed             \tab PubMed format (.txt) or CSV (.csv) \cr
#'   Embase             \tab RIS (.ris)                         \cr
#'   PsycINFO           \tab RIS (.ris)                         \cr
#'   CINAHL             \tab RIS (.ris)                         \cr
#'   Google Scholar     \tab BibTeX (.bib)                      \cr
#' }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(paperfetch)
#'
#' # Import from multiple databases and deduplicate
#' refs <- import_refs(
#'   files = c("wos_export.bib", "scopus_export.ris", "cochrane_results.txt")
#' )
#'
#' # Then fetch PDFs
#' fetch_pdfs(refs$doi, email = "you@institution.edu")
#'
#' # Or pipe directly
#' import_refs(c("wos_export.bib", "scopus_export.ris")) |>
#'   fetch_refs_pdfs(email = "you@institution.edu")
#' }

import_refs <- function(files,
                        deduplicate = TRUE,
                        match_by    = "title",
                        id_col      = "doi",
                        verbose     = TRUE) {
  
 
  # Check synthesisr is available
  if (!requireNamespace("synthesisr", quietly = TRUE)) {
    cli_abort(c(
      "Package {.pkg synthesisr} is required for importing references.",
      "i" = "Install it with: {.code install.packages(\"synthesisr\")}",
      "i" = "Or from GitHub: {.code devtools::install_github(\"mjwestgate/synthesisr\")}"
    ))
  }
  
  # Validate files exist
  missing_files <- files[!file.exists(files)]
  if (length(missing_files) > 0) {
    cli_abort(c(
      "The following files were not found:",
      setNames(missing_files, rep("x", length(missing_files)))
    ))
  }
  
  # Step 1: Import 
  
  cli_h1("Importing References")
  
  # Import with per-file reporting
  all_refs <- lapply(files, function(f) {
    tryCatch({
      refs_f <- synthesisr::read_refs(f)
      if (verbose) {
        cli_alert_success(
          "Imported {nrow(refs_f)} record{?s} from {.file {basename(f)}}"
        )
      }
      refs_f
    }, error = function(e) {
      cli_alert_danger("Failed to import {.file {basename(f)}}: {conditionMessage(e)}")
      NULL
    })
  })
  
  # Remove failed imports
  all_refs <- Filter(Negate(is.null), all_refs)
  
  if (length(all_refs) == 0) {
    cli_abort("No files were successfully imported.")
  }
  
  # Combine all references
  refs_combined <- do.call(rbind, all_refs)
  n_total <- nrow(refs_combined)
  
  cli_alert_info(
    "Total records across {length(files)} file{?s}: {n_total}"
  )
  
  # Step 2: Deduplicate
  
  if (deduplicate) {
    cli_h1("Deduplicating References")
    
    # Check if match_by column exists
    if (!match_by %in% colnames(refs_combined)) {
      cli_alert_warning("Column {.field {match_by}} not found. Falling back to {.field title}.")
      match_by <- "title"
    }
    
    refs_out <- tryCatch({
      # Using 'Finer Control' method from synthesisr docs
      dups <- synthesisr::find_duplicates(
        refs_combined[[match_by]],
        method = "string_osa",
        rm_punctuation = TRUE,
        to_lower = TRUE
      )
      synthesisr::extract_unique_references(refs_combined, matches = dups)
    }, error = function(e) {
      cli_alert_warning("Deduplication failed: {conditionMessage(e)}. Returning non-deduplicated refs.")
      refs_combined
    })
    
    n_dupes <- n_total - nrow(refs_out)
    cli_alert_success("Unique records after deduplication: {nrow(refs_out)}")
    cli_alert_info("Duplicates removed: {n_dupes} ({sprintf('%.1f%%', (n_dupes/n_total)*100)})")
  } else {
    refs_out <- refs_combined
  }
  
  # Step 3: Validate ID column
  cli_h1("Checking Identifiers")
  
  # Find the actual column name (handles 'doi' vs 'DOI')
  actual_id_col <- colnames(refs_out)[tolower(colnames(refs_out)) == tolower(id_col)][1]
  
  if (is.na(actual_id_col)) {
    cli_alert_warning("Column {.field {id_col}} not found in references.")
    
    # Suggest available ID columns (Keep your great suggestion logic!)
    possible_id_cols <- intersect(
      colnames(refs_out),
      c("doi", "pmid", "pubmed_id", "PMID", "DOI", "url", "isbn")
    )
    
    if (length(possible_id_cols) > 0) {
      cli_alert_info("Available identifier columns: {.field {possible_id_cols}}")
    } else {
      cli_alert_danger("No recognisable identifier columns found. Manual inspection required.")
    }
  } else {
    # Use the 'actual' column found
    ids       <- refs_out[[actual_id_col]]
    n_ids     <- sum(!is.na(ids) & nchar(trimws(ids)) > 0)
    n_missing <- nrow(refs_out) - n_ids
    
    cli_alert_success("Records with {.field {actual_id_col}}: {n_ids} / {nrow(refs_out)}")
    
    if (n_missing > 0) {
      cli_alert_warning("{n_missing} record{?s} missing a {.field {actual_id_col}}; these will be skipped during fetching.")
    }
  }
  
  # Summary (Keep your clean bullet points)
  cli_rule()
  cli_alert_info("Import summary:")
  cli_bullets(c(
    " " = "Databases imported: {length(files)}",
    " " = "Total records (pre-dedup): {n_total}",
    " " = "Unique records: {nrow(refs_out)}",
    " " = "Records with {id_col}: {if (!is.na(actual_id_col)) sum(!is.na(refs_out[[actual_id_col]])) else 'unknown'}"
  ))
  cli_rule()
  
  return(refs_out)
}


#' Fetch PDFs from an Imported Reference Data Frame
#'
#' Convenience wrapper that takes a reference data frame (from
#' \code{import_refs()} or any data frame with a \code{doi} or
#' \code{pmid} column) and fetches PDFs directly. Designed for
#' pipe-friendly workflows.
#'
#' @param refs Data frame of references (from \code{import_refs()})
#' @param id_col Column to use for fetching: \code{"doi"} or \code{"pmid"}
#'   (auto-detected if not specified)
#' @param output_folder Directory for saving PDFs (default: "downloads")
#' @param delay Seconds between requests (default: 2)
#' @param email Your email for Unpaywall API. Can be set via
#'   \code{PAPERFETCH_EMAIL} in \code{.Renviron}
#' @param timeout Maximum seconds per request (default: 15)
#' @param log_file Path for structured CSV log (default: "download_log.csv")
#' @param report_file Path for Markdown report (default: "acquisition_report.md")
#' @param validate_pdfs Validate downloaded files (default: TRUE)
#' @param remove_invalid Remove invalid files (default: TRUE)
#' @param proxy Proxy URL or NULL (default: NULL)
#'
#' @return Invisibly returns the download log data frame
#' @export
#'
#' @examples
#' \dontrun{
#' # Pipe-friendly workflow
#' import_refs(c("wos_export.bib", "scopus_export.ris")) |>
#'   fetch_refs_pdfs(email = "you@institution.edu")
#'
#' # With custom options
#' refs <- import_refs(c("wos_export.bib", "scopus_export.ris"))
#' fetch_refs_pdfs(
#'   refs          = refs,
#'   output_folder = "systematic_review/pdfs",
#'   log_file      = "systematic_review/logs/download_log.csv",
#'   report_file   = "systematic_review/logs/acquisition_report.md",
#'   email         = "you@institution.edu"
#' )
#' }

fetch_refs_pdfs <- function(refs,
                            id_col         = NULL,
                            output_folder  = "downloads",
                            delay          = 2,
                            email          = NULL,
                            timeout        = 15,
                            log_file       = "download_log.csv",
                            report_file    = "acquisition_report.md",
                            validate_pdfs  = TRUE,
                            remove_invalid = TRUE,
                            proxy          = NULL) {
  
  if (!is.data.frame(refs)) {
    cli_abort("{.arg refs} must be a data frame (e.g. from {.fn import_refs}).")
  }
  
  # Auto-detect ID column
  if (is.null(id_col)) {
    if ("doi" %in% colnames(refs) && 
        sum(!is.na(refs$doi)) > 0) {
      id_col <- "doi"
      cli_alert_info("Auto-detected ID column: {.field doi}")
      
    } else if (any(c("pmid","PMID","pubmed_id") %in% colnames(refs))) {
      id_col <- intersect(c("pmid","PMID","pubmed_id"), colnames(refs))[1]
      cli_alert_info("Auto-detected ID column: {.field {id_col}}")
      
    } else {
      cli_abort(c(
        "Could not auto-detect an ID column.",
        "i" = "Specify {.arg id_col = \"doi\"} or {.arg id_col = \"pmid\"}."
      ))
    }
  }
  
  # Validate column exists
  if (!id_col %in% colnames(refs)) {
    cli_abort("Column {.field {id_col}} not found in refs data frame.")
  }
  
  # Extract and clean IDs
  ids <- refs[[id_col]]
  ids <- ids[!is.na(ids) & nchar(trimws(ids)) > 0]
  
  if (length(ids) == 0) {
    cli_abort("No valid IDs found in column {.field {id_col}}.")
  }
  
  cli_alert_info("Fetching PDFs for {length(ids)} record{?s} using {.field {id_col}}...")
  
  # Pass to fetch_pdfs()
  fetch_pdfs(
    input          = ids,
    output_folder  = output_folder,
    delay          = delay,
    email          = email,
    timeout        = timeout,
    log_file       = log_file,
    report_file    = report_file,
    validate_pdfs  = validate_pdfs,
    remove_invalid = remove_invalid,
    proxy          = proxy
  )
}