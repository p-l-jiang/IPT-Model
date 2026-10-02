# Run the counterfactual scenarios listed in the configuration.
#
# Usage: Rscript scripts/07_run_scenarios.R [--config config/default.yml] [--only id1,id2]

source("src/load.R")
cfg <- script_config()
args <- commandArgs(trailingOnly = TRUE)
only <- if ("--only" %in% args) strsplit(args[match("--only", args) + 1], ",")[[1]] else NULL

base <- readRDS(processed_path(cfg, "baseline.rds"))
costs_file <- processed_path(cfg, "trade_cost_decomposition.csv")
costs <- if (file.exists(costs_file)) readr::read_csv(costs_file, show_col_types = FALSE) else NULL
scenarios <- load_scenarios(cfg)
if (!is.null(only)) scenarios <- scenarios[intersect(names(scenarios), only)]

summary_rows <- list()
lines <- c(sprintf("# Scenario results: %s", cfg$name), "",
           sprintf("Configuration `%s`, calibration year %d. Percent changes relative to the baseline.",
                   cfg$config_file, cfg$years$target), "")
for (s in scenarios) {
  sol <- run_scenario(s, base, cfg, costs)
  if (!sol$converged) warnf("Scenario %s did not converge.", s$id)
  res <- write_scenario_results(sol, base, cfg, output_dir(cfg, s$id))
  can <- res$canada
  summary_rows[[s$id]] <- tibble(scenario = s$id, label = s$label,
                                 canada_real_income = can$change_pct[can$measure == "real_income"],
                                 canada_real_income_per_capita = can$change_pct[can$measure == "real_income_per_capita"],
                                 converged = sol$converged, iterations = sol$iterations)
  tab <- format_region_table(res$regions)
  lines <- c(lines, sprintf("## %s", s$label), "", sprintf("Scenario id: `%s`", s$id), "",
             markdown_table(tab), "",
             sprintf("Canada (weights: %s): real income %.3f%%; real income per capita %.3f%%.",
                     can$weights[1], can$change_pct[1], can$change_pct[2]), "")
}
summary <- bind_rows(summary_rows)
write_table(summary, file.path(output_dir(cfg), "summary.csv"))
writeLines(lines, file.path(output_dir(cfg), "summary.md"))
print(summary |> mutate(across(where(is.numeric), \(x) round(x, 4))), n = Inf, width = Inf)
log_info("Results written to ", output_dir(cfg))
