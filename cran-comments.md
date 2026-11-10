## Submission

This is a new submission of `scimapR` (version 0.5.0).

scimapR is a toolkit for bibliometric and scientometric analysis with
embedding-based research cluster discovery, reproducible corpus
certificates, equity auditing and retrieval-grounded conversational
exploration. It is designed as a complement to the existing 'bibliometrix'
package (Aria & Cuccurullo, 2017, <doi:10.1016/j.joi.2017.08.007>), with
which it shares no source code. For bibliographic formats also handled by
bibliometrix (Web of Science, Scopus, Cochrane, Lens, Dimensions), scimapR
ships parsers written from the public format specifications and offers an
optional `engine = "bibliometrix"` argument. The DESCRIPTION, README,
inst/CITATION and a dedicated vignette credit Aria & Cuccurullo's work.

## Test environments

* local macOS (aarch64), R 4.6.1:
  `R CMD check --as-cran --no-manual` (LaTeX is not installed locally, so
  the PDF manual was not built here; the suggested package 'arrow' was not
  installed locally, `_R_CHECK_FORCE_SUGGESTS_=false`)
* GitHub Actions (r-lib/actions v2, `--as-cran`):
  macos-latest (release), windows-latest (release),
  ubuntu-latest (devel, release, oldrel-1)

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
  New submission

## Notes for CRAN

* Web APIs: the package can query OpenAlex, Crossref, Semantic Scholar,
  PubMed, arXiv, bioRxiv, ORCID, Overton, Unpaywall, OpenCitations, ROR
  and Altmetric. No example, test or vignette accesses the internet during
  `R CMD check`: examples that would contact a web service are in
  `\dontrun{}` with a comment naming the service, tests use recorded
  responses or mocks and skip any live request on CRAN, and the vignettes
  work on bundled synthetic data.
* All examples that run use bundled example files
  (`sm_example_files()`), the `sm_example_corpus()` generator or small
  files written to `tempdir()`.
* Python-dependent embedding functions degrade gracefully when
  'reticulate' or 'sentence-transformers' are unavailable; LLM-dependent
  functions error informatively when 'ellmer' is unavailable; all
  functions using packages from Suggests check them with
  `requireNamespace()`.
* README.md and the vignettes carry CRAN badges linking to
  <https://CRAN.R-project.org/package=scimapR>, which returns 404 until the
  package has been accepted.
