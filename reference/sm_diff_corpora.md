# Compare two corpora

**\[superseded\]**

Produces a detailed comparison between two `sm_corpus` objects,
reporting works added, removed, and changed; author differences;
reference differences; and screening changes. This is useful for
auditing how a corpus evolved between snapshots or after a refresh.

This function compares strictly by internal `work_id`. For content-based
reconciliation across corpora that do not share identifiers (matching by
normalised DOI with a fuzzy title fallback), use
[`sm_reconcile()`](https://cttir.github.io/scimapR/reference/sm_reconcile.md).

## Usage

``` r
sm_diff_corpora(corpus1, corpus2, call = rlang::caller_env())

# S3 method for class 'sm_corpus_diff'
print(x, ...)
```

## Arguments

- corpus1:

  An `sm_corpus` object (the "before" state).

- corpus2:

  An `sm_corpus` object (the "after" state).

- call:

  Caller environment for error reporting.

- x:

  An `sm_corpus_diff` object.

- ...:

  Ignored.

## Value

An `sm_corpus_diff` S3 object (a list) with components:

- added:

  Tibble of works in `corpus2` but not `corpus1`.

- removed:

  Tibble of works in `corpus1` but not `corpus2`.

- changed:

  Tibble of works present in both but with differing fields.

- summary:

  A one-row summary tibble with counts.

- hash1:

  Hash of `corpus1`.

- hash2:

  Hash of `corpus2`.

## See also

[`sm_reconcile()`](https://cttir.github.io/scimapR/reference/sm_reconcile.md)

Other reproducibility:
[`sm_certificate()`](https://cttir.github.io/scimapR/reference/sm_certificate.md),
[`sm_cite_corpus()`](https://cttir.github.io/scimapR/reference/sm_cite_corpus.md),
[`sm_hash_corpus()`](https://cttir.github.io/scimapR/reference/sm_hash_corpus.md),
[`sm_provenance()`](https://cttir.github.io/scimapR/reference/sm_provenance.md),
[`sm_snapshot()`](https://cttir.github.io/scimapR/reference/sm_snapshot.md)

## Examples

``` r
# \donttest{
c1 <- sm_example_corpus(seed = 1L)
c2 <- sm_example_corpus(seed = 2L)
d <- sm_diff_corpora(c1, c2)
print(d)
#> 
#> ── <sm_corpus_diff> ────────────────────────────────────────────────────────────
#> Works added: 0
#> Works removed: 0
#> Works changed: 1590
#> Works unchanged: -1390
#> 
#> Authors added: 0
#> Authors removed: 0
#> References: 1932 -> 1846
#> Screening: 0 -> 0
#> 
#> Hash (before): 8c148d1bfae1
#> Hash (after): 5d1d1da46a2d
# }
```
