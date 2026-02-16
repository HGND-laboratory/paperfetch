#' Generate Acquisition Report
#'
#' Creates a PRISMA-compliant Markdown report from download log data
#'
#' @param log_data Data frame with download log entries
#' @param report_file Path for output Markdown file
#' @param email Email used for downloads
#' @param id_type Type of IDs processed ("doi", "pmid", or "mixed")
#' @keywords internal

generate_acquisition_report <- function(log_data, report_file, email, id_type = "mixed") {
  require(dplyr)
  
  # Calculate statistics
  total <- nrow(log_data)
  successful <- sum(log_data$success & log_data$status != "exists", na.rm = TRUE)
  skipped <- sum(log_data$status == "exists", na.rm = TRUE)
  failed <- total - successful - skipped
  success_rate <- if (total > 0) (successful / (total - skipped)) * 100 else 0
  
  # Method breakdown (exclude skipped)
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
  
  # Build report
  report <- paste0(
    "# Full-Text Acquisition Report\n\n",
    "**Generated:** ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n",
    "**Package:** paperfetch v0.1.0\n",
    "**Analyst:** ", email, "\n\n",
    "---\n\n",
    "## Summary\n\n",
    "- **Total records:** ", total, "\n",
    "- **Successfully downloaded:** ", successful, " (", sprintf("%.1f%%", success_rate), ")\n",
    "- **Failed to retrieve:** ", failed, " (", sprintf("%.1f%%", (failed / total) * 100), ")\n",
    if (skipped > 0) paste0("- **Already existed (skipped):** ", skipped, " (", sprintf("%.1f%%", (skipped / total) * 100), ")\n") else "",
    "\n---\n\n"
  )
  
  # Retrieval Methods section
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
  
  # Failure Analysis section
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
  
  # Failed Records section
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
  
  # Reproducibility Information
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
                   "---\n\n",
                   "## Recommendations for Failed Records\n\n",
                   "1. **Paywalled content:** Request via institutional library or interlibrary loan\n",
                   "2. **No PDF available:** Check if articles are HTML-only or contact authors directly\n",
                   "3. **Technical failures:** Retry manually during off-peak hours or contact publisher support\n\n",
                   "---\n\n",
                   "## Citation\n\n",
                   "If you use paperfetch in your research, please cite:\n\n",
                   "```\n",
                   "Misra, K. (2025). paperfetch: The full-text acquisition layer for systematic reviews in R.\n",
                   "R package version 0.1.0. https://github.com/HGND-laboratory/paperfetch\n",
                   "```\n\n",
                   "---\n\n",
                   "**Note:** This report documents full-text retrieval procedures in accordance with PRISMA guidelines.\n"
  )
  
  writeLines(report, report_file)
}