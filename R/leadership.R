# The leadership outcome of sm_its(), sm_did() and sm_synth(): which works
# a focal institution leads, through which author role.

#' Author roles that can lead a work, as `lead_role` accepts them
#' @noRd
.lead_roles <- function() {
  c("corresponding", "first", "last", "first_or_last", "any_lead")
}

#' Plain-text name of a lead role
#' @noRd
.lead_role_text <- function(lead_role) {
  switch(lead_role,
    corresponding = "corresponding author",
    first = "first author",
    last = "last author",
    first_or_last = "first or last author",
    any_lead = "first, last or corresponding author"
  )
}

#' Authorship rows that belong to focal institutions
#'
#' A row belongs to them when any of its label columns is one of
#' `institutions`: `institution_match`, `institution_name`,
#' `institution_id` or the `display_name` of that id in `institutions_tbl`.
#' This is the OR over label columns that group membership in sm_did() and
#' sm_synth() uses; the precedence of `.resolve_institution_labels()` only
#' names the kind of label in print output.
#' @return A logical vector along the rows.
#' @noRd
.focal_rows <- function(authorships, institutions_tbl, institutions) {
  hit <- rep(FALSE, nrow(authorships))
  for (col in .institution_label_columns(FALSE)) {
    if (col %in% names(authorships)) {
      hit <- hit | as.character(authorships[[col]]) %in% institutions
    }
  }
  named <- .institution_column_labels(authorships, institutions_tbl,
                                      "institution_id")
  hit | named %in% institutions
}

#' Every institution label that some authorship row carries
#' @noRd
.focal_labels_available <- function(authorships, institutions_tbl) {
  labels <- lapply(.institution_label_columns(FALSE), function(col) {
    .institution_column_labels(authorships, institutions_tbl, col)
  })
  if ("institution_id" %in% names(authorships)) {
    labels <- c(labels, list(as.character(authorships$institution_id)))
  }
  labels <- unique(unlist(labels, use.names = FALSE))
  labels[!is.na(labels) & nzchar(trimws(labels))]
}

#' Check focal institutions and return the authorship rows they hold
#'
#' Labels that no authorship row carries give a warning that lists the
#' nearest labels of the corpus (by [utils::adist()]); when no row belongs
#' to any of the institutions the function aborts.
#' @return A logical vector along `corpus$authorships` (`.focal_rows()`).
#' @noRd
.check_focal_institutions <- function(corpus, institutions,
                                      arg = "institutions",
                                      call = rlang::caller_env()) {
  if (!is.character(institutions) || length(institutions) == 0L ||
        anyNA(institutions) || !all(nzchar(trimws(institutions)))) {
    cli::cli_abort(
      "{.arg {arg}} must be a character vector of institution labels.",
      call = call
    )
  }
  a <- corpus$authorships
  focal <- .focal_rows(a, corpus$institutions, institutions)
  available <- .focal_labels_available(a, corpus$institutions)
  unknown <- unique(institutions[!institutions %in% available])
  if (length(unknown) > 0L && length(available) > 0L) {
    near <- vapply(unknown, function(u) {
      d <- utils::adist(tolower(u), tolower(available))[1L, ]
      paste(available[order(d)][seq_len(min(3L, length(available)))],
            collapse = "; ")
    }, character(1))
    lines <- paste0(unknown, ": nearest labels ", near)
    cli::cli_warn(c(
      "No authorship carries the institution label{?s} {.val {unknown}}.",
      stats::setNames(.sm_cli_escape(lines), rep("*", length(lines))),
      "i" = paste0("Labels are compared exactly with {.field ",
                   "institution_match}, {.field institution_name}, ",
                   "{.field institution_id} and the names of ",
                   "{.code corpus$institutions}.")
    ), class = "scimapR_unknown_institutions", call = call)
  }
  if (!any(focal)) {
    cli::cli_abort(c(
      paste0("No authorship belongs to {.val {institutions}}, so no work ",
             "can be led from there."),
      "i" = paste0("Run {.fn sm_affiliation_match} with a dictionary of ",
                   "these institutions first, or check the labels.")
    ), class = "scimapR_no_focal_works", call = call)
  }
  focal
}

