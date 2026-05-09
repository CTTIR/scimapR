#' Build an author trajectory analysis
#'
#' @description
#' Analyses the career trajectory of a single author within a corpus,
#' partitioning their publication record into `n_periods` career stages.
#' For each period, the function computes:
#'
#' - **Career stages**: dominant topics and publication volume.
#' - **Topic pivots**: how much the research focus shifted between periods,
#'   measured as the Jaccard distance of concept sets.
#' - **Collaborator turnover**: Jaccard similarity of co-author sets across
#'   consecutive periods, plus counts of new, kept, and lost collaborators.
#' - **Emerging collaborators**: co-authors who first appear in the most
#'   recent period.
#' - **H-index curve**: cumulative h-index at the end of each period.
#' - **Novelty curve**: average concept novelty per period.
#' - **Citation acceleration**: mean citations per period relative to the
#'   corpus-wide mean for the same years.
#'
#' @param corpus An `sm_corpus` object.
#' @param orcid Character. ORCID of the author to analyse. Either `orcid`
#'   or `author_id` must be supplied.
#' @param author_id Character. Internal author ID. Either `orcid` or
#'   `author_id` must be supplied.
#' @param n_periods Integer. Number of career periods to divide the
#'   publication span into. Default `5`.
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_trajectory` S3 object.
#'
#' @family trajectory
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' # Use the first author's ID
#' traj <- sm_author_trajectory(corpus, author_id = "A000000001")
#' print(traj)
sm_author_trajectory <- function(corpus,
                                 orcid = NULL,
                                 author_id = NULL,
                                 n_periods = 5L,
                                 call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  n_periods <- .check_positive_int(n_periods, call = call)

  # Resolve author
  if (is.null(orcid) && is.null(author_id)) {
    cli::cli_abort(
      "Either {.arg orcid} or {.arg author_id} must be provided.",
      call = call
    )
  }

  if (!is.null(orcid)) {
    match_row <- dplyr::filter(corpus$authors, .data$orcid == !!orcid)
    if (nrow(match_row) == 0L) {
      cli::cli_abort(
        "No author found with ORCID {.val {orcid}}.",
        call = call
      )
    }
    author_id <- match_row$author_id[1]
  }

  author_row <- dplyr::filter(corpus$authors, .data$author_id == !!author_id)
  if (nrow(author_row) == 0L) {
    cli::cli_abort(
      "No author found with ID {.val {author_id}}.",
      call = call
    )
  }

  author_name <- author_row$display_name[1]
  author_orcid <- author_row$orcid[1] %||% NA_character_

  # Get author's works
  author_work_ids <- corpus$authorships$work_id[
    corpus$authorships$author_id == author_id
  ]
  author_work_ids <- unique(author_work_ids)

  author_works <- dplyr::filter(
    corpus$works, .data$work_id %in% author_work_ids
  )
  author_works <- dplyr::arrange(author_works, .data$year)

  if (nrow(author_works) == 0L) {
    cli::cli_inform(c(
      "!" = "Author {.val {author_name}} has no works in the corpus."
    ))
    return(new_sm_trajectory(
      author_id = author_id,
      author_name = author_name,
      orcid = author_orcid,
      n_periods = n_periods,
      career_stages = .empty_career_stages(),
      topic_pivots = .empty_topic_pivots(),
      collaborator_turnover = .empty_collaborator_turnover(),
      emerging_collaborators = tibble::tibble(
        author_id = character(), display_name = character(),
        first_year = integer()
      ),
      h_index_curve = .empty_h_index_curve(),
      novelty_curve = .empty_novelty_curve(),
      citation_acceleration = .empty_citation_acceleration()
    ))
  }

  # Partition into periods
  years <- author_works$year[!is.na(author_works$year)]
  if (length(years) == 0L) {
    years <- rep(NA_integer_, nrow(author_works))
  }

  year_range <- range(years, na.rm = TRUE)
  if (any(is.na(year_range)) || year_range[1] == year_range[2]) {
    # All works in same year or all NA
    n_periods <- 1L
  }

  period_breaks <- .make_period_breaks(year_range, n_periods)
  author_works$period <- .assign_periods(author_works$year, period_breaks)

  # Career stages
  career_stages <- .compute_career_stages(
    author_works, corpus$concepts, period_breaks
  )

  # Topic pivots
  topic_pivots <- .compute_topic_pivots(
    author_works, corpus$concepts, period_breaks
  )

  # Collaborator turnover
  collab_result <- .compute_collaborator_turnover(
    author_id, corpus$authorships, author_works, period_breaks
  )

  # Emerging collaborators
  emerging <- .compute_emerging_collaborators(
    author_id, corpus$authorships, corpus$authors, author_works, period_breaks
  )

  # H-index curve
  h_curve <- .compute_h_index_curve(author_works, period_breaks)

  # Novelty curve
  novelty_curve <- .compute_novelty_curve(
    author_works, corpus$concepts, period_breaks
  )

  # Citation acceleration
  citation_accel <- .compute_citation_acceleration(
    author_works, corpus$works, period_breaks
  )

  new_sm_trajectory(
    author_id = author_id,
    author_name = author_name,
    orcid = author_orcid,
    n_periods = length(period_breaks) - 1L,
    career_stages = career_stages,
    topic_pivots = topic_pivots,
    collaborator_turnover = collab_result,
    emerging_collaborators = emerging,
    h_index_curve = h_curve,
    novelty_curve = novelty_curve,
    citation_acceleration = citation_accel
  )
}

#' Create period breakpoints
#' @noRd
.make_period_breaks <- function(year_range, n_periods) {
  if (any(is.na(year_range))) {
    return(c(0L, 1L))
  }
  breaks <- seq(year_range[1], year_range[2],
                length.out = n_periods + 1L)
  unique(floor(breaks))
}

#' Assign works to periods based on year
#' @noRd
.assign_periods <- function(years, breaks) {
  if (length(breaks) <= 1L) return(rep(1L, length(years)))
  # Use findInterval: returns index of the break interval
  periods <- findInterval(years, breaks, rightmost.closed = TRUE)
  periods <- pmax(periods, 1L)
  periods <- pmin(periods, length(breaks) - 1L)
  as.integer(periods)
}

#' Compute career stages
#' @noRd
.compute_career_stages <- function(author_works, concepts, period_breaks) {
  if (nrow(author_works) == 0L) return(.empty_career_stages())

  n_p <- length(period_breaks) - 1L
  stages <- lapply(seq_len(n_p), function(p) {
    p_works <- dplyr::filter(author_works, .data$period == p)
    yr_lo <- period_breaks[p]
    yr_hi <- period_breaks[p + 1L]
    yr_label <- paste0(yr_lo, "-", yr_hi)

    # Dominant topics
    p_concepts <- dplyr::filter(
      concepts, .data$work_id %in% p_works$work_id
    )
    top_topics <- if (nrow(p_concepts) > 0L) {
      topic_counts <- dplyr::count(p_concepts, .data$concept_name,
                                   sort = TRUE)
      as.list(utils::head(topic_counts$concept_name, 3L))
    } else {
      list()
    }

    # H-index for this period (cumulative up to period end)
    cum_works <- dplyr::filter(
      author_works,
      !is.na(.data$year), .data$year <= yr_hi
    )
    h <- .compute_h_index(cum_works$cited_by_count)

    tibble::tibble(
      period = p,
      year_range = yr_label,
      n_works = nrow(p_works),
      dominant_topics = list(top_topics),
      h_index = h
    )
  })

  dplyr::bind_rows(stages)
}

#' Compute h-index from citation counts
#' @noRd
.compute_h_index <- function(citations) {
  citations <- citations[!is.na(citations)]
  if (length(citations) == 0L) return(0L)
  sorted <- sort(citations, decreasing = TRUE)
  h <- 0L
  for (i in seq_along(sorted)) {
    if (sorted[i] >= i) {
      h <- as.integer(i)
    } else {
      break
    }
  }
  h
}

#' Compute topic pivots between consecutive periods
#' @noRd
.compute_topic_pivots <- function(author_works, concepts, period_breaks) {
  n_p <- length(period_breaks) - 1L
  if (n_p <= 1L) return(.empty_topic_pivots())

  pivots <- lapply(seq(2L, n_p), function(p) {
    prev_works <- dplyr::filter(author_works, .data$period == (p - 1L))
    curr_works <- dplyr::filter(author_works, .data$period == p)

    prev_topics <- unique(dplyr::filter(
      concepts, .data$work_id %in% prev_works$work_id
    )$concept_name)

    curr_topics <- unique(dplyr::filter(
      concepts, .data$work_id %in% curr_works$work_id
    )$concept_name)

    if (length(prev_topics) == 0L && length(curr_topics) == 0L) {
      return(tibble::tibble(
        period = p,
        year = as.integer(period_breaks[p + 1L]),
        pivot_score = 0.0,
        from_topic = NA_character_,
        to_topic = NA_character_
      ))
    }

    # Jaccard distance as pivot score
    intersect_n <- length(intersect(prev_topics, curr_topics))
    union_n <- length(union(prev_topics, curr_topics))
    jaccard_dist <- if (union_n > 0L) 1 - intersect_n / union_n else 0.0

    # Identify most notable shift
    lost <- setdiff(prev_topics, curr_topics)
    gained <- setdiff(curr_topics, prev_topics)

    tibble::tibble(
      period = p,
      year = as.integer(period_breaks[p + 1L]),
      pivot_score = round(jaccard_dist, 3),
      from_topic = if (length(lost) > 0L) lost[1] else NA_character_,
      to_topic = if (length(gained) > 0L) gained[1] else NA_character_
    )
  })

  dplyr::bind_rows(pivots)
}

#' Compute collaborator turnover between periods
#' @noRd
.compute_collaborator_turnover <- function(author_id, authorships,
                                           author_works, period_breaks) {
  n_p <- length(period_breaks) - 1L
  if (n_p <= 1L) return(.empty_collaborator_turnover())

  turnovers <- lapply(seq(2L, n_p), function(p) {
    prev_works <- author_works$work_id[author_works$period == (p - 1L)]
    curr_works <- author_works$work_id[author_works$period == p]

    prev_coauthors <- setdiff(
      unique(authorships$author_id[authorships$work_id %in% prev_works]),
      author_id
    )
    curr_coauthors <- setdiff(
      unique(authorships$author_id[authorships$work_id %in% curr_works]),
      author_id
    )

    kept <- intersect(prev_coauthors, curr_coauthors)
    new_auth <- setdiff(curr_coauthors, prev_coauthors)
    lost_auth <- setdiff(prev_coauthors, curr_coauthors)

    union_n <- length(union(prev_coauthors, curr_coauthors))
    jaccard <- if (union_n > 0L) length(kept) / union_n else 0.0

    tibble::tibble(
      period = p,
      jaccard_to_prev = round(jaccard, 3),
      n_new = length(new_auth),
      n_kept = length(kept),
      n_lost = length(lost_auth)
    )
  })

  dplyr::bind_rows(turnovers)
}

#' Compute emerging collaborators (new in most recent period)
#' @noRd
.compute_emerging_collaborators <- function(author_id, authorships, authors,
                                            author_works, period_breaks) {
  n_p <- length(period_breaks) - 1L
  if (n_p == 0L || nrow(author_works) == 0L) {
    return(tibble::tibble(
      author_id = character(),
      display_name = character(),
      first_year = integer()
    ))
  }

  last_works <- author_works$work_id[author_works$period == n_p]
  earlier_works <- author_works$work_id[author_works$period < n_p]

  last_coauthors <- setdiff(
    unique(authorships$author_id[authorships$work_id %in% last_works]),
    author_id
  )
  earlier_coauthors <- setdiff(
    unique(authorships$author_id[authorships$work_id %in% earlier_works]),
    author_id
  )

  emerging_ids <- setdiff(last_coauthors, earlier_coauthors)

  if (length(emerging_ids) == 0L) {
    return(tibble::tibble(
      author_id = character(),
      display_name = character(),
      first_year = integer()
    ))
  }

  emerging <- dplyr::filter(authors, .data$author_id %in% emerging_ids)

  # Get first year of collaboration for each
  first_years <- vapply(emerging_ids, function(aid) {
    aid_works <- authorships$work_id[authorships$author_id == aid]
    shared <- intersect(aid_works, author_works$work_id)
    yrs <- author_works$year[author_works$work_id %in% shared]
    if (length(yrs) > 0L) min(yrs, na.rm = TRUE) else NA_integer_
  }, integer(1))

  tibble::tibble(
    author_id = emerging_ids,
    display_name = emerging$display_name[match(emerging_ids, emerging$author_id)],
    first_year = as.integer(first_years)
  )
}

#' Compute cumulative h-index curve
#' @noRd
.compute_h_index_curve <- function(author_works, period_breaks) {
  n_p <- length(period_breaks) - 1L
  if (n_p == 0L) return(.empty_h_index_curve())

  h_rows <- lapply(seq_len(n_p), function(p) {
    yr_hi <- period_breaks[p + 1L]
    cum_works <- dplyr::filter(
      author_works,
      !is.na(.data$year), .data$year <= yr_hi
    )
    h <- .compute_h_index(cum_works$cited_by_count)
    yr_label <- paste0(period_breaks[p], "-", yr_hi)

    tibble::tibble(
      period = p,
      year = as.integer(yr_hi),
      year_range = yr_label,
      h_index = h
    )
  })

  dplyr::bind_rows(h_rows)
}

#' Compute novelty curve per period
#' @noRd
.compute_novelty_curve <- function(author_works, concepts, period_breaks) {
  n_p <- length(period_breaks) - 1L
  if (n_p == 0L) return(.empty_novelty_curve())

  # Use concept diversity as a novelty proxy
  # Novelty = number of unique concepts per work in the period
  rows <- lapply(seq_len(n_p), function(p) {
    p_works <- dplyr::filter(author_works, .data$period == p)
    yr_label <- paste0(period_breaks[p], "-", period_breaks[p + 1L])

    if (nrow(p_works) == 0L) {
      return(tibble::tibble(
        period = p,
        year_range = yr_label,
        mean_novelty = NA_real_
      ))
    }

    p_concepts <- dplyr::filter(
      concepts, .data$work_id %in% p_works$work_id
    )

    if (nrow(p_concepts) == 0L) {
      return(tibble::tibble(
        period = p,
        year_range = yr_label,
        mean_novelty = 0.0
      ))
    }

    # Novelty per work = number of unique concepts
    concept_counts <- dplyr::count(p_concepts, .data$work_id)
    mean_nov <- mean(concept_counts$n, na.rm = TRUE)

    tibble::tibble(
      period = p,
      year_range = yr_label,
      mean_novelty = round(mean_nov, 2)
    )
  })

  dplyr::bind_rows(rows)
}

#' Compute citation acceleration per period
#' @noRd
.compute_citation_acceleration <- function(author_works, all_works,
                                           period_breaks) {
  n_p <- length(period_breaks) - 1L
  if (n_p == 0L) return(.empty_citation_acceleration())

  rows <- lapply(seq_len(n_p), function(p) {
    yr_lo <- period_breaks[p]
    yr_hi <- period_breaks[p + 1L]
    yr_label <- paste0(yr_lo, "-", yr_hi)

    p_works <- dplyr::filter(author_works, .data$period == p)

    if (nrow(p_works) == 0L) {
      return(tibble::tibble(
        period = p,
        year_range = yr_label,
        mean_citations = NA_real_,
        delta_vs_field = NA_real_
      ))
    }

    author_mean <- mean(p_works$cited_by_count, na.rm = TRUE)

    # Field mean for same years
    field_works <- dplyr::filter(
      all_works,
      !is.na(.data$year),
      .data$year >= yr_lo,
      .data$year <= yr_hi
    )
    field_mean <- if (nrow(field_works) > 0L) {
      mean(field_works$cited_by_count, na.rm = TRUE)
    } else {
      0.0
    }

    delta <- author_mean - field_mean

    tibble::tibble(
      period = p,
      year_range = yr_label,
      mean_citations = round(author_mean, 1),
      delta_vs_field = round(delta, 1)
    )
  })

  dplyr::bind_rows(rows)
}
