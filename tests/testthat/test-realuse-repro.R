# Regression tests for the issues found when scimapR ran on a real Web of
# Science corpus, reproduced on the synthetic real-use fixture (see the
# helpers in helper-realuse.R). Each test describes the fixed behaviour and
# stays skipped until the prompt named in its skip() message fixes the
# issue; that prompt may adapt the calls to its final API but keeps the
# intent written next to the skip().

test_that("H1: years without a finite outcome are dropped, not fatal", {
  # Intent: no 2026 work has a journal quartile, so share_q1 has no value
  # for 2026. sm_its() drops that year with a warning naming it instead of
  # failing on mismatched fitted values; sm_did() drops it as well instead
  # of fitting on fewer years and keeping NaN in its series, and reports
  # it per group.
  fix <- realuse_corpus()
  expect_warning(its <- sm_its(fix, 2021, "share_q1"), "2026")
  expect_s3_class(its, "sm_its")
  usable <- tapply(!is.na(fix$works$quartile), fix$works$year, any)
  expect_equal(nrow(its$series), sum(usable))
  expect_false(2026L %in% its$series$year)
  expect_identical(its$dropped_years, 2026L)

  matched <- suppressMessages(sm_affiliation_match(fix, realuse_dict()))
  expect_warning(
    did <- sm_did(matched,
                  treated = "Armed Forces Hospital Northtown",
                  control = "Federal Armed Forces Institute of Microbiology",
                  intervention_year = 2021, outcome = "share_q1"),
    "2026"
  )
  expect_false(any(is.nan(did$series$value)))
  expect_false(2026L %in% did$series$year)
  expect_identical(did$dropped_years$year, c(2026L, 2026L))
  expect_identical(as.character(did$dropped_years$group),
                   c("control", "treated"))
})

test_that("H2: keyword consumers read the vocabularies readers write", {
  # Intent: the fixture's concepts use the vocabularies sm_read_wos()
  # writes ("author-keywords", "keywords-plus", ...). The bibliometrix
  # export fills DE from the author keywords, the keyword co-word network
  # finds them, and the canonical vocabulary set lists "author-keywords".
  fix <- realuse_corpus()
  concepts <- fix$concepts
  has_kw <- unique(concepts$work_id[concepts$vocabulary == "author-keywords"])
  m <- sm_to_bibliometrix(fix)
  de <- m$DE[match(has_kw, m$work_id)]
  expect_true(all(!is.na(de) & nzchar(de)))
  g <- sm_network_coword(fix, field = "keywords")
  expect_gt(igraph::vcount(g), 0L)
  expect_true("author-keywords" %in% sm_concept_vocabularies())
})

test_that("H3: sm_to_bibliometrix() exports the Web of Science tags", {
  # Intent: the export carries C1, RP, ID, WC and UT from the corpus tables
  # (UT from provenance, or from a WOS: work_id for the two works without a
  # provenance row), lists each author once in AU even when the author has
  # two address rows, and declares a Web of Science database.
  fix <- realuse_corpus()
  m <- sm_to_bibliometrix(fix)
  for (tag in c("C1", "RP", "ID", "WC", "UT")) {
    expect_true(tag %in% names(m), info = tag)
    expect_true(any(!is.na(m[[tag]]) & nzchar(m[[tag]])), info = tag)
  }
  expect_true(all(startsWith(m$UT, "WOS:")))
  au <- strsplit(m$AU, ";", fixed = TRUE)
  expect_false(any(vapply(au, anyDuplicated, integer(1)) > 0L))
  expect_identical(unique(m$DB), "ISI")
})

test_that("H3: bibliometrix finds institutions and local citations", {
  skip_if_not_installed("bibliometrix")
  # Intent: on the exported data frame bibliometrix extracts affiliations
  # (AU_UN), and histNetwork() links every work whose CR line carries the
  # DOI of another corpus work (the planted local citations).
  fix <- realuse_corpus()
  m <- sm_to_bibliometrix(fix)
  un <- suppressMessages(bibliometrix::metaTagExtraction(m, "AU_UN"))
  expect_true(any(!is.na(un$AU_UN) & nzchar(un$AU_UN)))
  refs <- fix$references
  local <- !is.na(refs$cited_doi) & refs$cited_doi %in% fix$works$doi
  planted <- unique(refs[local, c("work_id", "cited_doi")])
  hist <- bibliometrix::histNetwork(m, min.citations = 0, sep = ";",
                                    verbose = FALSE)
  expect_equal(sum(hist$histData$LCS), nrow(planted))
})

