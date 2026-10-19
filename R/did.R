# Part C2: difference-in-differences (DiD) and synthetic control.

#' Resolve the works belonging to a set of institutions
#'
#' Looks across the institution-attribution columns produced by
#' [sm_affiliation_match()] / [sm_attribute_institution()]
#' (`institution_name`, `institution_match`, `institution_id`) and returns the
#' `work_id`s with at least one authorship in `institutions`.
#' @noRd
.resolve_group_works <- function(corpus, institutions,
                                 call = rlang::caller_env()) {
  a <- corpus$authorships
  cols <- intersect(c("institution_name", "institution_match",
                      "institution_id"), names(a))
  if (length(cols) == 0L) {
    cli::cli_abort(c(
      "No institution-attribution columns found on {.code corpus$authorships}.",
      "i" = "Run {.fn sm_affiliation_match} / {.fn sm_attribute_institution} first."
    ), call = call)
  }
  hit <- Reduce(`|`, lapply(cols, function(cc) a[[cc]] %in% institutions))
  unique(a$work_id[hit])
}

#' Difference-in-differences for a treated vs control institution set
#'
#' @description
#' Fits a difference-in-differences (DiD) model comparing the yearly `outcome`
#' series of a treated institution set against a control set, before and after
#' `intervention_year`. Group membership is resolved via the
#' institution-attribution columns from [sm_affiliation_match()] /
#' [sm_attribute_institution()].
#'
#' @param corpus An `sm_corpus` with institution-attribution columns.
#' @param treated,control Character vectors of institution labels (matched
#'   against `institution_name` / `institution_match` / `institution_id`).
#'   The two may not share a label.
#' @param intervention_year Year the intervention takes effect: one whole
#'   number such as `2020`, or text holding one.
#' @param outcome One of `"count"`, `"share_q1"`, `"cnci"`, `"leadership"`
#'   (see [sm_its()]).
#' @param family Optional GLM family; defaults to Gaussian (DiD is an additive
#'   contrast). Override for, e.g., a Poisson count model; a Poisson fit
#'   warns when the counts are overdispersed.
#' @param lag Citation-maturity lag in years (default `2`), as in
#'   [sm_its()]: for `"cnci"` the most recent `lag` years are
#'   citation-immature and excluded.
#' @param institution_aware For `outcome = "leadership"`: if `TRUE`, each
#'   group's share counts the works whose author in the role `lead_role`
#'   belongs to the group's own institutions (the treated series uses
#'   `institutions = treated`, the control series `institutions = control`,
#'   as in [sm_its()]). `FALSE` (default) counts the works with a
#'   corresponding author.
#' @param lead_role The author role that leads a work, as in [sm_its()], for
#'   `outcome = "leadership"` and for `shared = "lead"`. For the leadership
#'   outcome, roles other than `"corresponding"` need
#'   `institution_aware = TRUE`.
#' @param shared What to do with works that belong to both groups, such as
#'   works co-authored by a treated and a control institution: `"keep"`
#'   (default) keeps them in both series, `"exclude"` leaves them out of
#'   both, and `"lead"` puts each in the series of the group whose
#'   institution holds its author in the role `lead_role` (a work led from
#'   both groups or from neither leaves both series).
#' @param call Caller environment for error reporting.
#'
#' @details
#' Each group's yearly series is built as in [sm_its()]. For `"count"` a
#' group's years without works count 0, over every year from the first to
#' the last publication year of the corpus. For the other outcomes a year in
#' which a group has works but no usable value is dropped from that group's
#' series, with a warning, and listed in `dropped_years`. For `"cnci"` the
#' citation-immature years are then excluded from both series, by the same
#' rule as in [sm_its()], and listed in `provisional_years`; up to scimapR
#' 0.4.0 `sm_did()` kept them. Each group needs 4 or more years, with at
#' least one before `intervention_year` and one from it on; otherwise
#' `sm_did()` aborts. The confidence interval uses the reference
#' distribution of the p-value (t with the residual degrees of freedom for
#' the default Gaussian family); no correction for autocorrelation is
#' applied.
#'
#' A work belongs to a group when one of its authorships carries one of the
#' group's labels, so a work co-authored by both groups belongs to both.
#' Such shared works pull the two series together and the estimate toward
#' 0. `sm_did()` warns when there are shared works and `shared` is not
#' set, and records them in `shared_works`. For `"leadership"` the
#' denominators leave out the works whose lead is unknown, as in
#' [sm_its()].
#'
#' @return An `sm_did` S3 object with components: `model`, `did_estimate`
#'   (a one-row tibble: `estimate`, `std.error`, `conf.low`, `conf.high`,
#'   `p.value`), `series` (group-by-year tibble: `year`, `group`, `value`,
#'   `n_works`), `dropped_years` (tibble: `group`, `year`; the group-years
#'   left out for lack of a usable value), `provisional_years` (integer;
#'   the citation-immature years excluded for `"cnci"`), `shared_works`
#'   (tibble: `work_id`, `series`; the works of both groups and where they
#'   went: `"both"`, `"treated"`, `"control"` or `"none"`), `shared` (the
#'   policy), `leadership` (the leadership definition, as in [sm_its()],
#'   with `institutions` the labels of each group when `institution_aware`;
#'   `NULL` for the other outcomes), and metadata (`outcome`,
#'   `intervention_year`, `family`, `lag`).
#'
#' @family causal
#' @seealso [sm_its()], [sm_synth()]
#' @export
#' @examplesIf rlang::is_installed("stringdist")
#' corpus <- sm_example_corpus(n_works = 120, seed = 1)
#' # Tag two institution groups for illustration: each work belongs to one
#' a <- corpus$authorships
#' group <- rep(c("Inst A", "Inst B"), length.out = nrow(corpus$works))
#' corpus$authorships$institution_name <-
#'   group[match(a$work_id, corpus$works$work_id)]
#' did <- sm_did(corpus, treated = "Inst A", control = "Inst B",
#'               intervention_year = 2020, outcome = "count")
#' did
sm_did <- function(corpus,
                   treated,
                   control,
                   intervention_year,
                   outcome = c("count", "share_q1", "cnci", "leadership"),
                   family = NULL,
                   lag = NULL,
                   institution_aware = FALSE,
                   lead_role = c("corresponding", "first", "last",
                                 "first_or_last", "any_lead"),
                   shared = c("keep", "exclude", "lead"),
                   call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  outcome <- rlang::arg_match(outcome, error_call = call)
  .check_flag(institution_aware, call = call)
  role_given <- !missing(lead_role)
  lead_role <- rlang::arg_match(lead_role, error_call = call)
  shared_given <- !missing(shared)
  shared <- rlang::arg_match(shared, error_call = call)
  # shared = "lead" uses lead_role whatever the outcome
  given <- c("institution_aware", "lead_role")[
    c(institution_aware, role_given && shared != "lead")
  ]
  intervention_year <- .sm_intervention_year(intervention_year, call = call)
  lag <- as.integer(lag %||% 2L)
  both <- intersect(treated, control)
  if (length(both) > 0L) {
    cli::cli_abort(c(
      "{.arg treated} and {.arg control} share the label{?s} {.val {both}}.",
      "i" = "Give each institution label to one group only."
    ), call = call)
  }
  leadership <- NULL
  aware <- FALSE
  if (.sm_check_leadership_args(outcome, lead_role, given,
                                focal = institution_aware,
                                focal_arg = "institution_aware",
                                call = call)) {
    aware <- institution_aware
    leadership <- .sm_leadership_def(
      corpus, lead_role,
      if (aware) list(treated = treated, control = control),
      institution_aware = aware
    )
  }

  treated_works <- .resolve_group_works(corpus, treated, call = call)
  control_works <- .resolve_group_works(corpus, control, call = call)

  if (length(treated_works) == 0L || length(control_works) == 0L) {
    cli::cli_abort(c(
      "Both groups must contain works.",
      "i" = "treated: {length(treated_works)} works; control: {length(control_works)} works."
    ), call = call)
  }

  groups_of <- .sm_did_shared(corpus, treated_works, control_works, treated,
                              control, shared, lead_role,
                              warn = !shared_given, call = call)
  treated_works <- groups_of$treated
  control_works <- groups_of$control
  if (length(treated_works) == 0L || length(control_works) == 0L) {
    cli::cli_abort(c(
      "Both groups must contain works.",
      "i" = paste0("treated: {length(treated_works)} works; control: ",
                   "{length(control_works)} works, after the policy ",
                   "{.code shared = \"{shared}\"} for the ",
                   "{nrow(groups_of$shared_works)} works of both groups.")
    ), call = call)
  }

  # Both series derive the same FNCI: show its small-cell message once.
  .fnci_inform_once({
    y_t <- .sm_yearly_outcome(corpus, outcome, treated_works,
                              institutions = if (aware) treated,
                              lead_role = lead_role, call = call)
    y_c <- .sm_yearly_outcome(corpus, outcome, control_works,
                              institutions = if (aware) control,
                              lead_role = lead_role, call = call)
  })
  # citation-maturity exclusion, as in sm_its(), after the unusable years
  provisional_years <- integer()
  if (outcome == "cnci") {
    cutoff <- .maturity_cutoff(corpus, lag)
    if (!is.na(cutoff)) {
      years <- c(y_t$series$year, y_c$series$year)
      provisional_years <- sort(unique(years[years > cutoff]))
      y_t$series <- y_t$series[!y_t$series$year %in% provisional_years, ]
      y_c$series <- y_c$series[!y_c$series$year %in% provisional_years, ]
    }
  }
  # Each group drops its own unusable years (glm would omit their rows
  # anyway) and must keep years before and after the intervention.
  groups <- c("control", "treated")
  yearly <- list(control = y_c, treated = y_t)
  for (g in groups) {
    dropped <- yearly[[g]]$dropped_years
    notes <- if (length(dropped) > 0L) {
      paste0("Dropped for lack of usable ", outcome, " data: ",
             paste(dropped, collapse = ", "), ".")
    } else {
      character()
    }
    if (length(provisional_years) > 0L) {
      notes <- c(notes, paste0("Excluded as citation-immature: ",
                               paste(provisional_years, collapse = ", "),
                               "."))
    }
    .sm_check_years(yearly[[g]]$series$year, intervention_year,
                    paste0("for the DiD ", g, " group"), notes = notes,
                    call = call)
  }
  n_dropped <- c(length(y_c$dropped_years), length(y_t$dropped_years))
  dropped_years <- tibble::tibble(
    group = factor(rep(groups, n_dropped), levels = groups),
    year = c(y_c$dropped_years, y_t$dropped_years)
  )
  if (nrow(dropped_years) > 0L) {
    .sm_warn_dropped_units(
      dropped_years$group, dropped_years$year, outcome,
      "Dropped years with no usable {.val {outcome}} data from the DiD series:"
    )
  }

  s_t <- y_t$series
  s_c <- y_c$series
  s_t$group <- "treated"
  s_c$group <- "control"
  series <- dplyr::bind_rows(s_c, s_t)
  series$group <- factor(series$group, levels = groups)

  df <- series
  df$post <- as.integer(df$year >= intervention_year)

  fam <- if (is.null(family)) stats::gaussian() else
    .sm_outcome_family(outcome, family)

  fit <- stats::glm(value ~ group + post + group:post, data = df,
                    family = fam,
                    weights = if (outcome %in% c("share_q1", "leadership")) {
                      df$n_works
                    } else {
                      NULL
                    })
  .sm_check_overdispersion(fit)

  coefs <- .sm_tidy_glm(fit)
  int_row <- grep(":", coefs$term)
  did_estimate <- if (length(int_row) == 1L) {
    coefs[int_row, c("term", "estimate", "std.error", "conf.low",
                     "conf.high", "p.value")]
  } else {
    tibble::tibble(term = "group:post", estimate = NA_real_,
                   std.error = NA_real_, conf.low = NA_real_,
                   conf.high = NA_real_, p.value = NA_real_)
  }

  structure(
    list(
      model = fit,
      did_estimate = did_estimate,
      series = series,
      dropped_years = dropped_years,
      provisional_years = provisional_years,
      shared_works = groups_of$shared_works,
      shared = shared,
      leadership = leadership,
      outcome = outcome,
      intervention_year = intervention_year,
      family = fam$family,
      lag = lag
    ),
    class = "sm_did"
  )
}

