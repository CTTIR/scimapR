# Difference-in-differences for a treated vs control institution set

Fits a difference-in-differences (DiD) model comparing the yearly
`outcome` series of a treated institution set against a control set,
before and after `intervention_year`. Group membership is resolved via
the institution-attribution columns from
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_match.md)
/
[`sm_attribute_institution()`](https://cttir.github.io/scimapR/dev/reference/sm_attribute_institution.md).

## Usage

``` r
sm_did(
  corpus,
  treated,
  control,
  intervention_year,
  outcome = c("count", "share_q1", "cnci", "leadership"),
  family = NULL,
  call = rlang::caller_env()
)

# S3 method for class 'sm_did'
print(x, ...)

# S3 method for class 'sm_did'
summary(object, ...)

# S3 method for class 'sm_did'
autoplot(object, ...)
```

## Arguments

- corpus:

  An `sm_corpus` with institution-attribution columns.

- treated, control:

  Character vectors of institution labels (matched against
  `institution_name` / `institution_match` / `institution_id`).

- intervention_year:

  Year the intervention takes effect: one whole number such as `2020`,
  or text holding one.

- outcome:

  One of `"count"`, `"share_q1"`, `"cnci"`, `"leadership"` (see
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md)).

- family:

  Optional GLM family; defaults to Gaussian (DiD is an additive
  contrast). Override for, e.g., a Poisson count model; a Poisson fit
  warns when the counts are overdispersed.

- call:

  Caller environment for error reporting.

- x:

  An `sm_did` object.

- ...:

  Ignored.

- object:

  An `sm_did` object.

## Value

An `sm_did` S3 object with components: `model`, `did_estimate` (a
one-row tibble: `estimate`, `std.error`, `conf.low`, `conf.high`,
`p.value`), `series` (group-by-year tibble: `year`, `group`, `value`,
`n_works`), `dropped_years` (tibble: `group`, `year`; the group-years
left out for lack of a usable value), and metadata (`outcome`,
`intervention_year`, `family`).

`print` returns `x` invisibly.

`summary` returns the DiD estimate tibble.

`autoplot` returns a `ggplot` (parallel trends + divergence).

## Details

Each group's yearly series is built as in
[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md).
For `"count"` a group's years without works count 0, over every year
from the first to the last publication year of the corpus. For the other
outcomes a year in which a group has works but no usable value is
dropped from that group's series, with a warning, and listed in
`dropped_years`. Each group needs 4 or more years, with at least one
before `intervention_year` and one from it on; otherwise `sm_did()`
aborts. The confidence interval uses the reference distribution of the
p-value (t with the residual degrees of freedom for the default Gaussian
family); no correction for autocorrelation is applied.

## See also

[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md),
[`sm_synth()`](https://cttir.github.io/scimapR/dev/reference/sm_synth.md)

Other causal:
[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md),
[`sm_synth()`](https://cttir.github.io/scimapR/dev/reference/sm_synth.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 120, seed = 1)
# Tag two institution groups for illustration
corpus$authorships$institution_name <- rep(
  c("Inst A", "Inst B"), length.out = nrow(corpus$authorships))
did <- sm_did(corpus, treated = "Inst A", control = "Inst B",
              intervention_year = 2020, outcome = "count")
did
#> 
#> ── <sm_did> ────────────────────────────────────────────────────────────────────
#> Outcome: count Family: gaussian
#> Intervention year: 2020
#> 
#> DiD estimate: 0.6 [-5.5733, 6.7733] (p = 0.84)
```
