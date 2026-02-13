#this script is a wrapper for all the functions to be added

#install all packages at once
packs<-c("readr", "dplyr","tidyr","pdftools","rvest","rentrez","httr2")
lapply(packs, require, character.only = TRUE)

wrapper_function <- function(input_list, output_dir = "downloads", unfetched_file = "unfetched.txt") {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir)
  }
  
  unfetched <- character()
  
  for (input in input_list) {
    if (grepl("^10\\.\\d{4,9}/[-._;()/:A-Z0-9]+$", input, ignore.case = TRUE)) {
      # DOI
      success <- fetch_pdf_from_doi(input, file.path(output_dir, paste0(gsub("/", "_", input), ".pdf")))
    } else if (grepl("^\\d+$", input)) {
      # PubMed ID
      success <- fetch_pdf_from_pubmed(input, file.path(output_dir, paste0(input, ".pdf")))
    } else if (grepl("^PMC\\d+$", input, ignore.case = TRUE)) {
      # PMC ID
      success <- fetch_pdf_from_pmc(input, file.path(output_dir, paste0(input, ".pdf")))
    } else {
      success <- FALSE
    }
    
    if (!success) {
      message(paste("Failed to fetch:", input))
      unfetched <- c(unfetched, input)
    }
  }
  
  if (length(unfetched) > 0) {
    writeLines(unfetched, unfetched_file)
  }
}
