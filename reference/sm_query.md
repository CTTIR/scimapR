# Search works by text query

Full-text search across titles and abstracts in a corpus.

## Usage

``` r
sm_query(corpus, query, fields = c("title", "abstract"), ignore_case = TRUE)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- query:

  A search string (regex supported).

- fields:

  Which fields to search. Default `c("title", "abstract")`.

- ignore_case:

  Logical; case-insensitive search?

## Value

An `sm_corpus` with matching works.

## See also

Other filters:
[`sm_filter_works()`](https://cttir.github.io/scimapR/reference/sm_filter_works.md)

## Examples

``` r
corpus <- sm_example_corpus()
results <- sm_query(corpus, "transcriptomics")
```