#' Apply the policy for works that belong to both DiD groups
#'
#' @param warn Whether to warn about shared works kept in both series (the
#'   caller did not choose a policy).
#' @return A list: the `treated` and `control` work ids after the policy,
#'   and `shared_works` (tibble: `work_id`, `series`).
#' @noRd
.sm_did_shared <- function(corpus, treated_works, control_works, treated,
                           control, shared, lead_role, warn,
                           call = rlang::caller_env()) {
  ids <- intersect(treated_works, control_works)
  series <- rep(switch(shared, keep = "both", "none"), length(ids))
  if (length(ids) > 0L && shared == "lead") {
    a <- corpus$authorships
    a <- a[a$work_id %in% ids, , drop = FALSE]
    led_by <- function(labels) {
      focal <- .focal_rows(a, corpus$institutions, labels)
      status <- .lead_status(a, lead_role, focal)
      status$work_id[status$led %in% TRUE]
    }
    by_treated <- led_by(treated)
    by_control <- led_by(control)
    series[ids %in% setdiff(by_treated, by_control)] <- "treated"
    series[ids %in% setdiff(by_control, by_treated)] <- "control"
  }
  if (length(ids) > 0L && shared == "keep" && warn) {
    cli::cli_warn(c(
      paste0("Of {length(union(treated_works, control_works))} works, ",
             "{length(ids)} belong{?s/} to both the treated and the ",
             "control group and enter{?s/} both series."),
      "i" = paste0("Works co-authored by both groups pull the two series ",
                   "together, and the DiD estimate toward 0."),
      "i" = paste0("Set {.code shared = \"exclude\"} to leave them out of ",
                   "both series or {.code shared = \"lead\"} to give each ",
                   "to the group of its lead author; ",
                   "{.code shared = \"keep\"} keeps them without this ",
                   "warning.")
    ), class = "scimapR_did_shared_works", call = call)
  }
  out <- ids[series %in% "none"]
  list(
    treated = setdiff(treated_works, c(out, ids[series %in% "control"])),
    control = setdiff(control_works, c(out, ids[series %in% "treated"])),
    shared_works = tibble::tibble(work_id = as.character(ids),
                                  series = series)
  )
}

