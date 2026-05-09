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
