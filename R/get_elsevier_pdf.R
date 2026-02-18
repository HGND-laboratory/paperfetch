#' Fetch PDF via Elsevier TDM API
#'
#' Internal helper. Uses the Elsevier Full-Text Article API to download a PDF
#' directly, bypassing the journal website. Requires an API key; an
#' institutional token is needed for paywalled content.
#'
#' Credentials are resolved in order:
#'   1. Arguments passed explicitly
#'   2. \code{ELSEVIER_API_KEY} / \code{ELSEVIER_INSTTOKEN} in \code{.Renviron}
#'
#' @param doi A single DOI string
#' @param path File path to save the PDF to
#' @param user_agent User-agent string for the request
#' @param timeout Timeout in seconds
#' @param proxy Proxy URL or NULL
#' @param api_key Elsevier API key (or NULL to read from .Renviron)
#' @param insttoken Elsevier institutional token (or NULL to read from .Renviron)
#'
#' @return A list: \code{list(success = TRUE/FALSE, reason = "...")}
#' @keywords internal

get_elsevier_pdf <- function(doi,
                             path,
                             user_agent,
                             timeout   = 15,
                             proxy     = NULL,
                             api_key   = NULL,
                             insttoken = NULL) {
  
  # Resolve credentials: argument → .Renviron → ""
  if (is.null(api_key) || api_key == "") {
    api_key <- Sys.getenv("ELSEVIER_API_KEY")
  }
  if (is.null(insttoken) || insttoken == "") {
    insttoken <- Sys.getenv("ELSEVIER_INSTTOKEN")
  }
  
  # Can't do anything without an API key
  if (api_key == "") {
    return(list(success = FALSE, reason = "no_api_key"))
  }
  
  # Only attempt for Elsevier DOI prefixes
  elsevier_prefixes <- c("10.1016", "10.1053", "10.1054", "10.1067",
                         "10.1078", "10.1383", "10.3182")
  if (!any(startsWith(doi, elsevier_prefixes))) {
    return(list(success = FALSE, reason = "not_elsevier"))
  }
  
  tryCatch({
    url <- paste0("https://api.elsevier.com/content/article/doi/", doi)
    
    req <- build_request(
      url        = url,
      user_agent = user_agent,
      timeout    = timeout,
      proxy      = proxy
    ) %>%
      req_headers(
        "X-ELS-APIKey"    = api_key,
        "X-ELS-Insttoken" = insttoken,
        "Accept"          = "application/pdf"
      ) %>%
      req_error(is_error = \(resp) FALSE)  # handle errors manually below
    
    resp <- req %>% req_perform(path = path)
    
    status <- resp_status(resp)
    
    if (status == 200) {
      # Confirm we got a real PDF and not a JSON error body
      validation <- validate_pdf(path)
      if (validation$valid) {
        return(list(success = TRUE, reason = NA_character_))
      } else {
        unlink(path)
        return(list(success = FALSE, reason = paste0("invalid_pdf_", validation$reason)))
      }
    } else if (status == 401) {
      unlink(path)
      return(list(success = FALSE, reason = "elsevier_unauthorized"))
    } else if (status == 403) {
      unlink(path)
      return(list(success = FALSE, reason = "elsevier_no_entitlement"))  # no insttoken or not subscribed
    } else {
      unlink(path)
      return(list(success = FALSE, reason = paste0("elsevier_http_", status)))
    }
    
  }, error = function(e) {
    if (file.exists(path)) unlink(path)
    return(list(success = FALSE, reason = conditionMessage(e)))
  })
}
