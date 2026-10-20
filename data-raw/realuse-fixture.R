# Synthetic real-use fixture for the scimapR tests, examples and vignettes.
#
# A table-built corpus that looks like a Web of Science export of three
# military-medical units and their civilian partners, a tracker-style
# reference list, an affiliation dictionary and a Web of Science plaintext
# twin of ten of the works. Everything is invented: units, cities,
# postcodes, people, journals, titles and DOIs (10.9999/...).
#
# Run it from the package root after loading the development version with
# devtools::load_all(). It writes example_realuse_corpus.rds,
# example_realuse_reference.csv and example_realuse_affiliation_dict.csv
# to inst/extdata and realuse-wos-sample.txt to tests/testthat/fixtures.
#
# Reproducibility: each random block below is seeded with fixed RNG kinds.
# The metadata fields scimapR_version, build_date and last_refresh are set
# here because .safe_metadata() would otherwise stamp packageVersion() and
# Sys.time(); every POSIXct column holds a UTC constant; non-ASCII text is
# written as Unicode escapes. Rerunning the script gives a byte-identical
# rds with the same R version, platform and locale (last built with
# R 4.5.3, aarch64-apple-darwin, locale C.UTF-8). Local input files are not
# registered here, because a registration time would change the rds.
#
# Shapes the tests rely on:
# - 150 works, 2016-2026 (1 in 2016, 2 in 2017, 10 in 2026); work_id is the
#   WoS accession (WOS:...); DOIs are lower case everywhere.
# - quartile is NA for every 2026 work and known for some work in every
#   other year; fwci has gaps; field is the first WoS category.
# - About 15% German works with German abstracts.
# - Exactly one corresponding author per work; in about 40% of the works a
#   civilian partner who is not the first author. Authors with two address
#   rows keep one author_id, position and is_corresponding.
# - Ten authorship rows carry German address strings with non-ASCII
#   letters. Before Unicode-aware matching no dictionary pattern matches
#   them (the generic fallback pattern cannot reach them); afterwards eight
#   match their unit and two (a civilian clinic) stay unmatched.
# - Three keyword themes (anchors "orthohantavirus", "hemorrhage control",
#   "exertional heat illness"); works without an anchor keyword are
#   editorials and letters. One heat-theme abstract repeats the invented
#   token "quillotyrase" 15 times.
# - References are reader-shaped: cited_work_id is NA; local citations
#   carry the cited work's DOI in cited_doi and in the CR string.
# - Two works have no provenance row.
# - Yearly citation counts (citations_by_year) shaped like OpenAlex's
#   counts_by_year as of 2026-10-17 for the works with a DOI: each work's
#   cited_by_count spread over its years since publication, only the ten
#   years 2017-2026 kept and years without citations left out.
#   works$citations_as_of is 2026-10-17 for these works and NA for the
#   three without a DOI.

out_dir <- file.path("inst", "extdata")
twin_dir <- file.path("tests", "testthat", "fixtures")
refresh_epoch <- 1792195200
refresh_time <- .POSIXct(refresh_epoch, tz = "UTC")

seed_block <- function(block) {
  set.seed(20261018L + block, kind = "Mersenne-Twister",
           normal.kind = "Inversion", sample.kind = "Rejection")
}

draw <- function(x, size = 1L, replace = FALSE, prob = NULL) {
  x[sample.int(length(x), size, replace = replace, prob = prob)]
}

fill_slots <- function(template, slots) {
  for (nm in names(slots)) {
    template <- gsub(paste0("{", nm, "}"), slots[[nm]], template,
                     fixed = TRUE)
  }
  template
}

pick_slot <- function(x, late) {
  half <- seq_len(length(x) %/% 2L)
  own <- if (late) x[-half] else x[half]
  other <- if (late) x[half] else x[-half]
  if (stats::runif(1) < 0.85) draw(own, 1L) else draw(other, 1L)
}

cap_first <- function(x) {
  paste0(toupper(substr(x, 1L, 1L)), substring(x, 2L))
}

issn_with_check <- function(digits) {
  vapply(digits, function(d) {
    num <- as.integer(strsplit(d, "", fixed = TRUE)[[1L]])
    check <- (11L - sum(num * 8:2) %% 11L) %% 11L
    paste0(substr(d, 1L, 4L), "-", substr(d, 5L, 7L),
           if (check == 10L) "X" else check)
  }, character(1), USE.NAMES = FALSE)
}

# ---- units, partners and addresses -----------------------------------------

unit_names <- c(
  hospital = "Armed Forces Hospital Northtown",
  microbiology = "Federal Armed Forces Institute of Microbiology",
  zis = "Zentrales Institut des Sanit\u00e4tswesens Nordstadt",
  other = "Sonstige Dienststellen der Streitkr\u00e4fte"
)

affiliations <- data.frame(
  key = c("hosp_trauma", "hosp_intmed", "hosp_anes", "hosp_emerg",
          "afim_main", "afim_virol", "afim_bact", "afim_field",
          "zis_hyg", "zis_lab", "zis_occ", "other_medoff", "other_cmd",
          "un_clinchem", "un_microbiol", "un_trauma", "sms_infect",
          "nuh_derm", "lake_epi", "hill_surg", "fjord_med", "alp_inf",
          "river_ph"),
  unit = c(rep("hospital", 4L), rep("microbiology", 4L), rep("zis", 3L),
           rep("other", 2L), rep(NA_character_, 10L)),
  org = c(rep("Armed Forces Hosp Northtown", 4L),
          rep("Fed Armed Forces Inst Microbiol", 3L),
          "Armed Forces Hosp Northtown",
          rep("Zent Inst Sanitatswesens Nordstadt", 3L),
          "Armed Forces Med Off", "Armed Forces Command Med Serv",
          rep("Univ Northtown", 3L), "Southcity Med Sch",
          "Nordstadt Univ Hosp", "Lakeside Univ", "Hilltop Univ Med Ctr",
          "Univ Fjordby", "Alpenau Cantonal Hosp", "Univ Riverside"),
  dept = c("Dept Trauma Surg", "Dept Internal Med", "Dept Anesthesiol",
           "Dept Emergency Med", "", "Dept Virol", "Dept Bacteriol",
           "Fed Armed Forces Inst Microbiol Field Lab", "Dept Hyg",
           "Lab Med", "Dept Occupat Med", "", "Div Prevent Med",
           "Inst Clin Chem", "Dept Microbiol", "Dept Trauma Surg",
           "Dept Infect Dis", "Dept Dermatol", "Dept Epidemiol",
           "Dept Surg", "Inst Clin Med", "Dept Infect Dis",
           "Sch Publ Hlth"),
  city = c(rep("D-99001 Northtown", 4L), rep("D-99002 Southcity", 3L),
           "D-99001 Northtown", rep("D-99003 Nordstadt", 3L),
           "D-99009 Westburg", "D-99008 Eastham", rep("Northtown", 3L),
           "D-99012 Southcity", "D-99013 Nordstadt", "Lakeside, MA 02999",
           "NL-9999 ZZ Hilltop", "N-9999 Fjordby", "CH-9999 Alpenau",
           "Riverside RV9 9ZZ"),
  country = c(rep("Germany", 18L), "USA", "Netherlands", "Norway",
              "Switzerland", "England"),
  country_code = c(rep("DE", 18L), "US", "NL", "NO", "CH", "GB"),
  themes = c("2", "3", "2", "23", "1", "1", "1", "1", "13", "13", "3",
             "123", "123", "3", "1", "2", "1", "1", "1", "2", "1", "13",
             "3"),
  stringsAsFactors = FALSE
)
# WoS writes US addresses as "City, ST ZIP USA." (no comma before USA).
affiliations$c1 <- paste0(
  affiliations$org, ", ",
  ifelse(nzchar(affiliations$dept), paste0(affiliations$dept, ", "), ""),
  affiliations$city, ifelse(affiliations$country == "USA", " ", ", "),
  affiliations$country, "."
)

