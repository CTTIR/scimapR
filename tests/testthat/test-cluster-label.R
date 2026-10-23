# Build a small clustered corpus for labelling tests.
make_clustered_corpus <- function(n = 60, k = 3, seed = 1) {
  corpus <- sm_example_corpus(n_works = n, n_clusters = k,
                              with_embeddings = TRUE, seed = seed)
  set.seed(seed)
  suppressMessages(sm_cluster_kmeans(corpus, k = k, reducer = "pca"))
}

# A corpus with the given titles and cluster ids, for exact label checks.
label_corpus <- function(title, cluster_id, abstract = NA_character_,
                         language = "English", concepts = NULL) {
  n <- length(title)
  works <- tibble::tibble(
    work_id = sprintf("W%03d", seq_len(n)),
    title = title,
    abstract = rep_len(abstract, n),
    language = rep_len(language, n),
    cluster_id = as.integer(cluster_id)
  )
  suppressMessages(sm_corpus(works = works, concepts = concepts))
}

# One label per cluster id, named by the id
labels_by_cluster <- function(corpus, column = "cluster_label") {
  w <- corpus$works
  first <- !duplicated(w$cluster_id)
  stats::setNames(w[[column]][first], w$cluster_id[first])
}

# Two clusters of four works: a bleeding theme and a heat theme
bleeding_titles <- c(
  "Tourniquet application in combat trauma",
  "Early tourniquet application after blast trauma",
  "Tourniquet application and limb trauma",
  "Junctional bleeding and tourniquet application"
)
heat_titles <- c(
  "Exertional heat illness in recruits",
  "Cooling after exertional heat illness",
  "Exertional heat illness during marches",
  "Hydration and exertional heat illness"
)

# The real-use example corpus with its German works as cluster 1 and the
# others as cluster 2
german_cluster <- function() {
  fix <- readRDS(sm_example_files("example_realuse_corpus.rds"))
  fix$works$cluster_id <- ifelse(fix$works$language == "German", 1L, 2L)
  fix
}

# Count the messages of one class that an expression signals
count_messages <- function(expr, class) {
  n <- 0L
  value <- withCallingHandlers(expr, message = function(m) {
    if (inherits(m, class)) n <<- n + 1L
    invokeRestart("muffleMessage")
  })
  list(value = value, n = n)
}

test_that("sm_cluster_label rejects non-corpus input", {
  expect_error(sm_cluster_label(list(a = 1)), "sm_corpus")
})

test_that("sm_cluster_label validates method and n_terms", {
  corpus <- make_clustered_corpus()
  expect_error(sm_cluster_label(corpus, method = "bogus"))
  expect_error(sm_cluster_label(corpus, n_terms = 0), "positive integer")
})

test_that("sm_cluster_label validates min_works, ngram, stop_terms, noise", {
  corpus <- label_corpus(bleeding_titles, 1L)
  expect_error(sm_cluster_label(corpus, min_works = 0), "positive integer")
  expect_error(sm_cluster_label(corpus, min_works = 2.5), "positive integer")
  for (bad in list(0, 4, 1.5, NA, "1", integer(), c(1, NA))) {
    expect_error(sm_cluster_label(corpus, ngram = bad), "ngram")
  }
  expect_error(sm_cluster_label(corpus, stop_terms = 1), "stop_terms")
  expect_error(sm_cluster_label(corpus, noise = c(0L, 1L)), "noise")
  expect_error(sm_cluster_label(corpus, noise = NA), "noise")
})

test_that("sm_cluster_label errors when no cluster_id column", {
  corpus <- sm_example_corpus(n_works = 20, with_embeddings = TRUE, seed = 2)
  expect_error(sm_cluster_label(corpus, method = "tfidf"), "cluster_id")
})

