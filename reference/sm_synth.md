# Synthetic control for a treated institution

Builds the unit-by-time outcome panel for a treated institution against
a donor pool and estimates a synthetic control using the optional
tidysynth package. The dependency is kept in `Suggests`; when it is not
installed an informative error explains how to install it.

## Usage

``` r
sm_synth(
  corpus,
  treated,
  donors,
  intervention_year,
  outcome = c("count", "share_q1", "cnci", "leadership"),
  call = rlang::caller_env()
)

# S3 method for class 'sm_synth'
print(x, ...)
```

## Arguments

- corpus:

  An `sm_corpus` with institution-attribution columns.

- treated:

  A single institution label (the treated unit).

- donors:

  Character vector of donor-pool institution labels.

- intervention_year:

  Integer year the intervention takes effect.

- outcome:

  One of `"count"`, `"share_q1"`, `"cnci"`, `"leadership"`.

- call:

  Caller environment for error reporting.

- x:

  An `sm_synth` object.

- ...:

  Ignored.

## Value

An `sm_synth` S3 object wrapping the fitted `tidysynth` object
(`synth`), the long panel (`panel`), and metadata.

`print` returns `x` invisibly.

## See also

[`sm_did()`](https://cttir.github.io/scimapR/reference/sm_did.md)

Other causal:
[`sm_did()`](https://cttir.github.io/scimapR/reference/sm_did.md),
[`sm_its()`](https://cttir.github.io/scimapR/reference/sm_its.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 300, seed = 1)
corpus$authorships$institution_name <- sample(
  c("A", "B", "C", "D"), nrow(corpus$authorships), replace = TRUE)
synth <- sm_synth(corpus, treated = "A", donors = c("B", "C", "D"),
                  intervention_year = 2020, outcome = "count")
```