# German address strings (OpenAlex- or tracker-style) with the dictionary
# outcome expected after Unicode-aware matching.
german_rows <- data.frame(
  target = c("zis", "zis", "zis", "microbiology", "microbiology",
             "hospital", "hospital", "hospital", "nuh", "nuh"),
  text = c(
    rep("Zentrales Institut des Sanit\u00e4tswesens Nordstadt, Abt. \u00dcbung",
        2L),
    "Abt. \u00dcbung und Ausbildung, Nordstadt",
    rep("Institut f\u00fcr Mikrobiologie der Streitkr\u00e4fte, Southcity",
        2L),
    rep(paste0("Streitkr\u00e4ftekrankenhaus Northtown, Klinik f\u00fcr ",
               "Unfallchirurgie"), 2L),
    "Sektion Fu\u00df- und Sprunggelenkchirurgie, Northtown",
    rep("Universit\u00e4tsklinikum Nordstadt, Klinik f\u00fcr Dermatologie",
        2L)
  ),
  stringsAsFactors = FALSE
)

# Dictionary: institutes first, the city-anchored hospital next, the generic
# fallback last. Rows 2, 3, 4, 6 and 7 need Unicode-aware \w or \b to match
# the German strings above; the fallback only knows the English unit names.
dictionary <- data.frame(
  institution = unname(unit_names[c("microbiology", "microbiology", "zis",
                                    "zis", "hospital", "hospital",
                                    "hospital", "other")]),
  pattern = c(
    "fed\\w* armed forces inst\\w* microbiol",
    "institut f\\w+r mikrobiologie der streitkr\\w+fte",
    "sanit\\w+wesens",
    "\\b\u00fcbung\\b",
    "armed forces hosp\\w* northtown",
    "streitkr\\w+ftekrankenhaus northtown",
    "\\bfu\u00df\\b.*\\bnorthtown\\b",
    "\\barmed forces\\b"
  ),
  email_domain = c("microbiology.forces.example", NA,
                   "sanitaetswesen-nordstadt.example", NA,
                   "hospital-northtown.example", NA, NA, NA),
  stringsAsFactors = FALSE
)

# ---- journals --------------------------------------------------------------

journals <- data.frame(
  key = c("jexm", "eidr", "asur", "fepl", "ijtc", "afmi", "tpem", "zbsm",
          "ejph", "oetx"),
  so = c("JOURNAL OF EXAMPLE MEDICINE",
         "EXAMPLE INFECTIOUS DISEASE REPORTS",
         "ANNALS OF SYNTHETIC SURGERY",
         "FIELD EPIDEMIOLOGY LETTERS",
         "INTERNATIONAL JOURNAL OF INVENTED TRAUMA CARE",
         "ACTA FICTA MICROBIOLOGICA",
         "THERMAL PHYSIOLOGY AND EXAMPLE MEDICINE",
         "ZEITSCHRIFT FUR BEISPIELMEDIZIN",
         "EXAMPLE JOURNAL OF PUBLIC HEALTH",
         "OPEN EXAMPLE TOXICOLOGY"),
  j9 = c("J EXAMPLE MED", "EX INFECT DIS REP", "ANN SYNTH SURG",
         "FIELD EPIDEMIOL LETT", "INT J INVENT TRAUMA C",
         "ACTA FICTA MICROBIOL", "THERM PHYSIOL EX MED", "Z BEISPIELMED",
         "EX J PUBLIC HEALTH", "OPEN EX TOXICOL"),
  ji = c("J. Example Med.", "Ex. Infect. Dis. Rep.", "Ann. Synth. Surg.",
         "Field Epidemiol. Lett.", "Int. J. Invent. Trauma Care",
         "Acta Ficta Microbiol.", "Therm. Physiol. Ex. Med.",
         "Z. Beispielmed.", "Ex. J. Public Health", "Open Ex. Toxicol."),
  wc = c("Medicine, General & Internal",
         "Infectious Diseases; Microbiology",
         "Surgery",
         "Public, Environmental & Occupational Health; Infectious Diseases",
         "Emergency Medicine; Surgery",
         "Microbiology",
         "Physiology; Sport Sciences",
         "Medicine, General & Internal",
         "Public, Environmental & Occupational Health",
         "Toxicology; Pharmacology & Pharmacy"),
  quartile = c("Q2", "Q1", "Q1", "Q3", "Q2", "Q3", "Q2", "Q4", "Q2", NA),
  publisher = c("Example Medical Press", "Invented Science Publishers",
                "Example Medical Press", "Invented Science Publishers",
                "Example Medical Press", "Invented Science Publishers",
                "Example Medical Press", "Beispiel Fachverlag",
                "Invented Science Publishers", "Open Example Press"),
  publisher_country = c("US", "NL", "US", "NL", "US", "NL", "US", "DE",
                        "NL", "GB"),
  is_oa = c(FALSE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE,
            TRUE),
  stringsAsFactors = FALSE
)
journals$issn <- issn_with_check(sprintf("9999%03d", 1:10))
journals$eissn <- issn_with_check(sprintf("9998%03d", 1:10))
journals$source_id <- sprintf("S%09d", 1:10)

# WoS research areas (SC) for the WoS categories (WC) used above.
sc_of_wc <- c(
  "Medicine, General & Internal" = "General & Internal Medicine",
  "Infectious Diseases" = "Infectious Diseases",
  "Microbiology" = "Microbiology",
  "Surgery" = "Surgery",
  "Public, Environmental & Occupational Health" =
    "Public, Environmental & Occupational Health",
  "Emergency Medicine" = "Emergency Medicine",
  "Physiology" = "Physiology",
  "Sport Sciences" = "Sport Sciences",
  "Toxicology" = "Toxicology",
  "Pharmacology & Pharmacy" = "Pharmacology & Pharmacy"
)

theme_journals <- list(
  `0` = c(jexm = 0.4, oetx = 0.3, zbsm = 0.3),
  `1` = c(eidr = 0.35, fepl = 0.25, afmi = 0.25, ejph = 0.15),
  `2` = c(asur = 0.35, ijtc = 0.4, jexm = 0.25),
  `3` = c(tpem = 0.45, jexm = 0.25, ejph = 0.3)
)

# ---- people ----------------------------------------------------------------

first_de <- c("Anna", "Jonas", "Lea", "Felix", "Marie", "Lukas", "Hannah",
              "Moritz", "Clara", "Jan", "Sophie", "Tobias", "Lena",
              "Niklas", "Julia", "Paul", "Katrin", "Stefan", "Miriam",
              "Florian", "Svenja", "Henrik", "Carla", "Matthias", "Ines",
              "Robert", "Nora", "Dominik", "Ute", "Bernd")
first_int <- c("Grace", "Daniel", "Amara", "Pieter", "Sanne", "Ingrid",
               "Eirik", "Chiara", "Luca", "Olivia", "Ethan", "Priya",
               "Tomasz", "Yusuf", "Mei", "Oscar", "Leah", "Victor",
               "Helen", "Samuel")
