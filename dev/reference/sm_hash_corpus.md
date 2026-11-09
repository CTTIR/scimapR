# Hash a corpus for reproducibility

Computes a content-addressable SHA-256 hash of the corpus. The hash
covers the works (without `last_refreshed`), authors, authorships,
institutions, sources, references, concepts, screening decisions
(without `decided_at`) and embeddings, and the yearly citation counts
(`citations_by_year`) when the corpus has any, so a corpus without them
hashes as it did before the element existed.

Two corpora with identical scientific content will produce the same
hash, regardless of when they were built and of the order of their rows
and columns.

The hash leaves out the provenance table, which records when each record
was fetched, and the metadata (timestamps, the lock, the embedding model
and the local input files of
[`sm_register_input()`](https://cttir.github.io/scimapR/dev/reference/sm_register_input.md)):
changing them does not change the hash.
[`sm_verify_certificate()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md)
checks the local input files on their own.

## Usage

``` r
sm_hash_corpus(corpus, version = 2L)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- version:

  The hash algorithm: `2` (default) or `1` (scimapR 0.4.0 and earlier).
  See Details.

## Value

A single character string containing the hex-encoded SHA-256 hash.

## Details

`version` selects the algorithm. Version 2, the default from scimapR
0.5.0 on, hashes canonical UTF-8 text, independently of R's binary
serialisation. Table columns are sorted by name and rows by their text
values, using radix ordering. Missing values are distinct from the
string `"NA"`. Numbers use 15 significant digits, signed zero becomes
zero, dates use ISO dates and timestamps use UTC with six decimal places
for seconds. List cells use JSON. Column classes are included in the
text. Embeddings are sorted by work id and rounded to eight decimal
places. These rules make version 2 independent of the R version,
platform, time zone and collation locale. Hashes of version 2 therefore
differ from the hashes that earlier versions of scimapR computed for the
same content. Version 1 is the algorithm of these earlier versions.
Certificates
([`sm_certificate()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md))
and snapshots
([`sm_snapshot()`](https://cttir.github.io/scimapR/dev/reference/sm_snapshot.md))
record the version they used as `hash_version`; those written before it
existed are checked with version 1. Version 1 uses R's binary
serialisation and depends on the R version: older certificates and
snapshots remain verifiable on the R version that wrote them.

## See also

Other reproducibility:
[`sm_certificate()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md),
[`sm_cite_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_cite_corpus.md),
[`sm_diff_corpora()`](https://cttir.github.io/scimapR/dev/reference/sm_diff_corpora.md),
[`sm_provenance()`](https://cttir.github.io/scimapR/dev/reference/sm_provenance.md),
[`sm_register_input()`](https://cttir.github.io/scimapR/dev/reference/sm_register_input.md),
[`sm_snapshot()`](https://cttir.github.io/scimapR/dev/reference/sm_snapshot.md)

## Examples

``` r
corpus <- sm_example_corpus()
sm_hash_corpus(corpus)
#> [1] "61c0637eede72e86bf489cf7d8a27949789b82485ea6646cc707da9ec1945bb6"

# the order of the columns does not matter
reordered <- corpus
reordered$works <- reordered$works[, rev(names(reordered$works))]
identical(sm_hash_corpus(reordered), sm_hash_corpus(corpus))
#> [1] TRUE
```
