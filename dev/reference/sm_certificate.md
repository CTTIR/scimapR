# Create, rebuild from, and verify corpus certificates

A corpus certificate is a self-contained YAML document that records how
a corpus was made and lets others check it: the corpus hash
([`sm_hash_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_hash_corpus.md))
and the size of its tables, the steps recorded in its provenance
(searches, file reads, enrichments and refreshes), a summary of its
screening decisions, its embeddings and their model, and the local input
files registered with
[`sm_register_input()`](https://cttir.github.io/scimapR/dev/reference/sm_register_input.md),
each with its SHA-256 hash.

`sm_certificate()` creates a certificate from a corpus.
`sm_verify_certificate()` compares a live corpus, and its local input
files, against a certificate to detect divergence.
`sm_rebuild_from_cert()` runs the recorded searches again (see
"Rebuilding a corpus"); file reads and local inputs cannot be replayed,
and verification checks them instead.

Each recorded step (`queries`) has a `source`, `query`, `engine` and
`kind`: `"api_query"` for searches of a bibliographic API, `"file"` for
records read from a local file (the file relative to the working
directory when it lies below it, else its name), `"enrichment"` for
steps such as
[`sm_enrich_openalex_impact()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_openalex_impact.md)
that added fields to works already in the corpus, `"refresh"` for
[`sm_refresh()`](https://cttir.github.io/scimapR/dev/reference/sm_refresh.md)
and `"manual"` for synthetic records. The searches of
[`sm_fetch_openalex()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_openalex.md),
[`sm_fetch_pubmed()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_pubmed.md),
[`sm_fetch_crossref()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_crossref.md)
and
[`sm_corpus_for_question()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_for_question.md)
also record their `filter` and `n_max`. The kind comes from the
provenance column `kind`, else (for corpora and certificates written
before kinds were recorded) from the source label, the query and the
engine (see
[`sm_provenance()`](https://cttir.github.io/scimapR/dev/reference/sm_provenance.md)).

## Usage

``` r
sm_certificate(corpus, path = NULL, call = rlang::caller_env())

sm_rebuild_from_cert(cert, verbose = TRUE, call = rlang::caller_env())

sm_verify_certificate(
  corpus,
  cert,
  base_dir = NULL,
  call = rlang::caller_env()
)

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

- base_dir:

  `NULL` or the folder that the relative paths of the local inputs are
  relative to; looked in first. See "Local inputs".

- x:

  An `sm_certificate` or `sm_cert_verification` object.

- ...:

  Ignored.

## Value

For `sm_certificate()`: an `sm_certificate` S3 object (list), also
written to `path` if provided. For `sm_rebuild_from_cert()`: an
`sm_corpus` with the works of the replayed searches. For
`sm_verify_certificate()`: an `sm_cert_verification` S3 object, a list
with `pass`, `checks`, `n_not_checked`, `corpus_hash` (computed with the
certificate's hash version), `cert_hash`, `cert_created` and
`hash_version`.

`x` invisibly (print methods).

## Details

Certificates write their timestamps (`created`, the corpus's
`build_date` and `last_refresh`, and the `registered_at` of each local
input) in UTC as ISO 8601 text, for example `2026-10-17T11:45:00Z`, and
read back both this form and the older one with a numeric offset.
Printing a certificate shows `created` in UTC as well, so a certificate
read back from YAML prints the same time as the one it was written from.
The corpus timestamps may be stored as POSIXct, a Date, numeric seconds
since 1970-01-01 UTC (as in corpora restored from tables) or ISO 8601
text. A missing or implausible value is written as `NA`.

`embedding_info` describes `corpus$embeddings`: its size (`n_works`,
`n_dimensions`) and, from the record in `corpus$metadata$embedding` (see
[`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)),
the model behind it: `model`, `model_id`, `base_model_id`, `revision`,
`base_revision`, `text`, `prefix`, `models`, `versions` and `created`.
`method` names how the embeddings were made: `"sentence-transformers"`
or `"adapters"`
([`sm_embed_works()`](https://cttir.github.io/scimapR/dev/reference/sm_embed_works.md)),
`"semantic-scholar"`
([`sm_enrich_specter()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_specter.md),
[`sm_fetch_semantic_scholar()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_semantic_scholar.md))
or `"mixed"` for rows of several models; it is `"unknown"` for
embeddings without a record that fits them (such as embeddings made by
earlier versions of scimapR, or a matrix replaced by hand) and `"none"`
when the corpus has no embeddings. In these two cases `model` and
`model_id` say the same.

## Local inputs

The `local_inputs` block lists the files of `metadata$local_inputs`
([`sm_register_input()`](https://cttir.github.io/scimapR/dev/reference/sm_register_input.md))
with their `path`, `path_abs`, `root`, `basename`, `sha256`, `bytes`,
`role`, `builder` and `registered_at`. It is a tibble in the certificate
object, with no rows when no file is registered, and a list with one
entry per file in the YAML file.

`sm_verify_certificate()` adds one check per file, named
`input:<basename>` (`input:<path>` when files share a name). It looks
for a file with a relative `path` in `base_dir`, then in the folder of
the certificate file (when `cert` is a path), then in the working
directory, and last at `path_abs`; a file with an absolute `path` is
looked for there and at `path_abs`. The first file found is hashed
again, its check passes when the hash is the recorded one, and the
check's `location` says where it was found. A file found nowhere is not
checked, and the function warns (class `scimapR_cert_inputs_missing`),
naming the files and the folders searched, because a verification run
from the wrong folder would otherwise pass without a word.

## Verification results

`checks` has one row per check, with the columns `check`, `expected`,
`actual` (for a local input the first 16 characters of the hashes, or
`"missing"`), `pass`, `status` and `location`. `status` (character) is
`"pass"`, `"fail"` or `"not checked"`; `pass` is `TRUE`, `FALSE`, or
`NA` for a check that was not made. The overall `pass` is `TRUE` unless
a check failed, so it can be `TRUE` while `n_not_checked` counts checks
that were not made. The corpus hash is computed with the `hash_version`
the certificate records, or with version 1 for certificates written
before scimapR 0.5.0 (see
[`sm_hash_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_hash_corpus.md)).

## Rebuilding a corpus

`sm_rebuild_from_cert()` replays the `"api_query"` steps of OpenAlex,
PubMed and Crossref with the fetcher of their source
([`sm_fetch_openalex()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_openalex.md),
[`sm_fetch_pubmed()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_pubmed.md)
or
[`sm_fetch_crossref()`](https://cttir.github.io/scimapR/dev/reference/sm_fetch_crossref.md)),
the engine they were made with and the recorded `filter` and `n_max`.
The searches of
[`sm_corpus_for_question()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_for_question.md)
record the client package that ran them (openalexR, rentrez or
rcrossref) as their engine. A step without `n_max`, as in certificates
of earlier versions, fetches up to the number of works of the certified
corpus, with a message. The other steps (file reads, enrichments,
refreshes, synthetic records and searches of other sources) and the
local inputs cannot be replayed, and a message of class
`scimapR_cert_not_replayed` names them. When a certificate has no search
to replay but records file reads or local inputs, the function stops
instead, with an error of class `scimapR_cert_not_replayable` that lists
them, with the role, hash and builder of each local input. Without a
search to replay, file reads or local inputs (only synthetic records,
enrichments, refreshes or searches of other sources, or no step at all),
it returns an empty corpus.

The rebuilt corpus holds the works of the replayed searches, without
duplicate DOIs and with new work ids, and their provenance; its other
tables are empty. It shows what the recorded searches find today, so it
does not pass `sm_verify_certificate()`: its hash and table sizes differ
from those of the certified corpus.

## See also

Other reproducibility:
[`sm_cite_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_cite_corpus.md),
[`sm_diff_corpora()`](https://cttir.github.io/scimapR/dev/reference/sm_diff_corpora.md),
[`sm_hash_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_hash_corpus.md),
[`sm_provenance()`](https://cttir.github.io/scimapR/dev/reference/sm_provenance.md),
[`sm_register_input()`](https://cttir.github.io/scimapR/dev/reference/sm_register_input.md),
[`sm_snapshot()`](https://cttir.github.io/scimapR/dev/reference/sm_snapshot.md)

## Examples

``` r
corpus <- sm_example_corpus()
tracker <- tempfile(fileext = ".csv")
writeLines(c("doi,unit", "10.9999/example.1,Unit A"), tracker)
corpus <- sm_register_input(corpus, tracker, role = "publication tracker")
cert <- sm_certificate(corpus)
#> ✔ Certificate created. Corpus hash: 61c0637eede7
print(cert)
#> 
#> ── <sm_certificate> ────────────────────────────────────────────────────────────
#> Version: 1.0
#> Created: 2026-10-23 20:10:43 UTC
#> scimapR: v0.4.0.9000
#> R: 4.6.1 (unix)
#> 
#> Corpus hash: 61c0637eede72e86
#> Works: 200
#> Authors: 80
#> References: 1869
#> Queries: 1
#> Local inputs: 1
#> Embeddings: 200 x 64 ("unknown")
verification <- sm_verify_certificate(corpus, cert)
print(verification)
#> 
#> ── <sm_cert_verification> ──────────────────────────────────────────────────────
#> Result: PASS
#> 
#> ✔ corpus_hash: expected 61c0637eede72e86, got 61c0637eede72e86
#> ✔ n_works: expected 200, got 200
#> ✔ n_authors: expected 80, got 80
#> ✔ n_institutions: expected 0, got 0
#> ✔ n_references: expected 1869, got 1869
#> ✔ input:file1ec9652dae1e.csv: expected 721a6632cca2e6ea, got 721a6632cca2e6ea

# a changed input file fails its check
cat("10.9999/example.2,Unit B\n", file = tracker, append = TRUE)
sm_verify_certificate(corpus, cert)$pass
#> [1] FALSE
```
