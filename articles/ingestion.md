# Building a Corpus from Files and APIs

[![R-CMD-check](https://github.com/CTTIR/scimapR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/CTTIR/scimapR/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/CTTIR/scimapR/actions/workflows/pkgdown.yaml/badge.svg)](https://cttir.github.io/scimapR/)
[![CRAN
status](https://www.r-pkg.org/badges/version/scimapR)](https://CRAN.R-project.org/package=scimapR)
[![Codecov test
coverage](https://codecov.io/gh/CTTIR/scimapR/branch/main/graph/badge.svg)](https://app.codecov.io/gh/CTTIR/scimapR?branch=main)
[![CRAN
downloads](https://cranlogs.r-pkg.org/badges/scimapR)](https://cran.r-project.org/package=scimapR)
[![CRAN downloads
total](https://cranlogs.r-pkg.org/badges/grand-total/scimapR)](https://cran.r-project.org/package=scimapR)
[![License:
MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)

## Bring your own relational data (recommended)

If your data is already tabular – a manual tracker, an institutional
export, a spreadsheet of works – the most robust entry point is
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/reference/sm_corpus_from_tables.md).
It validates the required columns, coerces types, fills missing optional
tables with correctly-typed 0-row tibbles, and returns a ready
`sm_corpus`, side-stepping format-specific parsers entirely. A
works-only corpus is perfectly valid:

``` r

works <- data.frame(
  work_id = paste0("W", 1:3),
  title = c("Spatial transcriptomics in cancer",
            "Immune checkpoint resistance",
            "A biomarker discovery cohort"),
  year = c("2019", "2020", "2021"),   # character -> coerced to integer
  doi = paste0("10.1234/example.", 1:3),
  cited_by_count = c(12, 5, 1)
)
corpus <- sm_corpus_from_tables(list(works = works))
#> ℹ works: coerced column year and cited_by_count to the schema type.
#> ℹ works: filled missing column abstract, type, source_id, oa_status, language,
#>   pmid, arxiv_id, openalex_id, is_retracted, retraction_date, and
#>   last_refreshed with typed `NA`.
corpus
#> 
#> ── <sm_corpus> ─────────────────────────────────────────────────────────────────
#> Works: 3 | Authors: 0 | Institutions: 0
#> Years: 2019 - 2021
#> Sources (journals): 0
#> Embeddings: none
#> Status: Unlocked (last refreshed: never)
```

You can pass any of `works`, `authorships`, `sources`, `institutions`,
`references`, `concepts`, etc. as named list elements.

### Materialising cached enrichment

Once you have a corpus, fold cached enrichment (a metrics table, a
citation cache, …) into it with
[`sm_materialise()`](https://cttir.github.io/scimapR/reference/sm_materialise.md)
rather than hand-writing the join. It matches by key, fills `NA` cells
(or replaces with `overwrite = TRUE`), and returns a schema-valid corpus
— avoiding the classic `bind_rows()` bug where a `NULL` element silently
becomes a logical column.

``` r

metrics <- data.frame(work_id = corpus$works$work_id,
                      cnci = c(1.4, 0.8, 1.1))
corpus <- sm_materialise(corpus, sources = list(works = metrics))
#> ✔ Materialised 3 enrichment rows into works (+1 column).
"cnci" %in% names(corpus$works)
#> [1] TRUE
```

## File ingestion

scimapR reads 12 bibliographic formats with native clean-room parsers.

``` r

# List available example files
sm_example_files()
#>  [1] "example_affiliation_postcode.csv" "example_dimensions.csv"          
#>  [3] "example_journal_index.csv"        "example_lens.csv"                
#>  [5] "example_openalex_inverted.json"   "example_openalex.json"           
#>  [7] "example_pubmed.xml"               "example_ror.csv"                 
#>  [9] "example_scopus.csv"               "example_self_citation_corpus.rds"
#> [11] "example_sparse.bib"               "example_wos.txt"                 
#> [13] "example.bib"                      "example.ris"
```

``` r

# Read a BibTeX file
bib_path <- sm_example_files("example.bib")
corpus_bib <- sm_read_bib(bib_path)
#> ℹ Reading BibTeX file:
#>   /home/runner/work/_temp/Library/scimapR/extdata/example.bib
#> ℹ Parsed 3 BibTeX entries.
print(corpus_bib)
#> 
#> ── <sm_corpus> ─────────────────────────────────────────────────────────────────
#> Works: 3 | Authors: 9 | Institutions: 0
#> Years: 2022 - 2024
#> Sources (journals): 2
#> Embeddings: none
#> Provenance: bibtex (3)
#> Status: Unlocked (last refreshed: never)
```

``` r

# Read an RIS file
ris_path <- sm_example_files("example.ris")
corpus_ris <- sm_read_ris(ris_path)
#> ℹ Reading RIS file: /home/runner/work/_temp/Library/scimapR/extdata/example.ris
#> ℹ Parsed 3 RIS records.
nrow(corpus_ris$works)
#> [1] 3
```

## Combining multiple sources

``` r

combined <- sm_build_corpus(corpus_bib, corpus_ris, dedupe = TRUE)
#> ✔ Removed 3 duplicate works by DOI.
nrow(combined$works)
#> [1] 3
```

## Auto-detection

``` r

corpus_auto <- sm_read_auto(bib_path)
#> ℹ Detected format: "bibtex"
#> ℹ Reading BibTeX file:
#>   /home/runner/work/_temp/Library/scimapR/extdata/example.bib
#> ℹ Parsed 3 BibTeX entries.
nrow(corpus_auto$works)
#> [1] 3
```

## API fetching

For API-based ingestion, set your email for polite pool access:

``` r

Sys.setenv(SCIMAPR_MAILTO = "your.email@example.com")

# Fetch from OpenAlex
corpus <- sm_fetch_openalex(
 query = "spatial transcriptomics colorectal cancer",
 n_max = 100
)
```

All API fetchers populate the provenance table for reproducibility
tracking.

## Deduplication

``` r

corpus <- sm_example_corpus()
deduped <- sm_dedupe(corpus)
```

## Validation

``` r

issues <- sm_validate(corpus)
nrow(issues)
#> [1] 0
```
