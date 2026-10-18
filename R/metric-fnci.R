#' Calculate Field-Normalized Citation Impact
#'
#' @description
#' Computes the Field-Normalized Citation Impact (FNCI) for each work in the
#' corpus. FNCI normalises a work's citation count by the average citation
#' count of all works in the same field and publication year.
#'
#' @param corpus An [sm_corpus] object.
#' @param classification Character; the classification system used to assign
#'   works to fields. One of `"openalex_concepts"` (default), `"mesh"`, or
#'   `"manual"`.
#' @param min_cell `NULL` (default) or a positive integer. When set, a
#'   baseline needs at least `min_cell` works with a known citation count;
#'   works in smaller cells fall back to larger baselines (see Details), and
#'   the result gains the columns `n_cell` and `baseline`.
#' @param by_type Logical. If `TRUE`, baseline cells are also split by
#'   document type, normalised from `works$type`: articles and reviews get
#'   cells of their own and all other types get `fnci = NA`. Adds the column
#'   `doc_type`. Default `FALSE`.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with one row per work and the columns `work_id`, `field`,
#'   `year`, `cited_by_count`, `field_mean` (the baseline: the mean citation
#'   count of the work's cell) and `fnci`. The column set depends on the
#'   arguments: `by_type = TRUE` adds `doc_type` (`"article"`, `"review"` or
#'   `NA`), and `min_cell` adds `n_cell` (integer; the number of works with a
#'   known citation count in the baseline cell) and `baseline` (a factor with
#'   the levels `field_year`, `field_year_pm1`, `year` and `none`; the level
#'   the baseline comes from). An empty corpus gives a 0-row tibble with the
#'   same columns.
#'
#' @details
#' FNCI is defined as:
#'
#' \deqn{FNCI_i = \frac{C_i}{\bar{C}_{f,y}}}{FNCI_i = C_i / mean(C_f,y)}
#'
#' Where \eqn{C_i} is the citation count of work *i* and
#' \eqn{\bar{C}_{f,y}} is the mean citation count of all works in field *f*
#' published in year *y*.
#'
#' An FNCI of 1.0 means the work is cited at the corpus average of its
#' baseline cell (by default its field and year). Values > 1.0 indicate
#' above-average impact.
#'
#' For `"openalex_concepts"`, the highest-scoring level-0 concept from the
#' concepts table is used. For `"mesh"`, MeSH headings are used (requires
#' MeSH data in concepts; see below). For `"manual"`, a `field` column must
#' already exist in `corpus$works`.
#'
#' @section Small cells:
#' A cell with few works gives an unstable baseline, and a work alone in its
#' cell gets FNCI = 1 by construction. When `min_cell` is `NULL` and more
#' than 25% of the works with a citation count sit in cells with fewer than
#' 10 such works, a message (class `scimapR_fnci_small_cells`) gives that
#' share. [sm_its()] (`outcome = "cnci"`) and [sm_metric_summary()]
#' (`metric = "cnci"`) show it too when they derive impact from citation
#' counts.
#'
#' @section Fallback baselines:
#' With `min_cell` set, each work gets the most specific baseline that has at
#' least `min_cell` works with a known citation count, the work itself
#' included:
#'
#' 1. `field_year`: its field and publication year;
#' 2. `field_year_pm1`: its field in the pooled years y - 1 to y + 1
#'    (truncated at the edges of the corpus);
#' 3. `year`: all works of its publication year.
#'
#' If even the year has fewer than `min_cell` such works, `fnci` and
#' `field_mean` are `NA`, `baseline` is `"none"` and `n_cell` gives the size
#' of the year cell. Works without a field (`"unclassified"`) start at the
#' `year` level, and works without a year get `NA` throughout.
#'
#' In this mode `field` may list several categories separated by `;`, as
#' the Web of Science WC field does. A work belongs to the cell of each of its
#' categories. For each category the most specific level that reaches
#' `min_cell` is found, and the work's baseline is the average of the
#' category baselines at the most specific level any of them reached:
#' `baseline` names that level and `n_cell` is the smallest of the averaged
#' cells. The baselines are averaged (\eqn{C_i / mean(e_k)}), not the ratios
#' (\eqn{mean(C_i / e_k)}). `field` keeps the original string. Without
#' `min_cell` the string is one field, as before.
#'
#' @section Document types:
#' With `by_type = TRUE`, `works$type` is normalised: lower-cased, its first
#' `;`-separated part, trimmed. `"article"` covers article, journal-article,
#' jour and research-article; `"review"` covers review and review article.
#' Works of any other or a missing type get `fnci = NA` (and `baseline = NA`),
#' with one message (class `scimapR_fnci_other_types`). The type stays part
#' of the cell at every fallback level. The PubMed and Semantic Scholar
#' fetchers record every work as `"journal-article"`, so their reviews count
#' as articles.
#'
#' @section MeSH fields:
#' MeSH check tags (Humans, Animals, Male, Female, Pregnancy, the age groups,
#' common laboratory and farm animals, and the historical periods) describe
#' who or what was studied, and common descriptors of study design,
#' statistics and laboratory material (such as Retrospective Studies, Risk
#' Factors, Treatment Outcome or Cells, Cultured) describe how it was
#' studied. Neither is ever used as a field.
#'
#' [sm_fetch_pubmed()], [sm_read_pubmed_xml()] and [sm_enrich_concepts()]
#' (`source = "mesh"`) record each heading's major-topic flag as its score:
#' 1 for a major topic of the article (starred in PubMed) and 0 otherwise.
#' A work gets its highest-scoring heading; among several, the one that
#' most works of the corpus carry (ties in alphabetical order). A work whose
#' headings carry no scores, as with MeSH terms from other sources, gets its
#' heading that is most frequent in the corpus, with one message (class
#' `scimapR_fnci_mesh_unscored`). A work with no other headings is
#' unclassified.
#'
#' @references
#' Waltman, L., van Eck, N. J., van Leeuwen, T. N., Visser, M. S., &
#' van Raan, A. F. J. (2011). Towards a New Crown Indicator: Some Theoretical
#' Considerations. *Journal of Informetrics*, 5(1), 37--47.
#' \doi{10.1016/j.joi.2010.08.001}
#'
#' @family metrics
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' fnci <- sm_metric_fnci(corpus, classification = "openalex_concepts")
#' head(fnci)
#'
#' # Fall back to larger baselines for cells with fewer than 5 works, with
#' # articles and reviews normalised separately
#' fnci <- sm_metric_fnci(corpus, min_cell = 5, by_type = TRUE)
#' table(fnci$baseline, useNA = "ifany")
sm_metric_fnci <- function(corpus,
                           classification = c("openalex_concepts", "mesh",
                                              "manual"),
                           min_cell = NULL,
                           by_type = FALSE,
                           call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  classification <- rlang::arg_match(classification, error_call = call)
  bad_min_cell <- !is.null(min_cell) &&
    !(rlang::is_integerish(min_cell, n = 1, finite = TRUE) && min_cell >= 1)
  if (bad_min_cell) {
    cli::cli_abort(
      "{.arg min_cell} must be {.code NULL} or a positive integer.",
      call = call
    )
  }
  if (!rlang::is_bool(by_type)) {
    cli::cli_abort("{.arg by_type} must be {.code TRUE} or {.code FALSE}.",
                   call = call)
  }
  if (!is.null(min_cell)) min_cell <- as.integer(min_cell)

  works <- corpus$works
  template <- .fnci_template(min_cell, by_type)

  if (nrow(works) == 0L) {
    return(template)
  }

  # --- assign field ---
  field_map <- .assign_field(corpus, classification, call)

  # One row per work: year, citations, field ("unclassified" when it has
  # none) and, with by_type, the normalised document type
  work_data <- works[c("work_id", "year", "cited_by_count",
                       intersect("type", names(works)))]
  field <- field_map$field[match(work_data$work_id, field_map$work_id)]
  work_data$field <- ifelse(is.na(field), "unclassified", as.character(field))

  if (by_type) {
    raw_type <- if ("type" %in% names(work_data)) {
      work_data$type
    } else {
      rep(NA_character_, nrow(work_data))
    }
    work_data$doc_type <- .normalise_doc_type(raw_type)
    .inform_other_types(raw_type, work_data$doc_type)
  }

  result <- if (is.null(min_cell)) {
    .fnci_field_year(work_data, by_type)
  } else {
    .fnci_fallback(work_data, min_cell, by_type)
  }
  result[names(template)]
}


