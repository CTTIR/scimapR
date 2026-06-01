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
#' @param intervention_year Integer year the intervention takes effect.
#' @param outcome One of `"count"`, `"share_q1"`, `"cnci"`, `"leadership"`
#'   (see [sm_its()]).
#' @param family Optional GLM family; defaults to Gaussian (DiD is an additive
#'   contrast). Override for, e.g., a Poisson count model.
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_did` S3 object with components: `model`, `did_estimate`
#'   (a one-row tibble: `estimate`, `std.error`, `conf.low`, `conf.high`,
#'   `p.value`), `series` (group-by-year tibble: `year`, `group`, `value`,
#'   `n_works`), and metadata (`outcome`, `intervention_year`, `family`).
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
  intervention_year <- as.integer(intervention_year)

  treated_works <- .resolve_group_works(corpus, treated, call = call)
  control_works <- .resolve_group_works(corpus, control, call = call)

  if (length(treated_works) == 0L || length(control_works) == 0L) {
    cli::cli_abort(c(
      "Both groups must contain works.",
      "i" = "treated: {length(treated_works)} works; control: {length(control_works)} works."
    ), call = call)
  }

  s_t <- .sm_yearly_outcome(corpus, outcome, treated_works, call = call)
  s_c <- .sm_yearly_outcome(corpus, outcome, control_works, call = call)
  s_t$group <- "treated"
  s_c$group <- "control"
  series <- dplyr::bind_rows(s_c, s_t)
  series$group <- factor(series$group, levels = c("control", "treated"))

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
#' @param intervention_year Integer year the intervention takes effect.
#' @param outcome One of `"count"`, `"share_q1"`, `"cnci"`, `"leadership"`.
#' @param call Caller environment for error reporting.
#'
#' @return An `sm_synth` S3 object wrapping the fitted `tidysynth` object
#'   (`synth`), the long panel (`panel`), and metadata.
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
  intervention_year <- as.integer(intervention_year)

  if (!rlang::is_installed("tidysynth")) {
    cli::cli_abort(c(
      "Package {.pkg tidysynth} is required for {.fn sm_synth}.",
      "i" = "Install it with {.code install.packages(\"tidysynth\")}, or use {.fn sm_did} for a difference-in-differences comparison."
    ), call = call)
  }

  units <- c(treated, donors)
  panels <- lapply(units, function(u) {
    ids <- .resolve_group_works(corpus, u, call = call)
    s <- .sm_yearly_outcome(corpus, outcome, ids, call = call)
    s$unit <- u
    s
  })
  panel <- dplyr::bind_rows(panels)
  panel <- dplyr::select(panel, "unit", "year", "value")

  synth <- tidysynth::synthetic_control(
    panel,
    outcome = "value",
    unit = "unit",
    time = "year",
    i_unit = treated,
    i_time = intervention_year,
    generate_placebos = FALSE
  )

  structure(
    list(
      synth = synth,
      panel = panel,
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
  cli::cli_text("")
  cli::cli_text("Initialised {.pkg tidysynth} object in {.field $synth}; complete with {.fn tidysynth::generate_predictor} / {.fn tidysynth::generate_weights} / {.fn tidysynth::generate_control}.")
  invisible(x)
}
