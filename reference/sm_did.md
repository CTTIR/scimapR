# Difference-in-differences for a treated vs control institution set

Fits a difference-in-differences (DiD) model comparing the yearly
`outcome` series of a treated institution set against a control set,
before and after `intervention_year`. Group membership is resolved via
the institution-attribution columns from
[`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md)
/
[`sm_attribute_institution()`](https://cttir.github.io/scimapR/reference/sm_attribute_institution.md).

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

  Integer year the intervention takes effect.

- outcome:

  One of `"count"`, `"share_q1"`, `"cnci"`, `"leadership"` (see
  [`sm_its()`](https://cttir.github.io/scimapR/reference/sm_its.md)).

- family:

  Optional GLM family; defaults to Gaussian (DiD is an additive
  contrast). Override for, e.g., a Poisson count model.

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
`n_works`), and metadata (`outcome`, `intervention_year`, `family`).

`print` returns `x` invisibly.

`summary` returns the DiD estimate tibble.

`autoplot` returns a `ggplot` (parallel trends + divergence).

## See also

[`sm_its()`](https://cttir.github.io/scimapR/reference/sm_its.md),
[`sm_synth()`](https://cttir.github.io/scimapR/reference/sm_synth.md)

Other causal:
[`sm_its()`](https://cttir.github.io/scimapR/reference/sm_its.md),
[`sm_synth()`](https://cttir.github.io/scimapR/reference/sm_synth.md)

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
#> DiD estimate: 0.6 [-5.1075, 6.3075] (p = 0.84)
```