test_that("sm_cluster_label tfidf errors when tidytext missing", {
  corpus <- make_clustered_corpus()
  testthat::local_mocked_bindings(
    check_installed = function(pkg, ...) {
      if (pkg == "tidytext") stop("tidytext not installed")
      invisible(NULL)
    },
    .package = "rlang"
  )
  expect_error(sm_cluster_label(corpus, method = "tfidf"), "tidytext")
  expect_error(sm_cluster_label(corpus, method = "yake"), "tidytext")
  expect_error(sm_cluster_label(corpus, method = "keywords"), "tidytext")
})

test_that("sm_cluster_label tfidf adds cluster_label column", {
  skip_if_not_installed("tidytext")
  corpus <- make_clustered_corpus(seed = 3)
  out <- suppressMessages(
    sm_cluster_label(corpus, method = "tfidf", n_terms = 3L)
  )
  expect_s3_class(out, "sm_corpus")
  expect_true("cluster_label" %in% names(out$works))
  expect_equal(nrow(out$works), nrow(corpus$works))
  # Each labelled work has a non-empty label string
  labelled <- out$works$cluster_label[!is.na(out$works$cluster_id)]
  expect_true(all(nchar(labelled) > 0L))
  # Labels are constant within a cluster
  agg <- tapply(out$works$cluster_label, out$works$cluster_id,
                function(x) length(unique(x)))
  expect_true(all(agg == 1L))
  expect_true(all(out$works$cluster_label_basis == "tfidf"))
})

test_that("sm_cluster_label yake adds cluster_label column", {
  skip_if_not_installed("tidytext")
  corpus <- make_clustered_corpus(seed = 4)
  out <- suppressMessages(
    sm_cluster_label(corpus, method = "yake", n_terms = 4L)
  )
  expect_true("cluster_label" %in% names(out$works))
  labelled <- out$works$cluster_label[!is.na(out$works$cluster_id)]
  expect_true(all(nchar(labelled) > 0L))
  expect_true(all(out$works$cluster_label_basis == "yake"))
})

test_that("sm_cluster_label replaces an existing cluster_label column", {
  skip_if_not_installed("tidytext")
  corpus <- make_clustered_corpus(seed = 5)
  out1 <- suppressMessages(sm_cluster_label(corpus, method = "tfidf"))
  out2 <- suppressMessages(sm_cluster_label(out1, method = "yake"))
  expect_equal(sum(names(out2$works) == "cluster_label"), 1L)
  expect_equal(sum(names(out2$works) == "cluster_label_basis"), 1L)
  expect_true(all(out2$works$cluster_label_basis == "yake"))
})

test_that("tfidf scores the share of a cluster's works, not occurrences", {
  skip_if_not_installed("tidytext")
  # one bleeding paper repeats an invented token 15 times
  planted <- paste(rep("Quillotyrase levels rose.", 15L), collapse = " ")
  corpus <- label_corpus(c(bleeding_titles, heat_titles), rep(1:2, each = 4),
                         abstract = c(planted, rep(NA, 7L)))
  out <- suppressMessages(sm_cluster_label(corpus))
  labels <- labels_by_cluster(out)
  expect_false(any(grepl("quillotyrase", labels, fixed = TRUE)))
  # "trauma" (3 of 4 works, rarer in the corpus) outranks the terms all
  # four works share; the bigram takes the place of its words, and the
  # overlapping bigrams "exertional heat" and "heat illness" form one term
  expect_identical(unname(labels),
                   c("trauma; tourniquet application",
                     "exertional heat illness"))
  expect_identical(unique(out$works$cluster_label_basis), "tfidf")
})

