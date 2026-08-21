# Funding source audit

Audits the distribution of funding sources across works in a corpus.
Funding metadata is extracted from either Crossref `funder` fields or
OpenAlex `grants` fields, depending on the `source` parameter.

The result includes funder counts, the proportion of works with known
funding, and a concentration analysis.

## Usage

``` r
sm_audit_funding(
  corpus,
  source = c("crossref", "openalex"),
  call = rlang::caller_env()
)

# S3 method for class 'sm_audit_funding'
print(x, ...)
```

## Arguments

- corpus:

  An `sm_corpus` object.

- source:

  Character. Where to look for funding data: `"crossref"` (uses DOIs to
  query Crossref funder metadata) or `"openalex"` (uses OpenAlex IDs).

- call:

  Caller environment for error reporting.

- x:

  An audit object to print.

- ...:

  Ignored.

## Value

An `sm_audit_funding` S3 object containing:

- funders:

  Tibble with columns `funder_name`, `funder_doi`, `n_works`, `pct`.

- coverage:

  Proportion of works with at least one funder.

- n_works_total:

  Total number of works in corpus.

- n_works_funded:

  Number of works with funding data.

- source:

  The data source used.

## See also

Other audit:
[`print.sm_audit_summary()`](https://cttir.github.io/scimapR/reference/sm_audit_summary.md),
[`sm_audit_gender()`](https://cttir.github.io/scimapR/reference/sm_audit_gender.md),
[`sm_audit_geographic()`](https://cttir.github.io/scimapR/reference/sm_audit_geographic.md),
[`sm_audit_oa()`](https://cttir.github.io/scimapR/reference/sm_audit_oa.md)

## Examples

``` r
# \donttest{
corpus <- sm_example_corpus()
funding <- sm_audit_funding(corpus, source = "crossref")
#> Warning: 404 (client error): /works/10.1234/example.1 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.2 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.3 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.4 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.5 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.6 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.7 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.8 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.9 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.10 - Resource not found.
#> Warning: 429 (client error): /works/10.1234/example.11 - 
#> Warning: 429 (client error): /works/10.1234/example.12 - 
#> Warning: 429 (client error): /works/10.1234/example.13 - 
#> Warning: 404 (client error): /works/10.1234/example.14 - Resource not found.
#> Warning: 429 (client error): /works/10.1234/example.15 - 
#> Warning: 404 (client error): /works/10.1234/example.16 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.17 - Resource not found.
#> Warning: 429 (client error): /works/10.1234/example.18 - 
#> Warning: 404 (client error): /works/10.1234/example.19 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.20 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.21 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.22 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.23 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.24 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.25 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.26 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.27 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.28 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.29 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.30 - Resource not found.
#> Warning: 429 (client error): /works/10.1234/example.31 - 
#> Warning: 404 (client error): /works/10.1234/example.32 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.33 - Resource not found.
#> Warning: 429 (client error): /works/10.1234/example.34 - 
#> Warning: 404 (client error): /works/10.1234/example.35 - Resource not found.
#> Warning: 429 (client error): /works/10.1234/example.36 - 
#> Warning: 404 (client error): /works/10.1234/example.37 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.38 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.39 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.40 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.41 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.42 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.43 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.44 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.45 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.46 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.47 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.48 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.49 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.50 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.51 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.52 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.53 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.54 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.55 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.56 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.57 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.58 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.59 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.60 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.61 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.62 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.63 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.64 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.65 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.66 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.67 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.68 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.69 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.70 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.71 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.72 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.73 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.74 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.75 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.76 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.77 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.78 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.79 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.80 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.81 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.82 - Resource not found.
#> Warning: 429 (client error): /works/10.1234/example.83 - 
#> Warning: 429 (client error): /works/10.1234/example.84 - 
#> Warning: 404 (client error): /works/10.1234/example.85 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.86 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.87 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.88 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.89 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.90 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.91 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.92 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.93 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.94 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.95 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.96 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.97 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.98 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.99 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.100 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.101 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.102 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.103 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.104 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.105 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.106 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.107 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.108 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.109 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.110 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.111 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.112 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.113 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.114 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.115 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.116 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.117 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.118 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.119 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.120 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.121 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.122 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.123 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.124 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.125 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.126 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.127 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.128 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.129 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.130 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.131 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.132 - Resource not found.
#> Warning: 429 (client error): /works/10.1234/example.133 - 
#> Warning: 429 (client error): /works/10.1234/example.134 - 
#> Warning: 404 (client error): /works/10.1234/example.135 - Resource not found.
#> Warning: 429 (client error): /works/10.1234/example.136 - 
#> Warning: 404 (client error): /works/10.1234/example.137 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.138 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.139 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.140 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.141 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.142 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.143 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.144 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.145 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.146 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.147 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.148 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.149 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.150 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.151 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.152 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.153 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.154 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.155 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.156 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.157 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.158 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.159 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.160 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.161 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.162 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.163 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.164 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.165 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.166 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.167 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.168 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.169 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.170 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.171 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.172 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.173 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.174 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.175 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.176 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.177 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.178 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.179 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.180 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.181 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.182 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.183 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.184 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.185 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.186 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.187 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.188 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.189 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.190 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.191 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.192 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.193 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.194 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.195 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.196 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.197 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.198 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.199 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.200 - Resource not found.
#> ℹ No funding data found via "crossref".
#> ℹ This may be because the works lack DOIs/identifiers, or the source does not
#>   have funding metadata.
print(funding)
#> 
#> ── <sm_audit_funding> ──────────────────────────────────────────────────────────
#> Data source: crossref
#> Works with funding data: 0 / 200 (0%)
#> 
#> No funding data found.
#> 
#> 
#> ── Limitations 
#> • Funding metadata is voluntarily reported by publishers and is often
#> incomplete, especially for older publications.
#> • Crossref and OpenAlex may not capture all funding sources; institutional or
#> departmental funding is rarely recorded.
#> • Funder names are not standardised across databases; the same funder may
#> appear under multiple names.
#> • Absence of funding data does not mean a work was unfunded; it may simply be
#> unreported.
# }
```
