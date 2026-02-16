fetch_pdf_from_pmids <- function(pubmed_id, destination) {
  base_url <- "https://pubmed.ncbi.nlm.nih.gov/"
  pubmed_url <- paste0(base_url, pubmed_id)
  
  page <- try(read_html(pubmed_url), silent = TRUE)
  if (inherits(page, "try-error")) {
    return(FALSE)
  }
  
  pdf_link <- page %>% html_nodes("a") %>% html_attr("href") %>% grep(".pdf", ., value = TRUE) %>% unique()
  if (length(pdf_link) > 0) {
    pdf_url <- pdf_link[1]
    pdf_response <- GET(pdf_url)
    if (status_code(pdf_response) == 200) {
      writeBin(content(pdf_response, "raw"), destination)
      return(TRUE)
    }
  }
  return(FALSE)
}
