# Synthetic real-use fixture for the scimapR tests, examples and vignettes.
#
# A table-built corpus that looks like a Web of Science export of three
# regional research institutions and their academic partners, a
# tracker-style reference list, an affiliation dictionary and a Web of
# Science plaintext twin of ten of the works. Everything is invented:
# institutions, cities, postcodes, people, journals, titles and DOIs
# (10.9999/...).
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
# R 4.6.1, aarch64-apple-darwin, locale C.UTF-8). Local input files are not
# registered here, because a registration time would change the rds.
#
# Shapes the tests rely on:
# - 150 works, 2016-2026 (1 in 2016, 2 in 2017, 10 in 2026); work_id is the
#   WoS accession (WOS:...); DOIs are lower case everywhere.
# - quartile is NA for every 2026 work and known for some work in every
#   other year; fwci has gaps; field is the first WoS category.
# - About 15% German works with German abstracts.
# - Exactly one corresponding author per work; in about 40% of the works a
#   academic partner who is not the first author. Authors with two address
#   rows keep one author_id, position and is_corresponding.
# - Ten authorship rows carry German address strings with non-ASCII
#   letters. Before Unicode-aware matching no dictionary pattern matches
#   them (the generic fallback pattern cannot reach them); afterwards eight
#   match their unit and two (a academic clinic) stay unmatched.
# - Three keyword themes (anchors "norovirus", "acute stroke care",
#   "night shift work"); works without an anchor keyword are editorials
#   and letters. One shift-work abstract repeats the invented token
#   "quillotyrase" 15 times.
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
  hospital = "Northtown General Hospital",
  microbiology = "Regional Institute of Microbiology Southcity",
  vet = "Veterinary Research Centre Nordstadt",
  other = "Sonstige Einrichtungen der Gesundheits\u00e4mter"
)