surnames <- c(
  "Achterberg", "Brennecke", "Dorfmeister", "Eichhorn", "Falkenrath",
  "Gutknecht", "Hollerbach", "Ilgner", "Jankowski", "Kesselring",
  "Lindemann", "Morgenroth", "Nachtigall", "Oberle", "Pfannkuch",
  "Quernheim", "Rautenberg", "Sandkuhl", "Tiedemann", "Ulbrich",
  "Vogelsang", "Wendland", "Zeidler", "Ackermann", "Biermann", "Classen",
  "Dreyer", "Engelke", "Feldhaus", "Gerlach", "Hagedorn", "Imhoff",
  "Jasper", "Kahlert", "Lutterbeck", "Mertens", "Nolting", "Ostendorf",
  "Pieper", "Reinholz", "Schoppe", "Thielemann", "Uhlig", "Vahrenkamp",
  "Westphal", "Zirngibl", "Bockholt", "Dittmer", "Eggert", "Fromm",
  "Grabowski", "Hessling", "Okafor", "Haddad", "Lindqvist", "Moreau",
  "Kowalczyk", "Brennan", "Castellano", "Nakamura", "Petrovic",
  "Andersen", "Whitfield", "Carver", "Duarte", "Eriksen", "Fitzgerald",
  "Gallagher", "Hoekstra", "Iversen", "Jovanovic", "Kaminski", "Lombardi",
  "Nyberg", "Osei", "Pereira", "Quist", "Rasmussen", "Sorensen",
  "Takahashi", "Underwood", "Valdez", "Wojcik"
)

person_counts <- c(
  hosp_trauma = 6L, hosp_intmed = 5L, hosp_anes = 4L, hosp_emerg = 5L,
  afim_main = 6L, afim_virol = 4L, afim_bact = 3L, afim_field = 1L,
  zis_hyg = 5L, zis_lab = 4L, zis_occ = 3L, other_medoff = 3L,
  other_cmd = 3L, un_clinchem = 3L, un_microbiol = 3L, sms_infect = 4L,
  nuh_derm = 3L, lake_epi = 4L, hill_surg = 4L, fjord_med = 3L,
  alp_inf = 3L, river_ph = 4L
)

seed_block(1L)
people <- data.frame(
  home = rep(names(person_counts), person_counts),
  stringsAsFactors = FALSE
)
people$author_id <- sprintf("A%09d", seq_len(nrow(people)))
people$surname <- surnames[seq_len(nrow(people))]
german_home <- affiliations$country_code[match(people$home,
                                               affiliations$key)] == "DE"
people$given <- ifelse(
  german_home,
  draw(first_de, nrow(people), replace = TRUE),
  draw(first_int, nrow(people), replace = TRUE)
)
people$unit <- affiliations$unit[match(people$home, affiliations$key)]
people$themes <- affiliations$themes[match(people$home, affiliations$key)]
# Joint appointments: these authors list a university address as well.
people$second <- NA_character_
people$second[people$home == "hosp_trauma"][1:3] <- "un_trauma"
people$second[people$home == "afim_virol"][1:2] <- "un_microbiol"
people$second[people$home == "afim_main"][1] <- "un_microbiol"
people$second[people$home == "zis_lab"][1:2] <- "un_clinchem"
people$short <- paste0(people$surname, ", ", substr(people$given, 1L, 1L))
people$full <- paste0(people$surname, ", ", people$given)
people$cr_name <- paste0(people$surname, " ", substr(people$given, 1L, 1L))

authors <- tibble::tibble(
  author_id = people$author_id,
  orcid = NA_character_,
  display_name = paste(people$given, people$surname),
  display_name_alternatives = lapply(seq_len(nrow(people)), function(i) {
    c(people$short[i], people$full[i])
  }),
  inferred_gender = NA_character_,
  gender_confidence = NA_real_,
  gender_method = NA_character_
)

# ---- works: years, themes, types, languages, journals ----------------------

years <- rep(2016:2026, times = c(1L, 2L, 8L, 12L, 15L, 18L, 20L, 22L, 22L,
                                  20L, 10L))
n_works <- length(years)

seed_block(2L)
theme <- integer(n_works)
theme[years == 2016L] <- 1L
theme[years == 2017L] <- c(2L, 3L)
later <- which(years >= 2018L)
theme[later] <- draw(rep(1:3, times = c(57L, 57L, 33L)), length(later))
misc <- sort(draw(which(years >= 2018L), 10L))
theme[misc] <- 0L

type <- rep("Article", n_works)
type[misc] <- rep(c("Editorial Material", "Letter"), each = 5L)
themed <- setdiff(seq_len(n_works), c(misc, which(years <= 2017L)))
other_types <- draw(themed, 28L)
type[other_types] <- c(rep("Review", 25L), "Editorial Material",
                       "Editorial Material", "Letter")

german <- sort(draw(setdiff(seq_len(n_works), which(years <= 2017L)), 22L))
language <- ifelse(seq_len(n_works) %in% german, "German", "English")

journal <- vapply(seq_len(n_works), function(i) {
  if (i %in% german && stats::runif(1) < 0.7) return("zbsm")
  w <- theme_journals[[as.character(theme[i])]]
  draw(names(w), 1L, prob = unname(w))
}, character(1))
jrow <- match(journal, journals$key)

doi_seq <- stats::ave(seq_len(n_works), journal, years, FUN = seq_along)
doi <- sprintf("10.9999/%s.%d.%03d", journal, years, doi_seq)
no_doi_pool <- misc[journal[misc] %in% c("zbsm", "oetx")]
if (length(no_doi_pool) < 3L) no_doi_pool <- misc
no_doi <- draw(no_doi_pool, 3L)
doi[no_doi] <- NA_character_

volume <- as.character(years - 2010L + jrow)
first_page <- as.character(draw(1:900, n_works, replace = TRUE))

seed_block(3L)
cited_by_count <- as.integer(stats::rnbinom(
  n_works, mu = 1.6 * (2026 - years) + 0.4, size = 0.9
))
cited_by_count[years == 2016L] <- max(cited_by_count[years == 2016L], 7L)
fwci <- round(stats::rlnorm(n_works, meanlog = -0.15, sdlog = 0.75), 2)
fwci[draw(seq_len(n_works), 12L)] <- NA_real_
fwci[is.na(doi)] <- NA_real_
quartile <- journals$quartile[jrow]
quartile[years == 2026L] <- NA_character_
wc <- journals$wc[jrow]
field <- sub(";.*$", "", wc)

# ---- titles and abstracts --------------------------------------------------

# Every title names its own invented site (most also a sample size), as real
# titles carry study-specific detail; without it the term overlap between
# time windows would be unrealistically high.
site_pool <- as.vector(outer(
  c("Ash", "Birch", "Bracken", "Cold", "Elm", "Fern", "Glen", "Hazel",
    "Iron", "Juniper", "Kestrel", "Lark", "Marrow", "Nettle", "Oak", "Pine",
    "Rush", "Sedge", "Thorn", "Wych"),
  c("brook", "combe", "dale", "field", "ford", "gate", "holt", "hurst",
    "leigh", "mere", "moor", "ridge", "stead", "ton", "wick", "wold",
    "worth", "bury", "by", "hollow"),
  paste0
))
populations <- c("soldiers", "recruits", "field personnel", "reservists",
                 "military trainees", "deployed staff", "combat engineers",
                 "medical officers", "infantry units", "naval personnel")
