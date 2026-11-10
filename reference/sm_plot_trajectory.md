# Plot author trajectory

Multi-panel visualization of an author's career trajectory.

## Usage

``` r
sm_plot_trajectory(traj, dark = FALSE, ...)
```

## Arguments

- traj:

  An `sm_trajectory` object.

- dark:

  Logical; dark mode?

- ...:

  Additional arguments.

## Value

A `ggplot` object composed via patchwork.

## See also

Other trajectory:
[`is_sm_trajectory()`](https://cttir.github.io/scimapR/reference/is_sm_trajectory.md),
[`sm_author_trajectory()`](https://cttir.github.io/scimapR/reference/sm_author_trajectory.md),
[`sm_plot_collab_turnover()`](https://cttir.github.io/scimapR/reference/sm_plot_collab_turnover.md),
[`sm_plot_topic_pivots()`](https://cttir.github.io/scimapR/reference/sm_plot_topic_pivots.md),
[`sm_researcher_profile()`](https://cttir.github.io/scimapR/reference/sm_researcher_profile.md),
[`sm_trajectory`](https://cttir.github.io/scimapR/reference/sm_trajectory.md)

## Examples

``` r
corpus <- sm_example_corpus()
traj <- sm_author_trajectory(corpus, author_id = corpus$authors$author_id[1])
sm_plot_trajectory(traj)
```
