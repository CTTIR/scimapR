#' Track cluster evolution over time
#'
#' @description
#' Analyses how research clusters evolve across time windows. For each pair
#' of consecutive windows, clusters are linked by measuring the Jaccard
#' similarity of their member works (or, more commonly, the overlap of terms).
#'
#' @param corpus An [sm_corpus] object with a `cluster_id` column in
#'   `corpus$works` and a `year` column.
#' @param time_windows A list of integer vectors defining year ranges for each
#'   window, or `NULL` (default). If `NULL`, windows are created automatically
#'   by splitting the year range into roughly equal periods.
#' @param link_threshold Numeric between 0 and 1; minimum Jaccard similarity
#'   to link two clusters across time windows. Defaults to `0.3`.
#' @param call Caller environment for error reporting.
#'
#' @return A list with two components:
#'   \describe{
#'     \item{`snapshots`}{A tibble with columns `window`, `cluster_id`,
#'       `n_works`, `top_terms` (a character string of representative terms).}
#'     \item{`transitions`}{A tibble with columns `from_window`, `to_window`,
#'       `from_cluster`, `to_cluster`, `jaccard`, `n_shared`.}
#'   }
#'
#' @details
#' The function:
#' 1. Splits works into time windows.
#' 2. Within each window, identifies the cluster composition.
#' 3. Between consecutive windows, computes pairwise Jaccard similarity of
#'    clusters based on overlapping work IDs or, when works do not persist
#'    across windows, based on shared terms from titles.
#' 4. Links clusters exceeding `link_threshold`.
#'
#' @family clustering
#' @export
#' @examples
#' corpus <- sm_example_corpus(with_embeddings = TRUE)
#' corpus <- sm_cluster_kmeans(corpus, k = 5)
#' evo <- sm_cluster_evolution(corpus)
#' evo$snapshots
#' evo$transitions
sm_cluster_evolution <- function(corpus,
                                 time_windows = NULL,
                                 link_threshold = 0.3,
                                 call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)

  if (!is.numeric(link_threshold) || length(link_threshold) != 1L ||
      link_threshold < 0 || link_threshold > 1) {
    cli::cli_abort(
      "{.arg link_threshold} must be a number between 0 and 1.",
      call = call
    )
  }

  works <- corpus$works

  if (!"cluster_id" %in% names(works)) {
    cli::cli_abort(
      c("No {.field cluster_id} column found in works.",
        "i" = "Run a clustering function first (e.g., {.fun sm_cluster_kmeans})."),
      call = call
    )
  }

  if (!"year" %in% names(works) || all(is.na(works$year))) {
    cli::cli_abort(
      "Works must have a non-NA {.field year} column for temporal analysis.",
      call = call
    )
  }

  works <- dplyr::filter(works, !is.na(.data$cluster_id), !is.na(.data$year))
  if (nrow(works) == 0L) {
    return(list(
      snapshots   = tibble::tibble(
        window = character(), cluster_id = integer(),
        n_works = integer(), top_terms = character()
      ),
      transitions = tibble::tibble(
        from_window = character(), to_window = character(),
        from_cluster = integer(), to_cluster = integer(),
        jaccard = double(), n_shared = integer()
      )
    ))
  }

  # --- build time windows ---
  if (is.null(time_windows)) {
    time_windows <- .auto_time_windows(works$year)
  }

  # Assign each work to a window
  works <- works %>%
    dplyr::mutate(window = .assign_window(.data$year, time_windows))

  works <- dplyr::filter(works, !is.na(.data$window))

  # --- compute snapshots ---
  # Get top terms per cluster-window
  snapshots <- works %>%
    dplyr::group_by(.data$window, .data$cluster_id) %>%
    dplyr::summarise(
      n_works   = dplyr::n(),
      top_terms = .top_terms_from_titles(
        .data$title[!is.na(.data$title)], n = 5L
      ),
      .groups = "drop"
    )

  # --- compute transitions ---
  window_names <- sort(unique(works$window))

  if (length(window_names) < 2L) {
    return(list(
      snapshots   = snapshots,
      transitions = tibble::tibble(
        from_window = character(), to_window = character(),
        from_cluster = integer(), to_cluster = integer(),
        jaccard = double(), n_shared = integer()
      )
    ))
  }

  transitions_list <- list()
  for (i in seq_len(length(window_names) - 1L)) {
    w1 <- window_names[i]
    w2 <- window_names[i + 1L]

    works_w1 <- dplyr::filter(works, .data$window == w1)
    works_w2 <- dplyr::filter(works, .data$window == w2)

    clusters_w1 <- unique(works_w1$cluster_id)
    clusters_w2 <- unique(works_w2$cluster_id)

    for (c1 in clusters_w1) {
      ids1 <- works_w1$work_id[works_w1$cluster_id == c1]
      for (c2 in clusters_w2) {
        ids2 <- works_w2$work_id[works_w2$cluster_id == c2]

        n_shared <- length(intersect(ids1, ids2))
        n_union <- length(union(ids1, ids2))

        if (n_union == 0L) next

        jaccard <- n_shared / n_union

        # If no direct work overlap, fall back to term-based similarity
        if (n_shared == 0L) {
          terms1 <- .extract_title_terms(
            works_w1$title[works_w1$cluster_id == c1]
          )
          terms2 <- .extract_title_terms(
            works_w2$title[works_w2$cluster_id == c2]
          )
          n_term_shared <- length(intersect(terms1, terms2))
          n_term_union <- length(union(terms1, terms2))
          if (n_term_union > 0L) {
            jaccard <- n_term_shared / n_term_union
          }
          n_shared <- n_term_shared
        }

        if (jaccard >= link_threshold) {
          transitions_list <- c(transitions_list, list(tibble::tibble(
            from_window  = w1,
            to_window    = w2,
            from_cluster = c1,
            to_cluster   = c2,
            jaccard      = round(jaccard, 4),
            n_shared     = as.integer(n_shared)
          )))
        }
      }
    }
  }

  transitions <- if (length(transitions_list) > 0L) {
    dplyr::bind_rows(transitions_list)
  } else {
    tibble::tibble(
      from_window = character(), to_window = character(),
      from_cluster = integer(), to_cluster = integer(),
      jaccard = double(), n_shared = integer()
    )
  }

  cli::cli_inform(c(
    "v" = "Cluster evolution computed across {length(window_names)} time windows.",
    "i" = "{nrow(transitions)} transition{?s} found above threshold {link_threshold}."
  ))

  list(snapshots = snapshots, transitions = transitions)
}