test_that("overlapping pairs of words are shown as the phrase they form", {
  skip_if_not_installed("tidytext")
  cross <- c("A cross-sectional study of burn care",
             "Cross sectional study of field hygiene",
             "Hearing loss: a cross-sectional study",
             "Sleep in recruits, a cross sectional study")
  corpus <- label_corpus(c(cross, bleeding_titles), rep(1:2, each = 4))
  out <- suppressMessages(sm_cluster_label(corpus))
  expect_identical(labels_by_cluster(out)[["1"]], "cross sectional study")
  # single words never form phrases
  out1 <- suppressMessages(sm_cluster_label(corpus, ngram = 1))
  expect_identical(labels_by_cluster(out1)[["1"]],
                   "cross; sectional; study")

  # "exertional heat" and "heat illness" overlap but never occur together,
  # so they stay apart, while "exertional heat stroke" is one phrase
  heat <- c("Exertional heat stroke in recruits",
            "Exertional heat stroke during marches",
            "Exertional heat stroke and cooling",
            "Heat illness among sailors", "Heat illness in pilots",
            "Heat illness after drills")
  corpus <- label_corpus(c(heat, bleeding_titles), rep(1:2, c(6L, 4L)))
  out <- suppressMessages(sm_cluster_label(corpus))
  expect_identical(labels_by_cluster(out)[["1"]],
                   "exertional heat stroke; heat illness")

  # a phrase in 3 of the 10 works with "heat illness" does not take its
  # place, but that of "exertional heat", which it covers
  illness <- rep(c("Exertional heat illness", "Heat illness"), c(3L, 7L))
  strain <- rep("Exertional heat strain", 6L)
  corpus <- label_corpus(c(illness, strain), rep(1:2, c(10L, 6L)))
  out <- suppressMessages(sm_cluster_label(corpus))
  terms <- strsplit(labels_by_cluster(out)[["1"]], "; ", fixed = TRUE)[[1]]
  expect_identical(terms[1:2], c("heat illness", "exertional heat illness"))
  expect_false("exertional heat" %in% terms)
})

test_that("a longer term covers 40% of the works of the term it replaces", {
  skip_if_not_installed("tidytext")
  kw <- function(work, name) {
    data.frame(work_id = sprintf("W%03d", work), concept_id = NA_character_,
               concept_name = name, level = NA_integer_, score = NA_real_,
               vocabulary = "author-keywords", stringsAsFactors = FALSE)
  }
  chain <- function(n_colorectal, n_metastatic) {
    concepts <- rbind(
      kw(1:20, "Cancer"), kw(1:20, "Chemotherapy"),
      kw(seq_len(n_colorectal), "Colorectal Cancer"),
      kw(seq_len(n_metastatic), "Metastatic Colorectal Cancer"),
      kw(21:40, "Sepsis"), kw(21:40, "Shock")
    )
    label_corpus(paste("Case report", 1:40), rep(1:2, each = 20),
                 concepts = concepts)
  }
  # "Metastatic Colorectal Cancer" covers half of the works with
  # "Colorectal Cancer" but only 4 of the 20 with "Cancer"
  out <- suppressMessages(sm_cluster_label(chain(8L, 4L),
                                           method = "keywords"))
  terms <- strsplit(labels_by_cluster(out)[["1"]], "; ", fixed = TRUE)[[1]]
  expect_identical(terms[1], "Colorectal Cancer")
  out <- suppressMessages(sm_cluster_label(chain(8L, 4L),
                                           method = "keywords",
                                           n_terms = 2L))
  expect_identical(labels_by_cluster(out)[["1"]],
                   "Colorectal Cancer; Chemotherapy")
  # in 9 of the 20 works it covers 40% of them and names the cluster
  out <- suppressMessages(sm_cluster_label(chain(10L, 9L),
                                           method = "keywords",
                                           n_terms = 2L))
  expect_identical(labels_by_cluster(out)[["1"]],
                   "Metastatic Colorectal Cancer; Chemotherapy")

  # the same for terms of the titles
  titles <- c(rep("Metastatic colorectal cancer", 2L),
              rep("Colorectal cancer", 2L), rep("Cancer", 6L),
              rep("Sepsis and shock", 10L))
  corpus <- label_corpus(titles, rep(1:2, each = 10))
  out <- suppressMessages(
    sm_cluster_label(corpus, ngram = 1:3, min_works = 2L, n_terms = 1L)
  )
  expect_identical(labels_by_cluster(out)[["1"]], "colorectal cancer")
})

