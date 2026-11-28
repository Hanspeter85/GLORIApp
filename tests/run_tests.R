# =============================================================================
# tests/run_tests.R  -  Run all unit tests (testthat)
# =============================================================================
# From the repo root:   Rscript tests/run_tests.R
# or in RStudio:        source("tests/run_tests.R")
# The tests build a tiny synthetic GLORIA in a temporary folder; the real data
# are not touched. See tests/testthat/test-*.R for what is tested.
# =============================================================================
library(testthat)
res <- test_dir("tests/testthat", reporter = "summary", stop_on_failure = FALSE)
df <- as.data.frame(res)
cat(sprintf("\n%d tests: %d passed, %d failed, %d skipped\n",
            sum(df$nb), sum(df$nb) - sum(df$failed) - sum(df$skipped), sum(df$failed), sum(df$skipped)))
if (sum(df$failed) > 0 || any(df$error)) quit(status = 1)
