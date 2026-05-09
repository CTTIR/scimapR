# Lock or unlock a corpus

Locking a corpus prevents mutation by
[`sm_refresh()`](https://cttir.github.io/scimapR/reference/sm_refresh.md)
and other modifying operations. This is useful for archival or when you
want to guarantee reproducibility after generating a
[`sm_certificate()`](https://cttir.github.io/scimapR/reference/sm_certificate.md).

`sm_lock()` sets `metadata$is_locked = TRUE` with an optional reason.
`sm_unlock()` reverses the lock but requires explicit confirmation to
prevent accidental unlocking of archived corpora.

## Usage

``` r
sm_lock(corpus, reason = NULL, call = rlang::caller_env())

sm_unlock(corpus, confirm = FALSE, call = rlang::caller_env())
```

## Arguments

- corpus:

  An `sm_corpus` object.

- reason:

  Optional character string documenting why the corpus was locked (e.g.,
  `"submitted for review"`, `"certificate generated"`).

- call:

  Caller environment for error reporting.

- confirm:

  Logical. Must be `TRUE` to actually unlock. This safeguard prevents
  accidental unlocking of archived corpora.

## Value

A modified `sm_corpus` with updated lock status.

## See also

Other refresh:
[`sm_refresh()`](https://cttir.github.io/scimapR/reference/sm_refresh.md),
[`sm_staleness()`](https://cttir.github.io/scimapR/reference/sm_staleness.md)

## Examples

``` r
corpus <- sm_example_corpus()
locked <- sm_lock(corpus, reason = "archival snapshot")
#> ✔ Corpus locked.
#> ℹ Reason: archival snapshot
locked$metadata$is_locked
#> [1] TRUE

unlocked <- sm_unlock(locked, confirm = TRUE)
#> ✔ Corpus unlocked.
unlocked$metadata$is_locked
#> [1] FALSE
```
