# Deduplicate corpus works by DOI

Remove duplicate works, preferring the record with more complete data.

## Usage

``` r
sm_dedupe(corpus, by = "doi", verbose = TRUE)
```

## Arguments

- corpus:

  An `sm_corpus`.

- by:

  Column(s) to deduplicate by. Default `"doi"`.

- verbose:

  Logical; show progress?

## Value

An `sm_corpus` object.

## See also

Other corpus:
[`as_sm_corpus()`](https://cttir.github.io/scimapR/reference/as_sm_corpus.md),
[`is_sm_corpus()`](https://cttir.github.io/scimapR/reference/is_sm_corpus.md),
[`sm_bind_corpora()`](https://cttir.github.io/scimapR/reference/sm_bind_corpora.md),
[`sm_build_corpus()`](https://cttir.github.io/scimapR/reference/sm_build_corpus.md),
[`sm_corpus()`](https://cttir.github.io/scimapR/reference/sm_corpus.md),
[`sm_save_corpus()`](https://cttir.github.io/scimapR/reference/sm_save_corpus.md),
[`sm_validate()`](https://cttir.github.io/scimapR/reference/sm_validate.md),
[`validate_sm_corpus()`](https://cttir.github.io/scimapR/reference/validate_sm_corpus.md)
