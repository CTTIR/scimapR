# Audit corpus coverage against a ground-truth reference

Computes recall, precision, and F1 of an `sm_corpus` against an external
ground-truth `reference` (a manual tracker, an ORCID works set, an
institutional-repository export, or another `sm_corpus`). This is the
core primitive for a coverage / completeness audit: "how much of what we
*should* have did we actually capture, and how much of what we captured
is real?"

Matching is by normalised DOI with a fuzzy-title fallback (see
[`sm_reconcile()`](https://cttir.github.io/scimapR/dev/reference/sm_reconcile.md)
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
  `doi`/`di` and `title`/`ti`/`display_name`, the year against
  `year`/`py`/`publication_year`). A `Date` or date-time year column
  gives its calendar year, and a year outside 1000-2999 (such as a day
  count) counts as missing. Rows are identified by the first of the
  columns `ut` (Web of Science accession numbers), `id`, `work_id`,
  `reference_id` and `ref_id` whose values are unique and never missing,
  and otherwise by their position (`R000001`, ...), with a warning when
  such a column had to be passed over. In a data frame with Web of
  Science field tags (such as `DI`, `TI`, `PY` or `UT`) a column named
  `ID` holds the Keywords Plus and is never the identifier.

- by:

  Optional character vector of breakdown dimensions. A name is either
  one of the named dimensions `"year"`, `"source"` and `"affiliation"`,
  written in lower case (see Details), or a column: of the reference
  data frame (matched case-insensitively) or of the `works` table of an
  `sm_corpus` (the exact name first, then case-insensitively). Each name
  is resolved on both sides; a name found on one side only gives levels
  whose columns for the other side are `NA`. A name that is neither a
  named dimension nor a column on either side is an error listing the
  available columns. The breakdowns label each dimension with the name
  as given.

- match:

  Matching strategy: `"doi_then_title"` (default), `"doi"`, or
  `"title"`.

- threshold:

  Minimum Jaro-Winkler title similarity (`[0, 1]`) to accept a title
  match. Default `0.9`. When the optional `stringdist` package is not
  installed, the title fallback degrades to normalised exact matching.
  Titles only match between records published at most one year apart
  (when both years are known) and never between two records with
  different DOIs.

- index_table:

  Optional journal index master list (same contract as
  [`sm_journal_in_index()`](https://cttir.github.io/scimapR/dev/reference/sm_journal_in_index.md);
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

  Reference records found in the corpus / total reference records. Each
  reference row is looked up on its own, so rows that report the same
  item (one paper reported by two units) are all found.

- precision:

  Matched corpus records / total corpus records. Each corpus record
  pairs with at most one reference row.

- f1:

  Harmonic mean of recall and precision.

- n_corpus, n_reference:

  Integer record counts.

- n_matched:

  Reference records found in the corpus (the numerator of recall).

- n_corpus_matched:

  Corpus records paired with a reference record (the numerator of
  precision); equal to `n_matched` unless reference rows share a corpus
  record.

- n_corpus_only, n_reference_only:

  Unmatched counts.

- matches:

  Tibble with one row per corpus record: `corpus_id`, `reference_id`,
  `match_type` (`"doi"`/`"title"`/`"none"`), `match_score`. When
  `index_table` is supplied, also `issn`, `indexable` (logical), and
  `indexed_title`.

- reference_matches:

  Tibble with one row per reference record: `reference_id`, `corpus_id`
  (the corpus record it was found in), `match_type` and `match_score`;
  the recall-side counterpart of `matches`.

- corpus_only:

  Tibble of corpus records absent from the reference.

- reference_only:

  Tibble of reference records absent from the corpus.

- breakdowns:

  A single flat tibble (`dimension`, `level`, `n_reference`,
  `n_matched`, `recall`) across all `by` dimensions, from the reference
  side. Use
  [`sm_coverage_breakdowns()`](https://cttir.github.io/scimapR/dev/reference/sm_coverage_breakdowns.md)
  to access/filter it, also with the corpus-side counts and precision.

- breakdowns_nested:

  The legacy named list of per-dimension tibbles (`slice`,
  `n_reference`, `n_matched`, `recall`). Retained for one release;
  prefer `breakdowns`.

- indexability:

  When `index_table` is supplied, a summary tibble of indexable vs
  non-indexable record counts; otherwise `NULL`.

`print` returns `x` invisibly.

`summary` returns a one-row tibble of headline metrics: `recall`,
`precision`, `f1`, `n_corpus`, `n_reference`, `n_matched`,
`n_corpus_only`, `n_reference_only` and `n_corpus_matched`, so that
`n_matched + n_reference_only` gives `n_reference` and
`n_corpus_matched + n_corpus_only` gives `n_corpus`.

`autoplot` returns a `ggplot` object.

## Details

**Named dimensions.** `"year"` uses the publication years. `"source"`
uses the source names of an `sm_corpus` (`sources$display_name`, or
`works$source_id` when the corpus has no source table) and, in a data
frame, the first of the columns `source`, `source_title`, `journal`,
`so` and `source_id`, in this order (names matched case-insensitively);
a `source_id` column holds ids, whose levels do not join the names of
the corpus side. `"affiliation"` uses, in a data frame, the first of the
columns `affiliation`, `affiliations`, `institution`, `country` and
`country_code`, in this order. A data-frame cell holds one value, so an
item reported by two units takes two rows; a list column gives each of
its values. Missing and blank values have no level. A named dimension
that neither side can resolve gives a warning and no breakdown rows.
Only `"affiliation"` joins a tracker's units with the institutions of
the corpus: `by = "institution"` names the column itself, which the
corpus side has only if `works` has a column of that name.

**Affiliation levels of a corpus.** For an `sm_corpus` (the corpus under
audit, or a reference given as one), `"affiliation"` labels the
authorships from the first of these `authorships` columns that has a
value in at least one row: `institution_match` (from
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)),
`institution_name` (from
[`sm_attribute_institution()`](https://cttir.github.io/scimapR/dev/reference/sm_attribute_institution.md)),
`institution_id` (named by `corpus$institutions$display_name` when that
table lists the id, else the id itself) and, as a last resort,
`country_code`. One column serves every row, so the levels of a side are
all of one kind, and an authorship without a value in that column has no
level. A message names the column used on each side, and a warning says
when a side falls back to country codes, whose levels do not join
institution names. Because
[`sm_attribute_institution()`](https://cttir.github.io/scimapR/dev/reference/sm_attribute_institution.md)
runs
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)
first, `institution_name` is used only when `institution_match` is
absent or empty; the Details of
[`sm_attribute_institution()`](https://cttir.github.io/scimapR/dev/reference/sm_attribute_institution.md)
show how to break the coverage down by its vocabulary instead.
`sm_count(level = "institution")` reads the same columns in the same
order, but row by row, and counts the raw affiliation string where none
has a value instead of falling back to countries; up to scimapR 0.4.0 it
used, for every row, the first of `institution_id`, `institution_match`
and the raw strings (matched with
[sm_affiliation_dict](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_dict.md))
that had a value in any row.

**Full counting.** A record belongs to every level of its values, so a
work with authors at two institutions counts in both slices, and the
per-level counts of a dimension can add up to more than `n_corpus` or
`n_reference`. The overall recall and precision count each record once.

## See also

[`sm_reconcile()`](https://cttir.github.io/scimapR/dev/reference/sm_reconcile.md),
[`sm_journal_in_index()`](https://cttir.github.io/scimapR/dev/reference/sm_journal_in_index.md),
[`sm_coverage_breakdowns()`](https://cttir.github.io/scimapR/dev/reference/sm_coverage_breakdowns.md),
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)

Other coverage:
[`sm_coverage_breakdowns()`](https://cttir.github.io/scimapR/dev/reference/sm_coverage_breakdowns.md),
[`sm_journal_in_index()`](https://cttir.github.io/scimapR/dev/reference/sm_journal_in_index.md),
[`sm_match_types()`](https://cttir.github.io/scimapR/dev/reference/sm_match_types.md),
[`sm_reconcile()`](https://cttir.github.io/scimapR/dev/reference/sm_reconcile.md)

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

# Any column of the reference or of the works is a dimension too
ref$unit <- rep(c("Unit A", "Unit B"), length.out = nrow(ref))
cov <- sm_coverage_audit(corpus, ref, by = c("unit", "type"), match = "doi")
sm_coverage_breakdowns(cov)
#> # A tibble: 5 × 8
#>   dimension level          n_reference n_matched recall n_corpus precision    f1
#>   <chr>     <chr>                <int>     <int>  <dbl>    <int>     <dbl> <dbl>
#> 1 unit      Unit A                  13        13      1       NA    NA        NA
#> 2 unit      Unit B                  12        12      1       NA    NA        NA
#> 3 type      journal-artic…          NA        NA     NA       18     0.833    NA
#> 4 type      letter                  NA        NA     NA        6     1        NA
#> 5 type      review                  NA        NA     NA        6     0.667    NA
```
