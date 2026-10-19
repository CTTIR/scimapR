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
#' @param intervention_year Year the intervention takes effect: one whole
#'   number such as `2020`, or text holding one.
#' @param outcome One of `"count"`, `"share_q1"`, `"cnci"`, `"leadership"`
#'   (see [sm_its()]).
#' @param family Optional GLM family; defaults to Gaussian (DiD is an additive
#'   contrast). Override for, e.g., a Poisson count model; a Poisson fit
#'   warns when the counts are overdispersed.
#' @param call Caller environment for error reporting.
#'
#' @details
#' Each group's yearly series is built as in [sm_its()]. For `"count"` a
#' group's years without works count 0, over every year from the first to
#' the last publication year of the corpus. For the other outcomes a year in
#' which a group has works but no usable value is dropped from that group's
#' series, with a warning, and listed in `dropped_years`. Each group needs 4
#' or more years, with at least one before `intervention_year` and one from
#' it on; otherwise `sm_did()` aborts. The confidence interval uses the
#' reference distribution of the p-value (t with the residual degrees of
#' freedom for the default Gaussian family); no correction for
#' autocorrelation is applied.
#'
#' @return An `sm_did` S3 object with components: `model`, `did_estimate`
#'   (a one-row tibble: `estimate`, `std.error`, `conf.low`, `conf.high`,
#'   `p.value`), `series` (group-by-year tibble: `year`, `group`, `value`,
#'   `n_works`), `dropped_years` (tibble: `group`, `year`; the group-years
#'   left out for lack of a usable value), and metadata (`outcome`,
#'   `intervention_year`, `family`).
#'
#' @family causal
#' @seealso [sm_its()], [sm_synth()]
#' @export
#' @examplesIf rlang::is_installed("stringdist")
#' corpus <- sm_example_corpus(n_works = 120, seed = 1)
#' # Tag two institution groups for illustration
#' corpus$authorships$institution_name <- rep(
#'   c("Inst A", "Inst B"), length.out = nrow(corpus$authorships))
#' did <- sm_did(corpus, treated = "Inst A", control = "Inst B",
#'               intervention_year = 2020, outcome = "count")
#' did
sm_did <- function(corpus,
                   treated,
                   control,
                   intervention_year,
                   outcome = c("count", "share_q1", "cnci", "leadership"),
                   family = NULL,
                   call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  outcome <- rlang::arg_match(outcome, error_call = call)
  intervention_year <- .sm_intervention_year(intervention_year, call = call)

  treated_works <- .resolve_group_works(corpus, treated, call = call)
  control_works <- .resolve_group_works(corpus, control, call = call)

  if (length(treated_works) == 0L || length(control_works) == 0L) {
    cli::cli_abort(c(
      "Both groups must contain works.",
      "i" = "treated: {length(treated_works)} works; control: {length(control_works)} works."
    ), call = call)
  }

  # Both series derive the same FNCI: show its small-cell message once.
  .fnci_inform_once({
    y_t <- .sm_yearly_outcome(corpus, outcome, treated_works, call = call)
    y_c <- .sm_yearly_outcome(corpus, outcome, control_works, call = call)
  })
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
      outcome = outcome,
      intervention_year = intervention_year,
      family = fam$family
    ),
    class = "sm_did"
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
  dropped <- x$dropped_years
  if (!is.null(dropped) && nrow(dropped) > 0L) {
    txt <- paste(.sm_unit_years(dropped$group, dropped$year), collapse = "; ")
    cli::cli_text("{.strong Dropped (no usable data):} ", .sm_cli_escape(txt))
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
#' @param units Unit labels, the treated unit first.
#' @return A list: `panel` (tibble: `unit`, `year`, `value`) and
#'   `dropped_years` (tibble: `unit`, `year`).
#' @noRd
.sm_synth_panel <- function(corpus, units, outcome, intervention_year,
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
  yearly <- .fnci_inform_once(lapply(ids, function(w) {
    .sm_yearly_outcome(corpus, outcome, w, call = call)
  }))
  years <- sort(unique(unlist(lapply(yearly, function(y) {
    c(y$series$year, y$dropped_years)
  }))))
  lacking <- lapply(yearly, function(y) setdiff(years, y$series$year))
  dropped_years <- tibble::tibble(
    unit = rep(units, lengths(lacking)),
    year = as.integer(unlist(lacking))
  )
  keep <- setdiff(years, dropped_years$year)

  # The panel is balanced, so this one check holds for every unit.
  notes <- character()
  if (nrow(dropped_years) > 0L) {
    lines <- .sm_unit_years(dropped_years$unit, dropped_years$year)
    notes <- paste0("Dropped for lack of usable ", outcome, " data in ",
                    "these units: ", paste(lines, collapse = "; "), ".")
  }
  .sm_check_years(keep, intervention_year, "for the synthetic-control panel",
                  min_pre = 2L, min_post = 1L, notes = notes, call = call)

  panel <- dplyr::bind_rows(Map(function(y, u) {
    s <- y$series[y$series$year %in% keep, , drop = FALSE]
    tibble::tibble(unit = rep(u, nrow(s)), year = s$year, value = s$value)
  }, yearly, units))
  list(panel = panel, dropped_years = dropped_years)
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
#' @param call Caller environment for error reporting.
#'
#' @details
#' Each unit's yearly series is built as in [sm_its()], and every unit must
#' contain works. For `"count"` a unit's years without works count 0, over
#' every year from the first to the last publication year of the corpus, so
#' no year is dropped. For the other outcomes the panel stays balanced: a
#' year in which any unit has no works or no usable value is dropped for
#' every unit, with a warning, and listed in `dropped_years`. At least 4
#' panel years must remain, 2 or more before `intervention_year` and 1 or
#' more from it on; otherwise `sm_synth()` aborts.
#'
#' @return An `sm_synth` S3 object wrapping the initialised `tidysynth`
#'   object (`synth`), the long panel (`panel`: `unit`, `year`, `value`),
#'   `dropped_years` (tibble: `unit`, `year`; the unit-years without a usable
#'   value, whose years were dropped for every unit), and metadata.
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
                     call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  outcome <- rlang::arg_match(outcome, error_call = call)

  if (!rlang::is_installed("tidysynth")) {
    cli::cli_abort(c(
      "Package {.pkg tidysynth} is required for {.fn sm_synth}.",
      "i" = "Install it with {.code install.packages(\"tidysynth\")}, or use {.fn sm_did} for a difference-in-differences comparison."
    ), call = call)
  }

  intervention_year <- .sm_intervention_year(intervention_year, call = call)
  built <- .sm_synth_panel(corpus, c(treated, donors), outcome,
                           intervention_year, call = call)
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
      treated = treated,
      donors = donors,
      outcome = outcome,
      intervention_year = intervention_year
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
  cli::cli_text("{.strong Panel:} {nrow(x$panel)} unit-year rows")
  dropped <- x$dropped_years
  if (!is.null(dropped) && nrow(dropped) > 0L) {
    years <- paste(sort(unique(dropped$year)), collapse = ", ")
    txt <- paste(.sm_unit_years(dropped$unit, dropped$year), collapse = "; ")
    cli::cli_text("{.strong Dropped for every unit:} ", years,
                  " (no usable data: ", .sm_cli_escape(txt), ")")
  }
  cli::cli_text("")
  cli::cli_text("Initialised {.pkg tidysynth} object in {.field $synth}; complete with {.fn tidysynth::generate_predictor} / {.fn tidysynth::generate_weights} / {.fn tidysynth::generate_control}.")
  invisible(x)
}
