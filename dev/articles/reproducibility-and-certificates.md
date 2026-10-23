# Reproducibility and Corpus Certificates

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

## Why certificates?

Every bibliometric analysis starts with a corpus, but most analyses
don’t document *how* the corpus was built. scimapR’s corpus certificates
solve this: they are structured YAML documents that record the corpus
hash, the steps behind the corpus and the local files it was built from,
so that another researcher can check a corpus against them and run its
searches again.

``` r

library(scimapR)
corpus <- sm_example_corpus(seed = 42)
```

## Provenance tracking

Every record in a scimapR corpus knows where it came from:

``` r

head(sm_provenance(corpus))
#> # A tibble: 6 × 8
#>   work_id    source    source_id_external fetch_date          query       engine
#>   <chr>      <chr>     <chr>              <dttm>              <chr>       <chr> 
#> 1 W000000001 synthetic NA                 2026-10-23 20:12:38 sm_example… native
#> 2 W000000002 synthetic NA                 2026-10-23 20:12:38 sm_example… native
#> 3 W000000003 synthetic NA                 2026-10-23 20:12:38 sm_example… native
#> 4 W000000004 synthetic NA                 2026-10-23 20:12:38 sm_example… native
#> 5 W000000005 synthetic NA                 2026-10-23 20:12:38 sm_example… native
#> 6 W000000006 synthetic NA                 2026-10-23 20:12:38 sm_example… native
#> # ℹ 2 more variables: scimapR_version <chr>, prompt_hash <chr>
```

## Corpus hashing

``` r

sm_hash_corpus(corpus)
#> [1] "61c0637eede72e86bf489cf7d8a27949789b82485ea6646cc707da9ec1945bb6"
```

## Creating a certificate

``` r

cert <- sm_certificate(corpus)
#> ✔ Certificate created. Corpus hash: 61c0637eede7
str(cert, max.level = 1)
#> List of 20
#>  $ certificate_version: chr "1.0"
#>  $ created            : POSIXct[1:1], format: "2026-10-23 20:12:38"
#>  $ scimapR_version    : chr "0.4.0.9000"
#>  $ r_version          : chr "4.6.1"
#>  $ platform           : chr "unix"
#>  $ corpus_hash        : chr "61c0637eede72e86bf489cf7d8a27949789b82485ea6646cc707da9ec1945bb6"
#>  $ hash_version       : int 2
#>  $ n_works            : int 200
#>  $ n_authors          : int 80
#>  $ n_institutions     : int 0
#>  $ n_references       : int 1869
#>  $ year_range         : int [1:2] 2015 2024
#>  $ question_id        : chr NA
#>  $ queries            :List of 1
#>  $ provenance_summary :List of 1
#>  $ screening_summary  : list()
#>  $ embedding_info     :List of 13
#>  $ local_inputs       : tibble [0 × 9] (S3: tbl_df/tbl/data.frame)
#>  $ is_locked          : logi FALSE
#>  $ metadata           :List of 2
#>  - attr(*, "class")= chr "sm_certificate"
```

## Verifying a certificate

``` r

result <- sm_verify_certificate(corpus, cert)
result$pass
#> [1] TRUE
result$checks[, c("check", "expected", "actual", "status")]
#> # A tibble: 5 × 4
#>   check          expected         actual           status
#>   <chr>          <chr>            <chr>            <chr> 
#> 1 corpus_hash    61c0637eede72e86 61c0637eede72e86 pass  
#> 2 n_works        200              200              pass  
#> 3 n_authors      80               80               pass  
#> 4 n_institutions 0                0                pass  
#> 5 n_references   1869             1869             pass
```

## Local input files

A corpus built from local files, such as a database snapshot, an
institutional export or an affiliation dictionary, records each file
with its SHA-256 hash. `sm_corpus_from_tables(inputs = )` registers the
files the tables come from;
[`sm_register_input()`](https://cttir.github.io/scimapR/dev/reference/sm_register_input.md)
adds any other file.

``` r

tracker <- tempfile(fileext = ".csv")
writeLines(c("doi,unit", "10.9999/example.1,Unit A"), tracker)
corpus <- sm_register_input(corpus, tracker, role = "publication tracker",
                            builder = "R/01_import.R::read_tracker")
cert <- sm_certificate(corpus)
#> ✔ Certificate created. Corpus hash: 61c0637eede7
sm_verify_certificate(corpus, cert)$checks[, c("check", "status")]
#> # A tibble: 6 × 2
#>   check                      status
#>   <chr>                      <chr> 
#> 1 corpus_hash                pass  
#> 2 n_works                    pass  
#> 3 n_authors                  pass  
#> 4 n_institutions             pass  
#> 5 n_references               pass  
#> 6 input:file2e5239e19cfa.csv pass

# once the file changes, its check fails
cat("10.9999/example.2,Unit B\n", file = tracker, append = TRUE)
sm_verify_certificate(corpus, cert)$pass
#> [1] FALSE
```

A file that verification cannot find is reported as `"not checked"`,
with a warning; its relative path is looked for in `base_dir`, in the
folder of the certificate file and in the working directory.
[`sm_rebuild_from_cert()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md)
replays the recorded searches of OpenAlex, PubMed and Crossref, but it
cannot replay local files or file reads: for a corpus built only from
them it stops and names the files and the code that read them.

## Saving and loading

``` r

tmp <- tempfile(fileext = ".rds")
sm_save_corpus(corpus, tmp)
#> ✔ Corpus saved to /tmp/RtmpmPRFEF/file2e529a0f858.rds
loaded <- sm_load_corpus(tmp)
nrow(loaded$works)
#> [1] 200
```

## Snapshot and diff

``` r

snap_path <- tempfile(fileext = ".rds")
sm_snapshot(corpus, snap_path)
#> ✔ Corpus snapshot saved to /tmp/RtmpmPRFEF/file2e52518cad97.rds.
#> ℹ Size: 122K | Hash: 61c0637eede7
```

## Citation

``` r

sm_cite_corpus(corpus)
#> Corpus assembled using scimapR v0.4.0.9000 on 2026-10-23. Contains 200 works by 80 authors (2015-2024). Data sources: synthetic. Corpus hash: 61c0637eede7.
```

## Locking a corpus

``` r

locked <- sm_lock(corpus, reason = "Final version for publication")
#> ✔ Corpus locked.
#> ℹ Reason: Final version for publication
locked$metadata$is_locked
#> [1] TRUE

# sm_refresh(locked)  # This would error -- corpus is locked
```