#' Baseline levels of the min_cell fallback, most specific first
#' @noRd
.fnci_baseline_levels <- c("field_year", "field_year_pm1", "year", "none")

#' Typed 0-row result whose columns depend on min_cell and by_type
#' @noRd
.fnci_template <- function(min_cell, by_type) {
  out <- tibble::tibble(
    work_id = character(), field = character(), year = integer(),
    cited_by_count = integer(), field_mean = double(), fnci = double()
  )
  if (by_type) out$doc_type <- character()
  if (!is.null(min_cell)) {
    out$n_cell <- integer()
    out$baseline <- factor(character(), levels = .fnci_baseline_levels)
  }
  out
}

#' FNCI against field x year (x type) cells, the default
#'
#' Works without a year share one cell per field, as before.
#' @noRd
.fnci_field_year <- function(work_data, by_type) {
  stratum <- if (by_type) work_data$doc_type else ""
  cell <- paste(work_data$field, work_data$year, stratum, sep = "\r")
  cites <- work_data$cited_by_count
  cell_mean <- tapply(cites, cell, mean, na.rm = TRUE)
  cell_n <- tapply(!is.na(cites), cell, sum)

  result <- work_data
  result$field_mean <- as.vector(cell_mean[cell])
  result$n_cell <- as.integer(cell_n[cell])
  if (by_type) result$field_mean[is.na(result$doc_type)] <- NA_real_
  result$fnci <- ifelse(
    is.na(result$field_mean) | result$field_mean == 0,
    NA_real_,
    round(cites / result$field_mean, 4)
  )
  .inform_small_cells(result, by_type)
  result
}

