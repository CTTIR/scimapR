#' Funding source audit
#'
#' @description
#' Audits the distribution of funding sources across works in a corpus.
#' Funding metadata is extracted from either Crossref `funder` fields or
#' OpenAlex `grants` fields, depending on the `source` parameter.
#'
#' The result includes funder counts, the proportion of works with known
#' funding, and a concentration analysis.
#'
#' @param corpus An `sm_corpus` object.
#' @param source Character. Where to look for funding data: `"crossref"`
#'   (uses DOIs to query Crossref funder metadata) or `"openalex"` (uses
#'   OpenAlex IDs).
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_audit_funding` S3 object containing:
#' \describe{
#'   \item{funders}{Tibble with columns `funder_name`, `funder_doi`,
#'     `n_works`, `pct`.}
#'   \item{coverage}{Proportion of works with at least one funder.}
#'   \item{n_works_total}{Total number of works in corpus.}
#'   \item{n_works_funded}{Number of works with funding data.}
#'   \item{source}{The data source used.}
#' }
#'
#' @family audit
#' @export
#' @examples
#' \donttest{
#' corpus <- sm_example_corpus()
#' funding <- sm_audit_funding(corpus, source = "crossref")
#' print(funding)
#' }
sm_audit_funding <- function(corpus,
                             source = c("crossref", "openalex"),
                             call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  source <- match.arg(source)

  n_works_total <- nrow(corpus$works)

  if (n_works_total == 0L) {
    return(.empty_audit_funding(source = source))
  }

  funders_data <- if (source == "crossref") {
    .fetch_funding_crossref(corpus$works, call)
  } else {
    .fetch_funding_openalex(corpus$works, call)
  }

  if (nrow(funders_data) == 0L) {
    cli::cli_inform(c(
      "i" = "No funding data found via {.val {source}}.",
      "i" = "This may be because the works lack DOIs/identifiers, or the source does not have funding metadata."
    ))
    return(.empty_audit_funding(source = source, n_works_total = n_works_total))
  }

  # Aggregate by funder
  funder_summary <- funders_data %>%
    dplyr::group_by(.data$funder_name, .data$funder_doi) %>%
    dplyr::summarise(n_works = dplyr::n_distinct(.data$work_id),
                     .groups = "drop") %>%
    dplyr::mutate(pct = round(100 * .data$n_works / n_works_total, 2)) %>%
    dplyr::arrange(dplyr::desc(.data$n_works))

  n_funded <- dplyr::n_distinct(funders_data$work_id)
  coverage <- n_funded / n_works_total

  structure(
    list(
      funders = funder_summary,
      coverage = round(coverage, 3),
      n_works_total = n_works_total,
      n_works_funded = n_funded,
      source = source
    ),
    class = "sm_audit_funding"
  )
}

#' Empty funding audit result
#' @noRd
.empty_audit_funding <- function(source = "crossref", n_works_total = 0L) {
  structure(
    list(
      funders = tibble::tibble(
        funder_name = character(),
        funder_doi = character(),
        n_works = integer(),
        pct = double()
      ),
      coverage = 0.0,
      n_works_total = n_works_total,
      n_works_funded = 0L,
      source = source
    ),
    class = "sm_audit_funding"
  )
}

#' Fetch funding data from Crossref
#' @noRd
.fetch_funding_crossref <- function(works, call) {
  has_cr <- rlang::is_installed("rcrossref")

  dois <- works$doi[!is.na(works$doi) & nzchar(works$doi)]
  work_doi_map <- tibble::tibble(
    work_id = works$work_id[!is.na(works$doi) & nzchar(works$doi)],
    doi = dois
  )

  if (length(dois) == 0L || !has_cr) {
    if (!has_cr) {
      cli::cli_inform(c(
        "i" = "Install {.pkg rcrossref} for Crossref funding lookup."
      ))
    }
    return(tibble::tibble(
      work_id = character(),
      funder_name = character(),
      funder_doi = character()
    ))
  }

  results <- list()

  # Query in batches
  batch_size <- 20L
  batches <- split(seq_along(dois), ceiling(seq_along(dois) / batch_size))

  for (batch_idx in batches) {
    batch_dois <- dois[batch_idx]
    batch_work_ids <- work_doi_map$work_id[batch_idx]

    for (i in seq_along(batch_dois)) {
      tryCatch({
        cr_result <- rcrossref::cr_works(dois = batch_dois[i])
        if (!is.null(cr_result$data) && nrow(cr_result$data) > 0L) {
          funder_col <- cr_result$data$funder
          if (!is.null(funder_col) && is.list(funder_col)) {
            for (f in funder_col) {
              if (is.data.frame(f) && nrow(f) > 0L) {
                results[[length(results) + 1L]] <- tibble::tibble(
                  work_id = batch_work_ids[i],
                  funder_name = f$name %||% NA_character_,
                  funder_doi = f$DOI %||% NA_character_
                )
              }
            }
          }
        }
      }, error = function(e) NULL)
    }
  }

  if (length(results) == 0L) {
    return(tibble::tibble(
      work_id = character(),
      funder_name = character(),
      funder_doi = character()
    ))
  }

  dplyr::bind_rows(results)
}

#' Fetch funding data from OpenAlex
#' @noRd
.fetch_funding_openalex <- function(works, call) {
  has_oalex <- rlang::is_installed("openalexR")

  oaids <- works$openalex_id[!is.na(works$openalex_id)]
  if (length(oaids) == 0L || !has_oalex) {
    if (!has_oalex) {
      cli::cli_inform(c(
        "i" = "Install {.pkg openalexR} for OpenAlex funding lookup."
      ))
    }
    return(tibble::tibble(
      work_id = character(),
      funder_name = character(),
      funder_doi = character()
    ))
  }

  results <- list()

  for (i in seq_along(oaids)) {
    wid <- works$work_id[works$openalex_id == oaids[i]][1]
    tryCatch({
      fetched <- openalexR::oa_fetch(
        entity = "works",
        identifier = oaids[i],
        verbose = FALSE
      )
      if (!is.null(fetched) && nrow(fetched) > 0L && "grants" %in% names(fetched)) {
        grants <- fetched$grants[[1]]
        if (is.data.frame(grants) && nrow(grants) > 0L) {
          results[[length(results) + 1L]] <- tibble::tibble(
            work_id = wid,
            funder_name = grants$funder_display_name %||% NA_character_,
            funder_doi = grants$funder %||% NA_character_
          )
        }
      }
    }, error = function(e) NULL)
  }

  if (length(results) == 0L) {
    return(tibble::tibble(
      work_id = character(),
      funder_name = character(),
      funder_doi = character()
    ))
  }

  dplyr::bind_rows(results)
}