populations_de <- c("Soldaten", "Rekruten", "Reservisten",
                    "Einsatzkr\u00e4ften", "Auszubildenden")
designs <- c("cohort study", "cross-sectional survey", "case series",
             "nested case-control study", "retrospective analysis",
             "prospective study", "registry study", "surveillance report")
seasons <- c("spring", "summer", "autumn", "winter")
seasons_de <- c("Fr\u00fchjahr", "Sommer", "Herbst", "Winter")

title_templates <- list(
  `1` = c("{a} at the {site} training area, {y1}-{y2}",
          "{b}: {n} samples from {site}",
          "{a} and {c} near {site}",
          "{b} and {a} in {n} {pop} at {site}",
          "{c} in {site}: {n} cases, {y1}-{y2}"),
  `2` = c("{a} at {site}: {n} casualties, {y1}-{y2}",
          "{b} and {c} in {n} patients at {site}",
          "{a} after {b}: {n} cases from {site}",
          "{c} following {a} at {site}",
          "{b} in {n} {pop}, {site} registry"),
  `3` = c("{a} during summer training at {site}",
          "{b} and {c} in {n} {pop} at {site}",
          "{a} on a road march near {site}: {n} cases",
          "{c} after {a} at {site}, {y1}-{y2}",
          "{b} against {a} in {n} {pop}, {site}"),
  `0` = c("{a} at {site}: an editorial",
          "reply to the comments on {b} at {site}",
          "{a} after the pandemic: {n} units at {site}",
          "{b} at {site} needs better evidence")
)
# Slot phrases drift over time: works from 2023 on mostly draw from the second
# half of each pool, earlier works from the first half.
title_slots <- list(
  `1` = list(
    a = c("orthohantavirus infection", "orthohantavirus seroconversion",
          "nephropathia epidemica", "rodent-borne zoonoses",
          "hantavirus exposure", "febrile renal syndrome"),
    b = c("rodent reservoir density", "bank vole abundance",
          "zoonotic surveillance", "field serology",
          "molecular typing of rodent isolates", "vector ecology mapping",
          "habitat suitability modelling", "trapping campaigns",
          "climate covariates", "laboratory screening"),
    c = c("human exposure", "case clustering", "seasonal risk",
          "occupational risk", "outbreak detection", "beech mast years",
          "storage depots", "forest camps", "renal outcomes",
          "spillover events")
  ),
  `2` = list(
    a = c("hemorrhage control", "junctional bleeding control",
          "damage control resuscitation", "massive transfusion",
          "tourniquet use", "whole blood transfusion"),
    b = c("early tourniquet application", "prehospital whole blood",
          "pelvic binder use", "hemostatic dressing use",
          "tactical field care", "rapid evacuation",
          "point-of-care coagulation testing", "fresh frozen plasma",
          "fibrinogen concentrate", "trauma team activation"),
    c = c("survival", "blood product use", "limb salvage",
          "time to surgery", "preventable death", "complication rates",
          "intensive care stay", "transfusion volume", "nerve injury",
          "readmission")
  ),
  `3` = list(
    a = c("exertional heat illness", "exertional heat stroke",
          "heat exhaustion", "hyperthermia", "heat injury",
          "thermal strain"),
    b = c("heat acclimatization", "core temperature monitoring",
          "active cooling", "work-rest cycles",
          "wet bulb globe temperature guidance", "fluid replacement",
          "cold water immersion", "sleep restriction", "body armour load",
          "aerobic fitness screening"),
    c = c("collapse rates", "time to recovery", "training attrition",
          "renal injury", "physiological strain", "medical evacuation",
          "rhabdomyolysis", "sodium balance", "cognitive performance",
          "return to duty")
  ),
  `0` = list(
    a = c("operational medicine", "medical education",
          "deployment health", "clinical governance",
          "health services research", "reserve medical services",
          "military nursing", "disaster preparedness"),
    b = c("field hospital staffing", "simulation-based training",
          "medical readiness", "data sharing in health care",
          "guideline adoption", "peer review", "open access publishing",
          "career pathways")
  )
)
title_templates_de <- list(
  `1` = c("Orthohantavirus-Infektionen bei {n} {pop} im Raum {site}",
          "Nagetierdichte und Serokonversion bei {n} {pop} in {site}"),
  `2` = c(paste0("Blutungskontrolle in der pr\u00e4klinischen Versorgung: ",
                 "{n} Verwundete aus {site}"),
          "Tourniquet-Anlage und \u00dcberleben bei {n} Verwundeten in {site}"),
  `3` = c(paste0("Hitzeerkrankungen bei {n} {pop} w\u00e4hrend der ",
                 "Ausbildung in {site}"),
          "K\u00fchlung und Hitzeakklimatisation bei {n} {pop} in {site}"),
  `0` = c("Aufgaben der medizinischen Ausbildung in {site}: ein Kommentar",
          "Antwort auf die Kommentare zu unserer Arbeit \u00fcber {site}")
)