#' FNCI with the min_cell fallback hierarchy and ';'-separated categories
#'
#' Counts (`n`, works with a known citation count) and citation sums (`s`)
#' are computed once per cell and looked up for one row per work and
#' category; the field x year +/- 1 cells add up the shifted years.
#' @noRd
.fnci_fallback <- function(work_data, min_cell, by_type) {
  n_works <- nrow(work_data)
  cites <- as.numeric(work_data$cited_by_count)
  counts <- cbind(n = !is.na(cites), s = ifelse(is.na(cites), 0, cites))
  year <- work_data$year
  stratum <- if (by_type) work_data$doc_type else rep("all", n_works)
  usable <- !is.na(year) & !is.na(stratum)

  # one row per work and category; "unclassified" starts at the year level
  categories <- lapply(strsplit(work_data$field, ";", fixed = TRUE),
                       function(x) {
                         x <- unique(trimws(x))
                         x[nzchar(x) & x != "unclassified"]
                       })
  categories[lengths(categories) == 0L] <- list(NA_character_)
  row <- rep(seq_len(n_works), lengths(categories))
  category <- unlist(categories, use.names = FALSE)
  row_usable <- usable[row]
  row <- row[row_usable]
  category <- category[row_usable]
  classified <- !is.na(category)

  look_up <- function(table, key) {
    hit <- table[match(key, rownames(table)), , drop = FALSE]
    hit[is.na(hit)] <- 0
    hit
  }
  cell_key <- function(shift) {
    paste(category, year[row] + shift, stratum[row], sep = "\r")
  }
  field_year <- rowsum(counts[row[classified], , drop = FALSE],
                       cell_key(0L)[classified])
  levels_n <- list(
    look_up(field_year, cell_key(0L)),
    look_up(field_year, cell_key(-1L)) + look_up(field_year, cell_key(0L)) +
      look_up(field_year, cell_key(1L)),
    look_up(
      rowsum(counts[usable, , drop = FALSE],
             paste(year, stratum, sep = "\r")[usable]),
      paste(year[row], stratum[row], sep = "\r")
    )
  )

  # the most specific level with at least min_cell works; 4 = "none"
  level <- rep(4L, length(row))
  level[levels_n[[3]][, "n"] >= min_cell] <- 3L
  level[classified & levels_n[[2]][, "n"] >= min_cell] <- 2L
  level[classified & levels_n[[1]][, "n"] >= min_cell] <- 1L
  size <- levels_n[[3]][, "n"]
  total <- rep(NA_real_, length(row))
  for (k in 1:3) {
    size[level == k] <- levels_n[[k]][level == k, "n"]
    total[level == k] <- levels_n[[k]][level == k, "s"]
  }

  # per work: the most specific level any category reached, and the average
  # of the category baselines at that level
  best <- tapply(level, row, min)
  at_best <- level == best[as.character(row)]
  best_mean <- tapply((total / size)[at_best], row[at_best], mean)
  best_size <- tapply(size[at_best], row[at_best], min)
  rows <- as.integer(names(best))

  result <- work_data
  result$field_mean <- NA_real_
  result$field_mean[rows] <- as.vector(best_mean[names(best)])
  result$n_cell <- NA_integer_
  result$n_cell[rows] <- as.integer(best_size[names(best)])
  baseline <- rep(NA_integer_, n_works)
  baseline[rows] <- as.integer(best)
  result$baseline <- factor(.fnci_baseline_levels[baseline],
                            levels = .fnci_baseline_levels)
  result$fnci <- ifelse(
    is.na(result$field_mean) | result$field_mean == 0,
    NA_real_,
    round(cites / result$field_mean, 4)
  )
  result
}