#' @rdname sm_did
#' @param x An `sm_did` object.
#' @param ... Ignored.
#' @return `print` returns `x` invisibly.
#' @export
print.sm_did <- function(x, ...) {
  cli::cli_h1("<sm_did>")
  cli::cli_text("{.strong Outcome:} {x$outcome}   {.strong Family:} {x$family}")
  cli::cli_text("{.strong Intervention year:} {x$intervention_year}")
  if (!is.null(x$leadership)) {
    own <- "one of the group's own institutions"
    cli::cli_text("{.strong Leadership:} ",
                  .sm_cli_escape(.sm_leadership_text(x$leadership, own)))
  }
  dropped <- x$dropped_years
  if (!is.null(dropped) && nrow(dropped) > 0L) {
    txt <- paste(.sm_unit_years(dropped$group, dropped$year), collapse = "; ")
    cli::cli_text("{.strong Dropped (no usable data):} ", .sm_cli_escape(txt))
  }
  if (length(x$provisional_years) > 0L) {
    cli::cli_text("{.strong Excluded (citation-immature):} ",
                  "{x$provisional_years}")
  }
  shared <- x$shared_works
  if (!is.null(shared) && nrow(shared) > 0L) {
    went <- table(factor(shared$series,
                         levels = c("both", "treated", "control", "none")))
    went <- went[went > 0L]
    where <- c(both = "in both series", treated = "treated only",
               control = "control only", none = "left out")[names(went)]
    cli::cli_text("{.strong Shared works:} {nrow(shared)} (",
                  paste(went, where, collapse = ", "), ")")
  }
  d <- x$did_estimate
  cli::cli_text("")
  cli::cli_text("{.strong DiD estimate:} {round(d$estimate, 4)} [{round(d$conf.low, 4)}, {round(d$conf.high, 4)}]  (p = {format.pval(d$p.value, digits = 2)})")
  invisible(x)
}

