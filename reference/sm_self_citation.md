# Compute self-citation from corpus reference lists

Identifies self-citations from the `references` already in the corpus —
no per-citation API calls. A citation from a citing work to a cited work
is a self-citation at the chosen `level` when the citing and cited works
share an author (or institution). This is the quota-light "reference
overlap" method.

## Usage

``` r
sm_self_citation(
  corpus,
  level = c("author", "institution"),
  method = c("reference_overlap"),
  call = rlang::caller_env()
)

# S3 method for class 'sm_self_citation'
print(x, ...)

# S3 method for class 'sm_self_citation'
summary(object, ...)
```

## Arguments

- corpus:

  An `sm_corpus` with a populated `references` sub-tibble whose
  `cited_work_id` links to corpus works.

- level:

  `"author"` (default) or `"institution"`.

- method:

  Self-citation definition; currently only `"reference_overlap"`.

- call:

  Caller environment for error reporting.

- x:

  An `sm_self_citation` object.

- ...:

  Ignored.

- object:

  An `sm_self_citation` object.

## Value

An `sm_self_citation` S3 object (a list) with components:

- by_entity:

  Tibble: `entity_id`, `n_citations_received` (internal citations to the
  entity's works), `n_self_citations`, `self_citation_share`.

- by_work:

  Tibble: `cited_work_id`, `n_citations_received`, `n_self_citations`,
  `self_citation_share` (per cited work).

- provenance:

  Tibble: `citing_work_id`, `cited_work_id`, and `shared_author_id`
  (author level) or `shared_institution_id` (institution level) — the
  evidence behind each self-citation.

Type-stable: when `references` is absent/empty the components are 0-row
tibbles with the documented columns, returned after a
[`cli::cli_warn`](https://cli.r-lib.org/reference/cli_abort.html) (the
function never spins).

`print` returns `x` invisibly.

`summary` returns the `by_entity` tibble.

## See also

[`sm_metric_h_index()`](https://cttir.github.io/scimapR/reference/sm_metric_h_index.md)

Other metrics:
[`sm_metric_collab_index()`](https://cttir.github.io/scimapR/reference/sm_metric_collab_index.md),
[`sm_metric_disruption()`](https://cttir.github.io/scimapR/reference/sm_metric_disruption.md),
[`sm_metric_fnci()`](https://cttir.github.io/scimapR/reference/sm_metric_fnci.md),
[`sm_metric_g_index()`](https://cttir.github.io/scimapR/reference/sm_metric_g_index.md),
[`sm_metric_h_index()`](https://cttir.github.io/scimapR/reference/sm_metric_h_index.md),
[`sm_metric_m_index()`](https://cttir.github.io/scimapR/reference/sm_metric_m_index.md),
[`sm_metric_novelty()`](https://cttir.github.io/scimapR/reference/sm_metric_novelty.md),
[`sm_metric_rcr()`](https://cttir.github.io/scimapR/reference/sm_metric_rcr.md),
[`sm_summary_authors()`](https://cttir.github.io/scimapR/reference/sm_summary_authors.md),
[`sm_summary_period()`](https://cttir.github.io/scimapR/reference/sm_summary_period.md),
[`sm_summary_sources()`](https://cttir.github.io/scimapR/reference/sm_summary_sources.md),
[`sm_summary_works()`](https://cttir.github.io/scimapR/reference/sm_summary_works.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 40, seed = 1)
sc <- sm_self_citation(corpus, level = "author")
head(sc$by_entity)
#> # A tibble: 6 × 4
#>   entity_id  n_citations_received n_self_citations self_citation_share
#>   <chr>                     <int>            <int>               <dbl>
#> 1 A000000001                  351              292              0.832 
#> 2 A000000003                   47                7              0.149 
#> 3 A000000061                   47                5              0.106 
#> 4 A000000015                   40                4              0.1   
#> 5 A000000046                   56                4              0.0714
#> 6 A000000057                   43                4              0.093 
```
