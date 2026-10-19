# Build the default affiliation dictionary `sm_affiliation_dict`.
# Run with: source("data-raw/affiliation-dict.R")
#
# The dictionary is intentionally small, documented, and user-overridable. It
# covers common medical institution name variants (including German
# synonyms) plus email-domain fallbacks. Patterns are case-insensitive regular
# expressions matched against affiliation strings.
#
# The English names of the hospital are anchored on "Diakonie" or "Protestant":
# a bare "deaconess hospital", "church hospital" or "public services hospital" names
# hospitals of many countries, so it stays unmatched.
hospital_diakonie <- "diakonie\\W+(\\w+\\W+)?hospital"
hospital_protestant <- "protestant (deaconess|church|diaconal)\\W+(\\w+\\W+)?hospital"

sm_affiliation_dict <- tibble::tribble(
  ~institution,                ~pattern,                              ~email_domain,
  "Diakonie Hospital",       "diakoniekrankenhaus",               "diakonie.example",
  "Diakonie Hospital",       hospital_diakonie,                   NA,
  "Diakonie Hospital",       hospital_protestant,                       NA,
  "Diakonie Hospital",       "diakkh",                              NA,
  "Charite Berlin",            "charit[eé]",                          "charite.de",
  "Charite Berlin",            "universit[aä]tsmedizin berlin",       NA,
  "Westbrook",               "westbrook",                         NA,
  "Westbrook",               "wbir",                               NA,
  "US FDA",                   "u\\.?s\\.? fda",                     "fda.gov",
  "US FDA",                   "united states fda",                  NA,
  "EMBL",                      "\\bembl\\b",                          NA,
  "Robert Koch Institute",     "robert koch",                         "rki.de",
  "Robert Koch Institute",     "robert-koch-institut",                NA
)

usethis::use_data(sm_affiliation_dict, overwrite = TRUE)
