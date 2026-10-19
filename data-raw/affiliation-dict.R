# Build the default affiliation dictionary `sm_affiliation_dict`.
# Run with: source("data-raw/affiliation-dict.R")
#
# The dictionary is intentionally small, documented, and user-overridable. It
# covers common military / medical institution name variants (including German
# synonyms) plus email-domain fallbacks. Patterns are case-insensitive regular
# expressions matched against affiliation strings.
#
# The English names of the hospital are anchored on "Bundeswehr" or "German":
# a bare "military hospital", "army hospital" or "armed forces hospital" names
# hospitals of many countries, so it stays unmatched.
hospital_bundeswehr <- "bundeswehr\\W+(\\w+\\W+)?hospital"
hospital_german <- "german (armed forces|army|military)\\W+(\\w+\\W+)?hospital"

sm_affiliation_dict <- tibble::tribble(
  ~institution,                ~pattern,                              ~email_domain,
  "Bundeswehr Hospital",       "bundeswehrkrankenhaus",               "bundeswehr.org",
  "Bundeswehr Hospital",       hospital_bundeswehr,                   NA,
  "Bundeswehr Hospital",       hospital_german,                       NA,
  "Bundeswehr Hospital",       "bwkrhs",                              NA,
  "Charite Berlin",            "charit[eé]",                          "charite.de",
  "Charite Berlin",            "universit[aä]tsmedizin berlin",       NA,
  "Walter Reed",               "walter reed",                         NA,
  "Walter Reed",               "wrair",                               NA,
  "US Army",                   "u\\.?s\\.? army",                     "army.mil",
  "US Army",                   "united states army",                  NA,
  "NATO",                      "\\bnato\\b",                          NA,
  "Robert Koch Institute",     "robert koch",                         "rki.de",
  "Robert Koch Institute",     "robert-koch-institut",                NA
)

usethis::use_data(sm_affiliation_dict, overwrite = TRUE)
