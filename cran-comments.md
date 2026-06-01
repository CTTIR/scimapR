## R CMD check results
0 errors | 0 warnings | 0 notes

## Test environments
* local: Windows 11, R 4.5.2
* GitHub Actions: ubuntu-release, ubuntu-devel, ubuntu-oldrel-1, macos-release, windows-release

## Release summary

Version 0.2.0 adds a research-management analytics layer (coverage and
completeness auditing, affiliation disambiguation and ROR attribution,
interrupted-time-series and difference-in-differences policy evaluation,
citation-maturity flagging, full/fractional counting, and robust impact
summaries) plus a reproducible tabular constructor and figure manifest. It
also fixes four ingestion bugs (OpenAlex abstract reconstruction and DOI
batching, a bibliometrix BibTeX wrapper failure on field-sparse entries, and
native BibTeX parser performance). All new optional dependencies are in
Suggests and guarded with `requireNamespace()`.

## This is a new submission.

scimapR is a comprehensive toolkit for bibliometric and scientometric
analysis with embedding-based research cluster discovery, reproducible
corpus certificates, equity auditing, and retrieval-grounded conversational
exploration. It is designed as a complement to the existing 'bibliometrix'
package (Aria & Cuccurullo, 2017, doi:10.1016/j.joi.2017.08.007), with
which it shares no source code.

For bibliographic formats also handled by bibliometrix (WoS, Scopus,
Cochrane, Lens, Dimensions), scimapR ships clean-room parsers written
from the public format specifications, and additionally offers an optional
`engine = "bibliometrix"` argument to delegate parsing to bibliometrix
when users have it installed. Round-trip interop is provided via
`sm_to_bibliometrix()` and `as_sm_corpus.bibliometrix()`.

The DESCRIPTION, README, inst/CITATION, and a dedicated vignette
(`relationship-to-bibliometrix.Rmd`) explicitly credit Aria & Cuccurullo's
foundational work.

All examples use bundled synthetic data and the `sm_example_corpus()`
generator. All network-fetching functions are wrapped in `\donttest{}`.
All Python-dependent embedding functions degrade gracefully when reticulate
or sentence-transformers are unavailable. All LLM-dependent functions
error informatively when ellmer is unavailable. All bibliometrix-dependent
functions guard with `requireNamespace()`.