#' @rdname sm_did
#' @param object An `sm_did` object.
#' @return `summary` returns the DiD estimate tibble.
#' @export
summary.sm_did <- function(object, ...) {
  object$did_estimate
}

#' @rdname sm_did
#' @param object An `sm_did` object.
#' @return `autoplot` returns a `ggplot` (parallel trends + divergence).
#' @importFrom ggplot2 autoplot
#' @export
autoplot.sm_did <- function(object, ...) {
  s <- object$series
  iy <- object$intervention_year
  ggplot2::ggplot(s, ggplot2::aes(.data$year, .data$value,
                                  colour = .data$group)) +
    ggplot2::geom_vline(xintercept = iy - 0.5, linetype = "dotted",
                        colour = "grey40") +
    ggplot2::geom_line(linewidth = 1) +
    ggplot2::geom_point(size = 2) +
    sm_scale_color() +
    sm_theme() +
    ggplot2::labs(
      title = paste0("Difference-in-differences: ", object$outcome),
      subtitle = paste0("Intervention at ", iy),
      x = "Year", y = object$outcome, colour = "Group"
    )
}

#' Build the balanced unit-by-year panel for sm_synth()
#'
#' A year enters the panel only when every unit has a usable value in it, so
#' the panel stays balanced. For the count outcome every unit has every
#' corpus year (years without works count 0) and nothing is dropped. The
#' years checked are the years in which any unit has works; each unit-year
#' without a usable value is returned in `dropped_years`. No warning here:
#' sm_synth() warns once.
#'
#' For `"cnci"` the citation-immature panel years are excluded after that,
#' as in sm_its(), and returned in `provisional_years`. With
#' `institution_aware`, each unit's leadership share uses the unit's own
#' label as its focal institution.
#'
#' @param units Unit labels, the treated unit first.
#' @return A list: `panel` (tibble: `unit`, `year`, `value`),
#'   `dropped_years` (tibble: `unit`, `year`) and `provisional_years`
#'   (integer).
#' @noRd
.sm_synth_panel <- function(corpus, units, outcome, intervention_year,
                            lag = 2L, institution_aware = FALSE,
                            lead_role = "corresponding",
                            call = rlang::caller_env()) {
  units <- as.character(units)
  ids <- lapply(units, function(u) {
    .resolve_group_works(corpus, u, call = call)
  })
  empty <- units[lengths(ids) == 0L]
  if (length(empty) > 0L) {
    cli::cli_abort(c(
      "Every unit of the synthetic-control panel must contain works.",
      "i" = "No works found for {.val {empty}}."
    ), call = call)
  }

  # Every unit derives the same FNCI: show its small-cell message once.
  yearly <- .fnci_inform_once(Map(function(w, u) {
    .sm_yearly_outcome(corpus, outcome, w,
                       institutions = if (institution_aware) u,
                       lead_role = lead_role, call = call)
  }, ids, units))
  years <- sort(unique(unlist(lapply(yearly, function(y) {
    c(y$series$year, y$dropped_years)
  }))))
  lacking <- lapply(yearly, function(y) setdiff(years, y$series$year))
  dropped_years <- tibble::tibble(
    unit = rep(units, lengths(lacking)),
    year = as.integer(unlist(lacking))
  )
  keep <- setdiff(years, dropped_years$year)

  # citation-maturity exclusion, as in sm_its(), after the unusable years
  provisional_years <- integer()
  if (outcome == "cnci") {
    cutoff <- .maturity_cutoff(corpus, lag)
    if (!is.na(cutoff)) {
      provisional_years <- as.integer(keep[keep > cutoff])
      keep <- setdiff(keep, provisional_years)
    }
  }

  # The panel is balanced, so this one check holds for every unit.
  notes <- character()
  if (nrow(dropped_years) > 0L) {
    lines <- .sm_unit_years(dropped_years$unit, dropped_years$year)
    notes <- paste0("Dropped for lack of usable ", outcome, " data in ",
                    "these units: ", paste(lines, collapse = "; "), ".")
  }
  if (length(provisional_years) > 0L) {
    notes <- c(notes, paste0("Excluded as citation-immature: ",
                             paste(provisional_years, collapse = ", "), "."))
  }
  .sm_check_years(keep, intervention_year, "for the synthetic-control panel",
                  min_pre = 2L, min_post = 1L, notes = notes, call = call)

  panel <- dplyr::bind_rows(Map(function(y, u) {
    s <- y$series[y$series$year %in% keep, , drop = FALSE]
    tibble::tibble(unit = rep(u, nrow(s)), year = s$year, value = s$value)
  }, yearly, units))
  list(panel = panel, dropped_years = dropped_years,
       provisional_years = provisional_years)
}

