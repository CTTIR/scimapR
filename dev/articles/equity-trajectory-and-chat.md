# Equity Audit, Trajectory Analysis, and Corpus Chat

[![R-CMD-check](https://github.com/CTTIR/scimapR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/CTTIR/scimapR/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/CTTIR/scimapR/actions/workflows/pkgdown.yaml/badge.svg)](https://cttir.github.io/scimapR/)
[![CRAN
status](https://www.r-pkg.org/badges/version/scimapR)](https://CRAN.R-project.org/package=scimapR)
[![Codecov test
coverage](https://codecov.io/gh/CTTIR/scimapR/branch/main/graph/badge.svg)](https://app.codecov.io/gh/CTTIR/scimapR?branch=main)
[![CRAN
downloads](https://cranlogs.r-pkg.org/badges/scimapR)](https://cran.r-project.org/package=scimapR)
[![CRAN downloads
total](https://cranlogs.r-pkg.org/badges/grand-total/scimapR)](https://cran.r-project.org/package=scimapR)
[![License:
MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)

## Equity and representation audit

scimapR includes built-in tools for auditing geographic, gender,
funding, and open-access representation – with explicit confidence
reporting and limitation caveats.

``` r

library(scimapR)
corpus <- sm_example_corpus(seed = 42)
```

### Geographic audit

``` r

geo <- sm_audit_geographic(corpus)
head(geo)
#> $distribution
#> # A tibble: 20 × 6
#>    group count citations   pct credit weighted_citations
#>    <chr> <int>     <int> <dbl>  <dbl>              <dbl>
#>  1 DE       63       954  9.17     63                954
#>  2 FI       46       708  6.7      46                708
#>  3 AU       44       646  6.4      44                646
#>  4 NO       38       472  5.53     38                472
#>  5 GB       37       544  5.39     37                544
#>  6 IT       37       540  5.39     37                540
#>  7 DK       36       500  5.24     36                500
#>  8 BR       33       533  4.8      33                533
#>  9 CA       33       568  4.8      33                568
#> 10 CH       33       474  4.8      33                474
#> 11 CN       33       541  4.8      33                541
#> 12 NL       33       487  4.8      33                487
#> 13 IL       31       700  4.51     31                700
#> 14 JP       30       464  4.37     30                464
#> 15 FR       29       445  4.22     29                445
#> 16 IN       29       429  4.22     29                429
#> 17 KR       29       442  4.22     29                442
#> 18 US       27       478  3.93     27                478
#> 19 ES       23       341  3.35     23                341
#> 20 SE       23       223  3.35     23                223
#> 
#> $gini
#> [1] 0.126
#> 
#> $coverage
#> [1] 1
#> 
#> $by
#> [1] "country"
#> 
#> $weight
#> [1] "count"
#> 
#> $method
#> [1] "full"
```

### Open access audit

``` r

oa <- sm_audit_oa(corpus)
head(oa)
#> $distribution
#> # A tibble: 5 × 4
#>   oa_status count   pct is_open
#>   <chr>     <int> <dbl> <lgl>  
#> 1 closed       87  43.5 FALSE  
#> 2 gold         35  17.5 TRUE   
#> 3 green        32  16   TRUE   
#> 4 bronze       24  12   TRUE   
#> 5 hybrid       22  11   TRUE   
#> 
#> $pct_open
#> [1] 56.5
#> 
#> $coverage
#> [1] 1
#> 
#> $n_works
#> [1] 200
```

### Equity dashboard

``` r

sm_plot_equity_dashboard(corpus)
```

![Equity
dashboard](equity-trajectory-and-chat_files/figure-html/dashboard-1.png)

Equity dashboard

### Epistemic humility

All audit functions report confidence, method, and caveats. The print
methods include explicit limitation blocks. scimapR does not pretend
that automated inference is ground truth.

## Author trajectory analysis

scimapR can track an author’s career evolution through topic pivots,
collaborator turnover, and productivity curves.

``` r

# The example corpus includes a trajectory seed author
traj <- sm_author_trajectory(corpus, author_id = "A000000001")
print(traj)
#> 
#> ── <sm_trajectory> ─────────────────────────────────────────────────────────────
#> Author: Elena Fischer
#> Author ID: A000000001
#> ORCID: 0000-0003-6689-5331
#> Periods: 5
#> 
#> ── Career stages
#> Period 1 (2015-2016): 5 works, h=6 | gene expression, biomarker discovery, drug
#> resistance
#> Period 2 (2016-2018): 6 works, h=9 | colorectal cancer, machine learning,
#> clinical outcomes
#> Period 3 (2018-2020): 6 works, h=11 | single-cell RNA-seq, biomarker discovery,
#> clinical outcomes
#> Period 4 (2020-2022): 10 works, h=13 | biomarker discovery, colorectal cancer,
#> single-cell RNA-seq
#> Period 5 (2022-2024): 13 works, h=14 | immune checkpoint, machine learning,
#> clinical outcomes
#> 
#> ── Topic pivots
#> Period 2: score=0.3 (stable)
#> Period 3: score=0.3 (stable)
#> Period 4: score=0.3 (stable)
#> Period 5: score=0 (stable)
#> 
#> ── Collaborator turnover
#> Period 2: Jaccard=0.194 (new=14, kept=7, lost=15)
#> Period 3: Jaccard=0.081 (new=16, kept=3, lost=18)
#> Period 4: Jaccard=0.085 (new=28, kept=4, lost=15)
#> Period 5: Jaccard=0.315 (new=22, kept=17, lost=15)
#> 
#> ── Emerging collaborators (9)
#> James Ibrahim (since 2024)
#> Carlos Smith (since 2022)
#> Wei Johansson (since 2024)
#> Carlos Patel (since 2024)
#> David Andersson (since 2023)
#> ... and 4 more
#> 
#> ── H-index curve
#> 2015-2016:6 -> 2016-2018:9 -> 2018-2020:11 -> 2020-2022:13 -> 2022-2024:14
#> 
#> ── Citation acceleration
#> 2015-2016: mean=9.4 (-5.3 vs field)
#> 2016-2018: mean=18.3 (+4 vs field)
#> 2018-2020: mean=17 (+2 vs field)
#> 2020-2022: mean=11.2 (-6.1 vs field)
#> 2022-2024: mean=11.8 (-2.5 vs field)
```

``` r

sm_plot_trajectory(traj)
```

![Author
trajectory](equity-trajectory-and-chat_files/figure-html/traj-plot-1.png)

Author trajectory

## LLM-grounded corpus chat

scimapR can use an LLM to answer questions about a corpus, with every
claim anchored to actual works via retrieval-constrained citations.

``` r

# Requires ellmer package
response <- sm_chat(
  corpus,
  "What methodological approaches dominate post-2020?",
  provider = ellmer::chat_anthropic()
)
print(response)
```

The LLM only sees works that were actually retrieved. Citations are
constrained to those retrieved works – no hallucinated references are
possible.
