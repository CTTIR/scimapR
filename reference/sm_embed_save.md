# Save embeddings to disk

Saves the embeddings matrix from an `sm_corpus` to an RDS file on disk.
This allows caching expensive embedding computations for later reuse
with
[`sm_embed_load()`](https://cttir.github.io/scimapR/reference/sm_embed_load.md).
The cache keeps the record of the model behind the embeddings
(`corpus$metadata$embedding`, see
[`sm_corpus()`](https://cttir.github.io/scimapR/reference/sm_corpus.md))
when the corpus has one.

## Usage

``` r
sm_embed_save(corpus, path, call = rlang::caller_env())
```

## Arguments

- corpus:

  An [sm_corpus](https://cttir.github.io/scimapR/reference/sm_corpus.md)
  object with a non-`NULL` `embeddings` matrix.

- path:

  Character; file path to write the embeddings to. Should end in `.rds`.

- call:

  Caller environment for error reporting.

## Value

The input `corpus` (invisibly).

## See also

Other embedding:
[`sm_embed_load()`](https://cttir.github.io/scimapR/reference/sm_embed_load.md),
[`sm_embed_works()`](https://cttir.github.io/scimapR/reference/sm_embed_works.md)

## Examples

``` r
corpus <- sm_example_corpus(with_embeddings = TRUE)
path <- tempfile(fileext = ".rds")
sm_embed_save(corpus, path)
#> ✔ Embeddings saved to /tmp/RtmpVfP8jz/file1b3d7a063807.rds.
#> ℹ 200 works x 64 dimensions, embeddings whose model is not recorded.
file.exists(path)
#> [1] TRUE
unlink(path)
```