test_that("H4: coverage breaks down by tracker columns and institutions", {
  # Intent: `by` accepts the tracker's own columns (here `category`), and
  # after sm_affiliation_match() the corpus side of the affiliation
  # breakdown uses the matched institutions instead of country codes, so
  # both sides of the table share their levels. Before the matching, the
  # corpus side falls back to country codes with a warning.
  fix <- realuse_corpus()
  ref <- realuse_reference()
  expect_warning(
    cov <- suppressMessages(
      sm_coverage_audit(fix, ref, by = c("year", "category", "affiliation"),
                        match = "doi")
    ),
    class = "scimapR_coverage_country_fallback"
  )
  expect_s3_class(cov, "sm_coverage")
  by_category <- sm_coverage_breakdowns(cov, "category")
  expect_setequal(by_category$level, unique(ref$category))
  expect_equal(nrow(by_category), length(unique(ref$category)))

  dict <- realuse_dict()
  matched <- suppressMessages(sm_affiliation_match(fix, dict))
  cov <- suppressMessages(
    sm_coverage_audit(matched, ref, by = "affiliation", match = "doi")
  )
  by_affiliation <- sm_coverage_breakdowns(cov, "affiliation")
  corpus_levels <- by_affiliation$level[!is.na(by_affiliation$n_corpus)]
  expect_gt(length(corpus_levels), 0L)
  expect_true(all(corpus_levels %in% dict$institution))
  expect_false(any(corpus_levels %in% fix$authorships$country_code))
})

test_that("H5: leadership can be restricted to a focal institution", {
  # Intent: every fixture work has a corresponding author, so the default
  # leadership share is 1 in every year. With `institutions`, a work counts
  # only when its corresponding author is affiliated with the focal unit;
  # the share then equals a hand computation on the matched fixture.
  fix <- suppressMessages(sm_affiliation_match(realuse_corpus(),
                                               realuse_dict()))
  unit <- "Armed Forces Hospital Northtown"
  default <- sm_its(fix, 2021, "leadership")
  focal <- sm_its(fix, 2021, "leadership", institutions = unit)
  expect_true(any(focal$series$observed != default$series$observed))

  a <- fix$authorships
  led <- unique(a$work_id[a$is_corresponding %in% TRUE &
                            a$institution_match %in% unit])
  share <- tapply(fix$works$work_id %in% led, fix$works$year, mean)
  expect_equal(focal$series$observed,
               as.vector(share[as.character(focal$series$year)]))
})

test_that("H6: OpenAlex impact fields survive parsing", {
  skip("H6 pending - prompt A07")
  # Intent: a saved OpenAlex work keeps fwci, the citation percentile with
  # its top-10% flag and the yearly citation counts instead of dropping
  # them; a work without them gets NA and no yearly rows.
  works <- list(
    list(id = "https://openalex.org/W9999000001",
         doi = "https://doi.org/10.9999/oa.2022.001",
         title = "Synthetic OpenAlex work one", publication_year = 2022,
         type = "article", cited_by_count = 12, fwci = 1.85,
         citation_normalized_percentile = list(
           value = 0.93, is_in_top_1_percent = FALSE,
           is_in_top_10_percent = TRUE
         ),
         counts_by_year = list(list(year = 2024, cited_by_count = 5),
                               list(year = 2023, cited_by_count = 7)),
         authorships = list()),
    list(id = "https://openalex.org/W9999000002",
         doi = "https://doi.org/10.9999/oa.2023.002",
         title = "Synthetic OpenAlex work two", publication_year = 2023,
         type = "article", cited_by_count = 0, fwci = NULL,
         citation_normalized_percentile = NULL, counts_by_year = list(),
         authorships = list())
  )
  path <- withr::local_tempfile(fileext = ".json")
  jsonlite::write_json(works, path, auto_unbox = TRUE, null = "null",
                       digits = NA)
  corpus <- sm_read_openalex_json(path, verbose = FALSE)
  expect_equal(corpus$works$fwci, c(1.85, NA))
  expect_equal(corpus$works$citation_percentile, c(0.93, NA))
  expect_identical(corpus$works$is_top_10pct, c(TRUE, NA))
  yearly <- corpus$citations_by_year
  expect_equal(nrow(yearly), 2L)
  expect_equal(sum(yearly$cited_by_count), 12)
})

