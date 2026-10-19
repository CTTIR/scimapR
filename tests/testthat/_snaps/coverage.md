# sm_journal_in_index errors without a reference list

    Code
      sm_journal_in_index("1078-8956")
    Condition
      Error:
      ! `reference_list` is required.
      i Supply a journal master list (e.g. a WoS/Scopus/DOAJ export).
      i scimapR does not ship proprietary lists; a synthetic example is at `system.file("extdata", "example_journal_index.csv", package = "scimapR")`.

# unknown breakdown names abort with the available columns

    Code
      sm_coverage_audit(corpus, ref, by = c("unit", "units", "Year2"), match = "doi")
    Condition
      Error:
      ! Can't break the coverage down by "units" and "Year2".
      x These names are neither a named dimension nor a column of `reference` or of `corpus$works`.
      i Named dimensions: "year", "source", and "affiliation".
      i Columns of `reference`: "id", "doi", and "unit".
      i Columns of `corpus$works`: "work_id", "doi", and "year".

