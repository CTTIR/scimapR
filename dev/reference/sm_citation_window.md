# Citations within a fixed window after publication

Counts each work's citations in its publication year and the `window`
years after it, from the yearly citation counts of the corpus
(`citations_by_year`, written by the OpenAlex readers and
[`sm_enrich_openalex_impact()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_openalex_impact.md)),
and says whether the counts cover the whole window. Fixed windows
compare old and recent works fairly, which `cited_by_count` (all
citations up to now) does not.

## Usage

``` r
sm_citation_window(corpus, window = 3L, call = rlang::caller_env())
```

## Arguments

- corpus:

  An `sm_corpus`.

- window:

  Number of years after the publication year, a whole number of 0 or
  more (default `3`). The window runs from the publication year through
  the publication year plus `window`, so it spans `window + 1` calendar
  years: `window = 3` counts the citations of a work from 2020 in 2020
  to 2023.

- call:

  Caller environment for error reporting.

## Value

A tibble with one row per work, in the order of `corpus$works`:
`work_id` (character), `year` (integer, the publication year), `window`
(integer), `citations` (integer) and `complete` (logical). A corpus
without works gives a 0-row tibble with these columns.

## Details

OpenAlex gives the citations of the ten most recent years only (its
`counts_by_year`: the year of the counts and the nine before it), and
leaves out the years without citations. A year missing from
`citations_by_year` therefore counts 0 for a work that has yearly
counts. The date of the counts is `works$citations_as_of` (the day
OpenAlex last updated the record, or of the fetch); its year is still
running, so it counts as partial. A corpus restored with
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md)
may hold this date as a day count (days since 1970-01-01, as SQLite
keeps dates) or as ISO 8601 text; both are read as the date they stand
for.

A window is `complete` when the work has a publication year and yearly
counts with a known date, its first year (the publication year) is no
earlier than nine years before the year of the counts, and its last year
is before the year of the counts. Otherwise `complete` is `FALSE` and
`citations` is a lower bound: the citations the counts hold for the
window years. A work without a publication year, or without yearly
counts (no rows in `citations_by_year` and no `citations_as_of`), gets
`citations = NA`.

The result depends only on the corpus, never on today's date, so it is
the same in every session. A corpus without `citations_by_year` gives
`NA` for every work, with one message (class
`scimapR_no_citations_by_year`) that points to
[`sm_enrich_openalex_impact()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_openalex_impact.md).

## See also

[`sm_citation_maturity()`](https://cttir.github.io/scimapR/dev/reference/sm_citation_maturity.md),
[`sm_enrich_openalex_impact()`](https://cttir.github.io/scimapR/dev/reference/sm_enrich_openalex_impact.md)

Other counting:
[`sm_citation_maturity()`](https://cttir.github.io/scimapR/dev/reference/sm_citation_maturity.md),
[`sm_count()`](https://cttir.github.io/scimapR/dev/reference/sm_count.md),
[`sm_metric_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_summary.md)

## Examples

``` r
works <- data.frame(
  work_id = c("W1", "W2", "W3"),
  title = c("Early work", "Recent work", "Unknown counts"),
  year = c(2018L, 2024L, 2019L),
  citations_as_of = as.Date(c("2026-10-17", "2026-10-17", NA))
)
yearly <- data.frame(
  work_id = c("W1", "W1", "W1", "W2"),
  year = c(2018L, 2019L, 2021L, 2025L),
  cited_by_count = c(2L, 5L, 4L, 3L)
)
corpus <- sm_corpus_from_tables(
  list(works = works, citations_by_year = yearly)
)
#> ℹ works: filled missing column doi, abstract, type, source_id, cited_by_count,
#>   oa_status, language, pmid, arxiv_id, openalex_id, is_retracted,
#>   retraction_date, and last_refreshed with typed `NA`.
sm_citation_window(corpus, window = 3)
#> # A tibble: 3 × 5
#>   work_id  year window citations complete
#>   <chr>   <int>  <int>     <int> <lgl>   
#> 1 W1       2018      3        11 TRUE    
#> 2 W2       2024      3         3 FALSE   
#> 3 W3       2019      3        NA FALSE   
```