affiliations <- data.frame(
  key = c("hosp_trauma", "hosp_intmed", "hosp_anes", "hosp_emerg",
          "mic_main", "mic_virol", "mic_bact", "mic_outreach",
          "vet_hyg", "vet_lab", "vet_occ", "other_west", "other_east",
          "un_clinchem", "un_microbiol", "un_trauma", "sms_infect",
          "nuh_derm", "lake_epi", "hill_surg", "fjord_med", "alp_inf",
          "river_ph"),
  unit = c(rep("hospital", 4L), rep("microbiology", 4L), rep("vet", 3L),
           rep("other", 2L), rep(NA_character_, 10L)),
  org = c(rep("Northtown Gen Hosp", 4L),
          rep("Reg Inst Microbiol Southcity", 3L),
          "Northtown Gen Hosp",
          rep("Veterinarmed Res Ctr Nordstadt", 3L),
          "Westburg Publ Hlth Off", "Eastham Publ Hlth Off",
          rep("Univ Northtown", 3L), "Southcity Med Sch",
          "Nordstadt Univ Hosp", "Lakeside Univ", "Hilltop Univ Med Ctr",
          "Univ Fjordby", "Alpenau Cantonal Hosp", "Univ Riverside"),
  dept = c("Dept Trauma Surg", "Dept Internal Med", "Dept Anesthesiol",
           "Dept Emergency Med", "", "Dept Virol", "Dept Bacteriol",
           "Reg Inst Microbiol Outreach Lab", "Dept Hyg",
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
  target = c("vet", "vet", "vet", "microbiology", "microbiology",
             "hospital", "hospital", "hospital", "nuh", "nuh"),
  text = c(
    rep(paste0("Veterin\u00e4rmedizinisches Forschungszentrum Nordstadt, ",
               "Abt. \u00d6kologie"), 2L),
    "Abt. \u00d6kologie und Lehre, Nordstadt",
    rep("Landesinstitut f\u00fcr Mikrobiologie, Southcity", 2L),
    rep(paste0("St\u00e4dtisches Krankenhaus Northtown, Klinik f\u00fcr ",
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
  institution = unname(unit_names[c("microbiology", "microbiology", "vet",
                                    "vet", "hospital", "hospital",
                                    "hospital", "other")]),
  pattern = c(
    "reg\\w* inst\\w* microbiol",
    "landesinstitut f\\w+r mikrobiologie",
    "veterin\\w+rmed",
    "\\b\u00f6kologie\\b",
    "northtown gen\\w* hosp",
    "st\\w+dtisches krankenhaus northtown",
    "\\bfu\u00df\\b.*\\bnorthtown\\b",
    "\\bhlth off\\b"
  ),
  email_domain = c("microbiology-southcity.example", NA,
                   "vetresearch-nordstadt.example", NA,
                   "hospital-northtown.example", NA, NA, NA),
  stringsAsFactors = FALSE
)

# ---- journals --------------------------------------------------------------

journals <- data.frame(
  key = c("jexm", "eidr", "asur", "fepl", "ijsc", "afmi", "sswr", "zbsm",
          "ejph", "oetx"),
  so = c("JOURNAL OF EXAMPLE MEDICINE",
         "EXAMPLE INFECTIOUS DISEASE REPORTS",
         "ANNALS OF SYNTHETIC NEUROLOGY",
         "FIELD EPIDEMIOLOGY LETTERS",
         "INTERNATIONAL JOURNAL OF INVENTED STROKE CARE",
         "ACTA FICTA MICROBIOLOGICA",
         "SLEEP AND SHIFT WORK RESEARCH",
         "ZEITSCHRIFT FUR BEISPIELMEDIZIN",
         "EXAMPLE JOURNAL OF PUBLIC HEALTH",
         "OPEN EXAMPLE TOXICOLOGY"),
  j9 = c("J EXAMPLE MED", "EX INFECT DIS REP", "ANN SYNTH NEUROL",
         "FIELD EPIDEMIOL LETT", "INT J INVENT STROKE C",
         "ACTA FICTA MICROBIOL", "SLEEP SHIFT WORK RES", "Z BEISPIELMED",
         "EX J PUBLIC HEALTH", "OPEN EX TOXICOL"),
  ji = c("J. Example Med.", "Ex. Infect. Dis. Rep.", "Ann. Synth. Neurol.",
         "Field Epidemiol. Lett.", "Int. J. Invent. Stroke Care",
         "Acta Ficta Microbiol.", "Sleep Shift Work Res.",
         "Z. Beispielmed.", "Ex. J. Public Health", "Open Ex. Toxicol."),
  wc = c("Medicine, General & Internal",
         "Infectious Diseases; Microbiology",
         "Clinical Neurology",
         "Public, Environmental & Occupational Health; Infectious Diseases",
         "Emergency Medicine; Clinical Neurology",
         "Microbiology",
         "Physiology; Public, Environmental & Occupational Health",
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
  "Clinical Neurology" = "Neurosciences & Neurology",
  "Public, Environmental & Occupational Health" =
    "Public, Environmental & Occupational Health",
  "Emergency Medicine" = "Emergency Medicine",
  "Physiology" = "Physiology",
  "Toxicology" = "Toxicology",
  "Pharmacology & Pharmacy" = "Pharmacology & Pharmacy"
)

theme_journals <- list(
  `0` = c(jexm = 0.4, oetx = 0.3, zbsm = 0.3),
  `1` = c(eidr = 0.35, fepl = 0.25, afmi = 0.25, ejph = 0.15),
  `2` = c(asur = 0.35, ijsc = 0.4, jexm = 0.25),
  `3` = c(sswr = 0.45, jexm = 0.25, ejph = 0.3)
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
  mic_main = 6L, mic_virol = 4L, mic_bact = 3L, mic_outreach = 1L,
  vet_hyg = 5L, vet_lab = 4L, vet_occ = 3L, other_west = 3L,
  other_east = 3L, un_clinchem = 3L, un_microbiol = 3L, sms_infect = 4L,
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
people$second[people$home == "mic_virol"][1:2] <- "un_microbiol"
people$second[people$home == "mic_main"][1] <- "un_microbiol"
people$second[people$home == "vet_lab"][1:2] <- "un_clinchem"
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
populations <- c("nurses", "care home residents", "hospital staff",
                 "junior doctors", "students", "kitchen staff",
                 "construction workers", "general practitioners",
                 "paramedics", "port workers")
populations_de <- c("Pflegekr\u00e4ften", "Lehrlingen", "Ehrenamtlichen",
                    "Rettungskr\u00e4ften", "Auszubildenden")
designs <- c("cohort study", "cross-sectional survey", "case series",
             "nested case-control study", "retrospective analysis",
             "prospective study", "registry study", "surveillance report")
seasons <- c("spring", "summer", "autumn", "winter")
seasons_de <- c("Fr\u00fchjahr", "Sommer", "Herbst", "Winter")

title_templates <- list(
  `1` = c("{a} at the {site} care home, {y1}-{y2}",
          "{b}: {n} samples from {site}",
          "{a} and {c} near {site}",
          "{b} and {a} in {n} {pop} at {site}",
          "{c} in {site}: {n} cases, {y1}-{y2}"),
  `2` = c("{a} at {site}: {n} patients, {y1}-{y2}",
          "{b} and {c} in {n} patients at {site}",
          "{a} after {b}: {n} cases from {site}",
          "{c} following {a} at {site}",
          "{b} in {n} {pop}, {site} registry"),
  `3` = c("{a} during winter rotas at {site}",
          "{b} and {c} in {n} {pop} at {site}",
          "{a} on a night ward near {site}: {n} cases",
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
    a = c("norovirus gastroenteritis", "norovirus outbreaks",
          "acute gastroenteritis", "food-borne infection",
          "viral gastroenteritis", "enteric virus shedding"),
    b = c("outbreak surveillance", "environmental swabbing",
          "genotyping of stool samples", "hand hygiene audits",
          "ward closure policies", "wastewater monitoring",
          "contact tracing", "cleaning protocols",
          "climate covariates", "laboratory screening"),
    c = c("attack rates", "case clustering", "seasonal risk",
          "staff absence", "outbreak duration", "bed days lost",
          "kitchen hygiene", "shared dining rooms", "hospital admissions",
          "secondary transmission")
  ),
  `2` = list(
    a = c("acute stroke care", "ischaemic stroke treatment",
          "mechanical thrombectomy", "intravenous thrombolysis",
          "stroke unit care", "reperfusion therapy"),
    b = c("prehospital stroke scales", "telestroke consultation",
          "mobile stroke units", "CT perfusion imaging",
          "direct transfer to angiography", "nurse-led triage",
          "blood pressure lowering", "dual antiplatelet therapy",
          "early mobilisation", "stroke team activation"),
    c = c("functional outcome", "haemorrhagic transformation",
          "time to treatment", "mortality", "recurrence",
          "length of stay", "discharge destination", "swallowing recovery",
          "readmission", "quality of life")
  ),
  `3` = list(
    a = c("night shift work", "shift work sleep disorder",
          "circadian misalignment", "sleep deprivation", "fatigue",
          "insomnia"),
    b = c("bright light exposure", "rota design", "planned napping",
          "melatonin use", "actigraphy monitoring", "caffeine intake",
          "forward-rotating schedules", "sleep hygiene education",
          "workload", "physical activity"),
    c = c("sleep duration", "error rates", "staff turnover",
          "cardiometabolic risk", "alertness", "sick leave", "mood",
          "glucose tolerance", "cognitive performance", "return to work")
  ),
  `0` = list(
    a = c("occupational medicine", "medical education",
          "community health services", "clinical governance",
          "health services research", "primary care",
          "municipal nursing", "emergency planning"),
    b = c("district hospital staffing", "simulation-based training",
          "workforce resilience", "data sharing in health care",
          "guideline adoption", "peer review", "open access publishing",
          "career pathways")
  )
)
title_templates_de <- list(
  `1` = c("Norovirus-Ausbr\u00fcche bei {n} {pop} im Raum {site}",
          "Hygienema\u00dfnahmen und Erkrankungsraten bei {n} {pop} in {site}"),
  `2` = c(paste0("Schlaganfallversorgung in der pr\u00e4klinischen Phase: ",
                 "{n} Patienten aus {site}"),
          "Thrombolyse und \u00dcberleben bei {n} Patienten in {site}"),
  `3` = c(paste0("Schlafst\u00f6rungen bei {n} {pop} w\u00e4hrend der ",
                 "Nachtschicht in {site}"),
          "Lichtexposition und Schichtplanung bei {n} {pop} in {site}"),
  `0` = c("Aufgaben der medizinischen Ausbildung in {site}: ein Kommentar",
          "Antwort auf die Kommentare zu unserer Arbeit \u00fcber {site}")
)

sentences <- list(
  `1` = c(
    paste0("We tested {n} stool samples from {k} care homes around {site} ",
           "for norovirus."),
    "Infection occurred in {p} percent of {pop} during outbreaks.",
    "Case numbers peaked in {season} and preceded hospital admissions.",
    "Outbreak surveillance was combined with genotyping of stool samples.",
    "Transmission was highest in shared dining rooms and bathrooms.",
    "Contaminated kitchen surfaces were the likely source.",
    "Most infections caused vomiting, diarrhoea and short-lived dehydration.",
    "Winters with new variants were followed by large outbreaks.",
    "Sequencing placed the strains in a lineage circulating in the region.",
    "Hygiene briefings and ward closures reduced new infections.",
    "Reported cases underestimated the burden of mild infections.",
    "Surveillance data from {k} seasons were linked with weather records."
  ),
  `2` = c(
    "We analysed {n} patients recorded in the {site} stroke registry.",
    "Early thrombolysis was associated with better functional outcome.",
    "Door-to-needle times shortened after prehospital alerts were introduced.",
    "Mechanical thrombectomy was completed in {p} percent of patients.",
    "Large vessel occlusion remained the leading cause of severe disability.",
    "Stroke recognition training improved skills among {pop}.",
    "Dysphagia screening was done in {p} percent of admissions.",
    "Haemorrhagic transformation did not increase with earlier treatment.",
    "The stroke team was activated {k} times a week.",
    "CT perfusion imaging guided the choice of treatment.",
    "Direct transfer to angiography reduced time to reperfusion by {m} minutes.",
    "Blood pressure lowering before treatment was not associated with harm."
  ),
  `3` = c(
    paste0("Sleep was recorded with actigraphy in {n} {pop} during a ",
           "{k}-week rota near {site}."),
    "Forward-rotating schedules over {k} weeks lowered the incidence of insomnia.",
    "A planned nap restored alertness within {m} minutes.",
    "Workload and the number of consecutive nights predicted errors.",
    "Caffeine intake did not differ between affected and unaffected {pop}.",
    "Shift work sleep disorder occurred in {p} percent of the staff.",
    "Planned naps were the most effective countermeasure on night shifts.",
    "A recent change of rota increased the risk of fatigue.",
    "Wrist-worn sensors were tolerated well during shifts.",
    "Rotas adapted to individual chronotypes prevented most complaints.",
    "Return to work after sick leave took a median of {k} weeks.",
    "Low physical activity was associated with poor sleep quality.",
    "Melatonin levels peaked later after consecutive night shifts.",
    "Sleep duration varied widely between individuals.",
    "Early morning shifts reduced the cumulative sleep debt.",
    "Long commutes added a substantial burden.",
    "Sleep restriction impaired vigilance in the early morning.",
    "Ward managers recognised early symptoms in most instances.",
    "Light exposure mattered more than the number of night shifts.",
    "Prior episodes predicted recurrence within the same year."
  ),
  `0` = c(
    "This editorial discusses research priorities for occupational medicine.",
    paste0("Recent work on night shift work, acute stroke care and ",
           "norovirus surveillance shows how routine data improve care."),
    "We comment on recent clinical guidelines and their use in training.",
    "Medical education has to adapt to new clinical requirements.",
    "The authors reply to the comments on their earlier article.",
    "Data sharing between municipal and private hospitals remains limited.",
    "Simulation-based training can close gaps in clinical experience.",
    "Resilience depends on staff, equipment and regular team training."
  )
)
sentences_de <- list(
  `1` = c(
    paste0("Wir untersuchten {n} Stuhlproben aus {k} Pflegeheimen auf ",
           "Noroviren."),
    paste0("Die Erkrankungsrate bei den {pop} lag w\u00e4hrend der ",
           "Ausbr\u00fcche bei {p} Prozent."),
    paste0("Die Fallzahlen stiegen im {season} an und gingen den ",
           "Krankenhausaufnahmen voraus."),
    paste0("Die meisten Infektionen verliefen mit Erbrechen und einer ",
           "vor\u00fcbergehenden Austrocknung."),
    paste0("Hygieneschulungen und Stationsschlie\u00dfungen ",
           "senkten die Zahl der Neuinfektionen.")
  ),
  `2` = c(
    "Wir analysierten {n} Patienten aus dem Schlaganfallregister in {site}.",
    paste0("Die fr\u00fche Thrombolyse war mit einer ",
           "geringeren Sterblichkeit verbunden."),
    paste0("Die pr\u00e4klinische Erkennung und die Voranmeldung ",
           "wurden durch Schulungen verbessert."),
    paste0("Die direkte Verlegung in die Angiographie verk\u00fcrzte die ",
           "Zeit bis zur Rekanalisation um {m} Minuten."),
    "Die Thrombektomie wurde in {p} Prozent der F\u00e4lle durchgef\u00fchrt."
  ),
  `3` = c(
    paste0("Der Schlaf wurde bei {n} Pflegekr\u00e4ften ",
           "w\u00e4hrend der Nachtschicht gemessen."),
    paste0("Vorw\u00e4rts rotierende Dienstpl\u00e4ne \u00fcber {k} Wochen ",
           "senkten die Rate der Schlafst\u00f6rungen."),
    paste0("Geplante Pausen und ausreichende Fl\u00fcssigkeitszufuhr ",
           "verhinderten schwere Ersch\u00f6pfung."),
    "Die Belastung und die Zahl der Nachtdienste sagten die Fehler voraus.",
    "Die R\u00fcckkehr in den Dienst dauerte im Median {k} Wochen."
  ),
  `0` = c(
    paste0("Der Beitrag diskutiert die Ausbildung und die Forschung im ",
           "Rettungsdienst."),
    "Die Autoren antworten auf die Kommentare zu ihrem Artikel.",
    paste0("Die Zusammenarbeit mit akademischen Kliniken und die ",
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

# One shift-work article repeats an invented token 15 times.
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
  `0` = c(hospital = 0.4, microbiology = 0.2, vet = 0.25, other = 0.15),
  `1` = c(microbiology = 0.5, vet = 0.35, other = 0.15),
  `2` = c(hospital = 0.85, other = 0.15),
  `3` = c(hospital = 0.45, vet = 0.45, other = 0.1)
)
is_municipal <- !is.na(people$unit)

theme_people <- function(t, municipal) {
  ok <- is_municipal == municipal
  if (t > 0L) ok <- ok & grepl(as.character(t), people$themes, fixed = TRUE)
  which(ok)
}

seed_block(5L)
# 60 of the 150 works (40%) get a academic corresponding author at position
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
  # a academic corresponding author must sit at position 2 or later
  if (corr_kind[i] == "partner" && all(is_municipal[ids[-1L]])) {
    ids[length(ids)] <- draw(setdiff(theme_people(t, FALSE), ids), 1L)
  }
  # every work has a unit author
  if (!any(is_municipal[ids])) {
    ids[1L] <- draw(setdiff(lead_pool, ids), 1L)
  }
  after_first <- seq_along(ids) > 1L
  partners_later <- which(!is_municipal[ids] & after_first)
  municipal_later <- which(is_municipal[ids] & after_first)
  corr <- switch(corr_kind[i],
    partner = partners_later[draw(seq_along(partners_later), 1L)],
    first = 1L,
    last = if (length(municipal_later) > 0L) max(municipal_later) else 1L
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
    vet = c("vet_hyg", "vet_lab", "vet_occ"),
    microbiology = c("mic_main", "mic_virol", "mic_bact"),
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
  "CLIN EX NEUROL", "STROKE CARE REV", "J SLEEP RES EX",
  "ENTERIC INFECT EX", "EX EPIDEMIOL INFECT", "CEREBROVASC EX MED",
  "OCCUP MED EX", "CHRONOBIOL EX", "J SYNTH VIROL", "NEUROL EX",
  "EX CRIT CARE", "J APPL PHYSIOL EX", "EX PUBLIC HEALTH REV",
  "FOODBORNE EX", "BEISPIEL ARCH HYG", "J INVENT EMERG MED",
  "EX OCCUP HLTH REP"
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
  `1` = c("outbreak surveillance", "care homes", "field epidemiology",
          "genotyping", "hand hygiene", "viral gastroenteritis",
          "food safety", "molecular typing"),
  `2` = c("thrombolysis", "prehospital care", "mechanical thrombectomy",
          "stroke unit", "stroke registry", "large vessel occlusion",
          "telemedicine", "door-to-needle time"),
  `3` = c("circadian rhythm", "sleep quality", "actigraphy",
          "nursing staff", "light exposure", "fatigue", "napping",
          "chronotype"),
  `0` = c("medical education", "health policy", "clinical guidelines",
          "research priorities", "workforce", "ethics")
)
anchors <- c(`1` = "norovirus", `2` = "acute stroke care",
             `3` = "night shift work")
plus_pools <- list(
  `1` = c("INFECTION", "EPIDEMIOLOGY", "VIRUS", "TRANSMISSION", "OUTBREAKS",
          "EUROPE", "GASTROENTERITIS"),
  `2` = c("MORTALITY", "STROKE", "REPERFUSION", "MANAGEMENT", "DISABILITY",
          "THERAPY", "OUTCOMES"),
  `3` = c("SLEEP", "NIGHT-WORK", "ALERTNESS", "PERFORMANCE", "SHIFT-WORK",
          "HUMANS", "MELATONIN"),
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

municipal_rows <- authorships[!is.na(people$unit[match(authorships$author_id,
                                                      people$author_id)]), ]
reporting_unit <- vapply(work_id, function(w) {
  r <- municipal_rows[municipal_rows$work_id == w, ]
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
            "sleep deprivation", "dental health",
            "mental health screening", "telemedicine pilots",
            "blood supply logistics", "workplace fitness tests")
only_category <- rep(c("cat-1", "cat-4", "cat-5"), times = c(15L, 10L, 15L))
only_title <- vapply(seq_along(only_category), function(j) {
  topic <- draw(topics, 1L)
  switch(only_category[j],
    `cat-1` = paste0("Experience report ", j, ": ", topic,
                     " in a community nursing team"),
    `cat-4` = paste0("Abstract ", j, ": ", topic, " at the ",
                     draw(site_pool, 1L), " medical conference"),
    `cat-5` = paste0(draw(c("Talk", "Poster"), 1L), " ", j, ": ", topic,
                     " for ward managers")
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
  !is_municipal[x$ids[x$corr]]
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
