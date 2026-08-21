# Build a figure caption and alt-text manifest

Scans a directory of figures and produces a tidy manifest of captions,
alt-text, and (where readable) pixel dimensions and DPI. This replaces
the hand-maintained `figure_captions.R` scripts that accompany many
manuscripts.

Captions and alt-text are pulled from a sidecar file if one is present
(`captions.csv`, `captions.yml`, or `captions.yaml` in `dir`), otherwise
the columns are left empty for the user to fill in.

## Usage

``` r
sm_figure_manifest(
  dir,
  pattern = NULL,
  output = NULL,
  call = rlang::caller_env()
)
```

## Arguments

- dir:

  Directory to scan.

- pattern:

  Optional regular expression to filter file names. Defaults to common
  figure extensions (`png`, `pdf`, `svg`, `tif`, `tiff`, `jpg`, `jpeg`,
  `eps`).

- output:

  Optional path to write the manifest to. A `.csv` extension writes CSV;
  `.yml`/`.yaml` writes YAML (requires the optional yaml package).

- call:

  Caller environment for error reporting.

## Value

A tibble with one row per figure file and columns `file`, `caption`,
`alt_text`, `width`, `height`, `dpi`. Pixel dimensions / DPI are read
from the image where feasible (using the optional magick or png
packages) and are `NA` otherwise. Type-stable: a missing or empty
directory returns a 0-row tibble (with a `cli` warning), never an error.

## See also

Other reporting:
[`sm_corpus_from_tables()`](https://cttir.github.io/scimapR/reference/sm_corpus_from_tables.md)

## Examples

``` r
# \donttest{
d <- withr::local_tempdir()
ggplot2::ggsave(file.path(d, "fig1.png"),
                ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
                  ggplot2::geom_point(),
                width = 4, height = 3, dpi = 150)
#> Error in ggplot2::ggsave(file.path(d, "fig1.png"), ggplot2::ggplot(mtcars,     ggplot2::aes(wt, mpg)) + ggplot2::geom_point(), width = 4,     height = 3, dpi = 150): Cannot find directory /tmp/RtmpVDxLPH/file25bd2e43545a.
#> ℹ Please supply an existing directory or use `create.dir = TRUE`.
sm_figure_manifest(d)
#> Warning: ! Directory /tmp/RtmpVDxLPH/file25bd2e43545a does not exist.
#> ℹ Returning an empty figure manifest.
#> # A tibble: 0 × 6
#> # ℹ 6 variables: file <chr>, caption <chr>, alt_text <chr>, width <int>,
#> #   height <int>, dpi <dbl>
# }
```