test_that("H7: multilingual models map to ids and get their prefix", {
  skip("H7 pending - prompt A08")
  # Intent: about 15% of the fixture works are German. Multilingual model
  # names map to their Hugging Face ids, and e5 models get the "query: "
  # input prefix their model card documents; other models get none.
  expect_identical(
    .embed_model_name("multilingual-mpnet"),
    "sentence-transformers/paraphrase-multilingual-mpnet-base-v2"
  )
  expect_identical(.embed_model_name("multilingual-e5"),
                   "intfloat/multilingual-e5-base")
  works <- realuse_corpus()$works
  e5 <- .embed_prepare_texts(works, "title_abstract",
                             model = "multilingual-e5")
  expect_true(all(startsWith(e5, "query: ")))
  mpnet <- .embed_prepare_texts(works, "title_abstract",
                                model = "multilingual-mpnet")
  expect_false(any(startsWith(mpnet, "query: ")))
})

test_that("H8: certificates record and verify local input files", {
  skip("H8 pending - prompt A09")
  skip_if_not_installed("yaml")
  # Intent: a registered local input is stored with its SHA-256, and
  # verification fails that input's check once the file has changed.
  input <- withr::local_tempfile(fileext = ".csv")
  file.copy(scimapR::sm_example_files("example_realuse_reference.csv"),
            input)
  fix <- sm_register_input(realuse_corpus(), input, role = "tracker")
  cert <- sm_certificate(fix)
  sha <- digest::digest(input, algo = "sha256", file = TRUE)
  expect_true(sha %in% unlist(cert$local_inputs))
  expect_true(sm_verify_certificate(fix, cert)$pass)

  cat("changed\n", file = input, append = TRUE)
  verification <- sm_verify_certificate(fix, cert)
  expect_false(verification$pass)
  checks <- verification$checks
  status <- checks$status[checks$check == paste0("input:", basename(input))]
  expect_identical(status, "fail")
})

test_that("H9: version metadata agree and print formats refresh times", {
  skip("H9 pending - prompt A10")
  # Intent: the package version matches the top NEWS heading (a
  # development heading for .9000 versions), and the fixture's numeric
  # last_refresh prints as a date instead of a number.
  news <- system.file("NEWS.md", package = "scimapR")
  skip_if_not(nzchar(news), "NEWS.md is not installed")
  headings <- grep("^# scimapR", readLines(news, encoding = "UTF-8"),
                   value = TRUE)
  version <- as.character(utils::packageVersion("scimapR"))
  expected <- if (grepl("\\.9000$", version)) {
    "# scimapR (development version)"
  } else {
    paste("# scimapR", version)
  }
  expect_identical(headings[1], expected)
  out <- cli::cli_fmt(print(realuse_corpus()))
  expect_true(any(grepl("last refreshed: 2026-", out, fixed = TRUE)))
  expect_false(any(grepl("1792195200", out, fixed = TRUE)))
})

test_that("H10: the cnci summary uses stored fwci, like sm_its()", {
  skip("H10 pending - prompt A07")
  # Intent: with works$fwci populated and no works$cnci, the robust summary
  # resolves impact like sm_its() instead of recomputing a within-corpus
  # FNCI; the summary rounds to four digits.
  fix <- realuse_corpus()
  summary <- sm_metric_summary(fix, metric = "cnci", robust = FALSE)
  expect_equal(summary$median,
               round(stats::median(fix$works$fwci, na.rm = TRUE), 4))
  expect_equal(summary$n, sum(!is.na(fix$works$fwci)))
})