#' One message when many works sit in cells with fewer than 10 works
#' @noRd
.inform_small_cells <- function(result, by_type) {
  counted <- !is.na(result$cited_by_count)
  if (by_type) counted <- counted & !is.na(result$doc_type)
  share <- if (any(counted)) mean(result$n_cell[counted] < 10L) else 0
  if (share > 0.25) {
    cli::cli_inform(
      c(
        "i" = paste0(
          round(100 * share), "% of the works sit in ",
          if (by_type) "field-year-type" else "field-year",
          " cells with fewer than 10 works, so their FNCI baselines rest on",
          " very few citation counts."
        ),
        "i" = "Set {.arg min_cell} of {.fn sm_metric_fnci} to fall back to
               larger baselines for small cells."
      ),
      class = "scimapR_fnci_small_cells"
    )
  }
  invisible(NULL)
}

#' Run `expr` and let only the first small-cell message through
#'
#' For callers that derive the same FNCI more than once, such as sm_did()
#' (one series per group).
#' @noRd
.fnci_inform_once <- function(expr) {
  seen <- FALSE
  withCallingHandlers(
    expr,
    scimapR_fnci_small_cells = function(cnd) {
      if (seen) rlang::cnd_muffle(cnd)
      seen <<- TRUE
    }
  )
}

#' Normalise reader document types to "article", "review" or NA
#'
#' Lower-cased, first ';'-separated part, trimmed: WoS "Article; Proceedings
#' Paper" is an article and "Review; Early Access" a review.
#' @noRd
.normalise_doc_type <- function(x) {
  first <- vapply(strsplit(as.character(x), ";", fixed = TRUE), function(s) {
    if (length(s) == 0L) NA_character_ else s[[1]]
  }, character(1))
  first <- tolower(trimws(first))
  out <- rep(NA_character_, length(first))
  out[first %in% c("article", "journal-article", "jour",
                   "research-article")] <- "article"
  out[first %in% c("review", "review article")] <- "review"
  out
}

#' One message for works whose type is neither article nor review
#' @noRd
.inform_other_types <- function(raw_type, doc_type) {
  other <- is.na(doc_type)
  if (!any(other)) return(invisible(NULL))
  types <- unique(as.character(raw_type[other]))
  types[is.na(types) | !nzchar(trimws(types))] <- "(missing)"
  types <- sort(unique(types), method = "radix")
  cli::cli_inform(
    c(
      "i" = "{sum(other)} work{?s} of a type other than article or review
             get{?s/} no FNCI with {.code by_type = TRUE}.",
      "i" = "Type{?s}: {.val {types}}."
    ),
    class = "scimapR_fnci_other_types"
  )
  invisible(NULL)
}


#' Assign works to fields based on classification system
#' @noRd
.assign_field <- function(corpus, classification, call) {
  concepts <- corpus$concepts
  works <- corpus$works

  switch(classification,
    openalex_concepts = {
      if (nrow(concepts) == 0L) {
        return(tibble::tibble(work_id = works$work_id,
                              field = rep(NA_character_, nrow(works))))
      }
      # Use highest-scoring level-0 concept
      concepts %>%
        dplyr::filter(.data$level == 0L) %>%
        dplyr::group_by(.data$work_id) %>%
        dplyr::slice_max(order_by = .data$score, n = 1L,
                         with_ties = FALSE) %>%
        dplyr::ungroup() %>%
        dplyr::select("work_id", field = "concept_name")
    },
    mesh = {
      if (nrow(concepts) == 0L) {
        return(tibble::tibble(work_id = works$work_id,
                              field = rep(NA_character_, nrow(works))))
      }
      # Use MeSH vocabulary concepts
      mesh_concepts <- concepts %>%
        dplyr::filter(tolower(.data$vocabulary) %in% c("mesh", "medline"))
      if (nrow(mesh_concepts) == 0L) {
        cli::cli_inform(c(
          "!" = "No MeSH terms found in concepts table.",
          "i" = "Falling back to {.val unclassified} for all works."
        ))
        return(tibble::tibble(work_id = works$work_id,
                              field = rep(NA_character_, nrow(works))))
      }
      .mesh_field(mesh_concepts)
    },
    manual = {
      if ("field" %in% names(works)) {
        works %>% dplyr::select("work_id", "field")
      } else {
        cli::cli_abort(
          c("Column {.field field} not found in works table.",
            "i" = "For {.val manual} classification, add a {.field field} column to {.code corpus$works}."),
          call = call
        )
      }
    }
  )
}