#' Create automatic time windows from year range
#' @noRd
.auto_time_windows <- function(years) {
  yr_range <- range(years, na.rm = TRUE)
  span <- yr_range[2] - yr_range[1] + 1L

  # Aim for 3-5 windows
  n_windows <- min(max(2L, span %/% 3L), 5L)
  breaks <- seq(yr_range[1], yr_range[2] + 1L,
                length.out = n_windows + 1L)
  breaks <- unique(floor(breaks))

  lapply(seq_len(length(breaks) - 1L), function(i) {
    seq(as.integer(breaks[i]), as.integer(breaks[i + 1] - 1L))
  })
}


#' Assign years to window labels
#' @noRd
.assign_window <- function(years, windows) {
  labels <- vapply(windows, function(w) {
    paste0(min(w), "-", max(w))
  }, character(1))

  result <- rep(NA_character_, length(years))
  for (i in seq_along(windows)) {
    result[years %in% windows[[i]]] <- labels[i]
  }
  result
}


#' Extract top terms from titles (simple tokenisation)
#' @noRd
.top_terms_from_titles <- function(titles, n = 5L) {
  if (length(titles) == 0L) return(NA_character_)

  words <- unlist(strsplit(tolower(paste(titles, collapse = " ")), "\\W+"))
  words <- words[nchar(words) >= 3L]

  # Remove common stopwords
  sw <- c("the", "and", "for", "with", "from", "that", "this", "are",
          "was", "were", "been", "has", "have", "had", "not", "but",
          "its", "our", "their", "can", "will", "may", "using", "based",
          "study", "analysis", "results", "used", "between", "two")
  words <- words[!words %in% sw]

  if (length(words) == 0L) return(NA_character_)

  freq <- sort(table(words), decreasing = TRUE)
  top <- names(freq)[seq_len(min(n, length(freq)))]
  paste(top, collapse = "; ")
}


#' Extract unique terms from titles
#' @noRd
.extract_title_terms <- function(titles) {
  if (length(titles) == 0L || all(is.na(titles))) return(character())
  titles <- titles[!is.na(titles)]
  words <- unlist(strsplit(tolower(paste(titles, collapse = " ")), "\\W+"))
  words <- words[nchar(words) >= 3L]
  sw <- c("the", "and", "for", "with", "from", "that", "this", "are",
          "was", "were", "been", "has", "have", "had", "not", "but",
          "its", "our", "their", "can", "will", "may", "using", "based",
          "study", "analysis", "results", "used", "between", "two")
  unique(words[!words %in% sw])
}
