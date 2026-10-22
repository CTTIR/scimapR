test_that("WoS BibTeX protective braces are removed once per field", {
  expect_no_warning(x <- sm_read_bib(
    test_path("fixtures", "wos-export.bib"), verbose = FALSE
  ))
  expect_identical(x$works$doi, c("10.9999/jsm.2017.001",
                                  "10.9999/jsm.2018.002"))
  expect_identical(x$works$title,
                   c("A RNA mapping study", "A second mapping study"))
  expect_identical(x$works$year, c(2017L, 2018L))
  expect_identical(x$sources$display_name, "Journal of Synthetic Mapping")
  expect_identical(x$concepts$concept_name,
                   c("Mapping", "Networks", "Data", "Methods"))
})

test_that("BibLaTeX dates and braced corporate authors retain their meaning", {
  x <- sm_read_bib(test_path("fixtures", "biblatex-export.bib"),
                   verbose = FALSE)
  expect_identical(x$works$year, c(2023L, 2021L, 2020L))
  expect_identical(x$sources$display_name, "Journal of Invented Studies")
  expect_identical(x$authors$display_name,
                   c("Research and Development Group", "J Smith",
                     "Barnes and Partners, Inc.", "T Okafor"))
  expect_identical(x$authorships$position, c(1L, 2L, 1L, 1L))
})

test_that("BibTeX quotes preserve braced accents and following fields", {
  path <- withr::local_tempfile(fileext = ".bib")
  writeLines(c(
    r"(@article{accents, title = "M{\"u}ller's {RNA} study",)",
    r"(author = {M{\"u}ller, J and {\ss} and \'{\i}},)",
    r"(abstract = {\'{e} \{x\} \& \% \$ \# \_ ~ -- $x^2$},)",
    r"(doi = {10.9999/abc\_def}, year = {2022}})"
  ), path)
  expect_no_warning(x <- sm_read_bib(path, verbose = FALSE))
  expect_identical(x$works$title, "M\u00fcller's RNA study")
  expect_identical(x$authors$display_name,
                   c("J M\u00fcller", "\u00df", "\u00ed"))
  expect_identical(x$works$abstract, "\u00e9 {x} & % $ # _ ~ -- $x^2$")
  expect_identical(x$works$doi, "10.9999/abc_def")
  expect_identical(x$works$year, 2022L)
})

test_that("BibTeX simple fixture values stay unchanged", {
  x <- sm_read_bib(sm_example_files("example.bib"), verbose = FALSE)
  expect_identical(x$works$title, c(
    paste("Spatial transcriptomics reveals tumor microenvironment",
          "heterogeneity in colorectal cancer"),
    paste("Machine learning approaches for biomarker discovery in spatially",
          "resolved transcriptomic data"),
    "Atlas of Spatial Omics in Colorectal Cancer"
  ))
  expect_identical(x$works$year, c(2023L, 2022L, 2024L))
  expect_identical(x$works$doi, c("10.1038/s41591-023-02345-6",
                                  "10.1145/3535508.3545539",
                                  "10.1007/978-3-031-45678-9"))
  expect_identical(x$authors$display_name,
                   c("Wei Chen", "Sarah Smith", "Yuki Tanaka", "Priya Patel",
                     "Anna Mueller", "Maria Garcia", "Wei Zhang",
                     "James Johnson", "Lars Andersson"))
  y <- sm_read_bib(sm_example_files("example_sparse.bib"), verbose = FALSE)
  expect_identical(y$works$title,
                   c("A Field-Sparse Article Missing Journal, Volume and Pages",
                     "Another Minimal Entry"))
  expect_identical(y$works$year, c(2020L, 2021L))
  expect_identical(y$works$doi, c(NA_character_, "10.1234/minimal.2021"))
  expect_identical(y$authors$display_name,
                   c("Jane Doe", "Richard Roe", "John Smith"))
})


test_that("BibTeX text cleaning decodes its documented macros", {
  text <- c(r"(\"a)", r"(\"{a})", r"({\"a})", r"({\"{a}})",
            r"(\'e)", r"(\`a)", r"(\^o)", r"(\~n)", r"(\=a)", r"(\.z)",
            r"(\c{c})", r"(\v s)", r"(\u{g})", r"(\H{o})",
            r"(\k{a})", r"(\r{a})", r"(\"q)")
  expect_identical(.bib_clean_text(text),
                   c(rep("\u00e4", 4), "\u00e9", "\u00e0", "\u00f4",
                     "\u00f1", "\u0101", "\u017c", "\u00e7", "\u0161",
                     "\u011f", "\u0151", "\u0105", "\u00e5", "q"))
  macros <- r"(\ss \o \O \aa \AA \ae \AE \oe \OE \l \L \i)"
  expect_identical(.bib_clean_text(macros),
                   paste("\u00df \u00f8 \u00d8 \u00e5 \u00c5 \u00e6",
                         "\u00c6 \u0153 \u0152 \u0142 \u0141 \u0131"))
  expect_identical(.bib_clean_text(c(NA, "{}", " a  b ")),
                   c(NA_character_, NA_character_, "a b"))
  expect_identical(.bib_clean_text(character()), character())
  expect_identical(.bib_clean_text(r"({10.9999/a\_b\"u})", doi = TRUE),
                   r"(10.9999/a_b\"u)")
  expect_identical(.bib_split_names("Smith, J and others"),
                   c("Smith, J", "others"))
  expect_identical(.bib_split_names("Smith, J AND Okafor, T"),
                   "Smith, J AND Okafor, T")
})


test_that("BibTeX math expressions remain as written", {
  path <- withr::local_tempfile(fileext = ".bib")
  writeLines(r"(@article{math, title = {{A $x_{1}$ and $\frac{a}{b}$ study}}})",
             path)
  x <- sm_read_bib(path, verbose = FALSE)
  expect_identical(x$works$title, r"(A $x_{1}$ and $\frac{a}{b}$ study)")
})