#' Synthetic control for a treated institution
#'
#' @description
#' Builds the unit-by-time outcome panel for a treated institution against a
#' donor pool and estimates a synthetic control using the optional
#' \pkg{tidysynth} package. The dependency is kept in `Suggests`; when it is not
#' installed an informative error explains how to install it.
#'
#' @param corpus An `sm_corpus` with institution-attribution columns.
#' @param treated A single institution label (the treated unit).
#' @param donors Character vector of donor-pool institution labels.
#' @param intervention_year Year the intervention takes effect: one whole
#'   number such as `2020`, or text holding one.
#' @param outcome One of `"count"`, `"share_q1"`, `"cnci"`, `"leadership"`.
#' @param lag Citation-maturity lag in years (default `2`), as in
#'   [sm_its()]: for `"cnci"` the most recent `lag` years are
#'   citation-immature and excluded from the panel.
#' @param institution_aware For `outcome = "leadership"`: if `TRUE`, each
#'   unit's share counts the works whose author in the role `lead_role`
#'   belongs to the unit itself (its label is the focal institution, as
#'   `institutions` in [sm_its()]); the treated unit and every donor use
#'   their own label. `FALSE` (default) counts the works with a
#'   corresponding author.
#' @param lead_role For `outcome = "leadership"`: the author role that leads
#'   a work, as in [sm_its()]. Roles other than `"corresponding"` need
#'   `institution_aware = TRUE`.
#' @param call Caller environment for error reporting.
#'
#' @details
#' Each unit's yearly series is built as in [sm_its()], and every unit must
#' contain works. For `"count"` a unit's years without works count 0, over
#' every year from the first to the last publication year of the corpus, so
#' no year is dropped. For the other outcomes the panel stays balanced: a
#' year in which any unit has no works or no usable value is dropped for
#' every unit, with a warning, and listed in `dropped_years`. For `"cnci"`
#' the citation-immature years are then excluded for every unit, by the
#' same rule as in [sm_its()], and listed in `provisional_years`; up to
#' scimapR 0.4.0 `sm_synth()` kept them. At least 4 panel years must
#' remain, 2 or more before `intervention_year` and 1 or more from it on;
#' otherwise `sm_synth()` aborts. For `"leadership"` the shares leave out
#' the works whose lead is unknown, as in [sm_its()].
#'
#' @return An `sm_synth` S3 object wrapping the initialised `tidysynth`
#'   object (`synth`), the long panel (`panel`: `unit`, `year`, `value`),
#'   `dropped_years` (tibble: `unit`, `year`; the unit-years without a usable
#'   value, whose years were dropped for every unit), `provisional_years`
#'   (integer; the citation-immature years excluded for `"cnci"`),
#'   `leadership` (the leadership definition, as in [sm_its()], with
#'   `institutions` the unit labels when `institution_aware`; `NULL` for
#'   the other outcomes), and metadata.
#'
#' @family causal
#' @seealso [sm_did()]
#' @export
#' @examplesIf rlang::is_installed("tidysynth")
#' corpus <- sm_example_corpus(n_works = 300, seed = 1)
#' corpus$authorships$institution_name <- sample(
#'   c("A", "B", "C", "D"), nrow(corpus$authorships), replace = TRUE)
#' synth <- sm_synth(corpus, treated = "A", donors = c("B", "C", "D"),
#'                   intervention_year = 2020, outcome = "count")
sm_synth <- function(corpus,
                     treated,
                     donors,
                     intervention_year,
                     outcome = c("count", "share_q1", "cnci", "leadership"),
                     lag = NULL,
                     institution_aware = FALSE,
                     lead_role = c("corresponding", "first", "last",
                                   "first_or_last", "any_lead"),
                     call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  outcome <- rlang::arg_match(outcome, error_call = call)
  .check_flag(institution_aware, call = call)
  given <- c("institution_aware", "lead_role")[c(institution_aware,
                                                 !missing(lead_role))]
  lead_role <- rlang::arg_match(lead_role, error_call = call)

  if (!rlang::is_installed("tidysynth")) {
    cli::cli_abort(c(
      "Package {.pkg tidysynth} is required for {.fn sm_synth}.",
      "i" = "Install it with {.code install.packages(\"tidysynth\")}, or use {.fn sm_did} for a difference-in-differences comparison."
    ), call = call)
  }

  intervention_year <- .sm_intervention_year(intervention_year, call = call)
  lag <- as.integer(lag %||% 2L)
  leadership <- NULL
  aware <- FALSE
  if (.sm_check_leadership_args(outcome, lead_role, given,
                                focal = institution_aware,
                                focal_arg = "institution_aware",
                                call = call)) {
    aware <- institution_aware
    leadership <- .sm_leadership_def(
      corpus, lead_role, if (aware) c(treated, donors),
      institution_aware = aware
    )
  }
  built <- .sm_synth_panel(corpus, c(treated, donors), outcome,
                           intervention_year, lag = lag,
                           institution_aware = aware, lead_role = lead_role,
                           call = call)
  panel <- built$panel
  dropped_years <- built$dropped_years
  if (nrow(dropped_years) > 0L) {
    .sm_warn_dropped_units(
      dropped_years$unit, dropped_years$year, outcome,
      paste0("Dropped years from the synthetic-control panel, for every ",
             "unit, because these units have no usable {.val {outcome}} ",
             "data in them:")
    )
  }

  # tidysynth expects bare (tidyselect) column names, not strings; the panel
  # columns are always `unit`/`value`/`year` (constructed above).
  synth <- tidysynth::synthetic_control(
    panel,
    outcome = !!rlang::sym("value"),
    unit = !!rlang::sym("unit"),
    time = !!rlang::sym("year"),
    i_unit = treated,
    i_time = intervention_year,
    generate_placebos = FALSE
  )

  structure(
    list(
      synth = synth,
      panel = panel,
      dropped_years = dropped_years,
      provisional_years = built$provisional_years,
      leadership = leadership,
      treated = treated,
      donors = donors,
      outcome = outcome,
      intervention_year = intervention_year,
      lag = lag
    ),
    class = "sm_synth"
  )
}

