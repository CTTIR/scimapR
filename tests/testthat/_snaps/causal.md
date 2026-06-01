# sm_synth errors gracefully without tidysynth

    Code
      sm_synth(corpus, treated = "Inst A", donors = "Inst B", intervention_year = 2020,
        outcome = "count")
    Condition
      Error:
      ! Package tidysynth is required for `sm_synth()`.
      i Install it with `install.packages("tidysynth")`, or use `sm_did()` for a difference-in-differences comparison.

