# Save and load an sm_corpus

Persist a corpus to disk as RDS and reload it.

## Usage

``` r
sm_save_corpus(corpus, path, compress = "xz")

sm_load_corpus(path)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- path:

  File path for saving.

- compress:

  Compression type passed to
  [`saveRDS()`](https://rdrr.io/r/base/readRDS.html).

## Value

For `sm_save_corpus`, the path invisibly. For `sm_load_corpus`, an
`sm_corpus` object.

## See also

Other corpus:
[`as_sm_corpus()`](https://cttir.github.io/scimapR/reference/as_sm_corpus.md),
[`is_sm_corpus()`](https://cttir.github.io/scimapR/reference/is_sm_corpus.md),
[`sm_bind_corpora()`](https://cttir.github.io/scimapR/reference/sm_bind_corpora.md),
[`sm_build_corpus()`](https://cttir.github.io/scimapR/reference/sm_build_corpus.md),
[`sm_corpus()`](https://cttir.github.io/scimapR/reference/sm_corpus.md),
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/reference/sm_corpus_from_tables.md),
[`sm_dedupe()`](https://cttir.github.io/scimapR/reference/sm_dedupe.md),
[`sm_materialise()`](https://cttir.github.io/scimapR/reference/sm_materialise.md),
[`sm_validate()`](https://cttir.github.io/scimapR/reference/sm_validate.md),
[`validate_sm_corpus()`](https://cttir.github.io/scimapR/reference/validate_sm_corpus.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 10)
path <- tempfile(fileext = ".rds")
sm_save_corpus(corpus, path)
#> ✔ Corpus saved to /tmp/Rtmp6vKbQn/file249a2105517.rds
loaded <- sm_load_corpus(path)
nrow(loaded$works)
#> [1] 10
```
