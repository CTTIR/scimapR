# Full and fractional output / impact counting

Attributes publication output (and citation impact) to entities using
either full or fractional counting. Reviewers routinely ask for
fractional counts so that a single multi-author / multi-institution
paper is not counted in full for every contributor.

## Usage

``` r
sm_count(
  corpus,
  method = c("full", "fractional"),
  level = c("institution", "author", "source"),
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus`.

- method:

  `"full"` (default) gives each entity credit 1 per work it appears on.
  `"fractional"` splits each work's single unit of credit equally among
  the distinct entities on that work.

- level:

  Entity level: `"institution"` (default), `"author"`, or `"source"`.

- call:

  Caller environment for error reporting.

## Value

A tibble, one row per entity, sorted by `credit` descending:

- entity_id:

  Entity identifier.

- entity_name:

  Human-readable name (falls back to `entity_id`).

- n_works:

  Number of distinct works the entity appears on (this is the full count
  and is identical for both methods).

- credit:

  Output credit: `n_works` under `"full"`; the sum of per-work
  fractional shares under `"fractional"`.

- weighted_citations:

  Citation impact attributed to the entity: summed `cited_by_count`
  under `"full"`; summed fractional-share weighted `cited_by_count`
  under `"fractional"`.

Type-stable: an empty/inapplicable corpus returns a 0-row tibble with
these columns.

## Details

The fractional rule is the standard equal-share rule: a work with \\k\\
distinct entities contributes \\1/k\\ of credit (and \\1/k\\ of its
citations) to each. For `level = "source"` each work has a single
source, so fractional and full counts coincide.

For `level = "institution"` each authorship row is labelled on its own,
by the first of these `authorships` columns that has a value in that
row: `institution_match` (from
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)),
`institution_name`, `institution_id` (named by
`corpus$institutions$display_name` when that table lists the id) and
`raw_affiliation`. A row labelled through `institution_id` has that id
as `entity_id`; every other row has its label as both `entity_id` and
`entity_name`. Rows labelled by their raw affiliation string are counted
un-disambiguated, with a warning, because `sm_count()` applies no
affiliation dictionary itself: run
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)
with a dictionary of your institutions first to count them. The order is
the one
[`sm_coverage_audit()`](https://cttir.github.io/scimapR/dev/reference/sm_coverage_audit.md)
uses for its affiliation levels, which however takes one column for all
rows and falls back to country codes instead of raw strings. Up to
scimapR 0.4.0, `sm_count()` used one column for every row (the first of
`institution_id`, `institution_match` and `raw_affiliation` with any
value), so rows without a value in it were left out, and it matched raw
strings against the shipped
[sm_affiliation_dict](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_dict.md)
before counting them.

[`sm_attribute_institution()`](https://cttir.github.io/scimapR/dev/reference/sm_attribute_institution.md)
keeps `institution_match`, so its roll-up of the matches to a controlled
vocabulary (ROR ids and names in `institution_id` and
`institution_name`) is counted only for rows without a match; up to
scimapR 0.4.0 the counts followed `institution_id`. To count by the
vocabulary, put its names first:

    a <- corpus$authorships
    corpus$authorships$institution_match <-
      dplyr::coalesce(a$institution_name, a$institution_match)

## See also

[`sm_metric_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_summary.md),
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)

Other counting:
[`sm_citation_maturity()`](https://cttir.github.io/scimapR/dev/reference/sm_citation_maturity.md),
[`sm_citation_window()`](https://cttir.github.io/scimapR/dev/reference/sm_citation_window.md),
[`sm_metric_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_summary.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 30, seed = 1)
sm_count(corpus, method = "fractional", level = "author")
#> # A tibble: 58 × 5
#>    entity_id  entity_name      n_works credit weighted_citations
#>    <chr>      <chr>              <int>  <dbl>              <dbl>
#>  1 A000000001 Fatima Liu            30  7.04              100.  
#>  2 A000000002 Fatima Andersson       5  0.910               7.33
#>  3 A000000015 Sarah Tanaka           3  0.811               9.39
#>  4 A000000020 Maria Smith            3  0.792              15.0 
#>  5 A000000025 Erik Wang              3  0.783               4.58
#>  6 A000000039 James Patel            4  0.761              10.0 
#>  7 A000000016 Mohammed Brown         3  0.7                 7.2 
#>  8 A000000050 Mei Santos             3  0.65               14.4 
#>  9 A000000006 Fatima Brown           3  0.644               3.42
#> 10 A000000040 Lars Garcia            2  0.625               2.88
#> # ℹ 48 more rows

# Institutions: match the affiliation strings with a dictionary of your
# institutions first, then count
a <- corpus$authorships
corpus$authorships$raw_affiliation <- ifelse(
  a$position == 1L,
  "Unit North, Northtown",
  "Department of Surgery, Unit South"
)
dict <- list("Unit North" = "unit north", "Unit South" = "unit south")
matched <- sm_affiliation_match(corpus, patterns = dict)
#> ✔ Affiliation matching flagged 145 authorships across 2 institutions.
#> ℹ By signal: name_token: 145. See `sm_affiliation_summary()` for the full
#>   breakdown.
sm_count(matched, method = "fractional", level = "institution")
#> # A tibble: 2 × 5
#>   entity_id  entity_name n_works credit weighted_citations
#>   <chr>      <chr>         <int>  <dbl>              <dbl>
#> 1 Unit North Unit North       30     16               226.
#> 2 Unit South Unit South       28     14               208.
```
