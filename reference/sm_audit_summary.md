# Combined equity audit summary

Runs all available equity audits (geographic, gender, funding, OA
status) on a corpus and returns a combined summary. Individual audit
results can be passed as `...` arguments to avoid re-computation; any
missing audits are run with default parameters.

## Usage

``` r
# S3 method for class 'sm_audit_summary'
print(x, ...)

sm_audit_summary(corpus, ..., call = rlang::caller_env())
```

## Arguments

- x:

  An audit object to print.

- ...:

  Optional pre-computed audit objects (e.g., `sm_audit_geographic`,
  `sm_audit_gender`, `sm_audit_funding`, `sm_audit_oa`). If provided,
  these are included directly rather than being re-run.

- corpus:

  An `sm_corpus` object.

- call:

  Caller environment for error reporting.

## Value

An `sm_audit_summary` S3 object containing:

- geographic:

  An `sm_audit_geographic` result.

- gender:

  An `sm_audit_gender` result.

- funding:

  An `sm_audit_funding` result.

- oa:

  An `sm_audit_oa` result.

- overview:

  A one-row tibble summarising coverage across all audits.

## See also

Other audit:
[`sm_audit_funding()`](https://r-heller.github.io/scimapR/reference/sm_audit_funding.md),
[`sm_audit_gender()`](https://r-heller.github.io/scimapR/reference/sm_audit_gender.md),
[`sm_audit_geographic()`](https://r-heller.github.io/scimapR/reference/sm_audit_geographic.md),
[`sm_audit_oa()`](https://r-heller.github.io/scimapR/reference/sm_audit_oa.md)

## Examples

``` r
# \donttest{
corpus <- sm_example_corpus()
summary_audit <- sm_audit_summary(corpus)
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
#> Warning: 404 (client error): /works/10.1234/example.11 - Resource not found.
#> Warning: 429 (client error): /works/10.1234/example.12 - 
#> Warning: 404 (client error): /works/10.1234/example.13 - Resource not found.
#> Warning: 429 (client error): /works/10.1234/example.14 - 
#> Warning: 404 (client error): /works/10.1234/example.15 - Resource not found.
#> Warning: 404 (client error): /works/10.1234/example.16 - Resource not found.
#> Warning: 429 (client error): /works/10.1234/example.17 - 
#> Warning: 429 (client error): /works/10.1234/example.18 - 
#> Warning: 429 (client error): /works/10.1234/example.19 - 
#> Warning: 429 (client error): /works/10.1234/example.20 - 
#> Warning: 429 (client error): /works/10.1234/example.21 - 
#> Warning: 404 (client error): /works/10.1234/example.22 - Resource not found.
#> Warning: 429 (client error): /works/10.1234/example.23 - 
#> Warning: 429 (client error): /works/10.1234/example.24 - 
#> Warning: 429 (client error): /works/10.1234/example.25 - 
#> Warning: 429 (client error): /works/10.1234/example.26 - 
#> Warning: 429 (client error): /works/10.1234/example.27 - 
#> Warning: 429 (client error): /works/10.1234/example.28 - 
#> Warning: 429 (client error): /works/10.1234/example.29 - 
#> Warning: 429 (client error): /works/10.1234/example.30 - 
#> Warning: 429 (client error): /works/10.1234/example.31 - 
#> Warning: 429 (client error): /works/10.1234/example.32 - 
#> Warning: 429 (client error): /works/10.1234/example.33 - 
#> Warning: 429 (client error): /works/10.1234/example.34 - 
#> Warning: 429 (client error): /works/10.1234/example.35 - 
#> Warning: 429 (client error): /works/10.1234/example.36 - 
#> Warning: 429 (client error): /works/10.1234/example.37 - 
#> Warning: 429 (client error): /works/10.1234/example.38 - 
#> Warning: 429 (client error): /works/10.1234/example.39 - 
#> Warning: 429 (client error): /works/10.1234/example.40 - 
#> Warning: 429 (client error): /works/10.1234/example.41 - 
#> Warning: 429 (client error): /works/10.1234/example.42 - 
#> Warning: 429 (client error): /works/10.1234/example.43 - 
#> Warning: 429 (client error): /works/10.1234/example.44 - 
#> Warning: 429 (client error): /works/10.1234/example.45 - 
#> Warning: 429 (client error): /works/10.1234/example.46 - 
#> Warning: 429 (client error): /works/10.1234/example.47 - 
#> Warning: 429 (client error): /works/10.1234/example.48 - 
#> Warning: 429 (client error): /works/10.1234/example.49 - 
#> Warning: 429 (client error): /works/10.1234/example.50 - 
#> Warning: 429 (client error): /works/10.1234/example.51 - 
#> Warning: 429 (client error): /works/10.1234/example.52 - 
#> Warning: 429 (client error): /works/10.1234/example.53 - 
#> Warning: 429 (client error): /works/10.1234/example.54 - 
#> Warning: 429 (client error): /works/10.1234/example.55 - 
#> Warning: 429 (client error): /works/10.1234/example.56 - 
#> Warning: 429 (client error): /works/10.1234/example.57 - 
#> Warning: 429 (client error): /works/10.1234/example.58 - 
#> Warning: 429 (client error): /works/10.1234/example.59 - 
#> Warning: 429 (client error): /works/10.1234/example.60 - 
#> Warning: 429 (client error): /works/10.1234/example.61 - 
#> Warning: 429 (client error): /works/10.1234/example.62 - 
#> Warning: 429 (client error): /works/10.1234/example.63 - 
#> Warning: 429 (client error): /works/10.1234/example.64 - 
#> Warning: 429 (client error): /works/10.1234/example.65 - 
#> Warning: 429 (client error): /works/10.1234/example.66 - 
#> Warning: 429 (client error): /works/10.1234/example.67 - 
#> Warning: 429 (client error): /works/10.1234/example.68 - 
#> Warning: 429 (client error): /works/10.1234/example.69 - 
#> Warning: 429 (client error): /works/10.1234/example.70 - 
#> Warning: 429 (client error): /works/10.1234/example.71 - 
#> Warning: 429 (client error): /works/10.1234/example.72 - 
#> Warning: 429 (client error): /works/10.1234/example.73 - 
#> Warning: 429 (client error): /works/10.1234/example.74 - 
#> Warning: 429 (client error): /works/10.1234/example.75 - 
#> Warning: 429 (client error): /works/10.1234/example.76 - 
#> Warning: 429 (client error): /works/10.1234/example.77 - 
#> Warning: 429 (client error): /works/10.1234/example.78 - 
#> Warning: 429 (client error): /works/10.1234/example.79 - 
#> Warning: 429 (client error): /works/10.1234/example.80 - 
#> Warning: 429 (client error): /works/10.1234/example.81 - 
#> Warning: 429 (client error): /works/10.1234/example.82 - 
#> Warning: 429 (client error): /works/10.1234/example.83 - 
#> Warning: 429 (client error): /works/10.1234/example.84 - 
#> Warning: 429 (client error): /works/10.1234/example.85 - 
#> Warning: 429 (client error): /works/10.1234/example.86 - 
#> Warning: 429 (client error): /works/10.1234/example.87 - 
#> Warning: 429 (client error): /works/10.1234/example.88 - 
#> Warning: 429 (client error): /works/10.1234/example.89 - 
#> Warning: 429 (client error): /works/10.1234/example.90 - 
#> Warning: 429 (client error): /works/10.1234/example.91 - 
#> Warning: 429 (client error): /works/10.1234/example.92 - 
#> Warning: 429 (client error): /works/10.1234/example.93 - 
#> Warning: 429 (client error): /works/10.1234/example.94 - 
#> Warning: 429 (client error): /works/10.1234/example.95 - 
#> Warning: 429 (client error): /works/10.1234/example.96 - 
#> Warning: 429 (client error): /works/10.1234/example.97 - 
#> Warning: 429 (client error): /works/10.1234/example.98 - 
#> Warning: 429 (client error): /works/10.1234/example.99 - 
#> Warning: 429 (client error): /works/10.1234/example.100 - 
#> Warning: 429 (client error): /works/10.1234/example.101 - 
#> Warning: 429 (client error): /works/10.1234/example.102 - 
#> Warning: 429 (client error): /works/10.1234/example.103 - 
#> Warning: 429 (client error): /works/10.1234/example.104 - 
#> Warning: 429 (client error): /works/10.1234/example.105 - 
#> Warning: 429 (client error): /works/10.1234/example.106 - 
#> Warning: 429 (client error): /works/10.1234/example.107 - 
#> Warning: 429 (client error): /works/10.1234/example.108 - 
#> Warning: 429 (client error): /works/10.1234/example.109 - 
#> Warning: 429 (client error): /works/10.1234/example.110 - 
#> Warning: 429 (client error): /works/10.1234/example.111 - 
#> Warning: 429 (client error): /works/10.1234/example.112 - 
#> Warning: 429 (client error): /works/10.1234/example.113 - 
#> Warning: 429 (client error): /works/10.1234/example.114 - 
#> Warning: 429 (client error): /works/10.1234/example.115 - 
#> Warning: 429 (client error): /works/10.1234/example.116 - 
#> Warning: 429 (client error): /works/10.1234/example.117 - 
#> Warning: 429 (client error): /works/10.1234/example.118 - 
#> Warning: 429 (client error): /works/10.1234/example.119 - 
#> Warning: 429 (client error): /works/10.1234/example.120 - 
#> Warning: 429 (client error): /works/10.1234/example.121 - 
#> Warning: 429 (client error): /works/10.1234/example.122 - 
#> Warning: 429 (client error): /works/10.1234/example.123 - 
#> Warning: 429 (client error): /works/10.1234/example.124 - 
#> Warning: 429 (client error): /works/10.1234/example.125 - 
#> Warning: 429 (client error): /works/10.1234/example.126 - 
#> Warning: 429 (client error): /works/10.1234/example.127 - 
#> Warning: 429 (client error): /works/10.1234/example.128 - 
#> Warning: 429 (client error): /works/10.1234/example.129 - 
#> Warning: 429 (client error): /works/10.1234/example.130 - 
#> Warning: 429 (client error): /works/10.1234/example.131 - 
#> Warning: 429 (client error): /works/10.1234/example.132 - 
#> Warning: 429 (client error): /works/10.1234/example.133 - 
#> Warning: 429 (client error): /works/10.1234/example.134 - 
#> Warning: 429 (client error): /works/10.1234/example.135 - 
#> Warning: 429 (client error): /works/10.1234/example.136 - 
#> Warning: 429 (client error): /works/10.1234/example.137 - 
#> Warning: 429 (client error): /works/10.1234/example.138 - 
#> Warning: 429 (client error): /works/10.1234/example.139 - 
#> Warning: 429 (client error): /works/10.1234/example.140 - 
#> Warning: 429 (client error): /works/10.1234/example.141 - 
#> Warning: 429 (client error): /works/10.1234/example.142 - 
#> Warning: 429 (client error): /works/10.1234/example.143 - 
#> Warning: 429 (client error): /works/10.1234/example.144 - 
#> Warning: 429 (client error): /works/10.1234/example.145 - 
#> Warning: 429 (client error): /works/10.1234/example.146 - 
#> Warning: 429 (client error): /works/10.1234/example.147 - 
#> Warning: 429 (client error): /works/10.1234/example.148 - 
#> Warning: 429 (client error): /works/10.1234/example.149 - 
#> Warning: 429 (client error): /works/10.1234/example.150 - 
#> Warning: 429 (client error): /works/10.1234/example.151 - 
#> Warning: 429 (client error): /works/10.1234/example.152 - 
#> Warning: 429 (client error): /works/10.1234/example.153 - 
#> Warning: 429 (client error): /works/10.1234/example.154 - 
#> Warning: 429 (client error): /works/10.1234/example.155 - 
#> Warning: 429 (client error): /works/10.1234/example.156 - 
#> Warning: 429 (client error): /works/10.1234/example.157 - 
#> Warning: 429 (client error): /works/10.1234/example.158 - 
#> Warning: 429 (client error): /works/10.1234/example.159 - 
#> Warning: 429 (client error): /works/10.1234/example.160 - 
#> Warning: 429 (client error): /works/10.1234/example.161 - 
#> Warning: 429 (client error): /works/10.1234/example.162 - 
#> Warning: 429 (client error): /works/10.1234/example.163 - 
#> Warning: 429 (client error): /works/10.1234/example.164 - 
#> Warning: 429 (client error): /works/10.1234/example.165 - 
#> Warning: 429 (client error): /works/10.1234/example.166 - 
#> Warning: 429 (client error): /works/10.1234/example.167 - 
#> Warning: 429 (client error): /works/10.1234/example.168 - 
#> Warning: 429 (client error): /works/10.1234/example.169 - 
#> Warning: 429 (client error): /works/10.1234/example.170 - 
#> Warning: 429 (client error): /works/10.1234/example.171 - 
#> Warning: 429 (client error): /works/10.1234/example.172 - 
#> Warning: 429 (client error): /works/10.1234/example.173 - 
#> Warning: 429 (client error): /works/10.1234/example.174 - 
#> Warning: 429 (client error): /works/10.1234/example.175 - 
#> Warning: 429 (client error): /works/10.1234/example.176 - 
#> Warning: 429 (client error): /works/10.1234/example.177 - 
#> Warning: 429 (client error): /works/10.1234/example.178 - 
#> Warning: 429 (client error): /works/10.1234/example.179 - 
#> Warning: 429 (client error): /works/10.1234/example.180 - 
#> Warning: 429 (client error): /works/10.1234/example.181 - 
#> Warning: 429 (client error): /works/10.1234/example.182 - 
#> Warning: 429 (client error): /works/10.1234/example.183 - 
#> Warning: 429 (client error): /works/10.1234/example.184 - 
#> Warning: 429 (client error): /works/10.1234/example.185 - 
#> Warning: 429 (client error): /works/10.1234/example.186 - 
#> Warning: 429 (client error): /works/10.1234/example.187 - 
#> Warning: 429 (client error): /works/10.1234/example.188 - 
#> Warning: 429 (client error): /works/10.1234/example.189 - 
#> Warning: 429 (client error): /works/10.1234/example.190 - 
#> Warning: 429 (client error): /works/10.1234/example.191 - 
#> Warning: 429 (client error): /works/10.1234/example.192 - 
#> Warning: 429 (client error): /works/10.1234/example.193 - 
#> Warning: 429 (client error): /works/10.1234/example.194 - 
#> Warning: 429 (client error): /works/10.1234/example.195 - 
#> Warning: 429 (client error): /works/10.1234/example.196 - 
#> Warning: 429 (client error): /works/10.1234/example.197 - 
#> Warning: 429 (client error): /works/10.1234/example.198 - 
#> Warning: 429 (client error): /works/10.1234/example.199 - 
#> Warning: 429 (client error): /works/10.1234/example.200 - 
#> ℹ No funding data found via "crossref".
#> ℹ This may be because the works lack DOIs/identifiers, or the source does not
#>   have funding metadata.
print(summary_audit)
#> 
#> ── <sm_audit_summary> ──────────────────────────────────────────────────────────
#> 
#> ── Overview 
#> geographic: coverage 100% | DE (10.2%)
#> gender: coverage 0% | NA (100%)
#> funding: coverage 0% | no data
#> open_access: coverage 100% | 56.5% open access
#> 
#> Use `print(x$geographic)`, `print(x$gender)`, etc. for detailed reports.
#> 
#> 
#> ── Limitations 
#> • All equity audits rely on metadata that may be incomplete, inaccurate, or
#> biased toward certain regions and publishers.
#> • Coverage varies across audit dimensions; low coverage means results should be
#> interpreted with extreme caution.
#> • These audits describe patterns in the available metadata and should not be
#> treated as definitive measures of equity.
#> • We encourage transparent reporting of method, coverage, and limitations
#> alongside any equity analysis.
# }
```