#' Lead status of works: led through an author role by focal rows
#'
#' Roles: `first` is the lowest `position` of a work, `last` the highest
#' (all rows of an author share the position, so an author with several
#' affiliation rows leads if any row is focal); `corresponding` the rows
#' with `is_corresponding` `TRUE`; `first_or_last`; `any_lead` first, last
#' or corresponding. A work's status is unknown (`NA`) when the role cannot
#' be told: all `is_corresponding` are `NA` (`"corresponding"`), all
#' positions are `NA` (the position roles), or both (`"any_lead"`, where an
#' unknown corresponding author counts as not leading).
#'
#' @param a Authorship rows of the works.
#' @param lead_role One of `.lead_roles()`.
#' @param focal Logical along `a`: rows of a focal institution (all `TRUE`
#'   without focal institutions).
#' @return A tibble: `work_id` and `led` (`TRUE`, `FALSE` or `NA`), one row
#'   per work that has authorship rows.
#' @noRd
.lead_status <- function(a, lead_role, focal) {
  if (nrow(a) == 0L) {
    return(tibble::tibble(work_id = character(), led = logical()))
  }
  w <- factor(as.character(a$work_id),
              levels = unique(as.character(a$work_id)))
  pos <- suppressWarnings(as.numeric(a$position))
  corr <- as.logical(a$is_corresponding)
  edge <- function(f) {
    stats::ave(pos, w, FUN = function(p) {
      if (all(is.na(p))) NA_real_ else f(p, na.rm = TRUE)
    })
  }
  first <- !is.na(pos) & pos == edge(min)
  last <- !is.na(pos) & pos == edge(max)
  corresponding <- corr %in% TRUE
  role <- switch(lead_role,
    corresponding = corresponding,
    first = first,
    last = last,
    first_or_last = first | last,
    any_lead = first | last | corresponding
  )
  led <- tapply(role & focal, w, any)
  pos_known <- tapply(!is.na(pos), w, any)
  corr_known <- tapply(!is.na(corr), w, any)
  known <- switch(lead_role,
    corresponding = corr_known,
    any_lead = pos_known | corr_known,
    pos_known
  )
  tibble::tibble(work_id = levels(w),
                 led = unname(ifelse(known, led, NA)))
}

#' Yearly leadership shares of a set of works
#'
#' The share of a year is over the works with a known lead status
#' (`.lead_status()`); works without authorship rows and works whose lead
#' is unknown leave the denominator, so `n_works` counts the works used.
#' Aborts when no work has a known lead status.
#'
#' @param works Works of the series, with integer `year`.
#' @param institutions Focal institution labels, or `NULL` for any.
#' @return A yearly tibble: `year`, `n_works`, `value`.
#' @noRd
.sm_leadership_series <- function(corpus, works, institutions, lead_role,
                                  call = rlang::caller_env()) {
  a <- corpus$authorships
  focal <- if (is.null(institutions)) {
    rep(TRUE, nrow(a))
  } else {
    .check_focal_institutions(corpus, institutions, call = call)
  }
  keep <- a$work_id %in% works$work_id
  status <- .lead_status(a[keep, , drop = FALSE], lead_role, focal[keep])
  led <- status$led[match(works$work_id, status$work_id)]
  known <- !is.na(led)
  if (!any(known)) .sm_abort_unknown_leads(lead_role, nrow(works), call)
  tibble::tibble(year = works$year[known], led = led[known]) |>
    dplyr::group_by(.data$year) |>
    dplyr::summarise(
      n_works = dplyr::n(),
      value = mean(.data$led),
      .groups = "drop"
    ) |>
    dplyr::arrange(.data$year)
}

