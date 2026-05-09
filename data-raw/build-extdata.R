## Generate the bundled example corpus ----
## Run this script with: source("data-raw/build-extdata.R")

sm_example_db <- scimapR::sm_example_corpus(seed = 42)
usethis::use_data(sm_example_db, overwrite = TRUE)
