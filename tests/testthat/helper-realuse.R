# Helpers: the synthetic real-use fixture (inst/extdata/example_realuse_*,
# built by data-raw/realuse-fixture.R) and its Web of Science plaintext
# twin (tests/testthat/fixtures/realuse-wos-sample.txt).
realuse_corpus <- function() {
  readRDS(scimapR::sm_example_files("example_realuse_corpus.rds"))
}

realuse_reference <- function() {
  readr::read_csv(
    scimapR::sm_example_files("example_realuse_reference.csv"),
    col_types = "cccicc", na = "", progress = FALSE
  )
}

realuse_dict <- function() {
  readr::read_csv(
    scimapR::sm_example_files("example_realuse_affiliation_dict.csv"),
    col_types = "ccc", na = "", progress = FALSE
  )
}

realuse_wos_sample <- function() {
  testthat::test_path("fixtures", "realuse-wos-sample.txt")
}

# The fixture matched with its affiliation dictionary, so its authorships
# carry institution_match
realuse_matched <- function() {
  suppressMessages(scimapR::sm_affiliation_match(realuse_corpus(),
                                                 realuse_dict()))
}

# One cluster per planted keyword theme (the anchor author keyword every
# work of the theme carries), the same id in every time window; works
# without an anchor (editorials and letters) are noise, cluster 0.
realuse_themes <- function(corpus) {
  anchors <- c("orthohantavirus", "hemorrhage control",
               "exertional heat illness")
  kw <- corpus$concepts
  kw <- kw[kw$vocabulary == "author-keywords" &
             kw$concept_name %in% anchors, ]
  theme <- match(kw$concept_name, anchors)[match(corpus$works$work_id,
                                                 kw$work_id)]
  theme[is.na(theme)] <- 0L
  theme
}
