# Hash a corpus for reproducibility

Computes a content-addressable SHA-256 hash of the corpus. The hash
captures the works, authors, authorships, references, concepts,
screening, and provenance tables. Metadata (which contains timestamps)
is excluded from the hash to allow comparing corpus content across
sessions.

Two corpora with identical scientific content will produce the same
hash, regardless of when they were built.

## Usage

``` r
sm_hash_corpus(corpus)
```

## Arguments

- corpus:

  An `sm_corpus` object.

## Value

A single character string containing the hex-encoded SHA-256 hash.

## See also

Other reproducibility:
[`sm_certificate()`](https://r-heller.github.io/scimapR/reference/sm_certificate.md),
[`sm_cite_corpus()`](https://r-heller.github.io/scimapR/reference/sm_cite_corpus.md),
[`sm_diff_corpora()`](https://r-heller.github.io/scimapR/reference/sm_diff_corpora.md),
[`sm_provenance()`](https://r-heller.github.io/scimapR/reference/sm_provenance.md),
[`sm_snapshot()`](https://r-heller.github.io/scimapR/reference/sm_snapshot.md)

## Examples

``` r
corpus <- sm_example_corpus()
sm_hash_corpus(corpus)
#> [1] "ea446b5f44659ca0804636faa6e2c6cb66dacc49278ed0ffb03b415cac54dee4"
```
