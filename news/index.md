# Changelog

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