test_that("ngram = 1 gives single words, ties broken alphabetically", {
  skip_if_not_installed("tidytext")
  corpus <- label_corpus(c(bleeding_titles, heat_titles), rep(1:2, each = 4))
  out <- suppressMessages(sm_cluster_label(corpus, ngram = 1))
  labels <- labels_by_cluster(out)
  expect_identical(unname(labels),
                   c("trauma; application; tourniquet",
                     "exertional; heat; illness"))
  terms <- unlist(strsplit(labels, "; ", fixed = TRUE))
  expect_false(any(grepl(" ", terms, fixed = TRUE)))
  # three-word terms on request
  out3 <- suppressMessages(sm_cluster_label(corpus, ngram = 1:3))
  expect_match(labels_by_cluster(out3)[["2"]], "exertional heat illness",
               fixed = TRUE)
})

test_that("noise gets no label and does not count for other clusters", {
  skip_if_not_installed("tidytext")
  noise_titles <- c("Tourniquet application: an editorial",
                    "Tourniquet application in the news",
                    "Tourniquet application, again",
                    "Tourniquet application revisited")
  clean <- label_corpus(c(bleeding_titles, heat_titles), rep(1:2, each = 4))
  noisy <- label_corpus(c(bleeding_titles, heat_titles, noise_titles),
                        c(rep(1:2, each = 4), rep(0L, 4L)))
  for (method in c("tfidf", "yake")) {
    a <- suppressMessages(sm_cluster_label(clean, method = method))
    b <- suppressMessages(sm_cluster_label(noisy, method = method))
    expect_identical(labels_by_cluster(b)[c("1", "2")],
                     labels_by_cluster(a)[c("1", "2")])
    expect_true(all(is.na(b$works$cluster_label[b$works$cluster_id == 0L])))
    expect_true(all(is.na(
      b$works$cluster_label_basis[b$works$cluster_id == 0L]
    )))
  }
  expect_message(sm_cluster_label(noisy), "4 noise works")
  # noise = NULL labels cluster 0 like any other cluster
  all_ids <- suppressMessages(sm_cluster_label(noisy, noise = NULL))
  expect_false(is.na(labels_by_cluster(all_ids)[["0"]]))
})

test_that("min_works is respected and relaxed to 2 when nothing reaches it", {
  skip_if_not_installed("tidytext")
  corpus <- label_corpus(c(bleeding_titles, heat_titles), rep(1:2, each = 4))
  out <- suppressMessages(sm_cluster_label(corpus, min_works = 4L))
  terms <- strsplit(labels_by_cluster(out)[["1"]], "; ", fixed = TRUE)[[1]]
  expect_false("trauma" %in% terms)
  expect_identical(terms, "tourniquet application")

  expect_message(
    relaxed <- sm_cluster_label(corpus, min_works = 5L),
    "as few as 2 works"
  )
  expect_identical(unname(labels_by_cluster(relaxed)[["1"]]),
                   "trauma; tourniquet application")
  expect_identical(
    unique(relaxed$works$cluster_label_basis), "tfidf (relaxed)"
  )
  # the label string itself carries no marker
  expect_false(any(grepl("relaxed|weak", relaxed$works$cluster_label)))
})

test_that("a cluster without a shared term gets NA with a message", {
  skip_if_not_installed("tidytext")
  corpus <- label_corpus(c(bleeding_titles, "Snakebite envenomation"),
                         c(1L, 1L, 1L, 1L, 2L))
  suppressMessages(
    expect_message(out <- sm_cluster_label(corpus),
                   class = "scimapR_cluster_label_unlabelled")
  )
  labels <- labels_by_cluster(out)
  expect_true(is.na(labels[["2"]]))
  expect_true(is.na(labels_by_cluster(out, "cluster_label_basis")[["2"]]))
  expect_false(is.na(labels[["1"]]))
})

