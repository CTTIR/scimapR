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
  mailto = Sys.getenv("SCIMAPR_MAILTO")
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

  Email for API polite pool.

## Value

An `sm_corpus` with trajectory attached as attribute.

## See also

Other trajectory:
[`is_sm_trajectory()`](https://r-heller.github.io/scimapR/reference/is_sm_trajectory.md),
[`sm_author_trajectory()`](https://r-heller.github.io/scimapR/reference/sm_author_trajectory.md),
[`sm_plot_collab_turnover()`](https://r-heller.github.io/scimapR/reference/sm_plot_collab_turnover.md),
[`sm_plot_topic_pivots()`](https://r-heller.github.io/scimapR/reference/sm_plot_topic_pivots.md),
[`sm_plot_trajectory()`](https://r-heller.github.io/scimapR/reference/sm_plot_trajectory.md),
[`sm_trajectory`](https://r-heller.github.io/scimapR/reference/sm_trajectory.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# profile <- sm_researcher_profile("0000-0001-8006-9742")
} # }
```
