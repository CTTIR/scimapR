test_that("the NEWS heading describes the installed version", {
  path <- system.file("DESCRIPTION", package = "scimapR")
  version <- read.dcf(path)[, "Version"]
  version <- unname(version)
  news <- readLines(system.file("NEWS.md", package = "scimapR"))
  headings <- grep("^# scimapR", news, value = TRUE)
  parts <- as.integer(strsplit(version, ".", fixed = TRUE)[[1]])
  # r-universe replaces the development heading with the version at build time
  expected <- paste("# scimapR", version)
  if (length(parts) > 3L && parts[4] >= 9000L) {
    expected <- c("# scimapR (development version)", expected)
  }
  expect_true(headings[1] %in% expected)
  meta <- as.list(read.dcf(path)[1, ])
  entry <- utils::readCitationFile(
    system.file("CITATION", package = "scimapR"), meta = meta
  )
  expected_note <- paste("R package version", version)
  expect_identical(entry[[1]]$note, expected_note)
  if (nzchar(system.file("Meta", "package.rds", package = "scimapR"))) {
    expect_identical(utils::citation("scimapR")[[1]]$note, expected_note)
  }
})

test_that("the citation manifest uses the package version", {
  path <- test_path("..", "..", "CITATION.cff")
  skip_if_not(file.exists(path))
  line <- grep("^version:", readLines(path), value = TRUE)
  version <- sub("^version: *", "", line)
  expect_identical(version, as.character(utils::packageVersion("scimapR")))
})

test_that("the archive manifest uses the package version", {
  path <- test_path("..", "..", ".zenodo.json")
  skip_if_not(file.exists(path))
  version <- jsonlite::fromJSON(path)$version
  expect_identical(version, as.character(utils::packageVersion("scimapR")))
})
