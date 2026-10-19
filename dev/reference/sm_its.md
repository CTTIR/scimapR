# Interrupted time series for a corpus outcome

A turnkey interrupted time series (ITS): aggregates the chosen `outcome`
to a yearly series, fits a segmented regression with a level shift and a
slope change at `intervention_year`, and derives the counterfactual (the
pre-intervention trend projected forward).

## Usage

``` r
sm_its(
  corpus,
  intervention_year,
  outcome = c("count", "share_q1", "cnci", "leadership"),
  family = NULL,
  lag = NULL,
  call = rlang::caller_env()
)

# S3 method for class 'sm_its'
print(x, ...)

# S3 method for class 'sm_its'
summary(object, ...)

# S3 method for class 'sm_its'
autoplot(object, ...)
```

## Arguments

- corpus:

  An `sm_corpus`.

- intervention_year:

  Year at which the intervention takes effect: one whole number such as
  `2020`, or text holding one.

- outcome:

  One of `"count"`, `"share_q1"`, `"cnci"`, `"leadership"`. The expected
  source columns are:

  `"count"`

  :   Works per year (uses `works$year`).

  `"share_q1"`

  :   Share of Q1-journal works among the works with a quartile; needs a
      journal-quartile column on `works` (`quartile`, `jif_quartile`, or
      `sjr_quartile`).

  `"cnci"`

  :   Mean field-normalised citation impact per year. Impact is resolved
      from the first populated of `works$cnci`, a `corpus$metrics` table
      (`cnci`/`fnci`/`value` keyed by `work_id`), or
      `works$cited_by_count` (from which FNCI is derived via
      [`sm_metric_fnci()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_fnci.md)).
      If none is populated, an informative error names the columns
      inspected. Works without a finite impact value are left out of the
      yearly mean.

  `"leadership"`

  :   Share of works with a corresponding/leadership author (uses
      `authorships$is_corresponding`).

- family:

  Optional GLM family (a `family` object, generator function, or name).
  Defaults to Poisson for `"count"` and Gaussian otherwise; document
  your choice when overriding. A Poisson fit warns when the counts are
  overdispersed; `"quasipoisson"` then scales the standard errors.

- lag:

  Citation-maturity lag in years (default `2`). For citation-based
  outcomes (`"cnci"`), the most recent `lag` years are citation-immature
  and are excluded from the fit; this is reported in the print method.

- call:

  Caller environment for error reporting.

- x:

  An `sm_its` object.

- ...:

  Ignored.

- object:

  An `sm_its` object.

## Value

An `sm_its` S3 object with components: `model` (the fitted `glm`),
`coefficients` (tidy tibble: `term`, `estimate`, `std.error`,
`conf.low`, `conf.high`, `statistic`, `p.value`), `series` (tibble:
`year`, `observed`, `fitted`, `counterfactual`), and metadata
(`outcome`, `intervention_year`, `family`, `lag`, `provisional_years`,
`dropped_years`). `dropped_years` (integer) lists the years left out for
lack of a usable value, `provisional_years` (integer) the
citation-immature years excluded after them.

`print` returns `x` invisibly.

`summary` returns the tidy coefficient tibble.

`autoplot` returns a `ggplot`.

## Details

The yearly series is built first. For `"count"` it runs over every year
from the first to the last publication year of the corpus, and a year
without works counts 0, so filter the corpus to the analysis window
beforehand. For the other outcomes a year with works but no usable value
is dropped with a warning and listed in `dropped_years`: no work of the
year has a journal quartile (`"share_q1"`) or a finite impact value
(`"cnci"`). For `"cnci"` the citation-immature years are excluded after
that and listed in `provisional_years`, so no year is in both.

At least 4 years must remain after these exclusions, with 2 or more
before `intervention_year` and 2 or more from it on, so that the
pre-trend, the level change and the slope change can all be estimated;
otherwise `sm_its()` aborts. With only 4 years the 4 coefficients fit
the series exactly: a family that estimates its dispersion (Gaussian,
quasi families) then has no residual degrees of freedom, so its standard
errors, intervals and p-values are `NaN` and `sm_its()` warns. Families
that fix the dispersion, such as the Poisson default for `"count"`, keep
their standard errors.

The confidence intervals are Wald intervals on the reference
distribution of the p-values: t with the residual degrees of freedom
when the family estimates its dispersion (Gaussian and quasi families),
normal when the family fixes it (Poisson, binomial). The standard errors
treat the yearly values as independent; no correction for
autocorrelation is applied.

## See also

[`sm_did()`](https://cttir.github.io/scimapR/dev/reference/sm_did.md),
[`sm_citation_maturity()`](https://cttir.github.io/scimapR/dev/reference/sm_citation_maturity.md)

Other causal:
[`sm_did()`](https://cttir.github.io/scimapR/dev/reference/sm_did.md),
[`sm_synth()`](https://cttir.github.io/scimapR/dev/reference/sm_synth.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 200, seed = 1)
its <- sm_its(corpus, intervention_year = 2020, outcome = "count")
its
#> 
#> ── <sm_its> ────────────────────────────────────────────────────────────────────
#> Outcome: count Family: poisson
#> Intervention year: 2020
#> 
#> 
#> ── Segmented regression coefficients 
#> Baseline level: 3.0063 [2.6712, 3.3413] (p = <2e-16)
#> Pre-trend (slope): 0.0236 [-0.1111, 0.1583] (p = 0.73)
#> Level change: -0.2997 [-0.8709, 0.2714] (p = 0.3)
#> Slope change: 0.0297 [-0.1669, 0.2262] (p = 0.77)
# \donttest{
ggplot2::autoplot(its)

# }
```