#' Abort when no work of a leadership series has a known lead
#' @noRd
.sm_abort_unknown_leads <- function(lead_role, n, call) {
  if (identical(lead_role, "corresponding")) {
    cli::cli_abort(c(
      paste0("None of the {n} work{?s} has a known corresponding author, ",
             "so the {.val leadership} share has no denominator."),
      "i" = paste0("{.field is_corresponding} is {.code NA} (unknown) for ",
                   "all their authorships. Readers of sources without ",
                   "corresponding-author data, such as PubMed, Crossref, ",
                   "Scopus, RIS or BibTeX files, record it so."),
      "i" = paste0("Measure leadership by author position instead: ",
                   "{.code lead_role = \"first\"} or {.code \"last\"}, ",
                   "with focal institutions.")
    ), class = "scimapR_leadership_unknown", call = call)
  }
  what <- if (identical(lead_role, "any_lead")) {
    "a known author position or corresponding author"
  } else {
    "a known author position"
  }
  cli::cli_abort(c(
    paste0("None of the {n} work{?s} has ", what, ", so the ",
           "{.val leadership} share has no denominator."),
    "i" = paste0("{.field position} is {.code NA} for all their ",
                 "authorships, as in corpora from {.fn sm_fetch_orcid}.")
  ), class = "scimapR_leadership_unknown", call = call)
}

#' The leadership definition stored in sm_its, sm_did and sm_synth results
#'
#' @param institutions The focal labels (sm_its()), the labels of each
#'   group (sm_did()) or unit (sm_synth()) when `institution_aware`, else
#'   `NULL`.
#' @return A list: `lead_role`, `institution_aware`, `institutions` and
#'   `label_column` (the column `.resolve_institution_labels()` labels the
#'   authorships by, `NA` without focal institutions).
#' @noRd
.sm_leadership_def <- function(corpus, lead_role, institutions = NULL,
                               institution_aware = FALSE) {
  label_column <- NA_character_
  if (length(institutions) > 0L) {
    label_column <- .resolve_institution_labels(
      corpus$authorships, corpus$institutions, country_fallback = FALSE
    )$column
  }
  list(lead_role = lead_role, institution_aware = institution_aware,
       institutions = institutions, label_column = label_column)
}

#' One line describing a leadership definition, for print methods
#' @param own Where an institution-aware series looks for its lead, as
#'   text completing "is at ...".
#' @noRd
.sm_leadership_text <- function(def, own = "the unit's own institution") {
  role <- .lead_role_text(def$lead_role)
  if (isTRUE(def$institution_aware)) {
    txt <- paste0("works whose ", role, " is at ", own)
  } else if (length(def$institutions) > 0L) {
    txt <- paste0("works whose ", role, " is at ",
                  paste(unlist(def$institutions), collapse = ", "))
  } else {
    return(paste0("works with a corresponding author, among the works ",
                  "whose corresponding author is known"))
  }
  if (!is.na(def$label_column)) {
    txt <- paste0(txt, " (institution labels from ", def$label_column, ")")
  }
  txt
}

#' Check the leadership arguments of the causal functions
#'
#' Warns when they are given with another outcome (they are ignored) and
#' aborts for a role other than `"corresponding"` without focal
#' institutions, which every work would pass.
#'
#' @param given Names of the leadership arguments the caller set
#'   (`institutions`, `lead_role`, `institution_aware`).
#' @param focal Whether focal institutions are used (`institutions` given,
#'   or `institution_aware = TRUE`).
#' @param focal_arg The argument that sets them, for the message.
#' @return `TRUE` when the outcome is `"leadership"`, else `FALSE`.
#' @noRd
.sm_check_leadership_args <- function(outcome, lead_role, given, focal,
                                      focal_arg, call = rlang::caller_env()) {
  if (outcome != "leadership") {
    if (length(given) > 0L) {
      cli::cli_warn(
        paste0("{.arg {given}} appl{?ies/y} only to ",
               "{.code outcome = \"leadership\"} and {?is/are} ignored."),
        class = "scimapR_leadership_ignored", call = call
      )
    }
    return(FALSE)
  }
  if (!focal && lead_role != "corresponding") {
    cli::cli_abort(c(
      paste0("{.code lead_role = \"{lead_role}\"} needs focal ",
             "institutions: set {.arg {focal_arg}}."),
      "i" = paste0("Every work has a first and a last author, so without ",
                   "focal institutions its share would be 1 in every year.")
    ), call = call)
  }
  TRUE
}