test_that("H11: a numeric last_refresh works in certificates and maturity", {
  skip_if_not_installed("yaml")
  # Intent: the fixture stores last_refresh as epoch seconds (2026-10-17
  # UTC). The certificate formats it as a date, and the maturity cutoff is
  # a calendar year instead of epoch seconds read as days.
  fix <- realuse_corpus()
  cert <- sm_certificate(fix)
  expect_s3_class(cert, "sm_certificate")
  expect_match(cert$metadata$last_refresh, "^2026-10-17")
  expect_identical(.maturity_cutoff(fix, lag = 2L), 2024L)
})

test_that("H12: small FNCI cells fall back to a larger baseline", {
  # Intent: with classification = "manual" (works$field) the default gives
  # FNCI = 1 to every cited work alone in its field-year cell, and says so
  # because more than a quarter of the works sit in cells of fewer than
  # ten. With min_cell no FNCI of exactly 1 comes from a cell smaller than
  # min_cell, and the result reports the cell size and the baseline level
  # used.
  fix <- realuse_corpus()
  expect_message(
    default <- sm_metric_fnci(fix, classification = "manual"),
    class = "scimapR_fnci_small_cells"
  )
  cell <- paste(default$field, default$year)
  expect_gt(mean(as.vector(table(cell)[cell]) < 10L), 0.25)
  singles <- cell %in% names(which(table(cell) == 1L)) &
    default$cited_by_count > 0L
  expect_gte(sum(singles), 5L)
  expect_true(all(default$fnci[singles] == 1))

  res <- sm_metric_fnci(fix, classification = "manual", min_cell = 3)
  expect_true(all(c("n_cell", "baseline") %in% names(res)))
  expect_false(any(res$fnci == 1 & res$n_cell < 3, na.rm = TRUE))
  expect_false(anyNA(res$baseline))
})

test_that("H13: a global clustering is followed across time windows", {
  # Intent: with one clustering for the whole corpus (the same cluster_id
  # in every window), link_by = "cluster_id" gives one transition per
  # cluster present in both windows and none for noise (cluster 0). The
  # default term-based linking finds no transition on this fixture.
  fix <- realuse_corpus()
  fix$works$cluster_id <- realuse_themes(fix)
  evo <- sm_cluster_evolution(fix, time_windows = list(2016:2021, 2022:2026),
                              link_by = "cluster_id")
  works <- fix$works
  both <- intersect(works$cluster_id[works$year <= 2021L],
                    works$cluster_id[works$year >= 2022L])
  both <- setdiff(both, 0L)
  transitions <- evo$transitions
  expect_equal(nrow(transitions), length(both))
  expect_setequal(transitions$from_cluster, both)
  expect_identical(transitions$from_cluster, transitions$to_cluster)
  expect_true(all(transitions$jaccard >= 0 & transitions$jaccard <= 1))
})

test_that("H14: dictionary patterns match non-ASCII affiliations", {
  # Intent: ten fixture rows carry German address strings. The dictionary
  # rows whose \w must consume an umlaut or whose \b sits next to one (rows
  # 2, 3, 4, 6 and 7) leave all ten unmatched before the fix, and the
  # generic fallback cannot reach them. After the fix eight of them match
  # their unit; the two rows of a civilian clinic stay unmatched and are
  # listed by sm_affiliation_unmatched().
  zis <- "Zentrales Institut des Sanit\u00e4tswesens Nordstadt"
  hospital <- "Armed Forces Hospital Northtown"
  expected <- data.frame(
    text = c(
      paste0(zis, ", Abt. \u00dcbung"),
      "Abt. \u00dcbung und Ausbildung, Nordstadt",
      "Institut f\u00fcr Mikrobiologie der Streitkr\u00e4fte, Southcity",
      "Streitkr\u00e4ftekrankenhaus Northtown, Klinik f\u00fcr Unfallchirurgie",
      "Sektion Fu\u00df- und Sprunggelenkchirurgie, Northtown",
      "Universit\u00e4tsklinikum Nordstadt, Klinik f\u00fcr Dermatologie"
    ),
    institution = c(zis, zis, "Federal Armed Forces Institute of Microbiology",
                    hospital, hospital, NA),
    stringsAsFactors = FALSE
  )
  matched <- suppressMessages(sm_affiliation_match(realuse_corpus(),
                                                   realuse_dict()))
  a <- matched$authorships
  rows <- a[a$raw_affiliation %in% expected$text, ]
  expect_equal(nrow(rows), 10L)
  expect_identical(
    rows$institution_match,
    expected$institution[match(rows$raw_affiliation, expected$text)]
  )
  unmatched <- sm_affiliation_unmatched(matched, n = 1000L)
  expect_true(expected$text[6] %in% unmatched$raw_affiliation)
  expect_false(any(expected$text[1:5] %in% unmatched$raw_affiliation))
  listed <- a$raw_affiliation %in% unmatched$raw_affiliation
  expect_true(all(is.na(a$institution_match[listed])))
})

