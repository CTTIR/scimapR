# Reproducibility and Corpus Certificates

## Why certificates?

Every bibliometric analysis starts with a corpus, but most analyses
don’t document *how* the corpus was built. scimapR’s corpus certificates
solve this: they are structured YAML documents that another researcher
can use to re-derive the exact same corpus.

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
#> 1 W000000001 synthetic NA                 2026-06-01 09:55:32 sm_example… native
#> 2 W000000002 synthetic NA                 2026-06-01 09:55:32 sm_example… native
#> 3 W000000003 synthetic NA                 2026-06-01 09:55:32 sm_example… native
#> 4 W000000004 synthetic NA                 2026-06-01 09:55:32 sm_example… native
#> 5 W000000005 synthetic NA                 2026-06-01 09:55:32 sm_example… native
#> 6 W000000006 synthetic NA                 2026-06-01 09:55:32 sm_example… native
#> # ℹ 2 more variables: scimapR_version <chr>, prompt_hash <chr>
```

## Corpus hashing

``` r

sm_hash_corpus(corpus)
#> [1] "ea446b5f44659ca0804636faa6e2c6cb66dacc49278ed0ffb03b415cac54dee4"
```

## Creating a certificate

``` r

cert <- sm_certificate(corpus)
#> ✔ Certificate created. Corpus hash: ea446b5f4465
str(cert, max.level = 1)
#> List of 18
#>  $ certificate_version: chr "1.0"
#>  $ created            : POSIXct[1:1], format: "2026-06-01 09:55:32"
#>  $ scimapR_version    : chr "0.2.0"
#>  $ r_version          : chr "4.6.0"
#>  $ platform           : chr "unix"
#>  $ corpus_hash        : chr "ea446b5f44659ca0804636faa6e2c6cb66dacc49278ed0ffb03b415cac54dee4"
#>  $ n_works            : int 200
#>  $ n_authors          : int 80
#>  $ n_institutions     : int 0
#>  $ n_references       : int 1869
#>  $ year_range         : int [1:2] 2015 2024
#>  $ question_id        : chr NA
#>  $ queries            :List of 1
#>  $ provenance_summary :List of 1
#>  $ screening_summary  : list()
#>  $ embedding_info     :List of 3
#>  $ is_locked          : logi FALSE
#>  $ metadata           :List of 2
#>  - attr(*, "class")= chr "sm_certificate"
```

## Verifying a certificate

``` r

result <- sm_verify_certificate(corpus, cert)
result$matches
#> NULL
```

## Saving and loading

``` r

tmp <- tempfile(fileext = ".rds")
sm_save_corpus(corpus, tmp)
#> ✔ Corpus saved to /tmp/Rtmp29rNXG/file30f661b71cac.rds
loaded <- sm_load_corpus(tmp)
nrow(loaded$works)
#> [1] 200
```

## Snapshot and diff

``` r

snap_path <- tempfile(fileext = ".rds")
sm_snapshot(corpus, snap_path)
#> ✔ Corpus snapshot saved to /tmp/Rtmp29rNXG/file30f66771a4c0.rds.
#> ℹ Size: 122K | Hash: ea446b5f4465
```

## Citation

``` r

sm_cite_corpus(corpus)
#> Corpus assembled using scimapR v0.2.0 on 2026-06-01. Contains 200 works by 80
#> authors (2015-2024). Data sources: synthetic. Corpus hash: ea446b5f4465.
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
