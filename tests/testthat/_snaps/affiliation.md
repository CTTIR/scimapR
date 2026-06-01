# sm_attribute_institution errors without ror_table

    Code
      sm_attribute_institution(corpus, vocabulary = "ror")
    Condition
      Error:
      ! `ror_table` is required for "ror" vocabulary.
      i Supply an offline ROR table with columns ror_id, name, aliases.
      i A synthetic example is at `system.file("extdata", "example_ror.csv", package = "scimapR")`.

