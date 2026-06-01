# Building a Corpus from Files and APIs

## File ingestion

scimapR reads 12 bibliographic formats with native clean-room parsers.

``` r

library(scimapR)

# List available example files
sm_example_files()
#>  [1] "example_dimensions.csv"         "example_journal_index.csv"     
#>  [3] "example_lens.csv"               "example_openalex_inverted.json"
#>  [5] "example_openalex.json"          "example_pubmed.xml"            
#>  [7] "example_ror.csv"                "example_scopus.csv"            
#>  [9] "example_sparse.bib"             "example_wos.txt"               
#> [11] "example.bib"                    "example.ris"
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
