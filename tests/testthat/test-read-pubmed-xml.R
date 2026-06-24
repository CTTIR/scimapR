.pubmed_fixture <- function() {
  path <- system.file("extdata", "example_pubmed.xml", package = "scimapR")
  if (!nzchar(path)) {
    path <- testthat::test_path("../../inst/extdata", "example_pubmed.xml")
  }
  path
}

test_that("sm_read_pubmed_xml parses the bundled example_pubmed.xml", {
  path <- .pubmed_fixture()
  expect_true(file.exists(path))

  corpus <- sm_read_pubmed_xml(path, verbose = FALSE)

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 3L)

  expect_equal(corpus$works$pmid, c("37654321", "36543210", "38765432"))
  expect_match(corpus$works$title[1],
               "Spatial transcriptomics reveals tumor microenvironment")
  expect_identical(corpus$works$year, c(2023L, 2022L, 2024L))
  expect_match(corpus$works$abstract[1], "Spatial transcriptomics enables")
})

test_that("sm_read_pubmed_xml builds journals, authors and provenance", {
  path <- .pubmed_fixture()
  corpus <- sm_read_pubmed_xml(path, verbose = FALSE)

  expect_true("Nature Medicine" %in% corpus$sources$display_name)
  expect_true("Genome Biology" %in% corpus$sources$display_name)
  expect_equal(nrow(corpus$authorships), 9L)
  expect_true("Wei Chen" %in% corpus$authors$display_name)

  expect_equal(unique(corpus$provenance$source), "pubmed")
  expect_equal(corpus$provenance$source_id_external[1], "37654321")
})

test_that("sm_read_pubmed_xml extracts DOI, language, type, MeSH and affiliations", {
  xml <- paste(
    '<?xml version="1.0"?>',
    "<PubmedArticleSet><PubmedArticle><MedlineCitation>",
    "<PMID>111</PMID><Article>",
    "<Journal><Title>J Test</Title><ISSN>1234-5678</ISSN>",
    "<JournalIssue><PubDate><MedlineDate>2019 Spring</MedlineDate>",
    "</PubDate></JournalIssue></Journal>",
    "<ArticleTitle>Full Article</ArticleTitle>",
    '<Abstract><AbstractText Label="BACKGROUND">Bg text.</AbstractText>',
    '<AbstractText Label="METHODS">Method text.</AbstractText></Abstract>',
    "<AuthorList>",
    "<Author><LastName>Smith</LastName><ForeName>John</ForeName>",
    "<AffiliationInfo><Affiliation>Univ A</Affiliation></AffiliationInfo>",
    "</Author>",
    "<Author><CollectiveName>The Study Group</CollectiveName></Author>",
    "</AuthorList>",
    "<Language>eng</Language>",
    "<PublicationTypeList><PublicationType>Review</PublicationType>",
    "</PublicationTypeList></Article>",
    "<MeshHeadingList>",
    "<MeshHeading><DescriptorName>Neoplasms</DescriptorName></MeshHeading>",
    "<MeshHeading><DescriptorName>Genomics</DescriptorName></MeshHeading>",
    "</MeshHeadingList></MedlineCitation>",
    "<PubmedData><ArticleIdList>",
    '<ArticleId IdType="doi">10.9/full</ArticleId>',
    "</ArticleIdList></PubmedData>",
    "</PubmedArticle></PubmedArticleSet>",
    sep = "\n"
  )
  path <- withr::local_tempfile(fileext = ".xml")
  writeLines(xml, path)

  corpus <- sm_read_pubmed_xml(path, verbose = FALSE)

  expect_equal(corpus$works$doi, "10.9/full")
  expect_equal(corpus$works$year, 2019L)         # parsed from MedlineDate
  expect_equal(corpus$works$language, "eng")
  expect_equal(corpus$works$type, "Review")
  # labeled abstract sections are concatenated with their labels
  expect_equal(corpus$works$abstract,
               "BACKGROUND: Bg text. METHODS: Method text.")
  expect_equal(corpus$sources$issn_l[1], "1234-5678")

  # author with ForeName + LastName, plus a collective-name author
  expect_setequal(corpus$authors$display_name,
                  c("John Smith", "The Study Group"))
  expect_equal(
    corpus$authorships$raw_affiliation[corpus$authorships$position == 1L],
    "Univ A"
  )

  # MeSH descriptors become concepts in the "mesh" vocabulary
  expect_setequal(corpus$concepts$concept_name, c("Neoplasms", "Genomics"))
  expect_equal(unique(corpus$concepts$vocabulary), "mesh")
})

test_that("sm_read_pubmed_xml returns an empty corpus when no articles", {
  path <- withr::local_tempfile(fileext = ".xml")
  writeLines('<?xml version="1.0"?><PubmedArticleSet></PubmedArticleSet>', path)

  corpus <- sm_read_pubmed_xml(path, verbose = FALSE)

  expect_s3_class(corpus, "sm_corpus")
  expect_equal(nrow(corpus$works), 0L)
  expect_equal(corpus$metadata$reader, "sm_read_pubmed_xml")
})

test_that("sm_read_pubmed_xml errors on a missing file", {
  expect_error(
    sm_read_pubmed_xml(tempfile(fileext = ".xml"), verbose = FALSE),
    "File not found"
  )
})

test_that("sm_read_pubmed_xml rejects an unknown engine value", {
  path <- .pubmed_fixture()
  expect_error(sm_read_pubmed_xml(path, engine = "bogus", verbose = FALSE))
})

test_that("sm_read_pubmed_xml emits a progress message only when verbose", {
  path <- .pubmed_fixture()
  expect_message(sm_read_pubmed_xml(path, verbose = TRUE), "PubMed")
  expect_silent(sm_read_pubmed_xml(path, verbose = FALSE))
})