sentences <- list(
  `1` = c(
    paste0("We tested {n} rodents trapped at {k} sites around {site} for ",
           "orthohantavirus antibodies."),
    "Seroconversion occurred in {p} percent of {pop} after field exercises.",
    "Bank vole density peaked in {season} and preceded human cases.",
    "Field serology was combined with molecular typing of lung samples.",
    "Exposure was highest near forest edges, storage sheds and bivouacs.",
    "Dust from nests in unused buildings was the likely source.",
    "Most infections caused fever, back pain and transient renal impairment.",
    "Beech mast years were followed by rodent outbreaks and case clusters.",
    "Sequencing placed the strains in a lineage circulating in the region.",
    "Hygiene briefings and rodent control reduced new infections.",
    "Reported cases underestimated the burden of mild infections.",
    "Surveillance data from {k} seasons were linked with weather records."
  ),
  `2` = c(
    "We analysed {n} casualties recorded in the {site} trauma registry.",
    "Early tourniquet application was associated with lower mortality.",
    "Prehospital intervals shortened after whole blood became available.",
    "Damage control resuscitation was completed in {p} percent of patients.",
    "Junctional bleeding remained the leading cause of preventable death.",
    "Hemorrhage control training improved skills among {pop}.",
    "Pelvic binders were applied in {p} percent of pelvic fractures.",
    "Limb ischaemia did not increase when tourniquets were converted early.",
    "Massive transfusion protocols were activated {k} times.",
    "Point-of-care coagulation testing guided blood product use.",
    "Helicopter evacuation reduced time to surgery by {m} minutes.",
    "Fluid restriction before surgery was not associated with harm."
  ),
  `3` = c(
    paste0("Core body temperature was recorded in {n} {pop} during a ",
           "{k}-day march near {site}."),
    "Acclimatization over {k} days lowered the incidence of illness.",
    "Active cooling restored normal thermoregulation within {m} minutes.",
    "Training load and wet bulb globe readings predicted collapse.",
    "Hydration status did not differ between affected and unaffected {pop}.",
    "Exertional heat illness occurred on {p} percent of training days.",
    "Cold water immersion was the fastest cooling method in the field.",
    "A recent viral infection increased the risk of collapse.",
    "Ingestible sensors were tolerated well during marches.",
    "Work-rest cycles adapted to ambient conditions prevented most cases.",
    "Return to duty after heat stroke took a median of {k} weeks.",
    "Low aerobic fitness was associated with injury.",
    "Serum creatine kinase peaked one day after the event.",
    "Sweat sodium losses varied widely between individuals.",
    "Night-time exercises reduced cumulative thermal load.",
    "Body armour added a substantial metabolic burden.",
    "Sleep restriction impaired vigilance on hot afternoons.",
    "Medical staff recognised early symptoms in most instances.",
    "Ambient humidity mattered more than air temperature.",
    "Prior episodes predicted recurrence within the same season."
  ),
  `0` = c(
    "This editorial discusses research priorities for operational medicine.",
    paste0("Recent work on exertional heat illness, hemorrhage control and ",
           "orthohantavirus surveillance shows how field data improve care."),
    "We comment on recent clinical guidelines and their use in training.",
    "Medical education has to adapt to new operational requirements.",
    "The authors reply to the comments on their earlier article.",
    "Data sharing between military and civilian hospitals remains limited.",
    "Simulation-based training can close gaps in clinical experience.",
    "Readiness depends on staff, equipment and regular exercises."
  )
)
sentences_de <- list(
  `1` = c(
    paste0("Wir untersuchten {n} Nagetiere aus {k} Fanggebieten auf ",
           "Antik\u00f6rper gegen Orthohantaviren."),
    paste0("Die Serokonversion bei den {pop} lag nach den ",
           "Feld\u00fcbungen bei {p} Prozent."),
    paste0("Die Dichte der R\u00f6telmaus stieg im {season} an und ging ",
           "den F\u00e4llen voraus."),
    paste0("Die meisten Infektionen verliefen mit Fieber und einer ",
           "vor\u00fcbergehenden Nierenfunktionsst\u00f6rung."),
    paste0("Hygieneschulungen und die Bek\u00e4mpfung der Nagetiere ",
           "senkten die Zahl der Neuinfektionen.")
  ),
  `2` = c(
    "Wir analysierten {n} Verwundete aus dem Traumaregister in {site}.",
    paste0("Die fr\u00fche Anlage eines Tourniquets war mit einer ",
           "geringeren Sterblichkeit verbunden."),
    paste0("Die pr\u00e4klinische Versorgung und die Blutungskontrolle ",
           "wurden durch Schulungen verbessert."),
    paste0("Vollblut am Einsatzort verk\u00fcrzte die Zeit bis zur ",
           "Operation um {m} Minuten."),
    "Die Massivtransfusion wurde in {p} Prozent der F\u00e4lle ausgel\u00f6st."
  ),
  `3` = c(
    paste0("Die K\u00f6rperkerntemperatur wurde bei {n} Rekruten ",
           "w\u00e4hrend eines Marsches gemessen."),
    paste0("Die Hitzeakklimatisation \u00fcber {k} Tage senkte die Rate ",
           "der Hitzeerkrankungen."),
    paste0("Aktive K\u00fchlung und ausreichende Fl\u00fcssigkeitszufuhr ",
           "verhinderten schwere Verl\u00e4ufe."),
    "Die Belastung und die Umgebungstemperatur sagten die Erkrankung voraus.",
    "Die R\u00fcckkehr in die Ausbildung dauerte im Median {k} Wochen."
  ),
  `0` = c(
    paste0("Der Beitrag diskutiert die Ausbildung und die Forschung im ",
           "Sanit\u00e4tsdienst."),
    "Die Autoren antworten auf die Kommentare zu ihrem Artikel.",
    paste0("Die Zusammenarbeit mit zivilen Kliniken und die ",
           "Digitalisierung bleiben wichtige Aufgaben.")
  )
)

seed_block(4L)
sites <- draw(site_pool, n_works)
work_slots <- lapply(seq_len(n_works), function(i) {
  y1 <- years[i] - draw(3:6, 1L)
  list(site = sites[i], n = as.character(draw(60:2400, 1L)),
       k = as.character(draw(2:14, 1L)), p = as.character(draw(2:60, 1L)),
       m = as.character(draw(5:90, 1L)), y1 = as.character(y1),
       y2 = as.character(years[i] - 1L), design = draw(designs, 1L),
       pop = if (language[i] == "German") {
         draw(populations_de, 1L)
       } else {
         draw(populations, 1L)
       },
       season = if (language[i] == "German") {
         draw(seasons_de, 1L)
       } else {
         draw(seasons, 1L)
       })
})

title <- vapply(seq_len(n_works), function(i) {
  key <- as.character(theme[i])
  if (language[i] == "German") {
    return(fill_slots(draw(title_templates_de[[key]], 1L), work_slots[[i]]))
  }
  slots <- c(work_slots[[i]], lapply(title_slots[[key]], pick_slot,
                                     late = years[i] >= 2023L))
  cap_first(fill_slots(draw(title_templates[[key]], 1L), slots))
}, character(1))
dup <- duplicated(title)
title[dup] <- paste0(title[dup], ": a second report")

abstract <- vapply(seq_len(n_works), function(i) {
  key <- as.character(theme[i])
  pool <- if (language[i] == "German") {
    sentences_de[[key]]
  } else {
    sentences[[key]]
  }
  k <- if (theme[i] == 0L) 2L else min(length(pool), 3L)
  paste(fill_slots(draw(pool, k), work_slots[[i]]), collapse = " ")
}, character(1))
abstract[draw(misc, 4L)] <- NA_character_

# One heat-theme article repeats an invented token 15 times.
planted <- draw(which(theme == 3L & language == "English" &
                        type == "Article" & years >= 2019L), 1L)
abstract[planted] <- paste(
  abstract[planted],
  paste0("Quillotyrase levels, quillotyrase kinetics and quillotyrase ",
         "clearance were measured on day ", 1:5, ".", collapse = " ")
)

work_id <- sprintf("WOS:0009999%08d", seq_len(n_works))

works <- tibble::tibble(
  work_id = work_id,
  doi = doi,
  title = title,
  abstract = abstract,
  year = years,
  type = type,
  source_id = journals$source_id[jrow],
  cited_by_count = cited_by_count,
  oa_status = NA_character_,
  language = language,
  pmid = NA_character_,
  arxiv_id = NA_character_,
  openalex_id = NA_character_,
  is_retracted = FALSE,
  retraction_date = as.Date(NA),
  last_refreshed = refresh_time,
  quartile = quartile,
  fwci = fwci,
  field = field,
  volume = volume,
  first_page = first_page
)

sources <- tibble::tibble(
  source_id = journals$source_id,
  issn_l = journals$issn,
  issn = lapply(seq_len(nrow(journals)), function(i) {
    c(journals$issn[i], journals$eissn[i])
  }),
  display_name = journals$so,
  type = "journal",
  is_oa = journals$is_oa,
  publisher = journals$publisher,
  publisher_country = journals$publisher_country,
  abbreviation = journals$j9,
  iso_abbreviation = journals$ji
)

# ---- authorships -----------------------------------------------------------

lead_units <- list(
  `0` = c(hospital = 0.4, microbiology = 0.2, zis = 0.25, other = 0.15),
  `1` = c(microbiology = 0.5, zis = 0.35, other = 0.15),
  `2` = c(hospital = 0.85, other = 0.15),
  `3` = c(hospital = 0.45, zis = 0.45, other = 0.1)
)
is_military <- !is.na(people$unit)

theme_people <- function(t, military) {
  ok <- is_military == military
  if (t > 0L) ok <- ok & grepl(as.character(t), people$themes, fixed = TRUE)
  which(ok)
}

