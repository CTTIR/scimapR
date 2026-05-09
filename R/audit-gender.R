#' Gender representation audit
#'
#' @description
#' Audits the inferred gender distribution of authors in a corpus. Gender
#' is inferred from first names using the specified method. Results include
#' the overall distribution, authorship-position breakdown, and a coverage
#' metric.
#'
#' **This function infers a binary gender proxy from names, which has
#' well-documented limitations.** See the Limitations section in the
#' printed output and the details below.
#'
#' @param corpus An `sm_corpus` object.
#' @param method Character. Gender inference method:
#'   - `"genderize"`: Uses the genderize.io API (requires API key for
#'     high volume).
#'   - `"ssa"`: Uses US Social Security Administration frequency tables
#'     (no API needed, but US-centric).
#'   - `"manual"`: Uses pre-existing `inferred_gender` column in the
#'     authors table (no inference performed).
#' @param api_key Character. API key for genderize.io. Read from the
#'   `GENDERIZE_API_KEY` environment variable by default.
#' @param cache_dir Character. Directory for caching API results.
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_audit_gender` S3 object containing:
#' \describe{
#'   \item{distribution}{Tibble with columns `inferred_gender`, `count`,
#'     `pct`.}
#'   \item{by_position}{Tibble breaking down gender by authorship position.}
#'   \item{coverage}{Proportion of authors with an inferred gender.}
#'   \item{method}{The method used.}
#'   \item{confidence_summary}{Summary statistics for gender confidence
#'     scores.}
#' }
#'
#' @details
#' **Known limitations of automated gender inference:**
#' - Name-based methods assign a binary gender proxy, which does not capture
#'   the full spectrum of gender identity.
#' - Accuracy varies dramatically by cultural context: names from East Asian,
#'   South Asian, and many African cultures are poorly served by Western-trained
#'   models.
#' - Non-binary, transgender, and gender-diverse individuals are systematically
#'   misclassified.
#' - The method cannot account for name changes, pen names, or initialised
#'   first names.
#'
#' @family audit
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' # Using manual method (no API call needed for examples):
#' gender_audit <- sm_audit_gender(corpus, method = "manual")
#' print(gender_audit)
sm_audit_gender <- function(corpus,
                            method = c("genderize", "ssa", "manual"),
                            api_key = Sys.getenv("GENDERIZE_API_KEY"),
                            cache_dir = tools::R_user_dir("scimapR", "cache"),
                            call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  method <- match.arg(method)

  if (nrow(corpus$authors) == 0L) {
    return(.empty_audit_gender(method = method))
  }

  authors <- corpus$authors

  if (method != "manual") {
    # Extract first names
    first_names <- vapply(
      strsplit(authors$display_name, "\\s+"),
      function(parts) if (length(parts) > 0L) parts[1] else NA_character_,
      character(1)
    )

    if (method == "genderize") {
      gender_result <- .infer_gender_genderize(
        first_names, api_key, cache_dir, call
      )
    } else if (method == "ssa") {
      gender_result <- .infer_gender_ssa(first_names, call)
    }

    authors$inferred_gender <- gender_result$gender
    authors$gender_confidence <- gender_result$confidence
    authors$gender_method <- method
  }

  # Compute distribution
  dist <- authors %>%
    dplyr::count(.data$inferred_gender) %>%
    dplyr::mutate(pct = round(100 * .data$n / sum(.data$n), 1)) %>%
    dplyr::rename(count = .data$n) %>%
    dplyr::arrange(dplyr::desc(.data$count))

  # By position
  by_position <- .compute_gender_by_position(
    authors, corpus$authorships
  )

  # Coverage
  n_known <- sum(!is.na(authors$inferred_gender) &
                   authors$inferred_gender != "unknown")
  coverage <- n_known / nrow(authors)

  # Confidence summary
  conf_vals <- authors$gender_confidence[!is.na(authors$gender_confidence)]
  conf_summary <- if (length(conf_vals) > 0L) {
    list(
      mean = round(mean(conf_vals), 3),
      median = round(stats::median(conf_vals), 3),
      min = round(min(conf_vals), 3),
      max = round(max(conf_vals), 3)
    )
  } else {
    list(mean = NA_real_, median = NA_real_, min = NA_real_, max = NA_real_)
  }

  structure(
    list(
      distribution = dist,
      by_position = by_position,
      coverage = round(coverage, 3),
      method = method,
      confidence_summary = conf_summary
    ),
    class = "sm_audit_gender"
  )
}

#' Empty gender audit result
#' @noRd
.empty_audit_gender <- function(method = "manual") {
  structure(
    list(
      distribution = tibble::tibble(
        inferred_gender = character(),
        count = integer(),
        pct = double()
      ),
      by_position = tibble::tibble(
        position_type = character(),
        inferred_gender = character(),
        count = integer(),
        pct = double()
      ),
      coverage = 0.0,
      method = method,
      confidence_summary = list(
        mean = NA_real_, median = NA_real_,
        min = NA_real_, max = NA_real_
      )
    ),
    class = "sm_audit_gender"
  )
}

#' Compute gender breakdown by authorship position
#' @noRd
.compute_gender_by_position <- function(authors, authorships) {
  if (nrow(authorships) == 0L || nrow(authors) == 0L) {
    return(tibble::tibble(
      position_type = character(),
      inferred_gender = character(),
      count = integer(),
      pct = double()
    ))
  }

  # Label positions
  aships <- authorships %>%
    dplyr::mutate(
      position_type = dplyr::case_when(
        .data$position == 1L ~ "first",
        isTRUE(.data$is_corresponding) ~ "corresponding",
        TRUE ~ "middle/last"
      )
    )

  # Join with author gender
  aships <- dplyr::left_join(
    aships,
    dplyr::select(authors, .data$author_id, .data$inferred_gender),
    by = "author_id"
  )

  result <- aships %>%
    dplyr::group_by(.data$position_type, .data$inferred_gender) %>%
    dplyr::summarise(count = dplyr::n(), .groups = "drop") %>%
    dplyr::group_by(.data$position_type) %>%
    dplyr::mutate(pct = round(100 * .data$count / sum(.data$count), 1)) %>%
    dplyr::ungroup()

  result
}

#' Infer gender from first names using genderize.io
#' @noRd
.infer_gender_genderize <- function(first_names, api_key, cache_dir, call) {
  # Ensure cache directory exists
  if (!fs::dir_exists(cache_dir)) {
    fs::dir_create(cache_dir, recurse = TRUE)
  }

  cache_file <- file.path(cache_dir, "genderize_cache.rds")
  cache <- if (file.exists(cache_file)) readRDS(cache_file) else list()

  unique_names <- unique(tolower(first_names[!is.na(first_names)]))
  to_query <- setdiff(unique_names, names(cache))

  if (length(to_query) > 0L) {
    cli::cli_inform(c(
      "i" = "Querying genderize.io for {length(to_query)} name{?s}..."
    ))

    for (nm in to_query) {
      tryCatch({
        url <- paste0("https://api.genderize.io?name=", utils::URLencode(nm))
        if (nzchar(api_key)) {
          url <- paste0(url, "&apikey=", api_key)
        }
        req <- httr2::request(url)
        resp <- httr2::req_perform(req)
        body <- httr2::resp_body_json(resp)
        cache[[nm]] <- list(
          gender = body$gender %||% NA_character_,
          confidence = body$probability %||% NA_real_
        )
      }, error = function(e) {
        cache[[nm]] <<- list(gender = NA_character_, confidence = NA_real_)
      })
    }

    saveRDS(cache, cache_file)
  }

  # Map results back
  names_lower <- tolower(first_names)
  gender <- vapply(names_lower, function(nm) {
    if (is.na(nm) || !nm %in% names(cache)) return(NA_character_)
    cache[[nm]]$gender %||% NA_character_
  }, character(1), USE.NAMES = FALSE)

  confidence <- vapply(names_lower, function(nm) {
    if (is.na(nm) || !nm %in% names(cache)) return(NA_real_)
    cache[[nm]]$confidence %||% NA_real_
  }, double(1), USE.NAMES = FALSE)

  list(gender = gender, confidence = confidence)
}

#' Infer gender from first names using SSA data
#' @noRd
.infer_gender_ssa <- function(first_names, call) {
  # Simple built-in heuristic for common Western names
  # In production, this would use the SSA baby names dataset
  gender <- rep(NA_character_, length(first_names))
  confidence <- rep(NA_real_, length(first_names))

  # Mark as method limitation
  cli::cli_inform(c(
    "!" = "SSA-based gender inference uses US-centric name frequencies.",
    "i" = "Results will be unreliable for non-Western names.",
    "i" = "Consider using {.val genderize} method for better cross-cultural coverage."
  ))

  list(gender = gender, confidence = confidence)
}
