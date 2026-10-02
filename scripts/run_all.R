# Run the whole pipeline for one configuration.
#
# Usage: Rscript scripts/run_all.R [--config config/default.yml] [--from 3]
#   --from k  start at step k (e.g. 5 to re-estimate trade costs and re-run the
#             model without rebuilding the data).

args <- commandArgs(trailingOnly = TRUE)
from <- if ("--from" %in% args) as.integer(args[match("--from", args) + 1]) else 1L
steps <- c("01_download_data.R", "02_build_distances.R", "03_build_trade_flows.R",
           "04_build_io_parameters.R", "05_estimate_trade_costs.R", "06_calibrate.R",
           "07_run_scenarios.R")
for (k in seq_along(steps)) {
  if (k < from) next
  message("\n=== Step ", k, ": ", steps[k], " ===")
  source(file.path("scripts", steps[k]), local = new.env())
}
