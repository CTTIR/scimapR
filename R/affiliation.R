#' Match author affiliations to institutions
#'
#' @description
#' A tested, extensible institution matcher for the `authorships` table. It
#' tags each authorship with the institution it belongs to, using a dictionary
#' of name variants (multilingual and synonym-aware) and an optional
#' email-domain fallback for records whose affiliation string is missing.
#'
#' Because the matcher operates per authorship row, it naturally handles
#' secondary / multiple affiliations per author (each authorship row is matched
#' independently).
#'
#' @param corpus An `sm_corpus` object.
#' @param patterns A dictionary of institution name variants. Either:
#'   \itemize{
#'     \item a named list mapping each canonical institution name to a
#'       character vector of case-insensitive regex variant patterns, or
#'     \item a data frame with columns `institution`, `pattern`, and an
#'       optional `email_domain` (the form of the bundled
#'       [sm_affiliation_dict]).
#'   }
#'   Defaults to [sm_affiliation_dict].
#' @param fields Character vector of `authorships` columns to search for
#'   affiliation text. Defaults to `"raw_affiliation"` (plus `"email"` if such
#'   a column exists). Values across multiple fields are concatenated per row.
#' @param email_domain_fallback Logical; if `TRUE` (default) and an authorship
#'   has no pattern match but does have an email address (in an `email` column),
#'   match the email's domain against the dictionary's `email_domain` entries.
#' @param postcode_signal Logical (default `FALSE`). When `TRUE` and the
#'   dictionary carries a `postcode` column, a postcode match is attempted as a
#'   last resort (lowest priority, after name tokens and email domains) so
#'   existing matches do not shift. Off by default.
#' @param call Caller environment for error reporting.
#'
#' @return The `corpus` with its `authorships` table gaining (or having
#'   updated) four columns:
#'   \describe{
#'     \item{institution_match}{Canonical institution name, or `NA`.}
#'     \item{match_method}{`"pattern"`, `"email_domain"`, `"postcode"`, or
#'       `"none"`.}
#'     \item{match_signal}{The signal that fired: `"name_token"`,
#'       `"email_domain"`, `"postcode"`, or `"none"`. Precedence (highest
#'       first): name token, email domain, postcode.}
#'     \item{match_evidence}{The actual substring / domain / postcode that
#'       triggered the match (an audit trail), or `NA`.}
#'   }
#'   Type-stable: a corpus with no authorships is returned unchanged with the
#'   four columns present and 0 rows. See [sm_affiliation_summary()] for a tidy
#'   breakdown.
#'
#' @details
#' To extend the dictionary, append rows to [sm_affiliation_dict] (or build your
#' own data frame with the same columns) and pass it as `patterns`. For example
#' `rbind(sm_affiliation_dict, tibble::tibble(institution = "My Uni",
#' pattern = "my university", email_domain = "myuni.edu"))`.
#'
#' @family affiliation
#' @seealso [sm_attribute_institution()], [sm_affiliation_dict]
#' @export
#' @examples
#' corpus <- sm_example_corpus(n_works = 5, n_authors = 5)
#' corpus$authorships$raw_affiliation[1] <- "Bundeswehrkrankenhaus Berlin"
#' matched <- sm_affiliation_match(corpus)
#' matched$authorships$institution_match[1]
sm_affiliation_match <- function(corpus,
                                 patterns = sm_affiliation_dict,
                                 fields = NULL,
                                 email_domain_fallback = TRUE,
                                 postcode_signal = FALSE,
                                 call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_flag(email_domain_fallback, call = call)
  .check_flag(postcode_signal, call = call)

  dict <- .normalize_aff_patterns(patterns, call = call)
  a <- corpus$authorships

  if (nrow(a) == 0L) {
    a$institution_match <- character()
    a$match_method <- character()
    a$match_signal <- character()
    a$match_evidence <- character()
    corpus$authorships <- a
    return(corpus)
  }

  fields <- fields %||% intersect(c("raw_affiliation", "email"), names(a))
  fields <- intersect(fields, names(a))
  text_fields <- setdiff(fields, "email")

  aff_text <- if (length(text_fields) > 0L) {
    do.call(paste, c(lapply(text_fields, function(f) {
      ifelse(is.na(a[[f]]), "", as.character(a[[f]]))
    }), sep = " "))
  } else {
    rep("", nrow(a))
  }
  aff_text <- trimws(aff_text)

  n <- nrow(a)
  institution_match <- rep(NA_character_, n)
  match_method <- rep("none", n)
  match_signal <- rep("none", n)
  match_evidence <- rep(NA_character_, n)

  # ---- 1. name-token (pattern) matching, capturing the matched substring ----
  has_text <- nzchar(aff_text)
  pat_rows <- which(!is.na(dict$pattern) & nzchar(dict$pattern))
  for (pr in pat_rows) {
    todo <- which(has_text & is.na(institution_match))
    if (length(todo) == 0L) break
    m <- regexpr(dict$pattern[pr], aff_text[todo], ignore.case = TRUE,
                 perl = TRUE)
    hit <- m != -1L
    if (any(hit)) {
      idx <- todo[hit]
      institution_match[idx] <- dict$institution[pr]
      match_method[idx] <- "pattern"
      match_signal[idx] <- "name_token"
      match_evidence[idx] <- regmatches(aff_text[todo], m)
    }
  }

  # ---- 2. email-domain fallback ----
  if (email_domain_fallback && "email" %in% names(a)) {
    dom_rows <- which(!is.na(dict$email_domain) & nzchar(dict$email_domain))
    if (length(dom_rows) > 0L) {
      emails <- as.character(a$email)
      domains <- tolower(sub("^[^@]*@", "", emails))
      domains[is.na(emails) | !grepl("@", emails)] <- NA_character_
      todo <- which(is.na(institution_match) & !is.na(domains))
      for (i in todo) {
        d <- domains[i]
        hit <- which(endsWith(d, tolower(dict$email_domain[dom_rows])))
        if (length(hit) > 0L) {
          institution_match[i] <- dict$institution[dom_rows[hit[1]]]
          match_method[i] <- "email_domain"
          match_signal[i] <- "email_domain"
          match_evidence[i] <- dict$email_domain[dom_rows[hit[1]]]
        }
      }
    }
  }

  # ---- 3. postcode signal (opt-in, lowest priority) ----
  if (postcode_signal && "postcode" %in% names(dict)) {
    pc_rows <- which(!is.na(dict$postcode) & nzchar(dict$postcode))
    for (pr in pc_rows) {
      todo <- which(has_text & is.na(institution_match))
      if (length(todo) == 0L) break
      pat <- paste0("\\b", gsub("\\s+", "\\\\s*", dict$postcode[pr]), "\\b")
      m <- regexpr(pat, aff_text[todo], perl = TRUE)
      hit <- m != -1L
      if (any(hit)) {
        idx <- todo[hit]
        institution_match[idx] <- dict$institution[pr]
        match_method[idx] <- "postcode"
        match_signal[idx] <- "postcode"
        match_evidence[idx] <- regmatches(aff_text[todo], m)
      }
    }
  }

  a$institution_match <- institution_match
  a$match_method <- match_method
  a$match_signal <- match_signal
  a$match_evidence <- match_evidence
  corpus$authorships <- a

  # ---- surface a concise match summary ----
  n_flagged <- sum(!is.na(institution_match))
  if (n_flagged > 0L) {
    by_sig <- table(match_signal[match_signal != "none"])
    sig_txt <- paste(sprintf("%s: %d", names(by_sig), as.integer(by_sig)),
                     collapse = ", ")
    cli::cli_inform(c(
      "v" = "Affiliation matching flagged {n_flagged} authorship{?s} across {dplyr::n_distinct(institution_match[!is.na(institution_match)])} institution{?s}.",
      "i" = "By signal: {sig_txt}. See {.fn sm_affiliation_summary} for the full breakdown."
    ))
  }

  corpus
}

