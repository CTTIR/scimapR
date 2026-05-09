# Load embeddings from disk

Loads a previously saved embeddings matrix from an RDS file and attaches
it to the corpus. Only embeddings for works present in the corpus are
loaded; mismatches are reported.

## Usage

``` r
sm_embed_load(corpus, path, call = rlang::caller_env())
```

## Arguments

- corpus:

  An
  [sm_corpus](https://r-heller.github.io/scimapR/reference/sm_corpus.md)
  object.

- path:

  Character; file path to read embeddings from (an `.rds` file created
  by
  [`sm_embed_save()`](https://r-heller.github.io/scimapR/reference/sm_embed_save.md)).

- call:

  Caller environment for error reporting.

## Value

The input `corpus` with `corpus$embeddings` updated.

## See also

Other embedding:
[`sm_embed_save()`](https://r-heller.github.io/scimapR/reference/sm_embed_save.md),
[`sm_embed_works()`](https://r-heller.github.io/scimapR/reference/sm_embed_works.md)

## Examples

``` r
if (FALSE) { # \dontrun{
corpus <- sm_example_corpus(with_embeddings = FALSE)
corpus <- sm_embed_load(corpus, "my_embeddings.rds")
dim(corpus$embeddings)
} # }
```
