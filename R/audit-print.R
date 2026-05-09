# Print methods for sm_audit_* classes
# Each MUST include a cli::cli_h3("Limitations") block with
# method-specific caveats about epistemic humility.

#' @rdname sm_audit_geographic
#' @param x An audit object to print.
#' @param ... Ignored.
#' @return `x` invisibly (print methods).
#' @export
print.sm_audit_geographic <- function(x, ...) {
  cli::cli_h1("<sm_audit_geographic>")

  cli::cli_text("{.strong Grouping:} {x$by}")
  cli::cli_text("{.strong Weighting:} {x$weight}")
  cli::cli_text("{.strong Coverage:} {round(x$coverage * 100, 1)}% of authorships have known geography")
  cli::cli_text("{.strong Gini coefficient:} {x$gini}")
  cli::cli_text("")

  if (nrow(x$distribution) > 0L) {
    cli::cli_h3("Distribution (top 10)")
    shown <- utils::head(x$distribution, 10L)
    for (i in seq_len(nrow(shown))) {
      cli::cli_text(
        "  {shown$group[i]}: {shown$count[i]} ({shown$pct[i]}%) [{shown$citations[i]} cit.]"
      )
    }
    if (nrow(x$distribution) > 10L) {
      cli::cli_text("  ... and {nrow(x$distribution) - 10L} more")
    }
  } else {
    cli::cli_text("No geographic data available.")
  }

  cli::cli_text("")
  cli::cli_h3("Limitations")
  cli::cli_ul(c(
    paste0(
      "Country codes are derived from author affiliation metadata, ",
      "which may be incomplete or inaccurate."
    ),
    paste0(
      "Multi-country affiliations may be under- or over-counted ",
      "depending on the data source."
    ),
    paste0(
      "Region and income tier classifications rely on institutional ",
      "metadata which may not be populated for all works."
    ),
    paste0(
      "Geographic representation does not capture diaspora researchers ",
      "or researchers with affiliations in multiple countries."
    ),
    paste0(
      "The Gini coefficient measures concentration but does not ",
      "account for population size or research funding differences."
    )
  ))

  invisible(x)
}

#' @rdname sm_audit_gender
#' @param x An audit object to print.
#' @param ... Ignored.
#' @export
print.sm_audit_gender <- function(x, ...) {
  cli::cli_h1("<sm_audit_gender>")

  cli::cli_text("{.strong Method:} {x$method}")
  cli::cli_text("{.strong Coverage:} {round(x$coverage * 100, 1)}% of authors have inferred gender")
  cli::cli_text("")

  if (nrow(x$distribution) > 0L) {
    cli::cli_h3("Overall distribution")
    for (i in seq_len(nrow(x$distribution))) {
      label <- x$distribution$inferred_gender[i]
      label <- if (is.na(label)) "unknown" else label
      cli::cli_text(
        "  {label}: {x$distribution$count[i]} ({x$distribution$pct[i]}%)"
      )
    }
  }

  if (nrow(x$by_position) > 0L) {
    cli::cli_text("")
    cli::cli_h3("By authorship position")
    positions <- unique(x$by_position$position_type)
    for (pos in positions) {
      pos_data <- dplyr::filter(x$by_position, .data$position_type == pos)
      entries <- paste0(
        pos_data$inferred_gender, ": ", pos_data$count,
        " (", pos_data$pct, "%)"
      )
      cli::cli_text("  {pos}: {paste(entries, collapse = ', ')}")
    }
  }

  if (!is.null(x$confidence_summary) &&
      !is.na(x$confidence_summary$mean)) {
    cli::cli_text("")
    cli::cli_h3("Confidence scores")
    cli::cli_text(
      "  Mean: {x$confidence_summary$mean}, Median: {x$confidence_summary$median}"
    )
    cli::cli_text(
      "  Range: [{x$confidence_summary$min}, {x$confidence_summary$max}]"
    )
  }

  cli::cli_text("")
  cli::cli_h3("Limitations")
  cli::cli_ul(c(
    paste0(
      "Gender is INFERRED from first names using a binary proxy. ",
      "This does not capture the full spectrum of gender identity."
    ),
    paste0(
      "Name-based methods have variable accuracy across cultures. ",
      "East Asian, South Asian, and many African names are poorly ",
      "served by Western-trained models."
    ),
    paste0(
      "Non-binary, transgender, and gender-diverse individuals ",
      "are systematically misclassified by these methods."
    ),
    paste0(
      "Initialised first names (e.g., 'J. Smith') cannot be ",
      "classified and reduce coverage."
    ),
    paste0(
      "These results should be reported with confidence intervals ",
      "and method-specific caveats in any publication."
    ),
    paste0(
      "We recommend against using these results to make claims ",
      "about individual researchers' gender identity."
    )
  ))

  invisible(x)
}

