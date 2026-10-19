# scimapR accessor return-type stability contract

scimapR treats the return type of its **documented accessors** as a
contract. The column set (names and types) of an accessor's documented
return value will not change without a
[lifecycle](https://lifecycle.r-lib.org/) deprecation and a
corresponding `NEWS.md` entry. New columns may be *added* (a
non-breaking change); existing documented columns will not be removed or
retyped silently.

This policy exists because a silent list -\> tibble change in
[`sm_coverage_breakdowns()`](https://cttir.github.io/scimapR/dev/reference/sm_coverage_breakdowns.md)
between 0.2.0 and 0.3.0 broke downstream code. From 0.4.0, accessors
that expose a tidy table take a `tidy = TRUE` argument whose column set
is the stable contract.

## Audited accessors and their stable return shapes

- [`sm_coverage_breakdowns()`](https://cttir.github.io/scimapR/dev/reference/sm_coverage_breakdowns.md)
  (`tidy = TRUE`):

  A long tibble: `dimension`, `level`, `n_reference`, `n_matched`,
  `recall`, `n_corpus`, `precision`, `f1`.

- [`summary.sm_coverage()`](https://cttir.github.io/scimapR/dev/reference/sm_coverage_audit.md):

  A one-row tibble: `recall`, `precision`, `f1`, `n_corpus`,
  `n_reference`, `n_matched`, `n_corpus_only`, `n_reference_only` and
  `n_corpus_matched` (the corpus records paired with a reference record,
  the numerator of `precision`; added after scimapR 0.4.0).

- [`sm_affiliation_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_summary.md):

  A tibble: `institution`, `match_signal` (factor, see
  [`sm_affiliation_signals()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_signals.md)),
  `n_authorships`, `n_works`, `example_evidence`.

- [`sm_affiliation_unmatched()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_unmatched.md):

  A tibble: `raw_affiliation` (character), `n_authorships` and `n_works`
  (integer), sorted by `n_authorships` descending and then by
  `raw_affiliation`.

- [`sm_reconcile()`](https://cttir.github.io/scimapR/dev/reference/sm_reconcile.md)
  ([`summary()`](https://rdrr.io/r/base/summary.html)):

  A one-row tibble: `n_a`, `n_b`, `n_both`, `n_only_a`, `n_only_b`,
  `jaccard`.

- [`sm_metric_summary()`](https://cttir.github.io/scimapR/dev/reference/sm_metric_summary.md):

  A one-row tibble: `metric`, `n`, `mean`, `median`, and (when
  `robust = TRUE`) `median_ci_low`, `median_ci_high`, `pp_top10`,
  `n_boot`.

- [`sm_self_citation()`](https://cttir.github.io/scimapR/dev/reference/sm_self_citation.md)
  (`by_entity` / `by_work` / `provenance`):

  Tidy tibbles with the columns documented at
  [`sm_self_citation()`](https://cttir.github.io/scimapR/dev/reference/sm_self_citation.md).

## Controlled vocabularies

Free-text controlled columns are emitted as factors with exported level
sets, so downstream filtering is reliable: see
[`sm_affiliation_signals()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_signals.md)
(`match_signal`),
[`sm_affiliation_methods()`](https://cttir.github.io/scimapR/dev/reference/sm_affiliation_methods.md)
(`match_method`), and
[`sm_match_types()`](https://cttir.github.io/scimapR/dev/reference/sm_match_types.md)
(coverage `match_type`).

The `vocabulary` column of `corpus$concepts` is the exception: it stays
character, so concept tables bind and hash as before, and its values are
the names returned by
[`sm_concept_vocabularies()`](https://cttir.github.io/scimapR/dev/reference/sm_concept_vocabularies.md).
Readers write these names, and
[`sm_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus.md)
and
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md)
rename legacy spellings to them.
`sm_concept_vocabularies(describe = TRUE)` returns a tibble with the
factor columns `level` and `family` and a character `description`.
