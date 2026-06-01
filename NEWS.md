# scimapR 0.2.0

A new capability layer for research-coverage, affiliation-attribution, and
policy-evaluation analyses, plus four reproducible bug fixes. All existing
functionality, the `sm_corpus` schema, bibliometrix interop, and the Shiny app
are preserved.

## New features

### Coverage & completeness auditing

- `sm_coverage_audit()` computes recall, precision, and F1 of a corpus against
  a ground-truth reference (manual tracker, ORCID set, repository export, or
  another `sm_corpus`), with per-`year`/`source`/`affiliation` breakdowns and
  full match provenance. Returns an `sm_coverage` object with `print`,
  `summary`, and `autoplot` methods.
- `sm_journal_in_index()` verifies source coverage against a user-supplied
  journal master list by normalised ISSN (print and electronic), fully offline.
- `sm_reconcile()` performs a content-based symmetric diff (DOI then fuzzy
  title) returning an `sm_reconciliation` (`in_both`/`only_a`/`only_b` +
  provenance), with `print`/`summary`/`autoplot`. `sm_diff_corpora()` is now
  marked superseded in favour of it (and continues to work unchanged).

### Affiliation disambiguation & attribution

- `sm_affiliation_match()` tags authorships with institutions using a
  multilingual / synonym-aware dictionary and an email-domain fallback, handling
  multiple affiliations per author.
- `sm_attribute_institution()` rolls matches up to a controlled vocabulary
  (ROR-backed via an offline ROR table, or a custom vocabulary).
- `sm_affiliation_dict`: a default, documented, user-overridable dictionary.

### Causal / policy evaluation

- `sm_its()`: turnkey interrupted time series (level + slope terms,
  counterfactual, `autoplot`), with automatic exclusion of citation-immature
  years for citation-based outcomes.
- `sm_did()`: difference-in-differences for treated vs control institution sets.
- `sm_synth()`: synthetic-control helper (optional `tidysynth`, graceful error
  when absent).

### Correctness: citation maturity & counting

- `sm_citation_maturity()` flags citation-immature recent years
  (`citation_mature` / `cnci_provisional`), wired into `sm_its()`.
- `sm_count()`: full vs fractional counting at institution / author / source
  level (output credit and fractionally-weighted impact).

### Robust impact summaries

- `sm_metric_summary(robust = TRUE)` reports medians with bootstrap CIs and
  %PP(top-10%) alongside means (base-R resampling by default; `boot` optional;
  reproducible via `seed`).

### Reproducible reporting glue

- `sm_figure_manifest()` scans a figure directory into a captions / alt-text /
  dimensions manifest (optional `magick`/`png`, sidecar caption files, CSV/YAML
  output).
- `sm_corpus_from_tables()`: a documented, validating constructor from a
  relational set of data frames — the recommended ingestion path for arbitrary
  tabular sources.

## Bug fixes

- **G1** `sm_fetch_openalex(engine = "native")`: abstract reconstruction from the
  OpenAlex inverted index is now type-stable and never aborts a fetch on an
  empty/`NULL`/malformed record (and no longer passes an invalid `.default` to
  `purrr::map_chr()`).
- **G2** `sm_fetch_openalex(engine = "openalexR")`: long DOI (or other ID) lists
  are auto-batched under the API's OR-filter limit via the new `batch_size`
  argument, then row-bound and de-duplicated.
- **G3** `sm_read_bib(engine = "bibliometrix")`: a field-sparse `@article` no
  longer triggers "undefined columns selected"; the scimapR wrapper catches the
  failure and falls back to the native parser (clean-room rule preserved).
- **G4** native BibTeX engine performance: the parser was rewritten from
  per-character `substr()`/`grepl()` scanning and per-entry tibble construction
  to linear character-vector scanning with single-pass column assembly. Parsing
  ~7,000 entries dropped from ~100 s to ~17 s on R 4.5.2 / Windows.

## New data & fixtures

- `inst/extdata/`: `example_sparse.bib`, `example_openalex_inverted.json`,
  `example_journal_index.csv`, `example_ror.csv`.

# scimapR 0.1.0

## Initial release

`scimapR` is a comprehensive R toolkit for bibliometric and scientometric
analysis: the reproducible, equity-aware, question-driven, AI-assisted
toolkit for working biomedical researchers. Designed as a complement to
the foundational `bibliometrix` package (Aria & Cuccurullo, 2017) with
first-class round-trip interop.

### Distinctive features

- **Live corpus refresh.** `sm_refresh()`, `sm_staleness()`, `sm_lock()`.
- **Research questions as objects.** `sm_question()`,
  `sm_corpus_for_question()`, `sm_screen_against_question()` with optional
  LLM grounding.
- **Reproducible-by-construction corpus certificates.** `sm_certificate()`,
  `sm_rebuild_from_cert()`, `sm_verify_certificate()`.
- **Author trajectory analysis.** `sm_author_trajectory()` with topic pivots,
  collaborator turnover, emerging-collaborator detection.
- **Equity and representation audit.** `sm_audit_geographic()`,
  `sm_audit_gender()`, `sm_audit_funding()`, `sm_audit_oa()` with built-in
  confidence reporting and limitation caveats.
- **LLM-grounded corpus chat.** `sm_chat()` with retrieval-constrained
  citations.

### Core modules

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
- Multi-format export (PNG 300/600 dpi, PDF, SVG, TIFF, XLSX, ZIP bundles)
- Comprehensive 13-tab Shiny application
- Systematic review bridge (PRISMA, Rayyan, Covidence)
