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

## See also

Other reproducibility:
[`sm_cite_corpus()`](https://r-heller.github.io/scimapR/reference/sm_cite_corpus.md),
[`sm_diff_corpora()`](https://r-heller.github.io/scimapR/reference/sm_diff_corpora.md),
[`sm_hash_corpus()`](https://r-heller.github.io/scimapR/reference/sm_hash_corpus.md),
[`sm_provenance()`](https://r-heller.github.io/scimapR/reference/sm_provenance.md),
[`sm_snapshot()`](https://r-heller.github.io/scimapR/reference/sm_snapshot.md)

## Examples

``` r
corpus <- sm_example_corpus()
cert <- sm_certificate(corpus)
#> ✔ Certificate created. Corpus hash: ea446b5f4465
print(cert)
#> 
#> ── <sm_certificate> ────────────────────────────────────────────────────────────
#> Version: 1.0
#> Created: 2026-05-09 07:23:17
#> scimapR: v0.1.0
#> R: 4.6.0 (unix)
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
