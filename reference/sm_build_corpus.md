# Build a corpus from multiple sources

Combine multiple file reads and/or API fetches into a single
deduplicated `sm_corpus`.

## Usage

``` r
sm_build_corpus(..., dedupe = TRUE, verbose = TRUE)
```

## Arguments

- ...:

  One or more `sm_corpus` objects or file paths.

- dedupe:

  Logical; deduplicate by DOI after combining?

- verbose:

  Logical; show progress messages?

## Value

An `sm_corpus` object.

## See also

Other corpus:
[`as_sm_corpus()`](https://r-heller.github.io/scimapR/reference/as_sm_corpus.md),
[`is_sm_corpus()`](https://r-heller.github.io/scimapR/reference/is_sm_corpus.md),
[`sm_bind_corpora()`](https://r-heller.github.io/scimapR/reference/sm_bind_corpora.md),
[`sm_corpus()`](https://r-heller.github.io/scimapR/reference/sm_corpus.md),
[`sm_dedupe()`](https://r-heller.github.io/scimapR/reference/sm_dedupe.md),
[`sm_save_corpus()`](https://r-heller.github.io/scimapR/reference/sm_save_corpus.md),
[`sm_validate()`](https://r-heller.github.io/scimapR/reference/sm_validate.md),
[`validate_sm_corpus()`](https://r-heller.github.io/scimapR/reference/validate_sm_corpus.md)

## Examples

``` r
c1 <- sm_example_corpus(n_works = 50, seed = 1)
c2 <- sm_example_corpus(n_works = 50, seed = 2)
combined <- sm_build_corpus(c1, c2, dedupe = TRUE)
#> ✔ Removed 50 duplicate works by DOI.
```