#' Summarise affiliation matches
#'
#' @description
#' Tidy summary of the matches produced by [sm_affiliation_match()], mirroring
#' the audit-style summaries elsewhere in the package: counts of works and
#' authorships flagged, broken down by institution and by `match_signal`.
#'
#' @param corpus An `sm_corpus` previously passed through
#'   [sm_affiliation_match()] (so its `authorships` carry `institution_match`
#'   and `match_signal`).
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with columns `institution`, `match_signal`, `n_authorships`,
#'   `n_works`, sorted by `n_authorships` descending. Type-stable: a 0-row
#'   tibble (with a warning) when no matches are present.
#'
#' @family affiliation
#' @seealso [sm_affiliation_match()]
#' @export
#' @examples
#' corpus <- sm_example_corpus(n_works = 5, n_authors = 5)
#' corpus$authorships$raw_affiliation[1] <- "Bundeswehrkrankenhaus Berlin"
#' corpus <- sm_affiliation_match(corpus)
#' sm_affiliation_summary(corpus)
sm_affiliation_summary <- function(corpus, call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  a <- corpus$authorships
  empty <- tibble::tibble(
    institution = character(), match_signal = character(),
    n_authorships = integer(), n_works = integer()
  )
  if (!"institution_match" %in% names(a)) {
    cli::cli_warn(c(
      "!" = "No affiliation matches found on this corpus.",
      "i" = "Run {.fn sm_affiliation_match} first."
    ))
    return(empty)
  }
  flagged <- dplyr::filter(a, !is.na(.data$institution_match))
  if (nrow(flagged) == 0L) return(empty)

  sig <- if ("match_signal" %in% names(flagged)) flagged$match_signal else
    rep(NA_character_, nrow(flagged))

  flagged %>%
    dplyr::mutate(.sig = sig) %>%
    dplyr::group_by(institution = .data$institution_match,
                    match_signal = .data$.sig) %>%
    dplyr::summarise(
      n_authorships = dplyr::n(),
      n_works = dplyr::n_distinct(.data$work_id),
      .groups = "drop"
    ) %>%
    dplyr::arrange(dplyr::desc(.data$n_authorships))
}

