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
#' @param unicode Logical (default `TRUE`). Match the patterns in Unicode
#'   mode, so `\w`, `\b`, `\d`, `\s` and POSIX classes such as `[[:alpha:]]`
#'   know non-ASCII letters, digits and spaces (see Details). `FALSE` gives
#'   the ASCII-only classes of scimapR 0.4.0 and earlier, to reproduce
#'   earlier results.
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
#' Dictionary patterns are case-insensitive Perl-compatible regular
#' expressions (PCRE) with Unicode-aware `\w`, `\b`, `\d` and `\s`, matched
#' against the affiliation text of each authorship. The rows are tried in
#' dictionary order and the first pattern that matches wins, so list specific
#' patterns before generic ones. [sm_affiliation_unmatched()] lists the most
#' frequent affiliation strings that nothing matched.
#'
#' In Unicode mode (`unicode = TRUE`, the default) each pattern is prefixed
#' with the PCRE item `(*UCP)` unless its leading items already include it.
#' Umlauts, accented letters and the sharp s are then word characters: `\w`
#' consumes them, `\b` finds the edge of a word that starts or ends with one,
#' and POSIX classes such as `[[:alpha:]]` are Unicode-aware too. In ASCII
#' mode (`unicode = FALSE`) every non-ASCII letter is a non-word character,
#' like punctuation: a pattern such as `sanit\w+wesens` cannot match the
#' German word spelled with an a-umlaut, and `\b` finds no edge between a
#' space and a word that starts with an umlaut. Unicode mode can therefore
#' also lose matches. A pattern that used `\W`, `\S`, `\D` or `\B` to stand
#' for a non-ASCII letter no longer matches it, and `\b` no longer finds an
#' edge between an ASCII letter and a non-ASCII letter next to it: the
#' shipped pattern `\bnato\b` does not match "NATO" directly followed by an
#' umlaut, as in a German compound word. To keep ASCII semantics in one
#' place, write the class out, for example `[A-Za-z0-9_]` instead of `\w`.
#'
#' `unicode = FALSE` gives the matches of scimapR 0.4.0.
#' [sm_attribute_institution()] calls `sm_affiliation_match()` with its
#' defaults, and so matches in Unicode mode, when the corpus has no
#' `institution_match` column; running `sm_affiliation_match(unicode = FALSE)`
#' first gives its earlier results. `sm_count(level = "institution")` no
#' longer matches affiliations itself: it counts each authorship by its
#' institution label, `institution_match` first, and by its raw affiliation
#' string when it has none (see [sm_count()]).
#'
#' The optional `postcode` column (used with `postcode_signal = TRUE`) is
#' matched case-sensitively as a whole word, in the same mode: it is wrapped
#' in `\b`, any run of whitespace in it matches any amount of whitespace
#' (including none), and it is used as a regular expression without escaping.
#'
#' To extend the dictionary, append rows to [sm_affiliation_dict] (or build your
#' own data frame with the same columns) and pass it as `patterns`. For example
#' `rbind(sm_affiliation_dict, tibble::tibble(institution = "My Uni",
#' pattern = "my university", email_domain = "myuni.edu"))`.
#'
#' @family affiliation
#' @seealso [sm_attribute_institution()], [sm_affiliation_dict],
#'   [sm_affiliation_unmatched()]
#' @export
#' @examples
#' corpus <- sm_example_corpus(n_works = 5, n_authors = 5)
#' corpus$authorships$raw_affiliation[1] <- "Bundeswehrkrankenhaus Berlin"
#' matched <- sm_affiliation_match(corpus)
#' matched$authorships$institution_match[1]
#'
#' # In Unicode mode \w consumes the umlaut of a German unit name
#' corpus$authorships$raw_affiliation[2] <-
#'   "Zentrales Institut des Sanit\u00e4tswesens Nordstadt"
#' dict <- list("Central Medical Institute" = "sanit\\w+wesens")
#' matched <- sm_affiliation_match(corpus, patterns = dict)
#' matched$authorships$institution_match[2]
#' ascii <- sm_affiliation_match(corpus, patterns = dict, unicode = FALSE)
#' ascii$authorships$institution_match[2]
sm_affiliation_match <- function(corpus,
                                 patterns = sm_affiliation_dict,
                                 fields = NULL,
                                 email_domain_fallback = TRUE,
                                 postcode_signal = FALSE,
                                 unicode = TRUE,
                                 call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_corpus_unlocked(corpus, call = call)
  .check_flag(email_domain_fallback, call = call)
  .check_flag(postcode_signal, call = call)
  .check_flag(unicode, call = call)

  dict <- .normalize_aff_patterns(patterns, call = call)
  a <- corpus$authorships

  if (nrow(a) == 0L) {
    a$institution_match <- character()
    a$match_method <- factor(character(), levels = .aff_method_levels())
    a$match_signal <- factor(character(), levels = .aff_signal_levels())
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
  # Unicode mode is added per pattern after the NA/empty filter: a prefixed
  # empty pattern would match every string.
  has_text <- nzchar(aff_text)
  pat_rows <- which(!is.na(dict$pattern) & nzchar(dict$pattern))
  for (pr in pat_rows) {
    todo <- which(has_text & is.na(institution_match))
    if (length(todo) == 0L) break
    m <- regexpr(.ucp_regex(dict$pattern[pr], unicode), aff_text[todo],
                 ignore.case = TRUE, perl = TRUE)
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
      m <- regexpr(.ucp_regex(pat, unicode), aff_text[todo], perl = TRUE)
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
  # B1: emit controlled-vocabulary columns as factors with stable levels
  a$match_method <- factor(match_method, levels = .aff_method_levels())
  a$match_signal <- factor(match_signal, levels = .aff_signal_levels())
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
#' @return A tibble with columns `institution`, `match_signal` (a factor; see
#'   [sm_affiliation_signals()]), `n_authorships`, `n_works`, and
#'   `example_evidence` (a representative matched-evidence string for that
#'   institution x signal --- the audit trail), sorted by `n_authorships`
#'   descending. Type-stable: a 0-row tibble (with a warning) when no matches
#'   are present.
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
    institution = character(),
    match_signal = factor(character(), levels = .aff_signal_levels()),
    n_authorships = integer(), n_works = integer(),
    example_evidence = character()
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
  ev <- if ("match_evidence" %in% names(flagged)) flagged$match_evidence else
    rep(NA_character_, nrow(flagged))

  flagged %>%
    dplyr::mutate(.sig = sig, .ev = ev) %>%
    dplyr::group_by(institution = .data$institution_match,
                    match_signal = .data$.sig) %>%
    dplyr::summarise(
      n_authorships = dplyr::n(),
      n_works = dplyr::n_distinct(.data$work_id),
      # F2: a representative evidence string for this institution x signal
      example_evidence = .data$.ev[!is.na(.data$.ev)][1],
      .groups = "drop"
    ) %>%
    dplyr::arrange(dplyr::desc(.data$n_authorships))
}

#' List affiliation strings that matched no institution
#'
#' @description
#' Audits an affiliation dictionary. After [sm_affiliation_match()], it lists
#' the most frequent `raw_affiliation` strings of the authorships that no
#' signal (name pattern, email domain or postcode) assigned to an
#' institution, so the dictionary can be extended where that matters most.
#'
#' @param corpus An `sm_corpus` previously passed through
#'   [sm_affiliation_match()] (so its `authorships` carry `institution_match`).
#' @param n Maximum number of strings to return: a positive whole number, or
#'   `Inf` for all of them. Default 25.
#' @param call Caller environment for error reporting.
#'
#' @return A tibble with columns `raw_affiliation` (character),
#'   `n_authorships` (integer: unmatched authorships with that string) and
#'   `n_works` (integer: distinct works among them), at most `n` rows,
#'   sorted by `n_authorships` descending and then by `raw_affiliation` in
#'   code-point order. Authorships whose `raw_affiliation` is `NA` or blank
#'   are not listed. Type-stable: a 0-row tibble when every affiliation
#'   matched, and a 0-row tibble with a warning when the corpus has not been
#'   matched.
#'
#' @family affiliation
#' @seealso [sm_affiliation_match()], [sm_affiliation_summary()]
#' @export
#' @examples
#' fix <- readRDS(sm_example_files("example_realuse_corpus.rds"))
#' dict <- readr::read_csv(
#'   sm_example_files("example_realuse_affiliation_dict.csv"),
#'   col_types = "ccc"
#' )
#' matched <- sm_affiliation_match(fix, dict)
#' sm_affiliation_unmatched(matched, n = 5)
sm_affiliation_unmatched <- function(corpus, n = 25L,
                                     call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  if (!rlang::is_integerish(n, n = 1L) || is.na(n) || n < 1) {
    cli::cli_abort(
      "{.arg n} must be a positive whole number or {.code Inf}.",
      call = call
    )
  }
  a <- corpus$authorships
  empty <- tibble::tibble(
    raw_affiliation = character(),
    n_authorships = integer(), n_works = integer()
  )
  if (!"institution_match" %in% names(a)) {
    cli::cli_warn(c(
      "!" = "No affiliation matches found on this corpus.",
      "i" = "Run {.fn sm_affiliation_match} first."
    ), call = call)
    return(empty)
  }
  raw <- if ("raw_affiliation" %in% names(a)) {
    as.character(a$raw_affiliation)
  } else {
    rep(NA_character_, nrow(a))
  }
  keep <- is.na(a$institution_match) & !is.na(raw) & nzchar(trimws(raw))
  if (!any(keep)) return(empty)

  unmatched <- tibble::tibble(raw_affiliation = raw[keep],
                              work_id = as.character(a$work_id[keep]))
  out <- dplyr::summarise(
    dplyr::group_by(unmatched, raw_affiliation = .data$raw_affiliation),
    n_authorships = dplyr::n(),
    n_works = dplyr::n_distinct(.data$work_id),
    .groups = "drop"
  )
  # radix order sorts strings by code point, the same in every locale
  out <- out[order(-out$n_authorships, out$raw_affiliation,
                   method = "radix"), ]
  out[seq_len(min(n, nrow(out))), ]
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
#'   [sm_affiliation_match()] is run first with default settings, that is
#'   with the shipped [sm_affiliation_dict]; to attribute your own
#'   institutions, run it first with a dictionary of them.
#' @param vocabulary `"ror"` (default) or `"custom"`.
#' @param ror_table For `vocabulary = "ror"`, a data frame with columns
#'   `ror_id`, `name`, and `aliases` (aliases either a `;`-separated string or
#'   a list-column). Matching is case-insensitive against `name` and each alias,
#'   as well as against the `institution_match` value. A synthetic example
#'   ships at `system.file("extdata", "example_ror.csv", package = "scimapR")`.
#' @param call Caller environment for error reporting.
#'
#' @return The `corpus` with `institution_id` and `institution_name` set on
#'   the `authorships` rows that match the vocabulary (for `"ror"`,
#'   `institution_id` holds the ROR id; for `"custom"`, `CUST:` and the
#'   matched name). Unmatched rows keep the `institution_id` and
#'   `institution_name` they had, such as the OpenAlex institution ids of
#'   a fetched corpus, or `NA` -- the function never errors on unmatched
#'   affiliations. Type-stable.
#'
#' @details
#' The `institution_match` column stays as it is.
#' `sm_count(level = "institution")` labels each authorship by
#' `institution_match` before `institution_name` and `institution_id`, so
#' the roll-up to the vocabulary reaches the counts only for authorships
#' without a match, and the `"affiliation"` breakdown of
#' [sm_coverage_audit()] uses `institution_name` only when no authorship has
#' a match. Up to scimapR 0.4.0, [sm_count()] counted by `institution_id`
#' whenever any authorship had one. To count or break down by the
#' vocabulary, put its names first, for example:
#'
#' ```
#' a <- corpus$authorships
#' corpus$authorships$institution_match <-
#'   dplyr::coalesce(a$institution_name, a$institution_match)
#' ```
#'
#' The ids written to matched rows are ROR ids or `CUST:` ids, which join
#' `corpus$institutions` only where that table lists them, so functions
#' that read the institutions table for these rows (such as
#' `sm_audit_geographic(by = "region")`) find no entry for them. Unmatched
#' rows keep their earlier ids and so their entries. Up to scimapR 0.4.0,
#' unmatched rows lost their `institution_id`.
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
  .check_corpus_unlocked(corpus, call = call)
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
  # unmatched rows keep the institution they had, such as an OpenAlex id
  previous <- function(col) {
    if (!col %in% names(a)) return(rep(NA_character_, nrow(a)))
    as.character(a[[col]])
  }
  prev_id <- previous("institution_id")
  prev_name <- previous("institution_name")

  if (vocabulary == "custom") {
    inst_name <- a$institution_match
    matched <- !is.na(inst_name)
    a$institution_id <- ifelse(
      matched,
      paste0("CUST:", gsub("[^a-z0-9]+", "-", tolower(inst_name), perl = TRUE)),
      prev_id
    )
    a$institution_name <- ifelse(matched, inst_name, prev_name)
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
  a$institution_id <- ifelse(is.na(hit), prev_id, lookup$ror_id[hit])
  a$institution_name <- ifelse(is.na(hit), prev_name, lookup$name[hit])

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
