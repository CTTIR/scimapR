# Changelog

## scimapR 0.3.0

Real-use refinements from running v0.2.0 on a ~6,853-work corpus:
robustness fixes, friendlier API shapes, two new capabilities, and
vignettes that ship in the installed binary. The public API is preserved
(deprecation paths only).

### Bug fixes

- **A1** `sm_its(outcome = "cnci")` no longer fails with a cryptic “Too
  few yearly observations: 0” when impact lives outside
  `cited_by_count`. The resolver now searches, in order, `works$cnci`, a
  `corpus$metrics` table, then `works$cited_by_count` (deriving FNCI);
  if none is populated it raises an informative error naming the columns
  it inspected.
- **A2** `sm_count(level = "institution")` falls back to
  `authorships$raw_affiliation` (with a `cli` warning that results are
  un-disambiguated) when structured institution IDs are absent, and
  warns rather than returning a silent empty result when no institution
  data exists.
- **A3**
  [`sm_metric_disruption()`](https://cttir.github.io/scimapR/reference/sm_metric_disruption.md)
  and
  [`sm_metric_novelty()`](https://cttir.github.io/scimapR/reference/sm_metric_novelty.md)
  fast-exit with a warning when the reference network is empty/absent
  instead of spinning; the disruption index was rewritten with O(1)
  adjacency lookups (no longer O(n^2)) and now shows a `cli` progress
  bar.
  [`sm_audit_summary()`](https://cttir.github.io/scimapR/reference/sm_audit_summary.md)
  shows a progress bar across its sub-audits.
- **A4** Network plots
  ([`sm_plot_citation_network()`](https://cttir.github.io/scimapR/reference/sm_plot_citation_network.md),
  [`sm_plot_collab()`](https://cttir.github.io/scimapR/reference/sm_plot_collab.md))
  gain `precompute = TRUE` (eager layout -\> a self-contained plain
  `ggplot` that prints cheaply in knitr/`callr`/workflowr subprocesses)
  and a `max_nodes` cap (default 200) for very large graphs.

### Ergonomics

- **B1** `sm_coverage_audit()$breakdowns` is now a single flat tibble
  (`dimension`, `level`, `n_reference`, `n_matched`, `recall`). The
  previous nested list remains available under `$breakdowns_nested` for
  one release. New accessor
  [`sm_coverage_breakdowns()`](https://cttir.github.io/scimapR/reference/sm_coverage_breakdowns.md)
  returns/filters the flat tibble.
- **B2**
  [`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md)
  documents its added columns and gains
  [`sm_affiliation_summary()`](https://cttir.github.io/scimapR/reference/sm_affiliation_summary.md)
  — a tidy works/authorships breakdown by institution and match signal,
  also surfaced as a `cli` summary on completion.
- **B3**
  [`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/reference/sm_corpus_from_tables.md)
  is promoted in the ingestion vignette as the recommended “bring your
  own relational data” entry point.

### New capabilities

- **C1** `sm_coverage_audit(..., index_table = )` additionally assesses
  journal **indexability** (reusing
  [`sm_journal_in_index()`](https://cttir.github.io/scimapR/reference/sm_journal_in_index.md)),
  adding `issn`/`indexable` columns to `$matches` and an `$indexability`
  summary. Output is unchanged when `index_table` is `NULL`.
- **C2**
  [`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md)
  returns `match_signal` (`name_token`/`email_domain`/`postcode`) and
  `match_evidence` (the matched substring/domain/code) for an audit
  trail, plus an opt-in `postcode_signal = TRUE` matcher (off by default
  so existing matches are stable).

### Packaging

- **D1** Vignettes now ship in the installed binary; browse them offline
  with `vignette(package = "scimapR")` / `browseVignettes("scimapR")`,
  or online at the pkgdown site. New `inst/extdata/` fixtures:
  `example_affiliation_postcode.csv`.

## scimapR 0.2.0

A new capability layer for research-coverage, affiliation-attribution,
and policy-evaluation analyses, plus four reproducible bug fixes. All
existing functionality, the `sm_corpus` schema, bibliometrix interop,
and the Shiny app are preserved.

### New features

#### Coverage & completeness auditing

- [`sm_coverage_audit()`](https://cttir.github.io/scimapR/reference/sm_coverage_audit.md)
  computes recall, precision, and F1 of a corpus against a ground-truth
  reference (manual tracker, ORCID set, repository export, or another
  `sm_corpus`), with per-`year`/`source`/`affiliation` breakdowns and
  full match provenance. Returns an `sm_coverage` object with `print`,
  `summary`, and `autoplot` methods.
- [`sm_journal_in_index()`](https://cttir.github.io/scimapR/reference/sm_journal_in_index.md)
  verifies source coverage against a user-supplied journal master list
  by normalised ISSN (print and electronic), fully offline.
- [`sm_reconcile()`](https://cttir.github.io/scimapR/reference/sm_reconcile.md)
  performs a content-based symmetric diff (DOI then fuzzy title)
  returning an `sm_reconciliation` (`in_both`/`only_a`/`only_b` +
  provenance), with `print`/`summary`/`autoplot`.
  [`sm_diff_corpora()`](https://cttir.github.io/scimapR/reference/sm_diff_corpora.md)
  is now marked superseded in favour of it (and continues to work
  unchanged).

#### Affiliation disambiguation & attribution

- [`sm_affiliation_match()`](https://cttir.github.io/scimapR/reference/sm_affiliation_match.md)
  tags authorships with institutions using a multilingual /
  synonym-aware dictionary and an email-domain fallback, handling
  multiple affiliations per author.
- [`sm_attribute_institution()`](https://cttir.github.io/scimapR/reference/sm_attribute_institution.md)
  rolls matches up to a controlled vocabulary (ROR-backed via an offline
  ROR table, or a custom vocabulary).
- `sm_affiliation_dict`: a default, documented, user-overridable
  dictionary.

#### Causal / policy evaluation

- [`sm_its()`](https://cttir.github.io/scimapR/reference/sm_its.md):
  turnkey interrupted time series (level + slope terms, counterfactual,
  `autoplot`), with automatic exclusion of citation-immature years for
  citation-based outcomes.
- [`sm_did()`](https://cttir.github.io/scimapR/reference/sm_did.md):
  difference-in-differences for treated vs control institution sets.
- [`sm_synth()`](https://cttir.github.io/scimapR/reference/sm_synth.md):
  synthetic-control helper (optional `tidysynth`, graceful error when
  absent).

#### Correctness: citation maturity & counting

- [`sm_citation_maturity()`](https://cttir.github.io/scimapR/reference/sm_citation_maturity.md)
  flags citation-immature recent years (`citation_mature` /
  `cnci_provisional`), wired into
  [`sm_its()`](https://cttir.github.io/scimapR/reference/sm_its.md).
- [`sm_count()`](https://cttir.github.io/scimapR/reference/sm_count.md):
  full vs fractional counting at institution / author / source level
  (output credit and fractionally-weighted impact).

#### Robust impact summaries

- `sm_metric_summary(robust = TRUE)` reports medians with bootstrap CIs
  and %PP(top-10%) alongside means (base-R resampling by default; `boot`
  optional; reproducible via `seed`).

#### Reproducible reporting glue

- [`sm_figure_manifest()`](https://cttir.github.io/scimapR/reference/sm_figure_manifest.md)
  scans a figure directory into a captions / alt-text / dimensions
  manifest (optional `magick`/`png`, sidecar caption files, CSV/YAML
  output).
- [`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/reference/sm_corpus_from_tables.md):
  a documented, validating constructor from a relational set of data
  frames — the recommended ingestion path for arbitrary tabular sources.

### Bug fixes

- **G1** `sm_fetch_openalex(engine = "native")`: abstract reconstruction
  from the OpenAlex inverted index is now type-stable and never aborts a
  fetch on an empty/`NULL`/malformed record (and no longer passes an
  invalid `.default` to
  [`purrr::map_chr()`](https://purrr.tidyverse.org/reference/map.html)).
- **G2** `sm_fetch_openalex(engine = "openalexR")`: long DOI (or other
  ID) lists are auto-batched under the API’s OR-filter limit via the new
  `batch_size` argument, then row-bound and de-duplicated.
- **G3** `sm_read_bib(engine = "bibliometrix")`: a field-sparse
  `@article` no longer triggers “undefined columns selected”; the
  scimapR wrapper catches the failure and falls back to the native
  parser (clean-room rule preserved).
- **G4** native BibTeX engine performance: the parser was rewritten from
  per-character
  [`substr()`](https://rdrr.io/r/base/substr.html)/[`grepl()`](https://rdrr.io/r/base/grep.html)
  scanning and per-entry tibble construction to linear character-vector
  scanning with single-pass column assembly. Parsing ~7,000 entries
  dropped from ~100 s to ~17 s on R 4.5.2 / Windows.

### New data & fixtures

- `inst/extdata/`: `example_sparse.bib`,
  `example_openalex_inverted.json`, `example_journal_index.csv`,
  `example_ror.csv`.

## scimapR 0.1.0

### Initial release

`scimapR` is a comprehensive R toolkit for bibliometric and
scientometric analysis: the reproducible, equity-aware, question-driven,
AI-assisted toolkit for working biomedical researchers. Designed as a
complement to the foundational `bibliometrix` package (Aria &
Cuccurullo, 2017) with first-class round-trip interop.

#### Distinctive features

- **Live corpus refresh.**
  [`sm_refresh()`](https://cttir.github.io/scimapR/reference/sm_refresh.md),
  [`sm_staleness()`](https://cttir.github.io/scimapR/reference/sm_staleness.md),
  [`sm_lock()`](https://cttir.github.io/scimapR/reference/sm_lock.md).
- **Research questions as objects.**
  [`sm_question()`](https://cttir.github.io/scimapR/reference/sm_question.md),
  [`sm_corpus_for_question()`](https://cttir.github.io/scimapR/reference/sm_corpus_for_question.md),
  [`sm_screen_against_question()`](https://cttir.github.io/scimapR/reference/sm_screen_against_question.md)
  with optional LLM grounding.
- **Reproducible-by-construction corpus certificates.**
  [`sm_certificate()`](https://cttir.github.io/scimapR/reference/sm_certificate.md),
  [`sm_rebuild_from_cert()`](https://cttir.github.io/scimapR/reference/sm_certificate.md),
  [`sm_verify_certificate()`](https://cttir.github.io/scimapR/reference/sm_certificate.md).
- **Author trajectory analysis.**
  [`sm_author_trajectory()`](https://cttir.github.io/scimapR/reference/sm_author_trajectory.md)
  with topic pivots, collaborator turnover, emerging-collaborator
  detection.
- **Equity and representation audit.**
  [`sm_audit_geographic()`](https://cttir.github.io/scimapR/reference/sm_audit_geographic.md),
  [`sm_audit_gender()`](https://cttir.github.io/scimapR/reference/sm_audit_gender.md),
  [`sm_audit_funding()`](https://cttir.github.io/scimapR/reference/sm_audit_funding.md),
  [`sm_audit_oa()`](https://cttir.github.io/scimapR/reference/sm_audit_oa.md)
  with built-in confidence reporting and limitation caveats.
- **LLM-grounded corpus chat.**
  [`sm_chat()`](https://cttir.github.io/scimapR/reference/sm_chat.md)
  with retrieval-constrained citations.

#### Core modules

- Corpus class (`sm_corpus`) with provenance and screening tables
- Clean-room native parsers for 12 bibliographic formats
- API fetchers for 8 scholarly data sources
- 8 enrichment functions
- Bibliometrix round-trip interop
- 6 network builders (citation, co-citation, coupling, collaboration,
  co-word, semantic)
- Embedding and clustering (HDBSCAN, Leiden, k-means)
- Modern indicators (h/g/m-index, CD index, RCR, FNCI, Uzzi novelty)
- Viridis-themed publication-ready visualization
- Multi-format export (PNG 300/600 dpi, PDF, SVG, TIFF, XLSX, ZIP
  bundles)
- Comprehensive 13-tab Shiny application
- Systematic review bridge (PRISMA, Rayyan, Covidence)
