# Create, rebuild from, and verify corpus certificates

A corpus certificate is a self-contained YAML document that captures
every query, file, enrichment, embedding, screening decision, and chat
interaction used to produce a corpus. It enables exact re-derivation of
the corpus from scratch.

`sm_certificate()` creates a certificate from a corpus.
`sm_rebuild_from_cert()` re-runs every recorded step to reconstruct the
corpus. `sm_verify_certificate()` compares a live corpus against a
certificate to detect divergence.

## Usage

``` r
sm_certificate(corpus, path = NULL, call = rlang::caller_env())

sm_rebuild_from_cert(cert, verbose = TRUE, call = rlang::caller_env())

sm_verify_certificate(corpus, cert, call = rlang::caller_env())

# S3 method for class 'sm_certificate'
print(x, ...)

# S3 method for class 'sm_cert_verification'
print(x, ...)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- path:

  Character. Optional file path to write the certificate YAML. If
  `NULL`, the certificate is returned but not written to disk.

- call:

  Caller environment for error reporting.

- cert:

  A certificate object (list) or path to a YAML certificate file.

- verbose:

  Logical. Print progress?

- x:

  An `sm_certificate` or `sm_cert_verification` object.

- ...:

  Ignored.

## Value

For `sm_certificate()`: an `sm_certificate` S3 object (list), also
written to `path` if provided. For `sm_rebuild_from_cert()`: an
`sm_corpus` reconstructed from the certificate. For
`sm_verify_certificate()`: an `sm_cert_verification` S3 object with
pass/fail and details.

`x` invisibly (print methods).

## Details

Certificates write their timestamps (`created` and the corpus's
`build_date` and `last_refresh`) in UTC as ISO 8601 text, for example
`2026-10-17T11:45:00Z`, and read back both this form and the older one
with a numeric offset. Printing a certificate shows `created` in UTC as
well, so a certificate read back from YAML prints the same time as the
one it was written from. The corpus timestamps may be stored as POSIXct,
a Date, numeric seconds since 1970-01-01 UTC (as in corpora restored
from tables) or ISO 8601 text. A missing or implausible value is written
as `NA`.

## See also

Other reproducibility:
[`sm_cite_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_cite_corpus.md),
[`sm_diff_corpora()`](https://cttir.github.io/scimapR/dev/reference/sm_diff_corpora.md),
[`sm_hash_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_hash_corpus.md),
[`sm_provenance()`](https://cttir.github.io/scimapR/dev/reference/sm_provenance.md),
[`sm_snapshot()`](https://cttir.github.io/scimapR/dev/reference/sm_snapshot.md)

## Examples

``` r
corpus <- sm_example_corpus()
cert <- sm_certificate(corpus)
#> ✔ Certificate created. Corpus hash: ea446b5f4465
print(cert)
#> 
#> ── <sm_certificate> ────────────────────────────────────────────────────────────
#> Version: 1.0
#> Created: 2026-10-19 15:54:19 UTC
#> scimapR: v0.4.0.9000
#> R: 4.6.1 (unix)
#> 
#> Corpus hash: ea446b5f44659ca0
#> Works: 200
#> Authors: 80
#> References: 1869
#> Queries: 1
verification <- sm_verify_certificate(corpus, cert)
print(verification)
#> 
#> ── <sm_cert_verification> ──────────────────────────────────────────────────────
#> Result: PASS
#> 
#> corpus_hash: expected ea446b5f44659ca0, got ea446b5f44659ca0
#> n_works: expected 200, got 200
#> n_authors: expected 80, got 80
#> n_institutions: expected 0, got 0
#> n_references: expected 1869, got 1869
```
