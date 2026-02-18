#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom httr2 request req_perform req_retry req_timeout req_headers
#' @importFrom httr2 req_user_agent req_proxy resp_body_json resp_body_html
#' @importFrom httr2 resp_url req_error resp_status
#' @importFrom rvest html_node html_nodes html_attr
#' @importFrom xml2 url_absolute
#' @importFrom readr read_csv write_csv
#' @importFrom dplyr filter group_by summarise mutate arrange desc n case_when
#' @importFrom dplyr left_join select pull coalesce bind_rows
#' @importFrom cli cli_abort cli_alert_info cli_alert_success
#' @importFrom cli cli_alert_danger cli_alert_warning cli_bullets
#' @importFrom cli cli_rule cli_h1 cli_h2
#' @importFrom progress progress_bar
#' @importFrom utils head
#' @importFrom stats setNames
#' @importFrom magrittr %>%
## usethis namespace: end
NULL

#' @export
magrittr::`%>%`

# Fix "no visible binding for global variable" NOTES
utils::globalVariables(c(
  ".", "attempts", "count", "failure_reason", "file_path", "id", 
  "log_file_name", "method", "n", "pdf_invalid_reason", 
  "pdf_valid", "pubmed_url", "reason", "status", "success", "valid"
))