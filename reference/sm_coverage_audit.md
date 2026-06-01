# Audit corpus coverage against a ground-truth reference

Computes recall, precision, and F1 of an `sm_corpus` against an external
ground-truth `reference` (a manual tracker, an ORCID works set, an
institutional-repository export, or another `sm_corpus`). This is the
core primitive for a coverage / completeness audit: "how much of what we
*should* have did we actually capture, and how much of what we captured
is real?"

Matching is by normalised DOI with a fuzzy-title fallback (see
[`sm_reconcile()`](https://cttir.github.io/scimapR/reference/sm_reconcile.md)
for the shared matching engine). Full match provenance is retained so
every decision can be inspected.

## Usage

``` r
sm_coverage_audit(
  corpus,
  reference,
  by = NULL,
  match = c("doi_then_title", "doi", "title"),
  threshold = 0.9,
  index_table = NULL,
  call = rlang::caller_env()
)

# S3 method for class 'sm_coverage'
print(x, ...)

# S3 method for class 'sm_coverage'
summary(object, ...)

# S3 method for class 'sm_coverage'
autoplot(object, dim = NULL, ...)
```

## Arguments

- corpus:

  An `sm_corpus` object (the corpus under audit).

- reference:

  The ground truth: an `sm_corpus` or a data frame with at least a DOI
  and/or title column (column names matched case-insensitively against
  `doi`/`di` and `title`/`ti`/`display_name`; an `id`/`work_id`/
  `reference_id` column is used as the identifier if present).

- by:

  Optional character vector of breakdown dimensions, any of `"year"`,
  `"source"`, `"affiliation"`. Per-slice recall is reported for each
  supplied dimension.

- match:

  Matching strategy: `"doi_then_title"` (default), `"doi"`, or
  `"title"`.

- threshold:

  Minimum Jaro-Winkler title similarity (`[0, 1]`) to accept a title
  match. Default `0.9`. When the optional `stringdist` package is not
  installed, the title fallback degrades to normalised exact matching.

- index_table:

  Optional journal index master list (same contract as
  [`sm_journal_in_index()`](https://cttir.github.io/scimapR/reference/sm_journal_in_index.md);
  document expected columns there). When supplied, the audit
  additionally reports, per corpus record, whether its journal is
  **indexable** – so "is this journal in the index" and "is this record
  captured" are assessed together. When `NULL` (default) the result is
  identical to before.

- call:

  Caller environment for error reporting.

- x:

  An `sm_coverage` object.

- ...:

  Ignored.

- object:

  An `sm_coverage` object.

- dim:

  Which breakdown dimension to plot (defaults to the first available).
  If no breakdowns exist, a recall/precision summary bar is drawn.

## Value

An `sm_coverage` S3 object (a list) with components:

- recall:

  Matched reference records / total reference records.

- precision:

  Matched corpus records / total corpus records.

- f1:

  Harmonic mean of recall and precision.

- n_corpus, n_reference, n_matched:

  Integer counts.

- n_corpus_only, n_reference_only:

  Unmatched counts.

- matches:

  Tibble with one row per corpus record: `corpus_id`, `reference_id`,
  `match_type` (`"doi"`/`"title"`/`"none"`), `match_score`. When
  `index_table` is supplied, also `issn`, `indexable` (logical), and
  `indexed_title`.

- corpus_only:

  Tibble of corpus records absent from the reference.

- reference_only:

  Tibble of reference records absent from the corpus.

- breakdowns:

  A single flat tibble (`dimension`, `level`, `n_reference`,
  `n_matched`, `recall`) across all `by` dimensions. Use
  [`sm_coverage_breakdowns()`](https://cttir.github.io/scimapR/reference/sm_coverage_breakdowns.md)
  to access/filter it.

- breakdowns_nested:

  The legacy named list of per-dimension tibbles (`slice`,
  `n_reference`, `n_matched`, `recall`). Retained for one release;
  prefer `breakdowns`.

- indexability:

  When `index_table` is supplied, a summary tibble of indexable vs
  non-indexable record counts; otherwise `NULL`.

`print` returns `x` invisibly.

`summary` returns a one-row tibble of headline metrics.

`autoplot` returns a `ggplot` object.

## See also

[`sm_reconcile()`](https://cttir.github.io/scimapR/reference/sm_reconcile.md),
[`sm_journal_in_index()`](https://cttir.github.io/scimapR/reference/sm_journal_in_index.md),
[`sm_coverage_breakdowns()`](https://cttir.github.io/scimapR/reference/sm_coverage_breakdowns.md)

Other coverage:
[`sm_coverage_breakdowns()`](https://cttir.github.io/scimapR/reference/sm_coverage_breakdowns.md),
[`sm_journal_in_index()`](https://cttir.github.io/scimapR/reference/sm_journal_in_index.md),
[`sm_reconcile()`](https://cttir.github.io/scimapR/reference/sm_reconcile.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 30, seed = 1)
# Pretend the reference is the corpus minus a few works, plus an extra one
ref <- corpus$works[1:25, c("work_id", "doi", "title", "year")]
cov <- sm_coverage_audit(corpus, ref, by = "year")
cov
#> 
#> ── <sm_coverage> ───────────────────────────────────────────────────────────────
#> Match strategy: doi_then_title (title threshold 0.9)
#> Recall: 1 (25/25 reference records found)
#> Precision: 0.8333 (25/30 corpus records in reference)
#> F1: 0.9091
#> 
#> Corpus-only: 5 Reference-only: 0
#> 
#> 
#> ── Worst-covered slices by year 
#> 2015: recall 1 (1/1)
#> 2016: recall 1 (2/2)
#> 2017: recall 1 (2/2)
#> 2018: recall 1 (2/2)
#> 2020: recall 1 (6/6)
```
