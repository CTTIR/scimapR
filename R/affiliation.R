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
#' @param call Caller environment for error reporting.
#'
#' @return The `corpus` with its `authorships` table gaining (or having
#'   updated) two columns:
#'   \describe{
#'     \item{institution_match}{Canonical institution name, or `NA`.}
#'     \item{match_method}{`"pattern"`, `"email_domain"`, or `"none"`.}
#'   }
#'   Type-stable: a corpus with no authorships is returned unchanged with the
#'   two columns present and 0 rows.
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
                                 call = rlang::caller_env()) {
  .check_sm_corpus(corpus, call = call)
  .check_flag(email_domain_fallback, call = call)

  dict <- .normalize_aff_patterns(patterns, call = call)
  a <- corpus$authorships

  if (nrow(a) == 0L) {
    a$institution_match <- character()
    a$match_method <- character()
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

  institution_match <- rep(NA_character_, nrow(a))
  match_method <- rep("none", nrow(a))

  # ---- pattern matching ----
  has_text <- nzchar(aff_text)
  pat_rows <- which(!is.na(dict$pattern) & nzchar(dict$pattern))
  for (pr in pat_rows) {
    todo <- which(has_text & is.na(institution_match))
    if (length(todo) == 0L) break
    hit <- grepl(dict$pattern[pr], aff_text[todo], ignore.case = TRUE,
                 perl = TRUE)
    if (any(hit)) {
      idx <- todo[hit]
      institution_match[idx] <- dict$institution[pr]
      match_method[idx] <- "pattern"
    }
  }

  # ---- email-domain fallback ----
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
        }
      }
    }
  }

  a$institution_match <- institution_match
  a$match_method <- match_method
  corpus$authorships <- a
  corpus
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
      }
    ))
  }

  if (is.list(patterns) && !is.null(names(patterns))) {
    inst <- rep(names(patterns), lengths(patterns))
    pat <- unlist(patterns, use.names = FALSE)
    return(tibble::tibble(
      institution = inst,
      pattern = as.character(pat),
      email_domain = NA_character_
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