#' @rdname sm_audit_funding
#' @param x An audit object to print.
#' @param ... Ignored.
#' @export
print.sm_audit_funding <- function(x, ...) {
  cli::cli_h1("<sm_audit_funding>")

  cli::cli_text("{.strong Data source:} {x$source}")
  cli::cli_text(
    "{.strong Works with funding data:} {x$n_works_funded} / {x$n_works_total} ({round(x$coverage * 100, 1)}%)"
  )
  cli::cli_text("")

  if (nrow(x$funders) > 0L) {
    cli::cli_h3("Top funders")
    shown <- utils::head(x$funders, 10L)
    for (i in seq_len(nrow(shown))) {
      cli::cli_text(
        "  {shown$funder_name[i]}: {shown$n_works[i]} works ({shown$pct[i]}%)"
      )
    }
    if (nrow(x$funders) > 10L) {
      cli::cli_text("  ... and {nrow(x$funders) - 10L} more")
    }
  } else {
    cli::cli_text("No funding data found.")
  }

  cli::cli_text("")
  cli::cli_h3("Limitations")
  cli::cli_ul(c(
    paste0(
      "Funding metadata is voluntarily reported by publishers and ",
      "is often incomplete, especially for older publications."
    ),
    paste0(
      "Crossref and OpenAlex may not capture all funding sources; ",
      "institutional or departmental funding is rarely recorded."
    ),
    paste0(
      "Funder names are not standardised across databases; ",
      "the same funder may appear under multiple names."
    ),
    paste0(
      "Absence of funding data does not mean a work was unfunded; ",
      "it may simply be unreported."
    )
  ))

  invisible(x)
}

#' @rdname sm_audit_oa
#' @param x An audit object to print.
#' @param ... Ignored.
#' @export
print.sm_audit_oa <- function(x, ...) {
  cli::cli_h1("<sm_audit_oa>")

  cli::cli_text("{.strong Open access:} {x$pct_open}%")
  cli::cli_text("{.strong Coverage:} {round(x$coverage * 100, 1)}% of works have known OA status")
  cli::cli_text("{.strong Total works:} {x$n_works}")
  cli::cli_text("")

  if (nrow(x$distribution) > 0L) {
    cli::cli_h3("OA status distribution")
    for (i in seq_len(nrow(x$distribution))) {
      cli::cli_text(
        "  {x$distribution$oa_status[i]}: {x$distribution$count[i]} ({x$distribution$pct[i]}%)"
      )
    }
  }

  cli::cli_text("")
  cli::cli_h3("Limitations")
  cli::cli_ul(c(
    paste0(
      "OA status may change over time as embargo periods expire ",
      "or publishers change their access policies."
    ),
    paste0(
      "'Green' OA indicates a version is available in a repository ",
      "but it may not be the version of record."
    ),
    paste0(
      "'Bronze' OA indicates free-to-read on the publisher site ",
      "without a formal open license; access may be revoked."
    ),
    paste0(
      "OA status data depends on Unpaywall/OpenAlex coverage, ",
      "which may not include all repositories."
    )
  ))

  invisible(x)
}

#' @rdname sm_audit_summary
#' @param x An audit object to print.
#' @param ... Ignored.
#' @export
print.sm_audit_summary <- function(x, ...) {
  cli::cli_h1("<sm_audit_summary>")

  cli::cli_h3("Overview")
  for (i in seq_len(nrow(x$overview))) {
    row <- x$overview[i, ]
    coverage_pct <- round(row$coverage * 100, 1)
    cli::cli_text(
      "  {row$audit}: coverage {coverage_pct}% | {row$top_finding}"
    )
  }

  cli::cli_text("")
  cli::cli_text(
    "Use {.code print(x$geographic)}, {.code print(x$gender)}, etc. for detailed reports."
  )

  cli::cli_text("")
  cli::cli_h3("Limitations")
  cli::cli_ul(c(
    paste0(
      "All equity audits rely on metadata that may be incomplete, ",
      "inaccurate, or biased toward certain regions and publishers."
    ),
    paste0(
      "Coverage varies across audit dimensions; low coverage ",
      "means results should be interpreted with extreme caution."
    ),
    paste0(
      "These audits describe patterns in the available metadata ",
      "and should not be treated as definitive measures of equity."
    ),
    paste0(
      "We encourage transparent reporting of method, coverage, ",
      "and limitations alongside any equity analysis."
    )
  ))

  invisible(x)
}
