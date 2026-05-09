# Empty tibble constructors for each corpus table
# Ensures type stability: empty input -> 0-row tibble with correct columns

.empty_works <- function() {
  tibble::tibble(
    work_id = character(),
    doi = character(),
    title = character(),
    abstract = character(),
    year = integer(),
    type = character(),
    source_id = character(),
    cited_by_count = integer(),
    oa_status = character(),
    language = character(),
    pmid = character(),
    arxiv_id = character(),
    openalex_id = character(),
    is_retracted = logical(),
    retraction_date = as.Date(character()),
    last_refreshed = as.POSIXct(character())
  )
}

.empty_authors <- function() {
  tibble::tibble(
    author_id = character(),
    orcid = character(),
    display_name = character(),
    display_name_alternatives = list(),
    inferred_gender = character(),
    gender_confidence = double(),
    gender_method = character()
  )
}

.empty_authorships <- function() {
  tibble::tibble(
    work_id = character(),
    author_id = character(),
    position = integer(),
    is_corresponding = logical(),
    institution_id = character(),
    raw_affiliation = character(),
    country_code = character()
  )
}

.empty_institutions <- function() {
  tibble::tibble(
    institution_id = character(),
    ror = character(),
    display_name = character(),
    country_code = character(),
    region = character(),
    income_tier = character(),
    type = character()
  )
}

.empty_sources <- function() {
  tibble::tibble(
    source_id = character(),
    issn_l = character(),
    issn = list(),
    display_name = character(),
    type = character(),
    is_oa = logical(),
    publisher = character(),
    publisher_country = character()
  )
}

.empty_references <- function() {
  tibble::tibble(
    work_id = character(),
    ref_index = integer(),
    cited_work_id = character(),
    cited_doi = character(),
    cited_raw = character()
  )
}

.empty_concepts <- function() {
  tibble::tibble(
    work_id = character(),
    concept_id = character(),
    concept_name = character(),
    level = integer(),
    score = double(),
    vocabulary = character()
  )
}

.empty_provenance <- function() {
  tibble::tibble(
    work_id = character(),
    source = character(),
    source_id_external = character(),
    fetch_date = as.POSIXct(character()),
    query = character(),
    engine = character(),
    scimapR_version = character(),
    prompt_hash = character()
  )
}

.empty_screening <- function() {
  tibble::tibble(
    work_id = character(),
    stage = character(),
    decision = character(),
    reason = character(),
    confidence = double(),
    source = character(),
    decided_at = as.POSIXct(character())
  )
}

.empty_metadata <- function() {
  list(
    scimapR_version = as.character(utils::packageVersion("scimapR")),
    build_date = Sys.time(),
    corpus_hash = NA_character_,
    is_locked = FALSE,
    last_refresh = NA_real_,
    question_id = NA_character_
  )
}

.safe_metadata <- function() {
  list(
    scimapR_version = tryCatch(
      as.character(utils::packageVersion("scimapR")),
      error = function(e) "0.1.0"
    ),
    build_date = Sys.time(),
    corpus_hash = NA_character_,
    is_locked = FALSE,
    last_refresh = NA_real_,
    question_id = NA_character_
  )
}
