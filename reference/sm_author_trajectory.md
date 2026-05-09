# Build an author trajectory analysis

Analyses the career trajectory of a single author within a corpus,
partitioning their publication record into `n_periods` career stages.
For each period, the function computes:

- **Career stages**: dominant topics and publication volume.

- **Topic pivots**: how much the research focus shifted between periods,
  measured as the Jaccard distance of concept sets.

- **Collaborator turnover**: Jaccard similarity of co-author sets across
  consecutive periods, plus counts of new, kept, and lost collaborators.

- **Emerging collaborators**: co-authors who first appear in the most
  recent period.

- **H-index curve**: cumulative h-index at the end of each period.

- **Novelty curve**: average concept novelty per period.

- **Citation acceleration**: mean citations per period relative to the
  corpus-wide mean for the same years.

## Usage

``` r
sm_author_trajectory(
  corpus,
  orcid = NULL,
  author_id = NULL,
  n_periods = 5L,
  call = rlang::caller_env()
)

# S3 method for class 'sm_trajectory'
print(x, ...)

# S3 method for class 'sm_trajectory'
format(x, ...)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- orcid:

  Character. ORCID of the author to analyse. Either `orcid` or
  `author_id` must be supplied.

- author_id:

  Character. Internal author ID. Either `orcid` or `author_id` must be
  supplied.

- n_periods:

  Integer. Number of career periods to divide the publication span into.
  Default `5`.

- call:

  Caller environment for error reporting.

- x:

  An `sm_trajectory` object.

- ...:

  Ignored.

## Value

An `sm_trajectory` S3 object.

- [`print()`](https://rdrr.io/r/base/print.html): `x` invisibly.

- [`format()`](https://rdrr.io/r/base/format.html): A single character
  string.

## See also

Other trajectory:
[`is_sm_trajectory()`](https://r-heller.github.io/scimapR/reference/is_sm_trajectory.md),
[`sm_plot_collab_turnover()`](https://r-heller.github.io/scimapR/reference/sm_plot_collab_turnover.md),
[`sm_plot_topic_pivots()`](https://r-heller.github.io/scimapR/reference/sm_plot_topic_pivots.md),
[`sm_plot_trajectory()`](https://r-heller.github.io/scimapR/reference/sm_plot_trajectory.md),
[`sm_researcher_profile()`](https://r-heller.github.io/scimapR/reference/sm_researcher_profile.md),
[`sm_trajectory`](https://r-heller.github.io/scimapR/reference/sm_trajectory.md)

## Examples

``` r
corpus <- sm_example_corpus()
# Use the first author's ID
traj <- sm_author_trajectory(corpus, author_id = "A000000001")
print(traj)
#> 
#> ── <sm_trajectory> ─────────────────────────────────────────────────────────────
#> Author: Elena Fischer
#> Author ID: A000000001
#> ORCID: 0000-0003-6689-5331
#> Periods: 5
#> 
#> 
#> ── Career stages 
#> Period 1 (2015-2016): 5 works, h=6 | gene expression, biomarker discovery, drug
#> resistance
#> Period 2 (2016-2018): 6 works, h=9 | colorectal cancer, machine learning,
#> clinical outcomes
#> Period 3 (2018-2020): 6 works, h=11 | single-cell RNA-seq, biomarker discovery,
#> clinical outcomes
#> Period 4 (2020-2022): 10 works, h=13 | biomarker discovery, colorectal cancer,
#> single-cell RNA-seq
#> Period 5 (2022-2024): 13 works, h=14 | immune checkpoint, machine learning,
#> clinical outcomes
#> 
#> 
#> ── Topic pivots 
#> Period 2: score=0.3 (stable)
#> Period 3: score=0.3 (stable)
#> Period 4: score=0.3 (stable)
#> Period 5: score=0 (stable)
#> 
#> 
#> ── Collaborator turnover 
#> Period 2: Jaccard=0.194 (new=14, kept=7, lost=15)
#> Period 3: Jaccard=0.081 (new=16, kept=3, lost=18)
#> Period 4: Jaccard=0.085 (new=28, kept=4, lost=15)
#> Period 5: Jaccard=0.315 (new=22, kept=17, lost=15)
#> 
#> 
#> ── Emerging collaborators (9) 
#> James Ibrahim (since 2024)
#> Carlos Smith (since 2022)
#> Wei Johansson (since 2024)
#> Carlos Patel (since 2024)
#> David Andersson (since 2023)
#> ... and 4 more
#> 
#> 
#> ── H-index curve 
#> 2015-2016:6 -> 2016-2018:9 -> 2018-2020:11 -> 2020-2022:13 -> 2022-2024:14
#> 
#> 
#> ── Citation acceleration 
#> 2015-2016: mean=9.4 (-5.3 vs field)
#> 2016-2018: mean=18.3 (+4 vs field)
#> 2018-2020: mean=17 (+2 vs field)
#> 2020-2022: mean=11.2 (-6.1 vs field)
#> 2022-2024: mean=11.8 (-2.5 vs field)
```
