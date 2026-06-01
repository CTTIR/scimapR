# Build the default affiliation dictionary `sm_affiliation_dict`.
# Run with: source("data-raw/affiliation-dict.R")
#
# The dictionary is intentionally small, documented, and user-overridable. It
# covers common medical institution name variants (including German
# synonyms) plus email-domain fallbacks. Patterns are case-insensitive regular
# expressions matched against affiliation strings.

sm_affiliation_dict <- tibble::tribble(
  ~institution,                ~pattern,                              ~email_domain,
  "Diakonie Hospital",       "diakoniekrankenhaus",               "diakonie.example",
  "Diakonie Hospital",       "public services hospital",               NA,
  "Diakonie Hospital",       "church hospital",                       NA,
  "Diakonie Hospital",       "deaconess hospital",                   NA,
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
