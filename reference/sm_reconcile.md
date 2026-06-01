# Reconcile two corpora by DOI and title

Computes a symmetric set difference between two corpora (or coercible
data frames) using the shared DOI-then-title matching engine. This
generalises
[`sm_diff_corpora()`](https://cttir.github.io/scimapR/reference/sm_diff_corpora.md),
which compares strictly by internal `work_id`: `sm_reconcile()` instead
matches on *content* (normalised DOI with a fuzzy title fallback), so it
works across corpora from different sources that do not share
identifiers.

## Usage

``` r
sm_reconcile(
  corpus_a,
  corpus_b,
  match = c("doi_then_title", "doi", "title"),
  threshold = 0.9,
  call = rlang::caller_env()
)

# S3 method for class 'sm_reconciliation'
print(x, ...)

# S3 method for class 'sm_reconciliation'
summary(object, ...)

# S3 method for class 'sm_reconciliation'
autoplot(object, ...)
```

## Arguments

- corpus_a, corpus_b:

  An `sm_corpus` or a data frame with DOI and/or title columns (see
  [`sm_coverage_audit()`](https://cttir.github.io/scimapR/reference/sm_coverage_audit.md)
  for accepted column aliases).

- match:

  Matching strategy: `"doi_then_title"` (default), `"doi"`, or
  `"title"`.

- threshold:

  Minimum Jaro-Winkler title similarity (`[0, 1]`) to accept a title
  match (default `0.9`).

- call:

  Caller environment for error reporting.

- x:

  An `sm_reconciliation` object.

- ...:

  Ignored.

- object:

  An `sm_reconciliation` object.

## Value

An `sm_reconciliation` S3 object with components:

- in_both:

  Tibble of matched pairs: `a_id`, `b_id`, `title`, `match_type`,
  `match_score`.

- only_a:

  Tibble of `corpus_a` records absent from `corpus_b` (`id`, `doi`,
  `title`, `year`).

- only_b:

  Tibble of `corpus_b` records absent from `corpus_a`.

- matches:

  Match provenance tibble (`a_id`, `b_id`, `match_type`, `match_score`),
  the same shape as
  [`sm_coverage_audit()`](https://cttir.github.io/scimapR/reference/sm_coverage_audit.md)'s.

- summary:

  One-row tibble with counts.

`print` returns `x` invisibly.

`summary` returns the one-row summary tibble.

`autoplot` returns a `ggplot` set-size bar chart.

## See also

[`sm_coverage_audit()`](https://cttir.github.io/scimapR/reference/sm_coverage_audit.md),
[`sm_diff_corpora()`](https://cttir.github.io/scimapR/reference/sm_diff_corpora.md)

Other coverage:
[`sm_coverage_audit()`](https://cttir.github.io/scimapR/reference/sm_coverage_audit.md),
[`sm_coverage_breakdowns()`](https://cttir.github.io/scimapR/reference/sm_coverage_breakdowns.md),
[`sm_journal_in_index()`](https://cttir.github.io/scimapR/reference/sm_journal_in_index.md),
[`sm_match_types()`](https://cttir.github.io/scimapR/reference/sm_match_types.md)

## Examples

``` r
a <- sm_example_corpus(n_works = 20, seed = 1)
b <- sm_example_corpus(n_works = 20, seed = 1)[5:20]
rec <- sm_reconcile(a, b)
rec
#> 
#> ── <sm_reconciliation> ─────────────────────────────────────────────────────────
#> A: 20 records B: 16 records
#> In both: 16 Only A: 4 Only B: 0
#> Jaccard overlap: 0.8
#> Matched via: 16 DOI, 0 title
```
