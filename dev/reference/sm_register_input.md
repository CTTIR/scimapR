# Register a local input file of a corpus

Record a local file that a corpus was built from, such as a database
snapshot, an institutional export, a publication tracker or an
affiliation dictionary, together with its SHA-256 hash.
[`sm_certificate()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md)
lists the registered files in its `local_inputs` block, and
[`sm_verify_certificate()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md)
checks that each of them still has the hash recorded here.
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/dev/reference/sm_corpus_from_tables.md)
registers the files given as its `inputs`.

## Usage

``` r
sm_register_input(
  corpus,
  path,
  role = NULL,
  builder = NULL,
  call = rlang::caller_env()
)
```

## Arguments

- corpus:

  An `sm_corpus` object. A locked corpus
  ([`sm_lock()`](https://cttir.github.io/scimapR/dev/reference/sm_lock.md))
  cannot be changed.

- path:

  Path of the file.

- role:

  `NULL` or a string: what the file is.

- builder:

  `NULL` or a string: the code that read the file.

- call:

  Caller environment for error reporting.

## Value

The corpus with the file recorded in `corpus$metadata$local_inputs`.

## Details

The file is hashed as a stream
(`digest::digest(path, algo = "sha256", file = TRUE)`), so large
snapshots are not read into memory. The function adds one row to
`corpus$metadata$local_inputs`, a tibble with these columns:

|                 |           |                                             |
|-----------------|-----------|---------------------------------------------|
| Column          | Type      | Content                                     |
| `path`          | character | The path, relative or as given (see below)  |
| `path_abs`      | character | The absolute path of the file               |
| `root`          | character | The working directory at registration       |
| `basename`      | character | The file name                               |
| `sha256`        | character | SHA-256 hash of the content                 |
| `bytes`         | double    | Size in bytes                               |
| `role`          | character | What the file is, such as `"dictionary"`    |
| `builder`       | character | The code that read it                       |
| `registered_at` | POSIXct   | When it was registered (UTC, whole seconds) |

`path` is relative to the working directory when the file lies below it,
and as given otherwise. `role` names the file's part in the corpus, such
as `"source database"` or `"publication tracker"`, and `builder` the
code that read it, such as `"R/02_corpus.R::build_corpus"`.

Registering the same file again replaces its row; paths are compared
after they are made absolute, so `"data/x.csv"` and `"./data/x.csv"`
name the same file. A corpus without registered files has no such
element;
[`sm_certificate()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md)
then writes an empty block.

Local inputs are metadata: they do not enter the corpus hash
([`sm_hash_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_hash_corpus.md)),
and
[`sm_rebuild_from_cert()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md)
cannot replay them. A certificate records `path_abs` and `root` as well
as `path`, so that
[`sm_verify_certificate()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md)
finds the files on the same computer from any folder; these absolute
paths show the folder names of that computer.

## See also

[`sm_certificate()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md),
[`sm_verify_certificate()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md)

Other reproducibility:
[`sm_certificate()`](https://cttir.github.io/scimapR/dev/reference/sm_certificate.md),
[`sm_cite_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_cite_corpus.md),
[`sm_diff_corpora()`](https://cttir.github.io/scimapR/dev/reference/sm_diff_corpora.md),
[`sm_hash_corpus()`](https://cttir.github.io/scimapR/dev/reference/sm_hash_corpus.md),
[`sm_provenance()`](https://cttir.github.io/scimapR/dev/reference/sm_provenance.md),
[`sm_snapshot()`](https://cttir.github.io/scimapR/dev/reference/sm_snapshot.md)

## Examples

``` r
corpus <- sm_example_corpus(n_works = 10)
tracker <- tempfile(fileext = ".csv")
writeLines(c("doi,unit", "10.9999/example.1,Unit A"), tracker)
corpus <- sm_register_input(corpus, tracker,
                            role = "publication tracker",
                            builder = "R/01_import.R::read_tracker")
corpus$metadata$local_inputs
#> # A tibble: 1 × 9
#>   path    path_abs root  basename sha256 bytes role  builder registered_at      
#>   <chr>   <chr>    <chr> <chr>    <chr>  <dbl> <chr> <chr>   <dttm>             
#> 1 /tmp/R… /tmp/Rt… /hom… file1c5… 721a6…    34 publ… R/01_i… 2026-10-28 08:36:29
```
