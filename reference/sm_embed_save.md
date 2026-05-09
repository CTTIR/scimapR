# Save embeddings to disk

Saves the embeddings matrix from an `sm_corpus` to an RDS file on disk.
This allows caching expensive embedding computations for later reuse
with
[`sm_embed_load()`](https://r-heller.github.io/scimapR/reference/sm_embed_load.md).

## Usage

``` r
sm_embed_save(corpus, path, call = rlang::caller_env())
```

## Arguments

- corpus:

  An
  [sm_corpus](https://r-heller.github.io/scimapR/reference/sm_corpus.md)
  object with a non-`NULL` `embeddings` matrix.

- path:

  Character; file path to write the embeddings to. Should end in `.rds`.

- call:

  Caller environment for error reporting.

## Value

The input `corpus` (invisibly).

## See also

Other embedding:
[`sm_embed_load()`](https://r-heller.github.io/scimapR/reference/sm_embed_load.md),
[`sm_embed_works()`](https://r-heller.github.io/scimapR/reference/sm_embed_works.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_example_corpus(with_embeddings = TRUE)
sm_embed_save(corpus, "my_embeddings.rds")
} # }
```
