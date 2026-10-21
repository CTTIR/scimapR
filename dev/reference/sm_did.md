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
  lag = NULL,
  institution_aware = FALSE,
  lead_role = c("corresponding", "first", "last", "first_or_last", "any_lead"),
  shared = c("keep", "exclude", "lead"),
  min_cell = NULL,
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
  `institution_name` / `institution_match` / `institution_id`). The two
  may not share a label.

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

- lag:

  Citation-maturity lag in years (default `2`), as in
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md):
  for `"cnci"` the most recent `lag` years are citation-immature and
  excluded.

- institution_aware:

  For `outcome = "leadership"`: if `TRUE`, each group's share counts the
  works whose author in the role `lead_role` belongs to the group's own
  institutions (the treated series uses `institutions = treated`, the
  control series `institutions = control`, as in
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md)).
  `FALSE` (default) counts the works with a corresponding author.

- lead_role:

  The author role that leads a work, as in
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md),
  for `outcome = "leadership"` and for `shared = "lead"`. For the
  leadership outcome, roles other than `"corresponding"` need
  `institution_aware = TRUE`.

- shared:

  What to do with works that belong to both groups, such as works
  co-authored by a treated and a control institution: `"keep"` (default)
  keeps them in both series, `"exclude"` leaves them out of both, and
  `"lead"` puts each in the series of the group whose institution holds
  its author in the role `lead_role` (a work led from both groups or
  from neither leaves both series).

- min_cell:

  For `outcome = "cnci"`: `NULL` (default) or a positive integer, passed
  to
  [`sm_metric_fnci()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_fnci.md)
  when the impact is derived from citation counts, as in
  [`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md).

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
left out for lack of a usable value), `provisional_years` (integer; the
citation-immature years excluded for `"cnci"`), `shared_works` (tibble:
`work_id`, `series`; the works of both groups and where they went:
`"both"`, `"treated"`, `"control"` or `"none"`), `shared` (the policy),
`leadership` (the leadership definition, as in
[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md),
with `institutions` the labels of each group when `institution_aware`;
`NULL` for the other outcomes), `impact_source` (where the impact values
of `"cnci"` come from, as in
[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md);
`NA` for the other outcomes), and metadata (`outcome`,
`intervention_year`, `family`, `lag`).

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
`dropped_years`. For `"cnci"` the citation-immature years are then
excluded from both series, by the same rule as in
[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md),
and listed in `provisional_years`; up to scimapR 0.4.0 `sm_did()` kept
them. Each group needs 4 or more years, with at least one before
`intervention_year` and one from it on; otherwise `sm_did()` aborts. The
confidence interval uses the reference distribution of the p-value (t
with the residual degrees of freedom for the default Gaussian family);
no correction for autocorrelation is applied.

A work belongs to a group when one of its authorships carries one of the
group's labels, so a work co-authored by both groups belongs to both.
Such shared works pull the two series together and the estimate toward
0. `sm_did()` warns when there are shared works and `shared` is not set,
and records them in `shared_works`. For `"leadership"` the denominators
leave out the works whose lead is unknown, as in
[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md).

## See also

[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md),
[`sm_synth()`](https://cttir.github.io/scimapR/dev/reference/sm_synth.md)

Other causal:
[`sm_its()`](https://cttir.github.io/scimapR/dev/reference/sm_its.md),
[`sm_synth()`](https://cttir.github.io/scimapR/dev/reference/sm_synth.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 120, seed = 1)
# Tag two institution groups for illustration: each work belongs to one
a <- corpus$authorships
group <- rep(c("Inst A", "Inst B"), length.out = nrow(corpus$works))
corpus$authorships$institution_name <-
  group[match(a$work_id, corpus$works$work_id)]
did <- sm_did(corpus, treated = "Inst A", control = "Inst B",
              intervention_year = 2020, outcome = "count")
did
#> 
#> ── <sm_did> ────────────────────────────────────────────────────────────────────
#> Outcome: count Family: gaussian
#> Intervention year: 2020
#> 
#> DiD estimate: 2.4 [-2.0366, 6.8366] (p = 0.27)
```
