# Crossref ORs repeated filters with the same name.
.crossref_lookup <- function(dois, filter_name = c("doi", "updates"),
                             select = NULL, rows = 20L, mailto = "",
                             call = rlang::caller_env()) {
  filter_name <- rlang::arg_match(filter_name)
  dois <- unique(.normalize_doi(dois))
  dois <- dois[!is.na(dois) & nzchar(dois)]
  batches <- unname(split(dois, ceiling(seq_along(dois) / 20L)))
  records <- list()
  failed <- character()
  condition <- NULL
  for (i in seq_along(batches)) {
    batch <- tryCatch({
      cursor <- "*"
      items <- list()
      repeat {
        query <- list(filter = paste(paste0(filter_name, ":", batches[[i]]),
                                     collapse = ","),
                      select = select, rows = rows, cursor = cursor)
        if (nzchar(.openalex_setting(mailto))) query$mailto <- mailto
        req <- httr2::request("https://api.crossref.org/works") |>
          httr2::req_url_query(!!!query) |>
          httr2::req_headers(`User-Agent` = .sm_user_agent())
        body <- .sm_http_read(req, "Crossref", call = call)$message
        page <- body$items %||% list()
        items <- c(items, page)
        cursor <- body[["next-cursor"]]
        total <- body[["total-results"]] %||% length(items)
        if (!length(page) || length(items) >= total || is.null(cursor)) break
      }
      items
    }, scimapR_request_failed = identity)
    if (inherits(batch, "scimapR_request_failed")) {
      condition <- batch
      if (inherits(batch, "scimapR_rate_limited")) {
        failed <- c(failed, unlist(batches[seq.int(i, length(batches))],
                                   use.names = FALSE))
        break
      }
      failed <- c(failed, batches[[i]])
    } else {
      records <- c(records, batch)
    }
  }
  records <- lapply(records, function(record) {
    if (!is.null(record$DOI)) record$DOI <- .normalize_doi(record$DOI)
    record
  })
  list(records = records, failed = failed, condition = condition)
}
