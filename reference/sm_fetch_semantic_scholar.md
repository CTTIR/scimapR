# Fetch works from Semantic Scholar

Query the [Semantic Scholar](https://www.semanticscholar.org/) Academic
Graph API for papers and return the results as an `sm_corpus`.

Supports both keyword search (`query`) and batch paper lookup
(`paper_ids`). Optionally fetches pre-computed SPECTER embeddings.

## Usage

``` r
sm_fetch_semantic_scholar(
  query = NULL,
  paper_ids = NULL,
  n_max = 100L,
  api_key = Sys.getenv("SEMANTIC_SCHOLAR_API_KEY"),
  include_embeddings = FALSE,
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- query:

  Free-text search query. If `NULL`, `paper_ids` must be supplied.

- paper_ids:

  Character vector of Semantic Scholar paper IDs, DOIs (prefixed
  `DOI:`), arXiv IDs (prefixed `ARXIV:`), or PMIDs (prefixed `PMID:`).
  If `NULL`, `query` must be supplied.

- n_max:

  Maximum number of papers to return (default 100).

- api_key:

  Semantic Scholar API key. Read from `SEMANTIC_SCHOLAR_API_KEY` env var
  by default.

- include_embeddings:

  Logical; if `TRUE`, request SPECTER embeddings for each paper and
  attach as an embedding matrix. These are the API's default SPECTER v1
  vectors, recorded in `metadata$embedding` with the model id
  `"embedding.specter_v1"` (see
  [`sm_corpus()`](https://cttir.github.io/scimapR/reference/sm_corpus.md));
  [`sm_enrich_specter()`](https://cttir.github.io/scimapR/reference/sm_enrich_specter.md)
  fetches SPECTER v2 vectors.

- verbose:

  Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An `sm_corpus` object.

## Failed requests

Native requests retry transient server and network failures, and short
announced rate-limit waits. Long waits abort immediately. If a later
page fails, the error inherits from `scimapR_fetch_incomplete` and holds
the earlier parsed works in `rlang::last_error()$partial`. Their
metadata records `fetch_incomplete` with the source, received and
expected counts, and failure reason. If those pages cannot be parsed,
`partial` is `NULL`. The default remains an error; an incomplete fetch
is never returned as an ordinary successful result.

## See also

Other fetchers:
[`sm_fetch_arxiv()`](https://cttir.github.io/scimapR/reference/sm_fetch_arxiv.md),
[`sm_fetch_biorxiv()`](https://cttir.github.io/scimapR/reference/sm_fetch_biorxiv.md),
[`sm_fetch_crossref()`](https://cttir.github.io/scimapR/reference/sm_fetch_crossref.md),
[`sm_fetch_openalex()`](https://cttir.github.io/scimapR/reference/sm_fetch_openalex.md),
[`sm_fetch_orcid()`](https://cttir.github.io/scimapR/reference/sm_fetch_orcid.md),
[`sm_fetch_overton()`](https://cttir.github.io/scimapR/reference/sm_fetch_overton.md),
[`sm_fetch_pubmed()`](https://cttir.github.io/scimapR/reference/sm_fetch_pubmed.md)

## Examples

``` r
# \donttest{
# Queries the Semantic Scholar web API; without an API key the shared
# rate limit can refuse the request.
if (requireNamespace("curl", quietly = TRUE) && curl::has_internet()) {
  corpus <- try(sm_fetch_semantic_scholar(query = "bibliometrics", n_max = 5))
  print(corpus)
}
#> ℹ Searching Semantic Scholar for: "bibliometrics"
#> Error in eval(expr, envir) : Semantic Scholar API request failed.
#> Caused by error in `.s2_perform()`:
#> ! Semantic Scholar request failed: HTTP 429.
#> ℹ {"message": "Too Many Requests. Please wait and try again or apply for a key
#>   for higher rate limits. <request> "code": "429"}
#> [1] "Error in eval(expr, envir) : \033[1m\033[22mSemantic Scholar API request failed.\n\033[1mCaused by error in `.s2_perform()`:\033[22m\n\033[1m\033[22m\033[33m!\033[39m Semantic Scholar request failed: HTTP 429.\n\033[36mℹ\033[39m {\"message\": \"Too Many Requests. Please wait and try again or apply for a key\n  for higher rate limits. <request> \"code\": \"429\"}\n"
#> attr(,"class")
#> [1] "try-error"
#> attr(,"condition")
#> <error/scimapR_rate_limited>
#> Error:
#> ! Semantic Scholar API request failed.
#> Caused by error in `.s2_perform()`:
#> ! Semantic Scholar request failed: HTTP 429.
#> ℹ {"message": "Too Many Requests. Please wait and try again or apply for a key
#>   for higher rate limits. <request> "code": "429"}
#> ---
#> Backtrace:
#>      ▆
#>   1. └─pkgdown::build_site_github_pages(new_process = FALSE, install = FALSE)
#>   2.   └─pkgdown::build_site(...)
#>   3.     └─pkgdown:::build_site_local(...)
#>   4.       └─pkgdown::build_reference(...)
#>   5.         ├─pkgdown:::unwrap_purrr_error(...)
#>   6.         │ └─base::withCallingHandlers(...)
#>   7.         └─purrr::map(...)
#>   8.           └─purrr:::map_("list", .x, .f, ..., .progress = .progress)
#>   9.             ├─purrr:::with_indexed_errors(...)
#>  10.             │ └─base::withCallingHandlers(...)
#>  11.             ├─purrr:::call_with_cleanup(...)
#>  12.             └─pkgdown (local) .f(.x[[i]], ...)
#>  13.               ├─base::withCallingHandlers(...)
#>  14.               └─pkgdown:::data_reference_topic(...)
#>  15.                 └─pkgdown:::run_examples(...)
#>  16.                   └─pkgdown:::highlight_examples(code, topic, env = env)
#>  17.                     └─downlit::evaluate_and_highlight(...)
#>  18.                       └─evaluate::evaluate(code, child_env(env), new_device = TRUE, output_handler = output_handler)
#>  19.                         ├─base::withRestarts(...)
#>  20.                         │ └─base (local) withRestartList(expr, restarts)
#>  21.                         │   ├─base (local) withOneRestart(withRestartList(expr, restarts[-nr]), restarts[[nr]])
#>  22.                         │   │ └─base (local) doWithOneRestart(return(expr), restart)
#>  23.                         │   └─base (local) withRestartList(expr, restarts[-nr])
#>  24.                         │     └─base (local) withOneRestart(expr, restarts[[1L]])
#>  25.                         │       └─base (local) doWithOneRestart(return(expr), restart)
#>  26.                         ├─evaluate:::with_handlers(...)
#>  27.                         │ ├─base::eval(call)
#>  28.                         │ │ └─base::eval(call)
#>  29.                         │ └─base::withCallingHandlers(...)
#>  30.                         ├─base::withVisible(eval(expr, envir))
#>  31.                         └─base::eval(expr, envir)
#>  32.                           └─base::eval(expr, envir)
#>  33.                             ├─base::try(...)
#>  34.                             │ └─base::tryCatch(...)
#>  35.                             │   └─base (local) tryCatchList(expr, classes, parentenv, handlers)
#>  36.                             │     └─base (local) tryCatchOne(expr, names, parentenv, handlers[[1L]])
#>  37.                             │       └─base (local) doTryCatch(return(expr), name, parentenv, handler)
#>  38.                             └─scimapR::sm_fetch_semantic_scholar(query = "bibliometrics", n_max = 5)
#>  39.                               ├─base::tryCatch(...)
#>  40.                               │ └─base (local) tryCatchList(expr, classes, parentenv, handlers)
#>  41.                               │   └─base (local) tryCatchOne(expr, names, parentenv, handlers[[1L]])
#>  42.                               │     └─base (local) doTryCatch(return(expr), name, parentenv, handler)
#>  43.                               └─scimapR:::.s2_perform(req, max_tries = 3L, max_wait = 60)
# }
```