#' @rdname sm_synth
#' @param x An `sm_synth` object.
#' @param ... Ignored.
#' @return `print` returns `x` invisibly.
#' @export
print.sm_synth <- function(x, ...) {
  cli::cli_h1("<sm_synth>")
  cli::cli_text("{.strong Treated:} {x$treated}")
  cli::cli_text("{.strong Donors:} {x$donors}")
  cli::cli_text("{.strong Outcome:} {x$outcome}   {.strong Intervention:} {x$intervention_year}")
  if (!is.null(x$leadership)) {
    cli::cli_text("{.strong Leadership:} ",
                  .sm_cli_escape(.sm_leadership_text(x$leadership)))
  }
  cli::cli_text("{.strong Panel:} {nrow(x$panel)} unit-year rows")
  dropped <- x$dropped_years
  if (!is.null(dropped) && nrow(dropped) > 0L) {
    years <- paste(sort(unique(dropped$year)), collapse = ", ")
    txt <- paste(.sm_unit_years(dropped$unit, dropped$year), collapse = "; ")
    cli::cli_text("{.strong Dropped for every unit:} ", years,
                  " (no usable data: ", .sm_cli_escape(txt), ")")
  }
  if (length(x$provisional_years) > 0L) {
    cli::cli_text("{.strong Excluded (citation-immature):} ",
                  "{x$provisional_years}")
  }
  cli::cli_text("")
  cli::cli_text("Initialised {.pkg tidysynth} object in {.field $synth}; complete with {.fn tidysynth::generate_predictor} / {.fn tidysynth::generate_weights} / {.fn tidysynth::generate_control}.")
  invisible(x)
}