#' MeSH check tags: population descriptors indexed on (nearly) every record
#' @noRd
.mesh_check_tags <- c(
  "humans", "animals", "male", "female", "pregnancy",
  "infant, newborn", "infant", "child, preschool", "child", "adolescent",
  "young adult", "adult", "middle aged", "aged", "aged, 80 and over",
  "cats", "cattle", "chick embryo", "cricetinae", "dogs", "guinea pigs",
  "horses", "mice", "rabbits", "rats", "sheep", "swine"
)

#' MeSH descriptors of how a study was done, not of its field
#'
#' Study designs, epidemiological and statistical methods and laboratory
#' material. They are indexed on a large share of MEDLINE records, so a
#' choice by corpus frequency would otherwise pick them.
#' @noRd
.mesh_method_descriptors <- c(
  "retrospective studies", "prospective studies", "cohort studies",
  "longitudinal studies", "follow-up studies", "cross-sectional studies",
  "case-control studies", "pilot projects", "feasibility studies",
  "double-blind method", "single-blind method", "random allocation",
  "surveys and questionnaires", "questionnaires", "treatment outcome",
  "prognosis", "risk factors", "risk assessment", "time factors",
  "age factors", "sex factors", "socioeconomic factors", "incidence",
  "prevalence", "odds ratio", "logistic models", "multivariate analysis",
  "regression analysis", "proportional hazards models",
  "kaplan-meier estimate", "survival analysis", "survival rate",
  "reproducibility of results", "sensitivity and specificity",
  "predictive value of tests", "roc curve", "severity of illness index",
  "dose-response relationship, drug", "kinetics", "molecular sequence data",
  "base sequence", "amino acid sequence", "cells, cultured", "cell line",
  "cell line, tumor", "disease models, animal"
)

#' One MeSH field per work, never a check tag or a method descriptor
#'
#' A work with scores (the PubMed readers record the major-topic flag, 1 or
#' 0) keeps its scored headings, one without keeps all. Of these the work
#' gets the highest-scoring one; ties, and every heading of an unscored
#' work, go to the heading that more works of the corpus carry, then to
#' alphabetical order. Unscored works get one message.
#' @noRd
.mesh_field <- function(mesh) {
  name <- trimws(as.character(mesh$concept_name))
  lower <- tolower(name)
  keep <- !is.na(name) & nzchar(name) &
    !lower %in% c(.mesh_check_tags, .mesh_method_descriptors) &
    !startsWith(lower, "history, ")
  heading <- data.frame(
    work_id = as.character(mesh$work_id[keep]), name = name[keep],
    score = as.numeric(mesh$score[keep]), stringsAsFactors = FALSE
  )
  # how many works carry each heading: the tie-break, and the choice for
  # works without scores
  pairs <- unique(heading[c("work_id", "name")])
  heading$n_works <- as.integer(table(pairs$name)[heading$name])

  # a work with scores keeps only its scored headings; then per work the
  # highest score, the most works, the first in alphabetical order
  has_score <- !is.na(heading$score)
  heading <- heading[has_score | !heading$work_id %in%
                       heading$work_id[has_score], ]
  rank <- ifelse(is.na(heading$score), -Inf, heading$score)
  heading <- heading[order(heading$work_id, -rank, -heading$n_works,
                           heading$name, method = "radix"), ]
  picked <- heading[!duplicated(heading$work_id), ]

  n_unscored <- sum(is.na(picked$score))
  if (n_unscored > 0L) {
    cli::cli_inform(
      c(
        "i" = "MeSH headings carry no scores (major-topic flags) for
               {n_unscored} work{?s}; each gets its heading that is most
               frequent in the corpus as field.",
        "i" = "Check tags such as {.val Humans} and study-design
               descriptors such as {.val Retrospective Studies} are never
               used. For a controlled field, add {.field field} to the works
               and use {.code classification = \"manual\"}."
      ),
      class = "scimapR_fnci_mesh_unscored"
    )
  }
  tibble::tibble(work_id = picked$work_id, field = picked$name)
}
