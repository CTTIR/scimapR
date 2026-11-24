# Fetch works from arXiv

Query the [arXiv](https://arxiv.org/) API (Atom feed) for preprints and
return the results as an `sm_corpus`.

Uses start/max_results pagination to retrieve up to `n_max` results. The
arXiv API is free and requires no authentication.

## Usage

``` r
sm_fetch_arxiv(query, n_max = 200L, verbose = TRUE, call = rlang::caller_env())
```

## Arguments

- query:

  arXiv search query string using the arXiv query syntax. Supports
  `all:`, `ti:`, `au:`, `abs:`, `cat:`, etc.

- n_max:

  Maximum number of results to return (default 200).

- verbose:

  Print progress messages?

- call:

  Caller environment for error reporting.

## Value

An `sm_corpus` object.

## See also

Other fetchers:
[`sm_fetch_biorxiv()`](https://cttir.github.io/scimapR/reference/sm_fetch_biorxiv.md),
[`sm_fetch_crossref()`](https://cttir.github.io/scimapR/reference/sm_fetch_crossref.md),
[`sm_fetch_openalex()`](https://cttir.github.io/scimapR/reference/sm_fetch_openalex.md),
[`sm_fetch_orcid()`](https://cttir.github.io/scimapR/reference/sm_fetch_orcid.md),
[`sm_fetch_overton()`](https://cttir.github.io/scimapR/reference/sm_fetch_overton.md),
[`sm_fetch_pubmed()`](https://cttir.github.io/scimapR/reference/sm_fetch_pubmed.md),
[`sm_fetch_semantic_scholar()`](https://cttir.github.io/scimapR/reference/sm_fetch_semantic_scholar.md)

## Examples

``` r
# \donttest{
# Queries the arXiv web API.
if (requireNamespace("curl", quietly = TRUE) && curl::has_internet()) {
  corpus <- try(sm_fetch_arxiv(query = "all:bibliometrics", n_max = 5))
  print(corpus)
}
#> ℹ Fetching from arXiv: "all:bibliometrics"
#> Error in eval(expr, envir) : arXiv API request failed.
#> ℹ HTTP 429 Too Many Requests.
#> [1] "Error in eval(expr, envir) : \033[1m\033[22marXiv API request failed.\n\033[36mℹ\033[39m HTTP 429 Too Many Requests.\n"
#> attr(,"class")
#> [1] "try-error"
#> attr(,"condition")
#> <error/rlang_error>
#> Error:
#> ! arXiv API request failed.
#> ℹ HTTP 429 Too Many Requests.
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
# }
```
