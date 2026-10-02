# Install the R packages used by IPT-Model.
#
# Usage: Rscript scripts/00_setup.R
# The model needs R >= 4.1 (native pipe). Packages are installed from CRAN into
# the default user library if they are missing.

packages <- c(
  "dplyr",       # data manipulation
  "tidyr",       # reshaping
  "readr",       # CSV input/output
  "tibble",      # data frames
  "data.table",  # fast reading of the large StatCan and ICIO files
  "yaml",        # configuration files
  "sandwich",    # cluster-robust standard errors for the gravity regressions
  "testthat"     # unit tests
)

if (getRversion() < "4.1.0") stop("IPT-Model requires R >= 4.1.")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  message("Installing: ", paste(missing, collapse = ", "))
  install.packages(missing, repos = "https://cloud.r-project.org")
} else {
  message("All required packages are installed.")
}