seed_block(5L)
# 60 of the 150 works (40%) get a civilian corresponding author at position
# 2 or later.
corr_kind <- draw(rep(c("partner", "first", "last"),
                      times = c(60L, 68L, 22L)), n_works)
author_lists <- lapply(seq_len(n_works), function(i) {
  t <- theme[i]
  w <- lead_units[[as.character(t)]]
  unit <- draw(names(w), 1L, prob = unname(w))
  n_auth <- if (t == 0L) {
    draw(2:3, 1L)
  } else {
    draw(2:8, 1L, prob = c(0.1, 0.18, 0.22, 0.2, 0.14, 0.1, 0.06))
  }
  lead_pool <- which(people$unit %in% unit)
  first <- if (stats::runif(1) < 0.88) {
    draw(lead_pool, 1L)
  } else {
    draw(theme_people(t, FALSE), 1L)
  }
  ids <- first
  while (length(ids) < n_auth) {
    pool <- if (stats::runif(1) < 0.55) {
      if (stats::runif(1) < 0.7) lead_pool else theme_people(t, TRUE)
    } else {
      theme_people(t, FALSE)
    }
    pool <- setdiff(pool, ids)
    if (length(pool) > 0L) ids <- c(ids, draw(pool, 1L))
  }
  # a civilian corresponding author must sit at position 2 or later
  if (corr_kind[i] == "partner" && all(is_military[ids[-1L]])) {
    ids[length(ids)] <- draw(setdiff(theme_people(t, FALSE), ids), 1L)
  }
  # every work has a unit author
  if (!any(is_military[ids])) {
    ids[1L] <- draw(setdiff(lead_pool, ids), 1L)
  }
  after_first <- seq_along(ids) > 1L
  partners_later <- which(!is_military[ids] & after_first)
  military_later <- which(is_military[ids] & after_first)
  corr <- switch(corr_kind[i],
    partner = partners_later[draw(seq_along(partners_later), 1L)],
    first = 1L,
    last = if (length(military_later) > 0L) max(military_later) else 1L
  )
  list(ids = ids, corr = corr)
})