test_that("H15: one paper cannot name a cluster; keyword labels; noise", {
  skip("H15 pending - prompt A15")
  skip_if_not_installed("tidytext")
  # Intent: with the theme clustering, the token one heat-theme abstract
  # repeats 15 times ("quillotyrase") is in no tf-idf label, the keyword
  # labels contain the planted anchor keywords, and noise (cluster 0) gets
  # no label.
  fix <- realuse_corpus()
  fix$works$cluster_id <- realuse_themes(fix)
  tfidf <- suppressMessages(sm_cluster_label(fix, method = "tfidf"))
  labels <- tfidf$works$cluster_label
  expect_false(any(grepl("quillotyrase", labels, fixed = TRUE)))
  expect_true(all(is.na(labels[tfidf$works$cluster_id == 0L])))

  keywords <- suppressMessages(sm_cluster_label(fix, method = "keywords"))
  anchors <- c("orthohantavirus", "hemorrhage control",
               "exertional heat illness")
  labels <- keywords$works$cluster_label
  ids <- keywords$works$cluster_id
  for (k in 1:3) {
    expect_match(labels[match(k, ids)], anchors[k], fixed = TRUE)
  }
  expect_true(all(is.na(labels[ids == 0L])))
})

test_that("H16: the WoS reader takes the corresponding author from RP", {
  # Intent: in the plaintext twin, four records name a corresponding author
  # who is not the first author, five name the first author and one has no
  # RP field. The reader flags the RP author and leaves the record without
  # RP unknown (NA) instead of flagging the first author.
  path <- realuse_wos_sample()
  twin <- sm_read_wos(path, verbose = FALSE)
  a <- twin$authorships
  a$doi <- twin$works$doi[match(a$work_id, twin$works$work_id)]
  fix <- realuse_corpus()
  truth <- fix$authorships[fix$authorships$is_corresponding, ]
  truth$doi <- fix$works$doi[match(truth$work_id, fix$works$work_id)]
  truth <- unique(truth[truth$doi %in% a$doi, c("doi", "position")])

  lines <- readLines(path, encoding = "UTF-8")
  record <- cumsum(grepl("^PT ", lines))
  rp <- vapply(split(lines, record)[-1], function(x) {
    any(grepl("^RP ", x))
  }, logical(1))
  di <- vapply(split(lines, record)[-1], function(x) {
    sub("^DI ", "", grep("^DI ", x, value = TRUE))
  }, character(1))
  truth <- truth[truth$doi %in% di[rp], ]
  expect_equal(sum(truth$position > 1L), 4L)

  flagged <- a[a$is_corresponding %in% TRUE, ]
  expect_setequal(paste(flagged$doi, flagged$position),
                  paste(truth$doi, truth$position))
  expect_true(all(is.na(a$is_corresponding[a$doi %in% di[!rp]])))
})

test_that("H17: specter2 needs the adapters module", {
  skip("H17 pending - prompt A08")
  skip_if_not_installed("reticulate")
  # Intent: allenai/specter2 is an adapter, so the default model takes the
  # adapters path. With Python available and the adapters module missing,
  # sm_embed_works() aborts with a message naming adapters instead of
  # failing inside SentenceTransformer(); no Python module is imported.
  testthat::local_mocked_bindings(
    py_available = function(...) TRUE,
    py_module_available = function(module) !identical(module, "adapters"),
    import = function(module, ...) stop("unexpected import of ", module),
    .package = "reticulate"
  )
  expect_error(
    sm_embed_works(realuse_corpus(), model = "specter2", verbose = FALSE),
    "adapters"
  )
})
