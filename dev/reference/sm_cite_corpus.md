# Generate citation block for a corpus

Produces a structured citation block for a corpus that can be included
in manuscripts. The block documents the number of works, sources
queried, date range, scimapR version, and corpus hash for
reproducibility.

The build date is the UTC date of `metadata$build_date`, which may be a
POSIXct, a Date, numeric seconds since 1970-01-01 UTC or ISO 8601 text;
a missing or implausible value is shown as `unknown`.

## Usage

``` r
sm_cite_corpus(
  corpus,
  style = c("text", "bibtex", "yaml"),
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- style:

  Character. Citation style: `"text"` for a plain-text paragraph,
  `"bibtex"` for a BibTeX entry, or `"yaml"` for a YAML block.

- call:

  Caller environment for error reporting.

## Value

A character string containing the formatted citation. Printed to the
console and returned invisibly.

## See also

Other reproducibility:
[`sm_certificate()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md),
[`sm_diff_corpora()`](https://cttir.github.io/scimapR/dev/reference/sm_diff_corpora.md),
[`sm_hash_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_hash_corpus.md),
[`sm_provenance()`](https://cttir.github.io/scimapR/dev/reference/sm_provenance.md),
[`sm_register_input()`](https://cttir.github.io/scimapR/dev/reference/sm_register_input.md),
[`sm_snapshot()`](https://cttir.github.io/scimapR/dev/reference/sm_snapshot.md)

## Examples

``` r
corpus <- sm_example_corpus()
sm_cite_corpus(corpus)
#> Corpus assembled using scimapR v0.4.0.9000 on 2026-10-26. Contains 200 works by 80 authors (2015-2024). Data sources: synthetic. Corpus hash: 61c0637eede7.
```
