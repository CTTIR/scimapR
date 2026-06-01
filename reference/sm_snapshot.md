# Save and load corpus snapshots

`sm_snapshot()` serializes an `sm_corpus` to disk as a compressed RDS
file, embedding the corpus hash as part of the filename for
traceability.

`sm_snapshot_load()` reads a previously saved snapshot and validates
that the loaded object is a well-formed `sm_corpus`.

## Usage

``` r
sm_snapshot(
  corpus,
  path = NULL,
  compress = c("xz", "gzip", "bzip2", "none"),
  call = rlang::caller_env()
)

sm_snapshot_load(path, call = rlang::caller_env())
```

## Arguments

- corpus:

  An `sm_corpus` object.

- path:

  Character. File path for the snapshot. If `NULL`, a path is generated
  in the current working directory using the corpus hash.

- compress:

  Character. Compression method passed to
  [`saveRDS()`](https://rdrr.io/r/base/readRDS.html). One of `"xz"`
  (default, best compression), `"gzip"`, `"bzip2"`, or `"none"`.

- call:

  Caller environment for error reporting.

## Value

For `sm_snapshot()`: the file path (invisibly). For
`sm_snapshot_load()`: an `sm_corpus` object.

## See also

Other reproducibility:
[`sm_certificate()`](https://cttir.github.io/scimapR/reference/sm_certificate.md),
[`sm_cite_corpus()`](https://cttir.github.io/scimapR/reference/sm_cite_corpus.md),
[`sm_diff_corpora()`](https://cttir.github.io/scimapR/reference/sm_diff_corpora.md),
[`sm_hash_corpus()`](https://cttir.github.io/scimapR/reference/sm_hash_corpus.md),
[`sm_provenance()`](https://cttir.github.io/scimapR/reference/sm_provenance.md)

## Examples

``` r
corpus <- sm_example_corpus()
path <- tempfile(fileext = ".rds")
sm_snapshot(corpus, path = path)
#> ✔ Corpus snapshot saved to /tmp/Rtmp9NJRZU/file254d7fa6420.rds.
#> ℹ Size: 122K | Hash: ea446b5f4465

loaded <- sm_snapshot_load(path)
#> ✔ Loaded corpus from /tmp/Rtmp9NJRZU/file254d7fa6420.rds.
#> ℹ 200 works, 80 authors.
identical(nrow(corpus$works), nrow(loaded$works))
#> [1] TRUE
```