test_that("stop_terms leaves out whole terms, singular and plural alike", {
  skip_if_not_installed("tidytext")
  corpus <- label_corpus(c(bleeding_titles, heat_titles), rep(1:2, each = 4))
  out <- suppressMessages(
    sm_cluster_label(corpus, stop_terms = "Tourniquet Application")
  )
  expect_identical(unname(labels_by_cluster(out)[["1"]]),
                   "trauma; application; tourniquet")
  out <- suppressMessages(
    sm_cluster_label(corpus, stop_terms = c("Tourniquets", NA))
  )
  terms <- strsplit(labels_by_cluster(out)[["1"]], "; ", fixed = TRUE)[[1]]
  expect_false("tourniquet" %in% terms)
  expect_true("tourniquet application" %in% terms)
})

test_that(".fold_plural folds plurals conservatively", {
  expect_identical(.fold_plural(c("fractures", "ticks", "injuries")),
                   c("fracture", "tick", "injury"))
  keep <- c("diagnosis", "virus", "analysis", "class", "days", "stress",
            "species", "series", "diabetes", "herpes", "rabies", "caries",
            "scabies", "measles", "aids", "lens", "physics")
  expect_identical(.fold_plural(keep), keep)
  expect_identical(.fold_plural(c("fournier's", "fournier\u2019s",
                                  "fourniers")),
                   rep("fournier", 3L))
  # names of fields stay apart from their adjectives
  fields <- c("logistics", "statistics", "biostatistics", "genetics",
              "genomics", "radiomics", "pediatrics", "paediatrics",
              "geriatrics", "orthopedics", "obstetrics", "ballistics",
              "ethics", "economics", "ergonomics", "mathematics",
              "diagnostics", "therapeutics", "informatics", "biomechanics",
              "pharmacokinetics", "hemodynamics", "aesthetics", "physics")
  expect_identical(.fold_plural(fields), fields)
  # plurals of nouns ending in "ic" are still folded
  expect_identical(
    .fold_plural(c("clinics", "antibiotics", "anesthetics", "epidemics",
                   "topics")),
    c("clinic", "antibiotic", "anesthetic", "epidemic", "topic")
  )
})

test_that("a label shows the spelling its works use most often", {
  skip_if_not_installed("tidytext")
  hip <- c("Hip fractures in the elderly", "Hip fractures after falls",
           "Surgery of hip fractures", "Hip fracture surgery")
  corpus <- label_corpus(c(hip, heat_titles), rep(1:2, each = 4))
  out <- suppressMessages(sm_cluster_label(corpus, ngram = 1))
  terms <- strsplit(labels_by_cluster(out)[["1"]], "; ", fixed = TRUE)[[1]]
  expect_true("fractures" %in% terms)
  expect_false("fracture" %in% terms)
})

test_that("German stop words leave the labels of German works", {
  skip_if_not_installed("tidytext")
  skip_if_not_installed("stopwords")
  de <- stopwords::stopwords("de", source = "snowball")
  for (method in c("tfidf", "yake")) {
    out <- suppressMessages(sm_cluster_label(german_cluster(),
                                             method = method))
    label <- labels_by_cluster(out)[["1"]]
    expect_false(is.na(label))
    words <- strsplit(label, "; | ")[[1]]
    expect_false(any(words %in% de))
  }
})

test_that("stop words of a work's language stay out of other works", {
  skip_if_not_installed("tidytext")
  skip_if_not_installed("stopwords")
  # "war" is a German stop word (was) and an English content word
  english <- c("War surgery in field hospitals", "War injuries of the limbs",
               "Lessons from war surgery", "Blast injuries in war")
  german <- c("Die Versorgung im Krieg war schwierig",
              "Versorgung im Krieg und danach",
              "Krieg und Versorgung in Kliniken",
              "Versorgung nach dem Krieg")
  corpus <- label_corpus(c(english, german), rep(1:2, each = 4),
                         language = rep(c("en", "ger"), each = 4))
  out <- suppressMessages(sm_cluster_label(corpus, ngram = 1))
  labels <- labels_by_cluster(out)
  expect_match(labels[["1"]], "\\bwar\\b")
  expect_false(grepl("\\b(war|und|die|im)\\b", labels[["2"]]))
})

