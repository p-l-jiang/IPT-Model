# Entry point for the IPT-Model function library.
#
# All pipeline scripts and tests run from the repository root and call
#   source("src/load.R")
# which attaches the required packages and sources every module in src/.

local({
  if (!file.exists(file.path("src", "load.R"))) {
    stop("IPT-Model scripts must be run from the repository root ",
         "(the folder that contains src/, config/ and scripts/).", call. = FALSE)
  }

  required <- c("dplyr", "tidyr", "readr", "data.table", "yaml", "sandwich")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop("Missing R packages: ", paste(missing, collapse = ", "),
         ". Run `Rscript scripts/00_setup.R` first.", call. = FALSE)
  }
  suppressPackageStartupMessages({
    library(dplyr)
    library(tidyr)
    library(readr)
  })
  options(dplyr.summarise.inform = FALSE, scipen = 999, ipt.root = normalizePath("."))

  modules <- c(
    "utils.R", "config.R", "concordance.R", "statcan.R", "icio.R", "fx.R",
    "distance.R", "trade_flows.R", "io_parameters.R", "trade_elasticities.R",
    "trade_costs.R", "calibration.R", "solver.R", "scenarios.R", "results.R"
  )
  for (m in modules) sys.source(file.path("src", m), envir = globalenv())
})
