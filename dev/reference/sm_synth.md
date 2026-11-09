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
  lag = NULL,
  institution_aware = FALSE,
  lead_role = c("corresponding", "first", "last", "first_or_last", "any_lead"),
  min_cell = NULL,
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

  Year the intervention takes effect: one whole number such as `2020`,
  or text holding one.

- outcome:

  One of `"count"`, `"share_q1"`, `"cnci"`, `"leadership"`.

- lag:

  Citation-maturity lag in years (default `2`), as in
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md):
  for `"cnci"` the most recent `lag` years are citation-immature and
  excluded from the panel.

- institution_aware:

  For `outcome = "leadership"`: if `TRUE`, each unit's share counts the
  works whose author in the role `lead_role` belongs to the unit itself
  (its label is the focal institution, as `institutions` in
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md));
  the treated unit and every donor use their own label. `FALSE`
  (default) counts the works with a corresponding author.

- lead_role:

  For `outcome = "leadership"`: the author role that leads a work, as in
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md).
  Roles other than `"corresponding"` need `institution_aware = TRUE`.

- min_cell:

  For `outcome = "cnci"`: `NULL` (default) or a positive integer, passed
  to
  [`sm_metric_fnci()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_fnci.md)
  when the impact is derived from citation counts, as in
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md).

- call:

  Caller environment for error reporting.

- x:

  An `sm_synth` object.

- ...:

  Ignored.

## Value

An `sm_synth` S3 object wrapping the initialised `tidysynth` object
(`synth`), the long panel (`panel`: `unit`, `year`, `value`),
`dropped_years` (tibble: `unit`, `year`; the unit-years without a usable
value, whose years were dropped for every unit), `provisional_years`
(integer; the citation-immature years excluded for `"cnci"`),
`leadership` (the leadership definition, as in
[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md),
with `institutions` the unit labels when `institution_aware`; `NULL` for
the other outcomes), `impact_source` (where the impact values of
`"cnci"` come from, as in
[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md);
`NA` for the other outcomes), and metadata.

`print` returns `x` invisibly.

## Details

Each unit's yearly series is built as in
[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md),
and every unit must contain works. For `"count"` a unit's years without
works count 0, over every year from the first to the last publication
year of the corpus, so no year is dropped. For the other outcomes the
panel stays balanced: a year in which any unit has no works or no usable
value is dropped for every unit, with a warning, and listed in
`dropped_years`. For `"cnci"` the citation-immature years are then
excluded for every unit, by the same rule as in
[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md),
and listed in `provisional_years`; up to scimapR 0.4.0 `sm_synth()` kept
them. At least 4 panel years must remain, 2 or more before
`intervention_year` and 1 or more from it on; otherwise `sm_synth()`
aborts. For `"leadership"` the shares leave out the works whose lead is
unknown, as in
[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md).

## See also

[`sm_did()`](https://cttir.github.io/scimapR/dev/reference/sm_did.md)

Other causal:
[`sm_did()`](https://cttir.github.io/scimapR/dev/reference/sm_did.md),
[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 300, seed = 1)
corpus$authorships$institution_name <- sample(
  c("A", "B", "C", "D"), nrow(corpus$authorships), replace = TRUE)
synth <- sm_synth(corpus, treated = "A", donors = c("B", "C", "D"),
                  intervention_year = 2020, outcome = "count")
```