#' Normalise an affiliation pattern dictionary to a standard tibble
#' @noRd
.normalize_aff_patterns <- function(patterns, call = rlang::caller_env()) {
  if (is.data.frame(patterns)) {
    if (!"institution" %in% names(patterns) ||
        !"pattern" %in% names(patterns)) {
      cli::cli_abort(c(
        "A data-frame {.arg patterns} must have {.field institution} and {.field pattern} columns.",
        "i" = "An optional {.field email_domain} column is also supported."
      ), call = call)
    }
    return(tibble::tibble(
      institution = as.character(patterns$institution),
      pattern = as.character(patterns$pattern),
      email_domain = if ("email_domain" %in% names(patterns)) {
        as.character(patterns$email_domain)
      } else {
        NA_character_
      },
      postcode = if ("postcode" %in% names(patterns)) {
        as.character(patterns$postcode)
      } else {
        NA_character_
      }
    ))
  }

  if (is.list(patterns) && !is.null(names(patterns))) {
    inst <- rep(names(patterns), lengths(patterns))
    pat <- unlist(patterns, use.names = FALSE)
    return(tibble::tibble(
      institution = inst,
      pattern = as.character(pat),
      email_domain = NA_character_,
      postcode = NA_character_
    ))
  }

  cli::cli_abort(
    "{.arg patterns} must be a named list or a data frame.",
    call = call
  )
}


