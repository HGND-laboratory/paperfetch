#' Construct PDF URLs for journals with predictable URL patterns
#'
#' Many major journals don't expose PDF URLs via Unpaywall or citation meta
#' tags, but have consistent, constructable PDF URLs based on the DOI.
#' This function returns a direct PDF URL when the DOI prefix matches a
#' known journal pattern, or NULL if no pattern is known.
#'
#' @param doi A single DOI string
#' @return A PDF URL string, or NULL if no pattern matches

construct_journal_pdf_url <- function(doi) {
  
  doi <- trimws(doi)
  
  # ── New England Journal of Medicine ────────────────────────────────────────
  # Pattern: https://www.nejm.org/doi/pdf/{doi}
  if (grepl("^10\\.1056/", doi)) {
    return(paste0("https://www.nejm.org/doi/pdf/", doi))
  }
  
  # ── JAMA Network (JAMA, JAMA Oncology, JAMA Neurology, etc.) ──────────────
  # Pattern: https://jamanetwork.com/journals/.../fullarticle/{doi} → PDF via /data/journals/.../pdf/...
  # Direct PDF not easily constructable; but JAMA does expose PDFs at:
  # https://jamanetwork.com/journals/jama/fullarticle/{doi}?resultClick=1
  # The PDF link requires scraping, so skip for now — handled by Step 2 scraping
  
  # ── The Lancet family ──────────────────────────────────────────────────────
  # Pattern: https://www.thelancet.com/journals/.../article/{doi}/fulltext
  # PDF: https://www.thelancet.com/journals/.../article/{doi}/pdf
  # Covers: S0140-6736 (Lancet), S1470-2045 (Lancet Oncology),
  #         S2352-3026 (Lancet Haematology), S2213-2600 (Lancet Resp), etc.
  if (grepl("^10\\.1016/S", doi)) {
    # Map DOI prefix to Lancet journal path
    lancet_map <- list(
      "S0140-6736" = "lancet",
      "S1470-2045" = "lanonc",
      "S2352-3026" = "lanhae",
      "S2213-2600" = "lanres",
      "S2213-8587" = "landia",
      "S2468-1253" = "langas",
      "S2214-109X" = "langlo",
      "S2667-193X" = "lanplh"
    )
    # Extract the S-code from DOI e.g. "10.1016/S1470-2045(23)00158-4" → "S1470-2045"
    scode <- regmatches(doi, regexpr("S[0-9]{4}-[0-9]{4}", doi))
    if (length(scode) == 1 && scode %in% names(lancet_map)) {
      journal_path <- lancet_map[[scode]]
      return(paste0(
        "https://www.thelancet.com/journals/", journal_path,
        "/article/", doi, "/pdf"
      ))
    }
  }
  
  # ── Oxford University Press ────────────────────────────────────────────────
  # Covers: JNCI, Brain, Neuro-Oncology (noae), JBMR, etc.
  # Pattern: https://academic.oup.com/[journal]/[article-path]/pdf → not constructable
  # OUP does set citation_pdf_url meta tags, so Step 2 scraping should catch these.
  # If scraping is failing, it's likely a paywall 403.
  
  # ── JAMA (10.1001) ────────────────────────────────────────────────────────
  if (grepl("^10\\.1001/", doi)) {
    return(paste0("https://jamanetwork.com/journals/fullarticle/", doi, "/pdf"))
  }
  
  # ── Taylor & Francis ───────────────────────────────────────────────────────
  # Pattern: https://www.tandfonline.com/doi/pdf/{doi}
  # Covers: 10.1080 (most T&F journals), 10.1179, 10.3109, etc.
  if (grepl("^10\\.(1080|1179|3109|3200|1300|1352|1365|1501|1533|1558)/", doi)) {
    return(paste0("https://www.tandfonline.com/doi/pdf/", doi, "?download=true"))
  }
  
  # ── MDPI ───────────────────────────────────────────────────────────────────
  # MDPI PDF URLs use a journal/volume/issue/page structure with a dynamic
  # ?version= timestamp — neither is derivable from the DOI alone.
  # DOI resolution + citation_pdf_url meta tag scraping (Step 2) handles these.
  
  # ── No known pattern ───────────────────────────────────────────────────────
  return(NULL)
}