test_that("without the stopwords package English stop words are used", {
  skip_if_not_installed("tidytext")
  local_mocked_bindings(.has_stopwords = function() FALSE)
  res <- count_messages(sm_cluster_label(german_cluster()),
                        "scimapR_cluster_label_no_stopwords")
  expect_identical(res$n, 1L)
  labels <- labels_by_cluster(res$value)
  expect_false(anyNA(labels))
  # an English-only corpus needs no message
  english <- label_corpus(c(bleeding_titles, heat_titles),
                          rep(1:2, each = 4))
  res <- count_messages(sm_cluster_label(english),
                        "scimapR_cluster_label_no_stopwords")
  expect_identical(res$n, 0L)
})

test_that("languages without a stop-word list are named once", {
  skip_if_not_installed("tidytext")
  skip_if_not_installed("stopwords")
  corpus <- label_corpus(c(bleeding_titles, heat_titles), rep(1:2, each = 4),
                         language = rep(c("Polish", "pl"), 4L))
  res <- count_messages(sm_cluster_label(corpus),
                        "scimapR_cluster_label_stopwords_unsupported")
  expect_identical(res$n, 1L)
  expect_false(anyNA(labels_by_cluster(res$value)))
})

keyword_concepts <- function() {
  kw <- function(work, name, vocab) {
    data.frame(work_id = sprintf("W%03d", work), concept_id = NA_character_,
               concept_name = name, level = NA_integer_, score = NA_real_,
               vocabulary = vocab, stringsAsFactors = FALSE)
  }
  rbind(
    # cluster 1: every work has "Sepsis" twice (DE and ID), three of five
    # name the more specific "testicular cancer"
    kw(1:5, "Sepsis", "author-keywords"),
    kw(1:5, "SEPSIS", "keywords-plus"),
    kw(1:5, "CANCER", "keywords-plus"),
    kw(1:3, "Testicular Cancer", "author-keywords"),
    kw(1:3, "TESTICULAR CANCER", "keywords-plus"),
    # cluster 2: keywords that occur once each
    kw(6:10, paste("topic", 6:10), "author-keywords")
  )
}

test_that("keywords: scored per work, specific terms, author spelling", {
  skip_if_not_installed("tidytext")
  titles <- c(paste("Sepsis after orchiectomy, case", 1:5),
              paste("Snakebite envenomation in rural clinics, report", 1:5))
  corpus <- label_corpus(titles, rep(1:2, each = 5),
                         concepts = keyword_concepts())
  out <- suppressMessages(sm_cluster_label(corpus, method = "keywords"))
  labels <- labels_by_cluster(out)
  basis <- labels_by_cluster(out, "cluster_label_basis")
  terms <- strsplit(labels[["1"]], "; ", fixed = TRUE)[[1]]
  expect_true(all(c("Sepsis", "Testicular Cancer") %in% terms))
  expect_false(any(c("cancer", "CANCER", "SEPSIS") %in% terms))
  expect_identical(basis[["1"]], "keywords")
  # cluster 2 has no keyword in two works: labelled from its titles
  expect_identical(basis[["2"]], "tfidf (fallback)")
  expect_match(labels[["2"]], "snakebite envenomation", fixed = TRUE)
  # a work counts once per keyword: "sepsis" is in 5 works, not 10
  out6 <- suppressMessages(
    sm_cluster_label(corpus, method = "keywords", min_works = 6L)
  )
  expect_identical(labels_by_cluster(out6, "cluster_label_basis")[["1"]],
                   "keywords (relaxed)")
})

test_that("keywords fall back to titles when there are none", {
  skip_if_not_installed("tidytext")
  corpus <- label_corpus(c(bleeding_titles, heat_titles), rep(1:2, each = 4))
  suppressMessages(expect_message(
    out <- sm_cluster_label(corpus, method = "keywords"),
    class = "scimapR_cluster_label_no_keywords"
  ))
  expect_identical(unique(out$works$cluster_label_basis), "tfidf (fallback)")
  expect_false(anyNA(out$works$cluster_label))
})

