#' Generate a synthetic example corpus
#'
#' @description
#' Creates a realistic synthetic corpus for examples, testing, and
#' demonstration. Works have plausible titles, DOIs, years, and citations.
#' Authors are clustered into collaborating groups.
#'
#' @param n_works Number of works to generate.
#' @param n_authors Number of authors to generate.
#' @param year_range Two-element integer vector of year range.
#' @param n_clusters Number of topic clusters.
#' @param with_embeddings Logical; generate random embeddings?
#' @param with_screening Logical; generate screening decisions?
#' @param with_trajectory_seed Logical; create a prolific author for
#'   trajectory demonstration?
#' @param seed Random seed for reproducibility.
#'
#' @return An `sm_corpus` object.
#'
#' @family example
#' @export
#' @examples
#' corpus <- sm_example_corpus()
#' print(corpus)
sm_example_corpus <- function(n_works = 200L,
                              n_authors = 80L,
                              year_range = c(2015L, 2024L),
                              n_clusters = 5L,
                              with_embeddings = TRUE,
                              with_screening = FALSE,
                              with_trajectory_seed = TRUE,
                              seed = 42L) {
  set.seed(seed)

  topics <- c("spatial transcriptomics", "single-cell RNA-seq",
               "tumor microenvironment", "immune checkpoint",
               "colorectal cancer", "machine learning",
               "biomarker discovery", "clinical outcomes",
               "drug resistance", "gene expression")
  methods <- c("cohort study", "meta-analysis", "randomized trial",
                "case-control study", "systematic review",
                "cross-sectional study", "prospective study")
  journals <- c("Nature Medicine", "Cell", "Cancer Research",
                 "Journal of Clinical Oncology", "PNAS",
                 "Genome Biology", "Bioinformatics",
                 "BMC Genomics", "PLoS ONE", "Scientific Reports")
  countries <- c("US", "CN", "GB", "DE", "JP", "FR", "CA", "AU", "KR", "IT",
                  "NL", "CH", "SE", "ES", "BR", "IN", "IL", "DK", "NO", "FI")

  first_names <- c("Wei", "Sarah", "Mohammed", "Yuki", "Maria",
                    "James", "Priya", "Lars", "Chen", "Anna",
                    "David", "Fatima", "Hiroshi", "Elena", "Raj",
                    "Thomas", "Aisha", "Erik", "Mei", "Carlos")
  last_names <- c("Zhang", "Smith", "Ali", "Tanaka", "Garcia",
                   "Johnson", "Patel", "Andersson", "Wang", "Mueller",
                   "Brown", "Hassan", "Sato", "Petrova", "Kumar",
                   "Fischer", "Ibrahim", "Johansson", "Liu", "Santos")

  n_works <- as.integer(n_works)
  n_authors <- as.integer(n_authors)

  work_ids <- paste0("W", formatC(seq_len(n_works), width = 9, flag = "0"))
  author_ids <- paste0("A", formatC(seq_len(n_authors), width = 9, flag = "0"))

  cluster_assign <- sample(seq_len(n_clusters), n_works, replace = TRUE)
  years <- sample(seq(year_range[1], year_range[2]), n_works, replace = TRUE)

  titles <- vapply(seq_len(n_works), function(i) {
    t1 <- sample(topics, 1)
    t2 <- sample(topics, 1)
    m <- sample(methods, 1)
    paste0(
      tools::toTitleCase(t1), " in ", t2, ": a ", m
    )
  }, character(1))

  abstracts <- vapply(seq_len(n_works), function(i) {
    paste0(
      "This study investigates ", sample(topics, 1),
      " using ", sample(methods, 1), " approaches. ",
      "We analyzed ", sample(50:5000, 1), " samples and found ",
      "significant associations with ", sample(topics, 1), "."
    )
  }, character(1))

  works <- tibble::tibble(
    work_id = work_ids,
    doi = paste0("10.1234/example.", seq_len(n_works)),
    title = titles,
    abstract = abstracts,
    year = as.integer(years),
    type = sample(c("journal-article", "review", "letter"),
                  n_works, replace = TRUE, prob = c(0.7, 0.2, 0.1)),
    source_id = paste0("S", formatC(
      sample(seq_len(min(length(journals), 10)), n_works, replace = TRUE),
      width = 9, flag = "0")),
    cited_by_count = as.integer(stats::rnbinom(n_works, mu = 15, size = 2)),
    oa_status = sample(c("gold", "green", "hybrid", "bronze", "closed"),
                       n_works, replace = TRUE,
                       prob = c(0.2, 0.15, 0.1, 0.1, 0.45)),
    language = "en",
    pmid = paste0(sample(20000000:39999999, n_works)),
    arxiv_id = NA_character_,
    openalex_id = paste0("W", sample(1000000000:9999999999, n_works)),
    is_retracted = sample(c(FALSE, TRUE), n_works, replace = TRUE,
                          prob = c(0.98, 0.02)),
    retraction_date = as.Date(NA),
    last_refreshed = Sys.time()
  )

  a_first <- sample(first_names, n_authors, replace = TRUE)
  a_last <- sample(last_names, n_authors, replace = TRUE)

  authors <- tibble::tibble(
    author_id = author_ids,
    orcid = ifelse(
      stats::runif(n_authors) > 0.4,
      paste0("0000-000", sample(1:3, n_authors, replace = TRUE), "-",
             formatC(sample(1000:9999, n_authors), width = 4, flag = "0"), "-",
             formatC(sample(1000:9999, n_authors), width = 4, flag = "0")),
      NA_character_
    ),
    display_name = paste(a_first, a_last),
    display_name_alternatives = lapply(seq_len(n_authors), function(i) character()),
    inferred_gender = NA_character_,
    gender_confidence = NA_real_,
    gender_method = NA_character_
  )

  authorships_list <- lapply(seq_len(n_works), function(i) {
    n_auth <- sample(1:8, 1, prob = c(0.1, 0.2, 0.25, 0.2, 0.1, 0.08, 0.05, 0.02))
    auth_idx <- sample(seq_len(n_authors), min(n_auth, n_authors))
    tibble::tibble(
      work_id = work_ids[i],
      author_id = author_ids[auth_idx],
      position = seq_along(auth_idx),
      is_corresponding = c(TRUE, rep(FALSE, length(auth_idx) - 1)),
      institution_id = NA_character_,
      raw_affiliation = NA_character_,
      country_code = sample(countries, length(auth_idx), replace = TRUE)
    )
  })
  authorships <- dplyr::bind_rows(authorships_list)

  if (with_trajectory_seed && n_authors >= 1) {
    traj_author <- author_ids[1]
    traj_works <- sample(work_ids, min(35, n_works))
    for (wid in traj_works) {
      if (!any(authorships$work_id == wid & authorships$author_id == traj_author)) {
        authorships <- dplyr::bind_rows(
          authorships,
          tibble::tibble(
            work_id = wid, author_id = traj_author,
            position = 1L, is_corresponding = TRUE,
            institution_id = NA_character_,
            raw_affiliation = NA_character_,
            country_code = "DE"
          )
        )
      }
    }
    all_years <- seq(year_range[1], year_range[2])
    for (yr in all_years) {
      yr_works <- works$work_id[works$year == yr]
      has_work <- any(
        authorships$work_id %in% yr_works &
          authorships$author_id == traj_author
      )
      if (!has_work && length(yr_works) > 0) {
        pick <- sample(yr_works, 1)
        authorships <- dplyr::bind_rows(
          authorships,
          tibble::tibble(
            work_id = pick, author_id = traj_author,
            position = 1L, is_corresponding = TRUE,
            institution_id = NA_character_,
            raw_affiliation = NA_character_,
            country_code = "DE"
          )
        )
      }
    }
  }

  sources_tbl <- tibble::tibble(
    source_id = paste0("S", formatC(seq_along(journals), width = 9, flag = "0")),
    issn_l = paste0(
      formatC(sample(1000:9999, length(journals)), width = 4, flag = "0"),
      "-",
      formatC(sample(1000:9999, length(journals)), width = 4, flag = "0")
    ),
    issn = lapply(seq_along(journals), function(i) character()),
    display_name = journals,
    type = "journal",
    is_oa = sample(c(TRUE, FALSE), length(journals), replace = TRUE),
    publisher = sample(c("Springer Nature", "Elsevier", "Wiley",
                          "Oxford University Press", "PLOS"), length(journals),
                       replace = TRUE),
    publisher_country = sample(c("US", "GB", "NL", "DE"), length(journals),
                               replace = TRUE)
  )

  refs_list <- lapply(seq_len(n_works), function(i) {
    n_refs <- sample(0:40, 1, prob = c(0.05, rep(0.95 / 40, 40)))
    if (n_refs == 0) return(tibble::tibble(
      work_id = character(), ref_index = integer(),
      cited_work_id = character(), cited_doi = character(),
      cited_raw = character()
    ))
    ref_pool <- setdiff(work_ids, work_ids[i])
    internal <- sample(ref_pool, min(n_refs %/% 2, length(ref_pool)))
    tibble::tibble(
      work_id = work_ids[i],
      ref_index = seq_len(length(internal)),
      cited_work_id = internal,
      cited_doi = works$doi[match(internal, work_ids)],
      cited_raw = works$title[match(internal, work_ids)]
    )
  })
  references <- dplyr::bind_rows(refs_list)

  concept_list <- lapply(seq_len(n_works), function(i) {
    n_c <- sample(2:5, 1)
    sel_topics <- sample(topics, n_c)
    tibble::tibble(
      work_id = work_ids[i],
      concept_id = paste0("C", digest::digest(sel_topics, serialize = FALSE) |>
                            substr(1, 8)),
      concept_name = sel_topics,
      level = sample(0:2, n_c, replace = TRUE),
      score = round(stats::runif(n_c, 0.3, 1.0), 3),
      vocabulary = "openalex"
    )
  })
  concepts <- dplyr::bind_rows(concept_list)

  provenance <- tibble::tibble(
    work_id = work_ids,
    source = "synthetic",
    source_id_external = NA_character_,
    fetch_date = Sys.time(),
    query = "sm_example_corpus()",
    engine = "native",
    scimapR_version = tryCatch(
      as.character(utils::packageVersion("scimapR")),
      error = function(e) "0.1.0"
    ),
    prompt_hash = NA_character_
  )

  embeddings <- NULL
  if (with_embeddings) {
    n_dim <- 64L
    centers <- matrix(stats::rnorm(n_clusters * n_dim), nrow = n_clusters)
    embeddings <- t(vapply(seq_len(n_works), function(i) {
      centers[cluster_assign[i], ] + stats::rnorm(n_dim, sd = 0.3)
    }, double(n_dim)))
    rownames(embeddings) <- work_ids
  }

  screening <- .empty_screening()
  if (with_screening) {
    screening <- tibble::tibble(
      work_id = work_ids,
      stage = "title-abstract",
      decision = sample(c("include", "exclude", "unclear"),
                        n_works, replace = TRUE, prob = c(0.4, 0.45, 0.15)),
      reason = "Synthetic screening decision",
      confidence = round(stats::runif(n_works, 0.5, 1.0), 2),
      source = "synthetic",
      decided_at = Sys.time()
    )
  }

  new_sm_corpus(
    works = works,
    authors = authors,
    authorships = authorships,
    institutions = .empty_institutions(),
    sources = sources_tbl,
    references = references,
    concepts = concepts,
    embeddings = embeddings,
    provenance = provenance,
    screening = screening,
    metadata = list(
      scimapR_version = tryCatch(
        as.character(utils::packageVersion("scimapR")),
        error = function(e) "0.1.0"
      ),
      build_date = Sys.time(),
      corpus_hash = NA_character_,
      is_locked = FALSE,
      last_refresh = Sys.time(),
      question_id = NA_character_
    )
  )
}

#' Get paths to example data files
#'
#' @description
#' Returns the path to bundled example bibliographic files in the package's
#' `inst/extdata` directory.
#'
#' @param name Name of the example file (without path). If `NULL`, lists
#'   all available files.
#'
#' @return A character string path, or a character vector of available files.
#'
#' @family example
#' @export
#' @examples
#' sm_example_files()
#' sm_example_files("example.bib")
sm_example_files <- function(name = NULL) {
  dir <- system.file("extdata", package = "scimapR")
  if (!nzchar(dir)) {
    cli::cli_abort("Example data directory not found in installed package.")
  }
  if (is.null(name)) {
    return(list.files(dir))
  }
  path <- file.path(dir, name)
  if (!file.exists(path)) {
    available <- list.files(dir)
    cli::cli_abort(c(
      "Example file {.file {name}} not found.",
      "i" = "Available files: {.file {available}}"
    ))
  }
  path
}