authorships <- do.call(rbind, lapply(seq_len(n_works), function(i) {
  ids <- author_lists[[i]]$ids
  rows <- lapply(seq_along(ids), function(pos) {
    p <- ids[pos]
    keys <- c(people$home[p], stats::na.omit(people$second[p]))
    data.frame(
      work_id = work_id[i],
      author_id = people$author_id[p],
      position = pos,
      is_corresponding = pos == author_lists[[i]]$corr,
      raw_affiliation = affiliations$c1[match(keys, affiliations$key)],
      country_code = affiliations$country_code[match(keys,
                                                     affiliations$key)],
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}))
rownames(authorships) <- NULL

# ---- the Web of Science twin: ten records ----------------------------------

corr_position <- vapply(author_lists, function(x) x$corr, integer(1))
twin_ok <- language == "English" & !is.na(doi) & theme > 0L &
  type %in% c("Article", "Review") & years >= 2018L & years <= 2025L &
  seq_len(n_works) != planted
seed_block(6L)
twin <- sort(c(draw(which(twin_ok & corr_position > 1L), 4L),
               draw(which(twin_ok & corr_position == 1L), 6L)))
twin_no_rp <- draw(twin[corr_position[twin] == 1L], 1L)

# ---- German address rows ---------------------------------------------------

seed_block(7L)
single <- !duplicated(authorships[, c("work_id", "author_id")]) &
  !duplicated(authorships[, c("work_id", "author_id")], fromLast = TRUE)
home_key <- people$home[match(authorships$author_id, people$author_id)]
candidate_rows <- function(keys, exclude_works) {
  which(single & home_key %in% keys &
          !authorships$work_id %in% c(work_id[twin], exclude_works))
}
used_works <- character()
for (j in seq_len(nrow(german_rows))) {
  keys <- switch(german_rows$target[j],
    zis = c("zis_hyg", "zis_lab", "zis_occ"),
    microbiology = c("afim_main", "afim_virol", "afim_bact"),
    hospital = if (grepl("Sektion", german_rows$text[j], fixed = TRUE)) {
      "hosp_trauma"
    } else {
      c("hosp_trauma", "hosp_intmed", "hosp_anes", "hosp_emerg")
    },
    nuh = "nuh_derm"
  )
  row <- draw(candidate_rows(keys, used_works), 1L)
  authorships$raw_affiliation[row] <- german_rows$text[j]
  used_works <- c(used_works, authorships$work_id[row])
}

# ---- references ------------------------------------------------------------

ext_surnames <- c(
  "Abbott", "Barlow", "Chandler", "Delgado", "Ellison", "Forsyth", "Greer",
  "Holloway", "Ingram", "Jarvis", "Kendrick", "Lowell", "Mercer",
  "Norwood", "Oakley", "Prescott", "Quigley", "Ramsey", "Sutton",
  "Thornton", "Upton", "Vance", "Whitaker", "Yates", "Albrecht", "Bauer",
  "Conrad", "Dahl", "Ebert", "Fuchs", "Graf", "Hahn", "Jung", "Kraft",
  "Lorenz", "Maier", "Nowak", "Otto", "Peters", "Roth", "Sauer", "Thiel",
  "Voss", "Wagner", "Ziegler", "Barros", "Costa", "Dias", "Ferreira",
  "Gomes", "Lopes", "Moura", "Nunes", "Pinto", "Ramos", "Silva"
)
ext_journals <- c(
  "J EXT MED RES", "ARCH INVENT PATHOL", "EUR J SAMPLE INFECT",
  "CLIN EX SURG", "PREHOSP CARE REV", "J THERM BIOL EX",
  "VECTOR ZOONOT EX", "EX EPIDEMIOL INFECT", "TRANSFUS EX MED",
  "SPORT MED EX", "WILDERNESS EX MED", "J SYNTH VIROL", "INJURY EX",
  "EX CRIT CARE", "J APPL PHYSIOL EX", "EX PUBLIC HEALTH REV",
  "ZOONOSES EX", "BEISPIEL ARCH HYG", "J INVENT EMERG MED",
  "EX MIL HLTH REP"
)

seed_block(8L)
n_ext <- 520L
ext_refs <- data.frame(
  group = rep(0:3, times = c(100L, 140L, 140L, 140L)),
  year = draw(1990:2025, n_ext, replace = TRUE),
  author = paste(draw(ext_surnames, n_ext, replace = TRUE),
                 draw(LETTERS[c(1:9, 11:20)], n_ext, replace = TRUE)),
  journal = draw(ext_journals, n_ext, replace = TRUE),
  volume = draw(1:60, n_ext, replace = TRUE),
  page = draw(1:999, n_ext, replace = TRUE),
  stringsAsFactors = FALSE
)
ext_refs$doi <- ifelse(stats::runif(n_ext) < 0.7,
                       sprintf("10.9999/ext.%05d", seq_len(n_ext)),
                       NA_character_)
ext_refs$cr <- paste0(ext_refs$author, ", ", ext_refs$year, ", ",
                      ext_refs$journal, ", V", ext_refs$volume, ", P",
                      ext_refs$page,
                      ifelse(is.na(ext_refs$doi), "",
                             paste0(", DOI ", ext_refs$doi)))

first_author_cr <- vapply(author_lists, function(x) {
  people$cr_name[x$ids[1L]]
}, character(1))
local_cr <- paste0(first_author_cr, ", ", years, ", ", journals$j9[jrow],
                   ", V", volume, ", P", first_page, ", DOI ", doi)

seed_block(9L)
ref_lists <- lapply(seq_len(n_works), function(i) {
  n_ref <- switch(type[i],
    Article = draw(8:20, 1L),
    Review = draw(20:35, 1L),
    `Editorial Material` = draw(0:4, 1L),
    Letter = draw(1:5, 1L)
  )
  earlier <- which(years < years[i] & !is.na(doi))
  same <- earlier[theme[earlier] == theme[i]]
  n_local <- min(length(earlier), draw(0:3, 1L))
  local <- if (n_local > 0L && length(same) >= n_local &&
                 stats::runif(1) < 0.7) {
    draw(same, n_local)
  } else if (n_local > 0L) {
    draw(earlier, n_local)
  } else {
    integer()
  }
  if (i %in% twin) {
    earlier_twin <- twin[years[twin] < years[i]]
    if (length(earlier_twin) > 0L && !any(local %in% earlier_twin)) {
      local <- c(local, draw(earlier_twin, 1L))
    }
  }
  pool <- which(ext_refs$year <= years[i] &
                  ext_refs$group %in% c(0L, theme[i]))
  ext <- draw(pool, max(0L, n_ref - length(local)))
  list(local = local, ext = ext)
})

references <- do.call(rbind, lapply(seq_len(n_works), function(i) {
  x <- ref_lists[[i]]
  cr <- c(local_cr[x$local], ext_refs$cr[x$ext])
  if (length(cr) == 0L) return(NULL)
  ord <- order(c(years[x$local], ext_refs$year[x$ext]), cr,
               method = "radix")
  data.frame(
    work_id = work_id[i],
    ref_index = seq_along(cr),
    cited_work_id = NA_character_,
    cited_doi = c(doi[x$local], ext_refs$doi[x$ext])[ord],
    cited_raw = cr[ord],
    stringsAsFactors = FALSE
  )
}))
rownames(references) <- NULL

# ---- concepts --------------------------------------------------------------

keyword_pools <- list(
  `1` = c("rodent reservoir", "zoonotic surveillance", "field epidemiology",
          "seroconversion", "vector ecology", "nephropathia epidemica",
          "bank vole", "molecular typing"),
  `2` = c("tourniquet", "prehospital care", "damage control resuscitation",
          "whole blood", "trauma registry", "junctional bleeding",
          "tactical medicine", "massive transfusion"),
  `3` = c("heat acclimatization", "core body temperature",
          "thermoregulation", "physical training", "active cooling",
          "hydration", "wet bulb globe temperature", "recruits"),
  `0` = c("medical education", "health policy", "clinical guidelines",
          "research priorities", "workforce", "ethics")
)
anchors <- c(`1` = "orthohantavirus", `2` = "hemorrhage control",
             `3` = "exertional heat illness")
plus_pools <- list(
  `1` = c("INFECTION", "EPIDEMIOLOGY", "VIRUS", "TRANSMISSION", "RODENTS",
          "EUROPE", "ANTIBODIES"),
  `2` = c("MORTALITY", "TRAUMA", "RESUSCITATION", "MANAGEMENT", "INJURY",
          "TRANSFUSION", "OUTCOMES"),
  `3` = c("EXERCISE", "TEMPERATURE", "HYPERTHERMIA", "PERFORMANCE",
          "HEAT-STRESS", "HUMANS", "DEHYDRATION"),
  `0` = c("CARE", "EDUCATION", "HEALTH")
)

seed_block(10L)
keywords_de <- lapply(seq_len(n_works), function(i) {
  key <- as.character(theme[i])
  if (theme[i] == 0L) return(draw(keyword_pools[[key]], draw(2:3, 1L)))
  c(anchors[[key]], draw(keyword_pools[[key]], draw(2:3, 1L)))
})
keywords_id <- lapply(seq_len(n_works), function(i) {
  pool <- plus_pools[[as.character(theme[i])]]
  draw(pool, min(length(pool), draw(2:4, 1L)))
})
wc_list <- strsplit(wc, "; ", fixed = TRUE)
sc_list <- lapply(wc_list, function(x) unique(unname(sc_of_wc[x])))

concepts <- do.call(rbind, lapply(seq_len(n_works), function(i) {
  terms <- c(keywords_de[[i]], keywords_id[[i]], sc_list[[i]], wc_list[[i]])
  vocab <- rep(c("author-keywords", "keywords-plus", "wos-subject-category",
                 "wos-category"),
               times = c(length(keywords_de[[i]]), length(keywords_id[[i]]),
                         length(sc_list[[i]]), length(wc_list[[i]])))
  data.frame(work_id = work_id[i], concept_id = NA_character_,
             concept_name = terms, level = NA_integer_, score = NA_real_,
             vocabulary = vocab, stringsAsFactors = FALSE)
}))
rownames(concepts) <- NULL

# ---- provenance ------------------------------------------------------------

seed_block(11L)
no_provenance <- draw(setdiff(seq_len(n_works), twin), 2L)
with_prov <- setdiff(seq_len(n_works), no_provenance)
provenance <- tibble::tibble(
  work_id = work_id[with_prov],
  source = "wos",
  source_id_external = work_id[with_prov],
  fetch_date = refresh_time,
  query = "synthetic Web of Science export",
  engine = "native",
  scimapR_version = "0.5.0",
  prompt_hash = NA_character_
)

# ---- yearly citation counts -------------------------------------------------

seed_block(13L)
counts_as_of <- as.Date("2026-10-17")
horizon <- seq.int(2017L, 2026L)
enriched <- which(!is.na(doi))
citations_by_year <- do.call(rbind, lapply(enriched, function(i) {
  span <- seq.int(years[i], 2026L)
  age <- span - years[i]
  weight <- (age + 1) * exp(-age / 2.5)
  n <- as.vector(stats::rmultinom(1L, cited_by_count[i], weight))
  keep <- span %in% horizon & n > 0L
  data.frame(work_id = rep(work_id[i], sum(keep)), year = span[keep],
             cited_by_count = as.integer(n[keep]), stringsAsFactors = FALSE)
}))
rownames(citations_by_year) <- NULL
works$citations_as_of <- rep(counts_as_of, n_works)
works$citations_as_of[is.na(doi)] <- as.Date(NA)

# ---- build the corpus ------------------------------------------------------

corpus <- suppressMessages(scimapR::sm_corpus_from_tables(
  list(works = works, authors = authors, authorships = authorships,
       sources = sources, references = references, concepts = concepts,
       provenance = provenance, citations_by_year = citations_by_year),
  metadata = list(
    scimapR_version = "0.5.0",
    build_date = as.POSIXct("2026-01-01", tz = "UTC"),
    last_refresh = refresh_epoch,
    corpus_hash = NA_character_
  )
))

# ---- reference list (tracker) ----------------------------------------------

military_rows <- authorships[!is.na(people$unit[match(authorships$author_id,
                                                      people$author_id)]), ]
reporting_unit <- vapply(work_id, function(w) {
  r <- military_rows[military_rows$work_id == w, ]
  r <- r[order(r$position), ]
  unit_names[[people$unit[match(r$author_id[1L], people$author_id)]]]
}, character(1), USE.NAMES = FALSE)
category_of_type <- c(Article = "cat-1", Review = "cat-2",
                      `Editorial Material` = "cat-3", Letter = "cat-3")

seed_block(12L)
in_reference <- sort(c(draw(which(!is.na(doi)), 118L),
                       draw(which(is.na(doi)), 2L)))
ref_doi <- doi[in_reference]
prefixed <- draw(which(!is.na(ref_doi)), 5L)
ref_doi[prefixed] <- paste0("https://doi.org/", ref_doi[prefixed])
reported <- data.frame(
  doi = ref_doi,
  title = title[in_reference],
  year = years[in_reference],
  institution = reporting_unit[in_reference],
  category = unname(category_of_type[type[in_reference]]),
  stringsAsFactors = FALSE
)

topics <- c("hand hygiene compliance", "vaccination uptake",
            "first aid refresher courses", "noise-induced hearing loss",
            "sleep deprivation", "dental readiness",
            "mental health screening", "telemedicine pilots",
            "blood supply logistics", "deployment fitness tests")
only_category <- rep(c("cat-1", "cat-4", "cat-5"), times = c(15L, 10L, 15L))
only_title <- vapply(seq_along(only_category), function(j) {
  topic <- draw(topics, 1L)
  switch(only_category[j],
    `cat-1` = paste0("Experience report ", j, ": ", topic,
                     " in a reserve medical company"),
    `cat-4` = paste0("Abstract ", j, ": ", topic, " at the ",
                     draw(site_pool, 1L), " medical conference"),
    `cat-5` = paste0(draw(c("Talk", "Poster"), 1L), " ", j, ": ", topic,
                     " for unit commanders")
  )
}, character(1))
reference_only <- data.frame(
  doi = ifelse(only_category == "cat-1",
               sprintf("10.9999/nonidx.%03d", seq_along(only_category)),
               NA_character_),
  title = only_title,
  year = draw(2016:2026, length(only_category), replace = TRUE),
  institution = draw(unname(unit_names), length(only_category),
                     replace = TRUE),
  category = only_category,
  stringsAsFactors = FALSE
)
reference <- rbind(reported, reference_only)
reference <- reference[order(reference$year, reference$title,
                             method = "radix"), ]
reference <- data.frame(id = sprintf("REF-%04d", seq_len(nrow(reference))),
                        reference, stringsAsFactors = FALSE)
rownames(reference) <- NULL

# ---- Web of Science plaintext twin -----------------------------------------

wos_field <- function(tag, values) {
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values) == 0L) return(character())
  c(paste(tag, values[1L]), if (length(values) > 1L) {
    paste0("   ", values[-1L])
  })
}

twin_record <- function(i) {
  a <- authorships[authorships$work_id == work_id[i], ]
  a <- a[order(a$position), ]
  pos <- unique(a$position)
  ids <- a$author_id[match(pos, a$position)]
  p <- match(ids, people$author_id)
  addr <- unique(a$raw_affiliation)
  c1 <- vapply(addr, function(x) {
    who <- unique(a$author_id[a$raw_affiliation == x])
    paste0("[", paste(people$full[match(who, people$author_id)],
                      collapse = "; "), "] ", x)
  }, character(1), USE.NAMES = FALSE)
  corr <- a[a$is_corresponding, ][1L, ]
  rp <- if (i == twin_no_rp) {
    NA_character_
  } else {
    paste0(people$short[match(corr$author_id, people$author_id)],
           " (corresponding author), ", corr$raw_affiliation)
  }
  r <- references[references$work_id == work_id[i], ]
  c("PT J",
    wos_field("AU", people$short[p]),
    wos_field("AF", people$full[p]),
    wos_field("TI", title[i]),
    wos_field("SO", journals$so[jrow[i]]),
    wos_field("LA", language[i]),
    wos_field("DT", type[i]),
    wos_field("DE", paste(keywords_de[[i]], collapse = "; ")),
    wos_field("ID", paste(keywords_id[[i]], collapse = "; ")),
    wos_field("AB", abstract[i]),
    wos_field("C1", c1),
    wos_field("RP", rp),
    wos_field("CR", r$cited_raw),
    wos_field("NR", as.character(nrow(r))),
    wos_field("TC", as.character(cited_by_count[i])),
    wos_field("SN", journals$issn[jrow[i]]),
    wos_field("EI", journals$eissn[jrow[i]]),
    wos_field("J9", journals$j9[jrow[i]]),
    wos_field("JI", journals$ji[jrow[i]]),
    wos_field("PY", as.character(years[i])),
    wos_field("VL", volume[i]),
    wos_field("BP", first_page[i]),
    wos_field("DI", doi[i]),
    wos_field("WC", wc[i]),
    wos_field("SC", paste(sc_list[[i]], collapse = "; ")),
    wos_field("UT", work_id[i]),
    "ER", "")
}
twin_lines <- c("FN Clarivate Analytics Web of Science", "VR 1.0",
                unlist(lapply(twin, twin_record)), "EF")

# ---- checks of the shapes the tests rely on --------------------------------

n_corr <- tapply(authorships$author_id[authorships$is_corresponding],
                 authorships$work_id[authorships$is_corresponding],
                 function(x) length(unique(x)))
cells <- stats::aggregate(list(n = seq_len(n_works)),
                          list(field = field, year = years), length)
cell_n <- cells$n[match(paste(field, years), paste(cells$field, cells$year))]
stopifnot(
  n_works == 150L,
  !anyDuplicated(work_id), !anyDuplicated(stats::na.omit(doi)),
  !anyDuplicated(title), identical(doi, tolower(doi)),
  all(is.na(quartile[years == 2026L])),
  all(tapply(!is.na(quartile), years, any)[as.character(2016:2025)]),
  mean(language == "German") > 0.1, mean(language == "German") < 0.2,
  length(n_corr) == n_works, all(n_corr == 1L),
  sum(cell_n == 1L & cited_by_count > 0L) >= 5L,
  mean(cell_n < 10L) > 0.25,
  sum(grepl("[^ -~]", authorships$raw_affiliation)) == 10L,
  length(twin) == 10L, sum(corr_position[twin] > 1L) == 4L,
  sum(references$cited_doi %in% stats::na.omit(doi)) > 0L,
  all(is.na(references$cited_work_id)),
  nrow(reference) == 160L
)
corr_partner <- vapply(author_lists, function(x) {
  !is_military[x$ids[x$corr]]
}, logical(1))
stopifnot(sum(corr_partner & corr_position > 1L) == 60L)

# Every non-ASCII string carries a UTF-8 mark, so the rds reads the same in
# every locale.
char_values <- function(x) {
  if (is.character(x)) return(x)
  if (is.list(x)) return(unlist(lapply(x, char_values), use.names = FALSE))
  character()
}
corpus_text <- char_values(unclass(corpus))
non_ascii <- corpus_text[grepl("[^ -~]", corpus_text, useBytes = TRUE)]
stopifnot(length(non_ascii) > 0L, all(Encoding(non_ascii) == "UTF-8"))

# ---- write -----------------------------------------------------------------

saveRDS(corpus, file.path(out_dir, "example_realuse_corpus.rds"),
        version = 3)
readr::write_csv(reference,
                 file.path(out_dir, "example_realuse_reference.csv"),
                 na = "")
readr::write_csv(dictionary,
                 file.path(out_dir, "example_realuse_affiliation_dict.csv"),
                 na = "")
dir.create(twin_dir, showWarnings = FALSE, recursive = TRUE)
con <- file(file.path(twin_dir, "realuse-wos-sample.txt"), open = "wb")
writeLines(enc2utf8(twin_lines), con, sep = "\n", useBytes = TRUE)
close(con)