test_that("sm_cluster_label llm requires a provider", {
  corpus <- make_clustered_corpus(seed = 6)
  expect_error(
    sm_cluster_label(corpus, method = "llm", llm_provider = NULL),
    "llm_provider"
  )
})

test_that("sm_cluster_label llm uses a mocked provider", {
  corpus <- make_clustered_corpus(seed = 7)
  local_mocked_bindings(.check_llm_available = function(...) NULL)
  fake_provider <- fake_chat(function(x) "Mocked Topic Label")
  out <- suppressMessages(
    sm_cluster_label(corpus, method = "llm", llm_provider = fake_provider)
  )
  expect_true("cluster_label" %in% names(out$works))
  labels <- unique(out$works$cluster_label[!is.na(out$works$cluster_id)])
  expect_true("Mocked Topic Label" %in% labels)
  expect_true(all(out$works$cluster_label_basis == "llm"))
})

test_that("sm_cluster_label llm leaves noise unlabelled", {
  skip_if_not_installed("ellmer")
  corpus <- label_corpus(c(bleeding_titles, heat_titles),
                         c(1L, 1L, 1L, 1L, 0L, 0L, 0L, 0L))
  asked <- 0L
  local_mocked_bindings(.check_llm_available = function(...) NULL)
  fake_provider <- fake_chat(function(x) {
    asked <<- asked + 1L
    "Mocked Topic Label"
  })
  out <- suppressMessages(
    sm_cluster_label(corpus, method = "llm", llm_provider = fake_provider)
  )
  expect_identical(asked, 1L)
  expect_true(all(is.na(out$works$cluster_label[5:8])))
  expect_identical(out$works$cluster_label[1:4],
                   rep("Mocked Topic Label", 4L))
})

test_that("sm_cluster_label keeps the label columns typed on empty input", {
  skip_if_not_installed("tidytext")
  corpus <- label_corpus(bleeding_titles, 1L)
  corpus$works <- corpus$works[0L, ]
  out <- sm_cluster_label(corpus)
  expect_identical(out$works$cluster_label, character())
  expect_identical(out$works$cluster_label_basis, character())
  only_noise <- label_corpus(bleeding_titles, 0L)
  out <- suppressMessages(sm_cluster_label(only_noise))
  expect_type(out$works$cluster_label, "character")
  expect_true(all(is.na(out$works$cluster_label)))
})


test_that("provider labels use fresh chats and reproducible title samples", {
  local_mocked_bindings(.check_llm_available = function(...) NULL)
  corpus <- label_corpus(paste("Invented title", 1:60), rep(1:2, each = 30))
  ch <- fake_chat(function(x) "Topic")
  set.seed(55)
  before <- .Random.seed
  for (i in 1:2) {
    out <- suppressMessages(sm_cluster_label(corpus, method = "llm",
                                             llm_provider = ch, seed = 1))
    expect_identical(.Random.seed, before)
    expect_true(all(out$works$cluster_label == "Topic"))
  }
  calls <- ch$log$calls
  expect_length(calls, 4L)
  expect_identical(calls[[1]]$user_text, calls[[3]]$user_text)
  expect_identical(calls[[2]]$user_text, calls[[4]]$user_text)
  expect_length(ch$turns, 0L)
  for (entry in calls) {
    expect_identical(entry$n_turns, 0L)
    json <- regmatches(entry$user_text,
                       regexpr("(?s)\\[.*\\]", entry$user_text, perl = TRUE))
    expect_length(jsonlite::parse_json(json), 20L)
    expect_match(entry$system_prompt, "data", fixed = TRUE)
  }
  expect_error(sm_cluster_label(corpus, method = "llm",
                                llm_provider = list(chat = identity)),
               class = "scimapR_chat_provider_invalid")
})
