#' Track cluster evolution over time
#'
#' @description
#' Analyses how research clusters evolve across time windows. For each pair
#' of consecutive windows, clusters are linked either by the overlap of the
#' terms in their titles (`link_by = "terms"`, the default) or, after one
#' clustering of the whole corpus, by their shared `cluster_id`
#' (`link_by = "cluster_id"`).
#'
#' @param corpus An [sm_corpus] object with a `cluster_id` column in
#'   `corpus$works` and a `year` column.
#' @param time_windows A list of integer vectors defining year ranges for each
#'   window, or `NULL` (default). If `NULL`, windows are created automatically
#'   by splitting the year range into roughly equal periods.
#' @param link_threshold Numeric between 0 and 1; minimum Jaccard similarity
#'   to link two clusters across time windows. Defaults to `0.3`. Not used
#'   with `link_by = "cluster_id"`.
#' @param link_by How clusters of consecutive windows are linked. `"terms"`
#'   (default) compares every pair of clusters by the Jaccard similarity of
#'   their title terms and keeps the pairs that reach `link_threshold`; use it
#'   when each window was clustered on its own. `"cluster_id"` follows a
#'   clustering of the whole corpus (for example from
#'   [sm_cluster_hdbscan()]): every cluster present in both windows gives one
#'   transition to itself.
#' @param noise The `cluster_id` that marks noise, the works no cluster
#'   claims: `0L` by default, as [sm_cluster_hdbscan()] assigns. With
#'   `link_by = "cluster_id"` noise gets no transition. `NULL` treats every
#'   id as a cluster; set it for clusterings that use another noise label or
#'   a real cluster 0. Not used with `link_by = "terms"`.
#' @param call Caller environment for error reporting.
#'
#' @return A list with two components and the attribute `link_by` (the
#'   linking mode used):
#'   \describe{
#'     \item{`snapshots`}{A tibble with columns `window`, `cluster_id`,
#'       `n_works`, `top_terms` (a character string of representative
#'       terms) and `share` (the cluster's share of the window's clustered
#'       works, noise included, so the shares of a window sum to 1).}
#'     \item{`transitions`}{A tibble with columns `from_window`, `to_window`,
#'       `from_cluster`, `to_cluster`, `jaccard` (the Jaccard similarity of
#'       the two clusters' title terms, rounded to 4 digits; 0 when neither
#'       has any) and `n_shared` (the number of shared title terms).}
#'   }
#'
#' @details
#' The function:
#' 1. Splits works into time windows.
#' 2. Within each window, identifies the cluster composition.
#' 3. Between consecutive windows, links clusters. A work sits in exactly
#'    one window, so clusters cannot share works; `"terms"` therefore
#'    compares the terms of their titles and links the pairs whose Jaccard
#'    similarity reaches `link_threshold`, while `"cluster_id"` links each
#'    cluster to itself and reports the title-term Jaccard of its two
#'    windows without filtering.
#'
#' With one clustering of the whole corpus, the same `cluster_id` in two
#' windows is the continuity, and large clusters rarely reach the term
#' threshold, so `"terms"` can report no transition at all. Use
#' `link_by = "cluster_id"` there.
#'
#' @family clustering
#' @export
#' @examples
#' \donttest{
#' corpus <- sm_example_corpus(with_embeddings = TRUE)
#' corpus <- sm_cluster_kmeans(corpus, k = 5)
#' evo <- sm_cluster_evolution(corpus)
#' evo$snapshots
#' evo$transitions
#'
#' # one clustering for the whole corpus: follow each cluster id
#' evo <- sm_cluster_evolution(corpus, link_by = "cluster_id")
#' evo$transitions
#' }
sm_cluster_evolution <- function(corpus,
                                 time_windows = NULL,
                                 link_threshold = 0.3,
                                 link_by = c("terms", "cluster_id"),
                                 noise = 0L,
                                 call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  link_by <- rlang::arg_match(link_by, error_call = call)

  if (!is.numeric(link_threshold) || length(link_threshold) != 1L ||
      link_threshold < 0 || link_threshold > 1) {
    cli::cli_abort(
      "{.arg link_threshold} must be a number between 0 and 1.",
      call = call
    )
  }
  .check_noise_id(noise, call = call)

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
    return(.evolution_result(
      tibble::tibble(
        window = character(), cluster_id = integer(),
        n_works = integer(), top_terms = character(), share = double()
      ),
      .empty_transitions(),
      link_by
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
  # each cluster's share of its window, noise included
  snapshots$share <- snapshots$n_works /
    stats::ave(snapshots$n_works, snapshots$window, FUN = sum)

  # --- compute transitions ---
  window_names <- sort(unique(works$window))

  if (length(window_names) < 2L) {
    return(.evolution_result(snapshots, .empty_transitions(), link_by))
  }

  transitions_list <- list()
  for (i in seq_len(length(window_names) - 1L)) {
    w1 <- window_names[i]
    w2 <- window_names[i + 1L]

    works_w1 <- dplyr::filter(works, .data$window == w1)
    works_w2 <- dplyr::filter(works, .data$window == w2)

    clusters_w1 <- unique(works_w1$cluster_id)
    clusters_w2 <- unique(works_w2$cluster_id)

    if (link_by == "cluster_id") {
      # one clustering of the whole corpus: each cluster continues itself
      shared <- sort(setdiff(intersect(clusters_w1, clusters_w2), noise))
      for (cl in shared) {
        overlap <- .title_term_overlap(
          works_w1$title[works_w1$cluster_id == cl],
          works_w2$title[works_w2$cluster_id == cl]
        )
        transitions_list <- c(transitions_list, list(
          .transition_row(w1, w2, cl, cl, overlap)
        ))
      }
      next
    }

    # A work sits in exactly one window, so clusters of two windows never
    # share works: compare the terms of their titles instead.
    for (c1 in clusters_w1) {
      for (c2 in clusters_w2) {
        overlap <- .title_term_overlap(
          works_w1$title[works_w1$cluster_id == c1],
          works_w2$title[works_w2$cluster_id == c2]
        )
        if (overlap$jaccard >= link_threshold) {
          transitions_list <- c(transitions_list, list(
            .transition_row(w1, w2, c1, c2, overlap)
          ))
        }
      }
    }
  }

  transitions <- if (length(transitions_list) > 0L) {
    dplyr::bind_rows(transitions_list)
  } else {
    .empty_transitions()
  }

  found <- if (link_by == "terms") {
    "{nrow(transitions)} transition{?s} found above threshold
     {link_threshold}."
  } else {
    "{nrow(transitions)} transition{?s} link{?s/} the same cluster id in
     consecutive windows."
  }
  cli::cli_inform(c(
    "v" = "Cluster evolution computed across {length(window_names)} time windows.",
    "i" = found
  ))

  .evolution_result(snapshots, transitions, link_by)
}


#' Result list of sm_cluster_evolution(), the same on every return path
#' @noRd
.evolution_result <- function(snapshots, transitions, link_by) {
  structure(list(snapshots = snapshots, transitions = transitions),
            link_by = link_by)
}


#' Typed 0-row transitions table
#' @noRd
.empty_transitions <- function() {
  tibble::tibble(
    from_window = character(), to_window = character(),
    from_cluster = integer(), to_cluster = integer(),
    jaccard = double(), n_shared = integer()
  )
}


#' One row of the transitions table
#' @noRd
.transition_row <- function(from_window, to_window, from_cluster,
                            to_cluster, overlap) {
  tibble::tibble(
    from_window  = from_window,
    to_window    = to_window,
    from_cluster = from_cluster,
    to_cluster   = to_cluster,
    jaccard      = round(overlap$jaccard, 4),
    n_shared     = overlap$n_shared
  )
}


#' Jaccard similarity and number of shared title terms of two clusters
#'
#' 0 and 0L when neither cluster has a title term.
#' @noRd
.title_term_overlap <- function(titles1, titles2) {
  terms1 <- .extract_title_terms(titles1)
  terms2 <- .extract_title_terms(titles2)
  n_shared <- length(intersect(terms1, terms2))
  n_union <- length(union(terms1, terms2))
  list(jaccard = if (n_union > 0L) n_shared / n_union else 0,
       n_shared = n_shared)
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
