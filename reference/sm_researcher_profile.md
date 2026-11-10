# Build a researcher profile

One-shot workflow: fetch all works for a researcher by ORCID, enrich,
embed, and build a trajectory analysis.

## Usage

``` r
sm_researcher_profile(
  orcid,
  sources = c("openalex"),
  enrich = c("oa_status"),
  embed = FALSE,
  trajectory = TRUE,
  mailto = Sys.getenv("SCIMAPR_MAILTO"),
  n_max = 200L
)
```

## Arguments

- orcid:

  ORCID identifier.

- sources:

  API sources to query.

- enrich:

  Enrichment steps to run.

- embed:

  Logical; compute embeddings?

- trajectory:

  Logical; build trajectory analysis?

- mailto:

  Contact address sent to OpenAlex (see
  [`sm_fetch_openalex()`](https://cttir.github.io/scimapR/reference/sm_fetch_openalex.md)).

- n_max:

  Maximum number of works to fetch (default `200`, as in
  [`sm_fetch_openalex()`](https://cttir.github.io/scimapR/reference/sm_fetch_openalex.md)).
  A researcher with more works gets a profile of the first `n_max` only,
  so raise it for long careers.

## Value

An `sm_corpus` with trajectory attached as attribute.

## See also

Other trajectory:
[`is_sm_trajectory()`](https://cttir.github.io/scimapR/reference/is_sm_trajectory.md),
[`sm_author_trajectory()`](https://cttir.github.io/scimapR/reference/sm_author_trajectory.md),
[`sm_plot_collab_turnover()`](https://cttir.github.io/scimapR/reference/sm_plot_collab_turnover.md),
[`sm_plot_topic_pivots()`](https://cttir.github.io/scimapR/reference/sm_plot_topic_pivots.md),
[`sm_plot_trajectory()`](https://cttir.github.io/scimapR/reference/sm_plot_trajectory.md),
[`sm_trajectory`](https://cttir.github.io/scimapR/reference/sm_trajectory.md)

## Examples

``` r
# \donttest{
# Queries the OpenAlex web API; 0000-0002-1825-0097 is the ORCID test record.
if (requireNamespace("curl", quietly = TRUE) && curl::has_internet()) {
  profile <- try(sm_researcher_profile("0000-0002-1825-0097", n_max = 20))
  print(profile)
}
#> ℹ Fetching works from OpenAlex...
#> ℹ Fetched 20 / 20 works.
#> ✔ Parsed 20 OpenAlex works into sm_corpus.
#> 
#> ── <sm_corpus> ─────────────────────────────────────────────────────────────────
#> Works: 20 | Authors: 76 | Institutions: 0
#> Years: 2004 - 2025
#> Sources (journals): 18
#> Embeddings: none
#> Provenance: openalex (20)
#> Status: Unlocked (last refreshed: never)
# }
```
