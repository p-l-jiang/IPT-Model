# Run the IPT-Model test suite from the repository root:
#   Rscript tests/testthat.R
source("src/load.R")
testthat::test_dir("tests/testthat", reporter = "summary", stop_on_failure = TRUE)
