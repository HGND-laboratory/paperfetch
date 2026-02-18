generate_acquisition_report <- function(log_data, report_file, email, id_type = "mixed") {
  
  # Calculate statistics
  total <- nrow(log_data)
  successful <- sum(log_data$success & log_data$status != "exists", na.rm = TRUE)
  skipped <- sum(log_data$status == "exists", na.rm = TRUE)
  failed <- total - successful - skipped
  success_rate <- if (total > 0) (successful / (total - skipped)) * 100 else 0
  
  # Method breakdown
  method_summary <- log_data %>%
    filter(status != "exists") %>%
    group_by(method) %>%
    summarise(
      attempts = n(),
      success = sum(success, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(success_rate = (success / attempts) * 100) %>%
    arrange(desc(success_rate))
  
  # Failure analysis
  failure_summary <- log_data %>%
    filter(!success & status != "exists") %>%
    group_by(failure_reason) %>%
    summarise(count = n(), .groups = "drop") %>%
    mutate(percentage = (count / failed) * 100) %>%
    arrange(desc(count))
  
  # Failed records by reason
  paywalled <- log_data %>% 
    filter(grepl("403|paywalled", failure_reason, ignore.case = TRUE)) %>% 
    pull(id)
  
  no_pdf <- log_data %>% 
    filter(grepl("no_pdf|not_found|404", failure_reason, ignore.case = TRUE)) %>% 
    pull(id)
  
  technical <- log_data %>% 
    filter(grepl("timeout|500|error", failure_reason, ignore.case = TRUE)) %>% 
    pull(id)
  
  # ── Build report ──────────────────────────────────────────────────────────────
  
  report <- paste0(
    "# Full-Text Acquisition Report\n\n",
    "**Generated:** ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n",
    "**Package:** paperfetch v0.1.0\n",
    "**Analyst:** ", email, "\n\n",
    "---\n\n"
  )
  
  # ── Summary ───────────────────────────────────────────────────────────────────
  
  report <- paste0(report,
                   "## Summary\n\n",
                   "- **Total records:** ", total, "\n",
                   "- **Successfully downloaded:** ", successful, " (", sprintf("%.1f%%", success_rate), ")\n",
                   "- **Failed to retrieve:** ", failed, " (", sprintf("%.1f%%", (failed / total) * 100), ")\n",
                   if (skipped > 0) paste0("- **Already existed (skipped):** ", skipped, " (", sprintf("%.1f%%", (skipped / total) * 100), ")\n") else "",
                   "\n---\n\n"
  )
  
  # ── Retrieval Methods ─────────────────────────────────────────────────────────
  
  if (nrow(method_summary) > 0) {
    report <- paste0(report,
                     "## Retrieval Methods\n\n",
                     "| Method | Attempts | Success | Success Rate |\n",
                     "|--------|----------|---------|-------------|\n"
    )
    
    for (i in 1:nrow(method_summary)) {
      report <- paste0(report,
                       "| ", method_summary$method[i], " | ",
                       method_summary$attempts[i], " | ",
                       method_summary$success[i], " | ",
                       sprintf("%.1f%%", method_summary$success_rate[i]), " |\n"
      )
    }
    
    report <- paste0(report, "\n---\n\n")
  }
  
  # ── Failure Analysis ──────────────────────────────────────────────────────────
  
  if (nrow(failure_summary) > 0) {
    report <- paste0(report,
                     "## Failure Analysis\n\n",
                     "| Reason | Count | Percentage |\n",
                     "|--------|-------|------------|\n"
    )
    
    for (i in 1:nrow(failure_summary)) {
      report <- paste0(report,
                       "| ", failure_summary$failure_reason[i], " | ",
                       failure_summary$count[i], " | ",
                       sprintf("%.1f%%", failure_summary$percentage[i]), " |\n"
      )
    }
    
    report <- paste0(report, "\n---\n\n")
  }
  
  # ── Failed Records ────────────────────────────────────────────────────────────
  
  if (length(paywalled) > 0 || length(no_pdf) > 0 || length(technical) > 0) {
    report <- paste0(report, "## Failed Records\n\n")
    
    if (length(paywalled) > 0) {
      report <- paste0(report,
                       "### Paywalled Content (n=", length(paywalled), ")\n```\n",
                       paste(head(paywalled, 20), collapse = "\n"), "\n",
                       if (length(paywalled) > 20) paste0("... and ", length(paywalled) - 20, " more\n") else "",
                       "```\n\n"
      )
    }
    
    if (length(no_pdf) > 0) {
      report <- paste0(report,
                       "### No PDF Available (n=", length(no_pdf), ")\n```\n",
                       paste(head(no_pdf, 20), collapse = "\n"), "\n",
                       if (length(no_pdf) > 20) paste0("... and ", length(no_pdf) - 20, " more\n") else "",
                       "```\n\n"
      )
    }
    
    if (length(technical) > 0) {
      report <- paste0(report,
                       "### Technical Failures (n=", length(technical), ")\n```\n",
                       paste(head(technical, 20), collapse = "\n"), "\n",
                       if (length(technical) > 20) paste0("... and ", length(technical) - 20, " more\n") else "",
                       "```\n\n"
      )
    }
    
    report <- paste0(report, "---\n\n")
  }
  
  # ── PDF Validation ────────────────────────────────────────────────────────────
  # Placed BEFORE Reproducibility to keep diagnostics together
  
  if ("pdf_valid" %in% colnames(log_data)) {
    n_validated <- sum(!is.na(log_data$pdf_valid))
    n_valid_pdfs <- sum(log_data$pdf_valid == TRUE, na.rm = TRUE)
    n_invalid_pdfs <- sum(log_data$pdf_valid == FALSE, na.rm = TRUE)
    
    if (n_validated > 0) {
      report <- paste0(report,
                       "## PDF Integrity Validation\n\n",
                       "- **PDFs validated:** ", n_validated, "\n",
                       "- **Valid PDFs:** ", n_valid_pdfs, " (", sprintf("%.1f%%", (n_valid_pdfs / n_validated) * 100), ")\n",
                       "- **Invalid PDFs detected and removed:** ", n_invalid_pdfs, " (", sprintf("%.1f%%", (n_invalid_pdfs / n_validated) * 100), ")\n\n"
      )
      
      # Invalid PDF reasons breakdown
      if (n_invalid_pdfs > 0) {
        invalid_pdf_summary <- log_data %>%
          filter(pdf_valid == FALSE) %>%
          group_by(pdf_invalid_reason) %>%
          summarise(count = n(), .groups = "drop") %>%
          arrange(desc(count))
        
        report <- paste0(report,
                         "### Invalid PDF Breakdown\n\n",
                         "| Reason | Count | Description |\n",
                         "|--------|-------|-------------|\n"
        )
        
        # Human-readable descriptions for each reason
        reason_descriptions <- list(
          "html_error_page"      = "HTML error page disguised as PDF",
          "file_too_small"       = "File too small (likely an error response)",
          "missing_eof_marker"   = "Corrupt PDF missing %%EOF marker",
          "invalid_pdf_format"   = "File does not begin with %PDF- header",
          "corrupted_pdf"        = "PDF is damaged and unreadable",
          "password_protected"   = "PDF is password-protected",
          "unreadable_pdf"       = "PDF could not be parsed"
        )
        
        for (i in 1:nrow(invalid_pdf_summary)) {
          reason <- invalid_pdf_summary$pdf_invalid_reason[i]
          description <- reason_descriptions[[reason]]
          if (is.null(description)) description <- "Unknown issue"
          
          report <- paste0(report,
                           "| ", reason, " | ",
                           invalid_pdf_summary$count[i], " | ",
                           description, " |\n"
          )
        }
        
        # List the actual invalid IDs
        invalid_ids <- log_data %>%
          filter(pdf_valid == FALSE) %>%
          pull(id)
        
        report <- paste0(report,
                         "\n### IDs with Invalid PDFs\n\n",
                         "These records require manual retrieval:\n\n```\n",
                         paste(head(invalid_ids, 20), collapse = "\n"), "\n",
                         if (length(invalid_ids) > 20) paste0("... and ", length(invalid_ids) - 20, " more\n") else "",
                         "```\n\n"
        )
      }
      
      report <- paste0(report, "---\n\n")
    }
  }
  # ── PRISMA 2020 Counts ────────────────────────────────────────────────────────
  
  prisma_counts <- as_prisma_counts(log_data, verbose = FALSE)
  
  report <- paste0(report,
                   "## PRISMA 2020 Full-Text Retrieval Counts\n\n",
                   "Copy these numbers directly into your PRISMA 2020 flow diagram:\n\n",
                   "| PRISMA 2020 Field | Count |\n",
                   "|-------------------|-------|\n",
                   "| Reports sought for retrieval | ",
                   prisma_counts$reports_sought_retrieval, " |\n",
                   "| Reports not retrieved | ",
                   prisma_counts$reports_not_retrieved, " |\n",
                   "| Reports excluded (invalid PDF) | ",
                   prisma_counts$reports_excluded_invalid, " |\n",
                   "| **Reports acquired** | **",
                   prisma_counts$reports_acquired, "** |\n\n",
                   "```r\n",
                   "# Generate PRISMA 2020 flow diagram\n",
                   "library(paperfetch)\n",
                   "library(PRISMA2020)\n\n",
                   "prisma_stats <- as_prisma_counts(\"", log_file_name, "\")\n",
                   "plot_prisma_fulltext(prisma_stats)\n",
                   "```\n\n",
                   "---\n\n"
  )
  # ── Reproducibility Information ───────────────────────────────────────────────
  
  report <- paste0(report,
                   "## Reproducibility Information\n\n",
                   "**System Information:**\n",
                   "- R version: ", R.version.string, "\n",
                   "- paperfetch version: 0.1.0\n",
                   "- Platform: ", R.version$platform, "\n\n",
                   "**Parameters:**\n",
                   "- Email: ", email, "\n",
                   "- Date: ", format(Sys.Date(), "%Y-%m-%d"), "\n\n",
                   "**Data Sources:**\n",
                   "- Unpaywall API (https://unpaywall.org)\n",
                   "- PubMed Central (https://www.ncbi.nlm.nih.gov/pmc/)\n",
                   "- Publisher websites via DOI resolution\n\n",
                   "---\n\n"
  )
  
  # ── Recommendations ───────────────────────────────────────────────────────────
  
  report <- paste0(report,
                   "## Recommendations for Failed Records\n\n",
                   "1. **Paywalled content:** Request via institutional library or interlibrary loan\n",
                   "2. **No PDF available:** Check if articles are HTML-only or contact authors directly\n",
                   "3. **Technical failures:** Retry manually during off-peak hours\n",
                   if ("pdf_valid" %in% colnames(log_data) && sum(log_data$pdf_valid == FALSE, na.rm = TRUE) > 0)
                     "4. **Invalid PDFs:** Re-attempt retrieval or obtain manually via library\n" else "",
                   "\n---\n\n"
  )
  
  # ── Citation ──────────────────────────────────────────────────────────────────
  
  report <- paste0(report,
                   "## Citation\n\n",
                   "If you use paperfetch in your research, please cite:\n\n",
                   "```\n",
                   "paperfetch: The full-text acquisition layer for systematic reviews in R.\n",
                   "R package version 0.1.0. https://github.com/HGND-laboratory/paperfetch\n",
                   "```\n\n",
                   "---\n\n",
                   "**Note:** This report documents full-text retrieval procedures in accordance with PRISMA guidelines.\n"
  )
  
  writeLines(report, report_file)
}