#' Attribute matched affiliations to a controlled institution vocabulary
#'
#' @description
#' Rolls institution matches (from [sm_affiliation_match()]) up to a controlled
#' vocabulary, writing a normalised `institution_id` and `institution_name`
#' onto the `authorships` table. Supports a ROR-backed vocabulary (via a
#' user-supplied offline ROR table) or a `"custom"` vocabulary derived directly
#' from the matched institution names.
#'
#' @param corpus An `sm_corpus`. If it has no `institution_match` column,
#'   [sm_affiliation_match()] is run first with default settings.
#' @param vocabulary `"ror"` (default) or `"custom"`.
#' @param ror_table For `vocabulary = "ror"`, a data frame with columns
#'   `ror_id`, `name`, and `aliases` (aliases either a `;`-separated string or
#'   a list-column). Matching is case-insensitive against `name` and each alias,
#'   as well as against the `institution_match` value. A synthetic example
#'   ships at `system.file("extdata", "example_ror.csv", package = "scimapR")`.
#' @param call Caller environment for error reporting.
#'
#' @return The `corpus` with its `authorships` table gaining `institution_id`
#'   and `institution_name` columns (for `"ror"`, `institution_id` holds the
#'   ROR id). Unmatched rows keep `NA` -- the function never errors on
#'   unmatched affiliations. Type-stable.
#'
#' @family affiliation
#' @seealso [sm_affiliation_match()]
#' @export
#' @examples
#' ror <- utils::read.csv(
#'   system.file("extdata", "example_ror.csv", package = "scimapR"),
#'   stringsAsFactors = FALSE
#' )
#' corpus <- sm_example_corpus(n_works = 5, n_authors = 5)
#' corpus$authorships$raw_affiliation[1] <- "Charite Universitatsmedizin Berlin"
#' corpus <- sm_affiliation_match(corpus)
#' corpus <- sm_attribute_institution(corpus, vocabulary = "ror",
#'                                    ror_table = ror)
#' corpus$authorships$institution_name[1]
sm_attribute_institution <- function(corpus,
                                     vocabulary = c("ror", "custom"),
                                     ror_table = NULL,
                                     call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  vocabulary <- rlang::arg_match(vocabulary, error_call = call)

  if (!"institution_match" %in% names(corpus$authorships)) {
    corpus <- sm_affiliation_match(corpus, call = call)
  }

  a <- corpus$authorships
  if (nrow(a) == 0L) {
    a$institution_id <- character()
    a$institution_name <- character()
    corpus$authorships <- a
    return(corpus)
  }

  # text used for attribution: prefer the canonical match, fall back to raw
  base_text <- ifelse(
    !is.na(a$institution_match), a$institution_match,
    if ("raw_affiliation" %in% names(a)) as.character(a$raw_affiliation) else NA_character_
  )

  if (vocabulary == "custom") {
    inst_name <- a$institution_match
    inst_id <- ifelse(
      is.na(inst_name), NA_character_,
      paste0("CUST:", gsub("[^a-z0-9]+", "-", tolower(inst_name), perl = TRUE))
    )
    a$institution_id <- inst_id
    a$institution_name <- inst_name
    corpus$authorships <- a
    return(corpus)
  }

  # ---- ROR vocabulary ----
  if (is.null(ror_table)) {
    cli::cli_abort(c(
      "{.arg ror_table} is required for {.val ror} vocabulary.",
      "i" = "Supply an offline ROR table with columns {.field ror_id}, {.field name}, {.field aliases}.",
      "i" = "A synthetic example is at {.code system.file(\"extdata\", \"example_ror.csv\", package = \"scimapR\")}."
    ), call = call)
  }
  lookup <- .build_ror_lookup(ror_table, call = call)

  key <- .norm_title(base_text)
  hit <- match(key, lookup$key)
  a$institution_id <- ifelse(is.na(hit), NA_character_, lookup$ror_id[hit])
  a$institution_name <- ifelse(is.na(hit), NA_character_, lookup$name[hit])

  corpus$authorships <- a
  corpus
}

#' Build a normalised name/alias -> (ror_id, name) lookup
#' @noRd
.build_ror_lookup <- function(ror_table, call = rlang::caller_env()) {
  if (!is.data.frame(ror_table) ||
      !all(c("ror_id", "name") %in% names(ror_table))) {
    cli::cli_abort(
      "{.arg ror_table} must be a data frame with at least {.field ror_id} and {.field name} columns.",
      call = call
    )
  }

  key_acc <- character()
  id_acc <- character()
  name_acc <- character()

  add <- function(values, id, name) {
    k <- .norm_title(values)
    keep <- !is.na(k)
    key_acc <<- c(key_acc, k[keep])
    id_acc <<- c(id_acc, rep(id, sum(keep)))
    name_acc <<- c(name_acc, rep(name, sum(keep)))
  }

  has_aliases <- "aliases" %in% names(ror_table)
  for (i in seq_len(nrow(ror_table))) {
    rid <- as.character(ror_table$ror_id[i])
    nm <- as.character(ror_table$name[i])
    add(nm, rid, nm)
    if (has_aliases) {
      al <- ror_table$aliases[[i]]
      if (is.character(al) && length(al) == 1L && !is.na(al)) {
        al <- trimws(strsplit(al, ";")[[1]])
      }
      al <- al[!is.na(al) & nzchar(al)]
      if (length(al) > 0L) add(al, rid, nm)
    }
  }

  keep <- !duplicated(key_acc)
  list(key = key_acc[keep], ror_id = id_acc[keep], name = name_acc[keep])
}
